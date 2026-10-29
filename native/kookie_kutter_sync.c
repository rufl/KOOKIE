#define _POSIX_C_SOURCE 200809L
#include "kookie_kutter_sync.h"
#include <curl/curl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if defined(_WIN32)
#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
typedef HANDLE ks_thread;
typedef CRITICAL_SECTION ks_mutex;
#define KS_LOCK() EnterCriticalSection(&mutex)
#define KS_UNLOCK() LeaveCriticalSection(&mutex)
#define KS_SLEEP() Sleep(10)
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <pthread.h>
#include <strings.h>
#include <time.h>
typedef pthread_t ks_thread;
typedef pthread_mutex_t ks_mutex;
#define KS_LOCK() pthread_mutex_lock(&mutex)
#define KS_UNLOCK() pthread_mutex_unlock(&mutex)
#define KS_SLEEP() do { struct timespec delay={0,10000000}; nanosleep(&delay,NULL); } while(0)
#endif
#if !defined(_WIN32)
#include <poll.h>
#endif
#if defined(_WIN32)
#define KS_STRCASECMP _stricmp
#else
#define KS_STRCASECMP strcasecmp
#endif

#define KS_MAX_WORDS 320
#define KS_MAX_FRAME (16 + KS_MAX_WORDS * 4)
#define KS_QUEUE 16
#define KS_PATH_MAX 256
static ks_mutex mutex;
static int mutex_ready, curl_ready, state, stopping, send_count, send_staged, send_pending, send_active;
static int send_words[KS_MAX_WORDS];
static int recv_queue[KS_QUEUE][KS_MAX_WORDS];
static int recv_counts[KS_QUEUE], recv_head, recv_tail, recv_size;
static unsigned session_epoch;

