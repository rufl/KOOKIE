#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif
#include "kookie_web_server.h"
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>
typedef SOCKET sock_t; typedef HANDLE thread_t; typedef CRITICAL_SECTION mutex_t;
#define BAD INVALID_SOCKET
#define CLOSE closesocket
#define LOCK() EnterCriticalSection(&mtx)
#define UNLOCK() LeaveCriticalSection(&mtx)
#define NAP() Sleep(5)
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <pthread.h>
#include <time.h>
#include <unistd.h>
typedef int sock_t; typedef pthread_t thread_t; typedef pthread_mutex_t mutex_t;
#define BAD (-1)
#define CLOSE close
#define LOCK() pthread_mutex_lock(&mtx)
#define UNLOCK() pthread_mutex_unlock(&mtx)
#define NAP() do { struct timespec t={0,5000000}; nanosleep(&t,NULL); } while(0)
#endif
#define NC 12
#define NE 64
#define NR 8192
#define NF 1296
#define NO 65536
typedef struct {
 sock_t fd;
 int used,dead,notified,ws,id,close_after,have_key;
 unsigned char key[24],in[NR+16],out[NO];
 size_t nin,nout,sent;
 long long last_activity_ns;
} conn;
typedef struct { int kind,id,opcode,len; unsigned char data[NR]; } event;
static mutex_t mtx; static sock_t listener=BAD; static conn cs[NC]; static event queue[NE],cur; static unsigned eh,et,ec; static int running,opened,nextid=1,portno; static thread_t thread;
static unsigned char stage[NO]; static int sid,slen,sactive;
#ifdef _WIN32
static int wsa;
static DWORD WINAPI run(LPVOID);
#else
static void *run(void*);
#endif
static int nonblock(sock_t s){
#ifdef _WIN32
 u_long x=1;return ioctlsocket(s,FIONBIO,&x)==0;
#else
 int f=fcntl(s,F_GETFL,0);return f>=0&&fcntl(s,F_SETFL,f|O_NONBLOCK)==0;
#endif
}
static int emit(int k,int id,int op,const unsigned char*p,size_t n){if(ec==NE)return 0;event*e=&queue[et];e->kind=k;e->id=id;e->opcode=op;e->len=(int)n;if(n)memcpy(e->data,p,n);et=(et+1)%NE;ec++;return 1;}
static int locate(int id){for(int i=0;i<NC;i++)if(cs[i].used&&cs[i].id==id&&!cs[i].dead)return i;return -1;}
static void drop(conn*c){if(!c->used||c->dead)return;CLOSE(c->fd);c->fd=BAD;c->dead=1;c->nout=c->sent=0;c->notified=emit(4,c->id,0,NULL,0);}
static void accepts(void){for(;;){struct sockaddr_in a;
#ifdef _WIN32
 int al=sizeof(a);
#else
 socklen_t al=sizeof(a);
#endif
 sock_t s=accept(listener,(struct sockaddr*)&a,&al);
 if(s==BAD)break;
 int j=-1;
 for(int i=0;i<NC;i++)if(!cs[i].used){j=i;break;}
 if(j<0){CLOSE(s);continue;}
 nonblock(s);
 int one=1;
 setsockopt(s,IPPROTO_TCP,TCP_NODELAY,(const char*)&one,sizeof(one));
 conn*c=&cs[j];
 memset(c,0,sizeof(*c));
 c->fd=s;c->used=1;c->id=nextid++;
 c->last_activity_ns=kookie_web_server_monotonic_nanoseconds();
 if(nextid<=0)nextid=1;
 if(!emit(1,c->id,0,NULL,0))drop(c);
 }}