typedef struct { unsigned epoch; } worker_arg;
static int is_local_host(const char *host) {
    if (!KS_STRCASECMP(host, "localhost") || !KS_STRCASECMP(host, "localhost.")) return 1;
    unsigned char v4[4], v6[16];
    if (inet_pton(AF_INET, host, v4) == 1) return v4[0] == 127;
    if (inet_pton(AF_INET6, host, v6) == 1) {
        static const unsigned char loopback[16] = {0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1};
        return memcmp(v6, loopback, sizeof v6) == 0;
    }
    return 0;
}
static int worker_stopped(unsigned epoch) {
    KS_LOCK(); int stop = stopping || session_epoch != epoch; KS_UNLOCK(); return stop;
}
static int transfer_progress(void *opaque, curl_off_t dltotal, curl_off_t dlnow,
                             curl_off_t ultotal, curl_off_t ulnow) {
    (void)dltotal; (void)dlnow; (void)ultotal; (void)ulnow;
    return worker_stopped(*(unsigned *)opaque);
}
static CURL *connect_server(unsigned epoch, unsigned *arg_epoch, struct curl_slist **headers_out) {
    const char *host = getenv("KOOKIE_KUTTER_HOST");
    const char *port = getenv("KOOKIE_KUTTER_PORT");
    const char *path = getenv("KOOKIE_KUTTER_PATH");
    const char *scheme = getenv("KOOKIE_KUTTER_SCHEME");
    if (!scheme || !*scheme) scheme = "wss";
    if (!host || !*host || !port || !*port) return NULL;
    char *end = NULL; long port_num = strtol(port, &end, 10);
    if (!end || *end || port_num < 1 || port_num > 65535) return NULL;
    if (strcmp(scheme, "ws") && strcmp(scheme, "wss")) return NULL;
    if (!strcmp(scheme, "ws") && !is_local_host(host)) return NULL;
    if (!path || !*path) path = "/kutter/session";
    if (path[0] != '/' || strlen(path) >= KS_PATH_MAX) return NULL;
    char url[KS_PATH_MAX + 512];
    int ipv6 = strchr(host, ':') != NULL && host[0] != '[';
    int n = snprintf(url, sizeof url, "%s://%s%s%s:%ld%s", scheme,
                     ipv6 ? "[" : "", host, ipv6 ? "]" : "", port_num, path);
    if (n < 0 || (size_t)n >= sizeof url) return NULL;
    const char *token = getenv("KOOKIE_KUTTER_TOKEN");
    char protocol_header[192];
    if (token && *token) {
        size_t token_len = strlen(token);
        if (token_len < 8 || token_len > 128) return NULL;
        for (size_t i=0; i<token_len; i++) {
            unsigned char c=(unsigned char)token[i];
            if (!((c>='A'&&c<='Z')||(c>='a'&&c<='z')||
                  (c>='0'&&c<='9')||c=='.'||c=='_'||c=='~'||c=='-')) return NULL;
        }
        snprintf(protocol_header,sizeof protocol_header,"Sec-WebSocket-Protocol: kookie.v1, bearer.%s",token);
    } else {
        strcpy(protocol_header,"Sec-WebSocket-Protocol: kookie.v1");
    }
    CURL *curl = curl_easy_init();
    if (!curl) return NULL;
    struct curl_slist *headers = curl_slist_append(NULL, protocol_header);
    if (!headers) { curl_easy_cleanup(curl); return NULL; }
    *arg_epoch = epoch;
    curl_easy_setopt(curl, CURLOPT_URL, url);
    curl_easy_setopt(curl, CURLOPT_CONNECT_ONLY, 2L);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, 10000L);
    curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(curl, CURLOPT_XFERINFOFUNCTION, transfer_progress);
    curl_easy_setopt(curl, CURLOPT_XFERINFODATA, arg_epoch);
    curl_easy_setopt(curl, CURLOPT_NOPROGRESS, 0L);
    CURLcode rc = curl_easy_perform(curl);
    if (rc != CURLE_OK || worker_stopped(epoch)) {
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
        return NULL;
    }
    *headers_out = headers;
    return curl;
}
static int pack_message(const int *words, int count, unsigned char *out, size_t *length) {
    if (count < 3 || count > KS_MAX_WORDS) return 0;
    size_t n = 16 + (size_t)count * 4;
    memcpy(out, "KWS1", 4); out[4] = 1; out[5] = (unsigned char)words[1];
    out[6] = out[7] = 0;
    uint32_t seq = (uint32_t)words[2];
    out[8] = (unsigned char)(seq >> 24); out[9] = (unsigned char)(seq >> 16);
    out[10] = (unsigned char)(seq >> 8); out[11] = (unsigned char)seq;
    out[12] = (unsigned char)(count >> 8); out[13] = (unsigned char)count;
    out[14] = out[15] = 0;
    for (int i = 0; i < count; i++) {
        uint32_t v = (uint32_t)words[i]; size_t j = 16 + (size_t)i * 4;
        out[j] = (unsigned char)(v >> 24); out[j+1] = (unsigned char)(v >> 16);
        out[j+2] = (unsigned char)(v >> 8); out[j+3] = (unsigned char)v;
    }
    unsigned sum = 0;
    for (size_t i = 0; i < n; i++) sum = (sum + (unsigned)((uint64_t)out[i] * (i+1))) & 65535;
    out[14] = (unsigned char)(sum >> 8); out[15] = (unsigned char)sum; *length = n;
    return 1;
}
static int deliver_message(const unsigned char *data, size_t length, unsigned epoch) {
    if (length < 16 || memcmp(data, "KWS1", 4) || data[4] != 1) return 0;
    unsigned count = ((unsigned)data[12] << 8) | data[13];
    if (count < 3 || count > KS_MAX_WORDS || length != 16 + count * 4 || data[6] || data[7]) return 0;
    unsigned sum = 0;
    for (size_t i=0;i<length;i++) { unsigned v=(i==14||i==15)?0:data[i]; sum=(sum+(unsigned)((uint64_t)v*(i+1)))&65535; }
    if (sum != (((unsigned)data[14] << 8) | data[15])) return 0;
    int words[KS_MAX_WORDS];
    for (unsigned i=0;i<count;i++) { unsigned j=16+i*4; words[i]=(int32_t)(((uint32_t)data[j]<<24)|((uint32_t)data[j+1]<<16)|((uint32_t)data[j+2]<<8)|data[j+3]); }
    if ((uint32_t)words[1] != (uint32_t)data[5] || (uint32_t)words[2] != (((uint32_t)data[8]<<24)|((uint32_t)data[9]<<16)|((uint32_t)data[10]<<8)|data[11])) return 0;
    KS_LOCK();
    while (recv_size >= KS_QUEUE && !stopping && session_epoch == epoch) { KS_UNLOCK(); KS_SLEEP(); KS_LOCK(); }
    if (stopping || session_epoch != epoch) { KS_UNLOCK(); return 0; }
    memcpy(recv_queue[recv_tail], words, count * sizeof(int)); recv_counts[recv_tail]=(int)count;
    recv_tail=(recv_tail+1)%KS_QUEUE; recv_size++; KS_UNLOCK(); return 1;
}
static int wait_socket(CURL *curl, int writing) {
    curl_socket_t socket_fd = CURL_SOCKET_BAD;
    if (curl_easy_getinfo(curl, CURLINFO_ACTIVESOCKET, &socket_fd) != CURLE_OK ||
        socket_fd == CURL_SOCKET_BAD) return 0;
#if defined(_WIN32)
    WSAPOLLFD descriptor;
    descriptor.fd = socket_fd;
    descriptor.events = writing ? POLLWRNORM : POLLRDNORM;
    descriptor.revents = 0;
    return WSAPoll(&descriptor, 1, 50) >= 0;
#else
    struct pollfd descriptor;
    descriptor.fd = socket_fd;
    descriptor.events = writing ? POLLOUT : POLLIN;
    descriptor.revents = 0;
    return poll(&descriptor, 1, 50) >= 0;
#endif
}

static int send_frame(CURL *curl, const unsigned char *data, size_t length) {
    size_t offset = 0;
    while (offset < length) {
        size_t sent = 0;
        CURLcode rc = curl_ws_send(curl, data + offset, length - offset, &sent, 0, CURLWS_BINARY);
        if (sent > length - offset) return 0;
        offset += sent;
        if (rc == CURLE_AGAIN) {
            if (!wait_socket(curl, 1)) return 0;
            continue;
        }
        if (rc != CURLE_OK || sent == 0) return 0;
    }
    return 1;
}
static int receive_message(CURL *curl, unsigned epoch) {
    unsigned char data[KS_MAX_FRAME];
    size_t used=0;
    for (;;) {
        if (worker_stopped(epoch)) return 0;
        unsigned char chunk[KS_MAX_FRAME];
        size_t n=0;
        const struct curl_ws_frame *meta=NULL;
        CURLcode rc=curl_ws_recv(curl,chunk,sizeof chunk,&n,&meta);
        if (rc==CURLE_AGAIN) {
            if (!wait_socket(curl, 0)) return 0;
            continue;
        }
        if (rc!=CURLE_OK || !meta) return 0;
        if (meta->flags & CURLWS_CLOSE) return 0;
        /* libcurl automatically answers PINGs; control frames do not interrupt
         * the data message being assembled here. */
        if (meta->flags & (CURLWS_PING|CURLWS_PONG)) continue;
        if (!(meta->flags & CURLWS_BINARY) || meta->bytesleft < 0 ||
            n > sizeof data - used ||
            meta->bytesleft > (curl_off_t)(sizeof data - used - n)) return 0;
        memcpy(data+used,chunk,n);
        used+=n;
        if (meta->bytesleft == 0 && !(meta->flags & CURLWS_CONT))
            return deliver_message(data,used,epoch);
    }
}
static void worker_main(unsigned epoch) {
    unsigned arg_epoch = epoch;
    struct curl_slist *headers = NULL;
    CURL *curl = connect_server(epoch, &arg_epoch, &headers);
    if (!curl) { KS_LOCK(); if(session_epoch==epoch) state=stopping?0:-1; KS_UNLOCK(); return; }
    KS_LOCK(); if(stopping || session_epoch!=epoch) {
        KS_UNLOCK(); curl_slist_free_all(headers); curl_easy_cleanup(curl); return;
    } state=2; KS_UNLOCK();
    int words[KS_MAX_WORDS];
    for (;;) {
        KS_LOCK(); int stop=stopping||session_epoch!=epoch, ready=send_pending, count=send_count;
        if (ready) {
            memcpy(words,send_words,(size_t)count*sizeof(int));
        }
        KS_UNLOCK();
        if (stop) break;
        if (ready) {
            unsigned char packet[KS_MAX_FRAME]; size_t n;
            if (!pack_message(words,count,packet,&n) || !send_frame(curl,packet,n)) break;
            KS_LOCK(); if(session_epoch==epoch) { send_pending=0; send_count=0; } KS_UNLOCK();
        }
        if (!receive_message(curl,epoch)) break;
    }
    curl_slist_free_all(headers);
    curl_easy_cleanup(curl);
    KS_LOCK(); if(session_epoch==epoch) state=stopping?0:-1; KS_UNLOCK();
}
#if defined(_WIN32)
static DWORD WINAPI worker_entry(LPVOID arg) { worker_arg *a=(worker_arg *)arg; unsigned epoch=a->epoch; free(a); worker_main(epoch); return 0; }
#else
static void *worker_entry(void *arg) { worker_arg *a=(worker_arg *)arg; unsigned epoch=a->epoch; free(a); worker_main(epoch); return NULL; }
#endif
bool kookie_kutter_sync_open(void) {
    if (!mutex_ready) {
#if defined(_WIN32)
        InitializeCriticalSection(&mutex);
#else
        if (pthread_mutex_init(&mutex,NULL)) return false;
#endif
        mutex_ready=1;
    }
    KS_LOCK();
    if (state==1 || state==2) { KS_UNLOCK(); return true; }
    if (!getenv("KOOKIE_KUTTER_HOST") || !getenv("KOOKIE_KUTTER_PORT")) { KS_UNLOCK(); return false; }
    if (!curl_ready) { if (curl_global_init(CURL_GLOBAL_DEFAULT)!=CURLE_OK) { KS_UNLOCK(); return false; } curl_ready=1; }
    stopping=0; unsigned epoch=++session_epoch; state=1;
    send_count=send_staged=send_pending=send_active=0; recv_size=recv_head=recv_tail=0; KS_UNLOCK();
    worker_arg *arg=(worker_arg *)malloc(sizeof *arg);
    if (!arg) { KS_LOCK(); if(session_epoch==epoch) state=-1; KS_UNLOCK(); return false; }
    arg->epoch=epoch;
#if defined(_WIN32)
    HANDLE thread=CreateThread(NULL,0,worker_entry,arg,0,NULL);
    if (!thread) { free(arg); KS_LOCK(); if(session_epoch==epoch) state=-1; KS_UNLOCK(); return false; }
    CloseHandle(thread);
#else
    pthread_t thread;
    if (pthread_create(&thread,NULL,worker_entry,arg)) { free(arg); KS_LOCK(); if(session_epoch==epoch) state=-1; KS_UNLOCK(); return false; }
    pthread_detach(thread);
#endif
    return true;
}
int kookie_kutter_sync_state(void) { if(!mutex_ready)return 0; KS_LOCK(); int v=state; KS_UNLOCK(); return v; }
bool kookie_kutter_sync_send_begin(int n) { if(!mutex_ready||n<3||n>KS_MAX_WORDS)return false; KS_LOCK(); if(state!=2||send_active||send_pending){KS_UNLOCK();return false;} send_count=n;send_staged=0;send_active=1;KS_UNLOCK();return true; }
bool kookie_kutter_sync_send_word(int i,int w) { if(!mutex_ready)return false;KS_LOCK();if(!send_active||i!=send_staged||i>=send_count){KS_UNLOCK();return false;}send_words[i]=w;send_staged++;KS_UNLOCK();return true; }
bool kookie_kutter_sync_send_commit(void) { if(!mutex_ready)return false;KS_LOCK();if(!send_active||send_staged!=send_count||state!=2||send_pending){KS_UNLOCK();return false;}send_active=0;send_pending=1;KS_UNLOCK();return true; }
int kookie_kutter_sync_receive_available(void) { if(!mutex_ready)return 0;KS_LOCK();int n=recv_size?recv_counts[recv_head]:0;KS_UNLOCK();return n; }
int kookie_kutter_sync_receive_word(int i) { if(!mutex_ready)return -1;KS_LOCK();if(!recv_size||i<0||i>=recv_counts[recv_head]){KS_UNLOCK();return -1;}int w=recv_queue[recv_head][i];if(i==recv_counts[recv_head]-1){recv_head=(recv_head+1)%KS_QUEUE;recv_size--;}KS_UNLOCK();return w; }
bool kookie_kutter_sync_close(void) { if(!mutex_ready)return true;KS_LOCK();stopping=1;session_epoch++;state=0;send_active=send_count=send_staged=send_pending=recv_size=0;KS_UNLOCK();return true; }