static int header_name_equal(const unsigned char *p, size_t n, const char *name) {
 size_t i=0;
 while(i<n&&p[i]!=':')i++;
 if(i!=strlen(name))return 0;
 for(size_t j=0;j<i;j++){
  unsigned char c=p[j];
  if(c>='A'&&c<='Z')c=(unsigned char)(c+('a'-'A'));
  if(c!=(unsigned char)name[j])return 0;
 }
 return i<n;
}
static int valid_websocket_key(const unsigned char *p, size_t n) {
 if(n!=24||p[22]!='='||p[23]!='=')return 0;
 for(size_t i=0;i<22;i++) {
  unsigned char c=p[i];
  if(!((c>='A'&&c<='Z')||(c>='a'&&c<='z')||
       (c>='0'&&c<='9')||c=='+'||c=='/'))return 0;
 }
 return 1;
}
static void capture_websocket_key(conn *c, size_t request_len) {
 c->have_key=0;
 size_t line=0;
 while(line<request_len) {
  size_t end=line;
  while(end+1<request_len&&!(c->in[end]=='\r'&&c->in[end+1]=='\n'))end++;
  if(end==line)break;
  size_t colon=0;
  while(line+colon<end&&c->in[line+colon]!=':')colon++;
  if(line+colon<end&&header_name_equal(c->in+line,colon+1,"sec-websocket-key")) {
   size_t start=line+colon+1,finish=end;
   while(start<finish&&(c->in[start]==' '||c->in[start]=='\t'))start++;
   while(finish>start&&(c->in[finish-1]==' '||c->in[finish-1]=='\t'))finish--;
   if(valid_websocket_key(c->in+start,finish-start)) {
    memcpy(c->key,c->in+start,24);c->have_key=1;
   }
   return;
  }
  line=end+2;
 }
}
static int append_output(conn *c,const unsigned char *data,size_t n) {
 size_t pending=c->nout-c->sent;
 if(n>NO-pending)return 0;
 if(c->sent&&pending)memmove(c->out,c->out+c->sent,pending);
 c->sent=0;c->nout=pending;
 memcpy(c->out+c->nout,data,n);c->nout+=n;return 1;
}
static void parse(conn *c) {
 while(!c->dead) {
  if(!c->ws) {
   size_t end;
   for(end=3;end<c->nin;end++)
    if(c->in[end-3]=='\r'&&c->in[end-2]=='\n'&&
       c->in[end-1]=='\r'&&c->in[end]=='\n')break;
   if(end==c->nin) {if(c->nin>=NR)drop(c);return;}
   size_t n=end+1;
   capture_websocket_key(c,n);
   if(!emit(2,c->id,0,c->in,n)){drop(c);return;}
   memmove(c->in,c->in+n,c->nin-n);c->nin-=n;
   return;
  }
  if(c->nin<2)return;
  unsigned char a=c->in[0],b=c->in[1];int op=a&15;
  size_t h=2,n=b&127;
  if(!(a&128)||(a&112)||!(b&128)){drop(c);return;}
  if(n==126){if(c->nin<4)return;n=((size_t)c->in[2]<<8)|c->in[3];h=4;}
  else if(n==127){drop(c);return;}
  if(n>NF||(op>=8&&n>125)){drop(c);return;}
  if(c->nin<h+4+n)return;
  unsigned char mask[4],payload[NF];
  memcpy(mask,c->in+h,4);h+=4;
  for(size_t i=0;i<n;i++)payload[i]=c->in[h+i]^mask[i&3];
  memmove(c->in,c->in+h+n,c->nin-h-n);c->nin-=h+n;
  if(op==8) {
   unsigned char reply[127];reply[0]=0x88;reply[1]=(unsigned char)n;
   if(n)memcpy(reply+2,payload,n);
   if(!append_output(c,reply,n+2)){drop(c);return;}
   c->close_after=1;return;
  }
  if(op==9||op==10) {
   if(op==9) {
    unsigned char reply[127];reply[0]=0x8a;reply[1]=(unsigned char)n;
    if(n)memcpy(reply+2,payload,n);
    if(!append_output(c,reply,n+2)){drop(c);return;}
   }
   continue;
  }
  if(op!=1&&op!=2){drop(c);return;}
  if(!emit(3,c->id,op,payload,n)){drop(c);return;}
 }
}
#ifdef _WIN32
static DWORD WINAPI run(LPVOID x)
#else
static void *run(void*x)
#endif
{
 (void)x;
 for(;;) {
  LOCK();
  if(!running){UNLOCK();break;}
  accepts();
  for(int i=0;i<NC;i++) {
   conn*c=&cs[i];
   if(!c->used||c->dead)continue;
   long long now=kookie_web_server_monotonic_nanoseconds();
   if(now>c->last_activity_ns&&
      now-c->last_activity_ns>30000000000LL){drop(c);continue;}
   if(c->sent<c->nout) {
    int count=(int)(c->nout-c->sent);
    int sent=(int)send(c->fd,(const char*)c->out+c->sent,count,0);
    if(sent>0) {
     c->sent+=(size_t)sent;
     c->last_activity_ns=kookie_web_server_monotonic_nanoseconds();
    }
    else if(sent<0
#ifdef _WIN32
     &&WSAGetLastError()!=WSAEWOULDBLOCK&&WSAGetLastError()!=WSAEINTR
#else
     &&errno!=EAGAIN&&errno!=EWOULDBLOCK&&errno!=EINTR
#endif
    )drop(c);
    if(c->sent==c->nout)c->sent=c->nout=0;
   }
   if(c->close_after&&c->nout==0){drop(c);continue;}
   if(!c->dead&&!c->close_after) {
    if(c->nin==sizeof(c->in))drop(c);
    else {
     int received=(int)recv(c->fd,(char*)c->in+c->nin,
                            (int)(sizeof(c->in)-c->nin),0);
     if(received>0) {
      c->nin+=(size_t)received;
      c->last_activity_ns=kookie_web_server_monotonic_nanoseconds();
      parse(c);
     }
     else if(received==0)drop(c);
     else
#ifdef _WIN32
      if(WSAGetLastError()!=WSAEWOULDBLOCK&&WSAGetLastError()!=WSAEINTR)
#else
      if(errno!=EAGAIN&&errno!=EWOULDBLOCK&&errno!=EINTR)
#endif
       drop(c);
    }
   }
  }
  UNLOCK();
  NAP();
 }
#ifdef _WIN32
 return 0;
#else
 return NULL;
#endif
}
static int spawn(void){
#ifdef _WIN32
 thread=CreateThread(NULL,0,run,NULL,0,NULL);return thread!=NULL;
#else
 return pthread_create(&thread,NULL,run,NULL)==0;
#endif
}
static void joiner(void){
#ifdef _WIN32
 WaitForSingleObject(thread,INFINITE);CloseHandle(thread);
#else
 pthread_join(thread,NULL);
#endif
}
bool kookie_web_server_open(int port){if(opened||port<1||port>65535)return false;
#ifdef _WIN32
 if(!wsa){WSADATA d;if(WSAStartup(MAKEWORD(2,2),&d))return false;wsa=1;}InitializeCriticalSection(&mtx);
#else
 pthread_mutex_init(&mtx,NULL);
#endif
 sock_t s=socket(AF_INET,SOCK_STREAM,IPPROTO_TCP);if(s==BAD)goto fail;int one=1;setsockopt(s,SOL_SOCKET,SO_REUSEADDR,(const char*)&one,sizeof(one));struct sockaddr_in a;memset(&a,0,sizeof(a));a.sin_family=AF_INET;a.sin_addr.s_addr=htonl(INADDR_LOOPBACK);a.sin_port=htons((unsigned short)port);if(bind(s,(struct sockaddr*)&a,sizeof(a))||listen(s,NC)||!nonblock(s)){CLOSE(s);goto fail;}listener=s;memset(cs,0,sizeof(cs));eh=et=ec=0;nextid=1;portno=port;running=opened=1;if(!spawn()){running=opened=0;CLOSE(listener);listener=BAD;goto fail;}return true;
fail:
#ifdef _WIN32
 DeleteCriticalSection(&mtx);
#else
 pthread_mutex_destroy(&mtx);
#endif
 return false;}
int kookie_web_server_poll_event(int ms){if(!opened||ms<0)return -1;int elapsed=0;for(;;){LOCK();if(ec){cur=queue[eh];eh=(eh+1)%NE;ec--;if(cur.kind==4)for(int i=0;i<NC;i++)if(cs[i].used&&cs[i].id==cur.id)memset(&cs[i],0,sizeof(cs[i]));for(int i=0;i<NC;i++)if(cs[i].used&&cs[i].dead&&!cs[i].notified){cs[i].notified=emit(4,cs[i].id,0,NULL,0);break;}UNLOCK();return cur.kind;}if(!running){UNLOCK();return -1;}UNLOCK();if(elapsed>=ms)return 0;NAP();elapsed+=5;}}
int kookie_web_server_event_connection_id(void){return cur.id;}int kookie_web_server_event_opcode(void){return cur.opcode;}int kookie_web_server_event_payload_length(void){return cur.len;}int kookie_web_server_event_payload_byte(int i){return i>=0&&i<cur.len?cur.data[i]:-1;}
static unsigned rol(unsigned x,int n){return(x<<n)|(x>>(32-n));}
static void accept_key(const unsigned char*key,unsigned char*out){static const char g[]="258EAFA5-E914-47DA-95CA-C5AB0DC85B11";unsigned char b[128]={0},d[20];memcpy(b,key,24);memcpy(b+24,g,36);b[60]=0x80;b[126]=1;b[127]=0xe0;uint32_t h[5]={0x67452301,0xefcdab89,0x98badcfe,0x10325476,0xc3d2e1f0};for(int block=0;block<2;block++){uint32_t w[80];for(int i=0;i<16;i++){int p=block*64+i*4;w[i]=((uint32_t)b[p]<<24)|((uint32_t)b[p+1]<<16)|((uint32_t)b[p+2]<<8)|b[p+3];}for(int i=16;i<80;i++)w[i]=rol(w[i-3]^w[i-8]^w[i-14]^w[i-16],1);uint32_t a=h[0],bb=h[1],c=h[2],dd=h[3],e=h[4];for(int i=0;i<80;i++){uint32_t f,k;if(i<20){f=(bb&c)|(~bb&dd);k=0x5a827999;}else if(i<40){f=bb^c^dd;k=0x6ed9eba1;}else if(i<60){f=(bb&c)|(bb&dd)|(c&dd);k=0x8f1bbcdc;}else{f=bb^c^dd;k=0xca62c1d6;}uint32_t t=rol(a,5)+f+e+k+w[i];e=dd;dd=c;c=rol(bb,30);bb=a;a=t;}h[0]+=a;h[1]+=bb;h[2]+=c;h[3]+=dd;h[4]+=e;}for(int i=0;i<5;i++)for(int j=0;j<4;j++)d[i*4+j]=(unsigned char)(h[i]>>(24-j*8));static const char t[]="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";int q=0;for(int i=0;i<18;i+=3){out[q++]=t[d[i]>>2];out[q++]=t[((d[i]&3)<<4)|(d[i+1]>>4)];out[q++]=t[((d[i+1]&15)<<2)|(d[i+2]>>6)];out[q++]=t[d[i+2]&63];}out[q++]=t[d[18]>>2];out[q++]=t[((d[18]&3)<<4)|(d[19]>>4)];out[q++]=t[(d[19]&15)<<2];out[q++]='=';out[q]=0;}
bool kookie_web_server_close_client(int id){LOCK();int i=locate(id);if(i<0){UNLOCK();return false;}drop(&cs[i]);UNLOCK();return true;}
bool kookie_web_server_close_client_after_output(int id) {
 LOCK();
 int index=locate(id);
 if(index<0) {
  UNLOCK();
  return false;
 }
 conn *c=&cs[index];
 c->close_after=1;
 if(c->nout==0)drop(c);
 UNLOCK();
 return true;
}
bool kookie_web_server_output_begin(int id,int n){if(n<0||n>NO)return false;LOCK();int ok=locate(id)>=0;UNLOCK();if(!ok)return false;sid=id;slen=n;sactive=1;return true;}
bool kookie_web_server_output_write_byte(int i,int v){if(!sactive||i<0||i>=slen||v<0||v>255)return false;stage[i]=(unsigned char)v;return true;}
bool kookie_web_server_output_commit(void){if(!sactive)return false;LOCK();int i=locate(sid);if(i<0||!append_output(&cs[i],stage,(size_t)slen)){if(i>=0)drop(&cs[i]);UNLOCK();sactive=0;return false;}UNLOCK();sactive=0;return true;}
bool kookie_web_server_upgrade_websocket(int id) {
 LOCK();
 int index=locate(id);
 if(index<0||cs[index].ws||!cs[index].have_key) {
  UNLOCK();
  return false;
 }
 conn *c=&cs[index];
 unsigned char accept[29];
 accept_key(c->key,accept);
 int length=snprintf((char*)c->out,NO,
  "HTTP/1.1 101 Switching Protocols\r\n"
  "Upgrade: websocket\r\n"
  "Connection: Upgrade\r\n"
  "Sec-WebSocket-Accept: %s\r\n"
  "Sec-WebSocket-Protocol: kookie.v1\r\n\r\n",accept);
 if(length<0||length>=NO||c->nout) {
  UNLOCK();
  return false;
 }
 c->nout=(size_t)length;
 c->ws=1;
 parse(c);
 int succeeded=!c->dead;
 UNLOCK();
 return succeeded;
}
bool kookie_web_server_close(void){if(!opened)return false;LOCK();running=0;UNLOCK();joiner();CLOSE(listener);listener=BAD;for(int i=0;i<NC;i++)if(cs[i].used&&!cs[i].dead)CLOSE(cs[i].fd);opened=0;
#ifdef _WIN32
 DeleteCriticalSection(&mtx);
#else
 pthread_mutex_destroy(&mtx);
#endif
 return true;}
long long kookie_web_server_monotonic_nanoseconds(void) {
#ifdef _WIN32
 LARGE_INTEGER counter;
 LARGE_INTEGER frequency;
 if(!QueryPerformanceCounter(&counter)||
    !QueryPerformanceFrequency(&frequency)||frequency.QuadPart<=0)return 0;
 long long seconds=(long long)(counter.QuadPart/frequency.QuadPart);
 long long remainder=(long long)(counter.QuadPart%frequency.QuadPart);
 return seconds*1000000000LL+
  remainder*1000000000LL/(long long)frequency.QuadPart;
#else
 struct timespec now;
 if(clock_gettime(CLOCK_MONOTONIC,&now)!=0)return 0;
 return (long long)now.tv_sec*1000000000LL+(long long)now.tv_nsec;
#endif
}
int kookie_web_server_port(void) {
 if(portno>0)return portno;
 const char *configured=getenv("KOOKIE_WEB_PORT");
 if(!configured||!*configured)return 8765;
 char *end=NULL;
 long value=strtol(configured,&end,10);
 if(!end||*end!='\0'||value<1||value>65535)return 8765;
 return (int)value;
}
int kookie_web_server_max_connections(void){return NC;}
