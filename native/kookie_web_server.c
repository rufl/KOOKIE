#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif

#include "kookie_web_server.h"

#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#endif
#include <winsock2.h>
#include <windows.h>
typedef SOCKET kookie_web_socket_t;
typedef int kookie_web_socklen_t;
typedef int kookie_web_io_size_t;
#define KOOKIE_WEB_INVALID_SOCKET INVALID_SOCKET
#else
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
typedef int kookie_web_socket_t;
typedef socklen_t kookie_web_socklen_t;
typedef ssize_t kookie_web_io_size_t;
#define KOOKIE_WEB_INVALID_SOCKET (-1)
#endif

#define KOOKIE_WEB_MAX_REQUEST_BYTES 8192
#define KOOKIE_WEB_MAX_RESPONSE_BYTES 16384
#define KOOKIE_WEB_KEY_BYTES 24
#define KOOKIE_WEB_ACCEPT_BYTES 28

static kookie_web_socket_t listener = KOOKIE_WEB_INVALID_SOCKET;
static kookie_web_socket_t client = KOOKIE_WEB_INVALID_SOCKET;
static unsigned char response[KOOKIE_WEB_MAX_RESPONSE_BYTES];
static int response_length;
static unsigned char websocket_key[KOOKIE_WEB_KEY_BYTES];

#ifdef _WIN32
static bool winsock_started;

static bool web_socket_runtime_open(void) {
    if (winsock_started) {
        return true;
    }
    WSADATA data;
    if (WSAStartup(MAKEWORD(2, 2), &data) != 0) {
        return false;
    }
    winsock_started = true;
    return true;
}

static void web_socket_close(kookie_web_socket_t socket_fd) {
    if (socket_fd != KOOKIE_WEB_INVALID_SOCKET) {
        closesocket(socket_fd);
    }
}

static bool web_socket_would_block(void) {
    int error = WSAGetLastError();
    return error == WSAEWOULDBLOCK || error == WSAETIMEDOUT;
}

static int web_socket_send_flags(void) {
    return 0;
}
#else
static bool web_socket_runtime_open(void) {
    return true;
}

static void web_socket_close(kookie_web_socket_t socket_fd) {
    if (socket_fd != KOOKIE_WEB_INVALID_SOCKET) {
        close(socket_fd);
    }
}

static bool web_socket_would_block(void) {
    return errno == EAGAIN || errno == EWOULDBLOCK;
}

static int web_socket_send_flags(void) {
#ifdef MSG_NOSIGNAL
    return MSG_NOSIGNAL;
#else
    return 0;
#endif
}
#endif

static int environment_int(const char *name, int fallback, int minimum, int maximum) {
    const char *encoded = getenv(name);
    if (encoded == NULL || encoded[0] == '\0') {
        return fallback;
    }
    char *end = NULL;
    long value = strtol(encoded, &end, 10);
    if (end == encoded || *end != '\0' || value < minimum || value > maximum) {
        return fallback;
    }
    return (int)value;
}

static bool valid_port(int port) {
    return port > 0 && port <= 65535;
}

static uint32_t rotate_left(uint32_t value, unsigned int amount) {
    return (value << amount) | (value >> (32u - amount));
}

static void sha1(const unsigned char *input, size_t length, unsigned char output[20]) {
    uint32_t h0 = UINT32_C(0x67452301);
    uint32_t h1 = UINT32_C(0xefcdab89);
    uint32_t h2 = UINT32_C(0x98badcfe);
    uint32_t h3 = UINT32_C(0x10325476);
    uint32_t h4 = UINT32_C(0xc3d2e1f0);
    size_t padded_length = ((length + 9u + 63u) / 64u) * 64u;
    unsigned char padded[128];
    if (padded_length > sizeof(padded)) {
        memset(output, 0, 20);
        return;
    }
    memset(padded, 0, sizeof(padded));
    memcpy(padded, input, length);
    padded[length] = 0x80;
    uint64_t bit_length = (uint64_t)length * 8u;
    for (int index = 0; index < 8; index += 1) {
        padded[padded_length - 1u - (size_t)index] =
            (unsigned char)(bit_length >> (index * 8));
    }
    for (size_t block_offset = 0;
        block_offset < padded_length; block_offset += 64) {
        uint32_t words[80];
        for (int index = 0; index < 16; index += 1) {
            size_t offset = block_offset + (size_t)index * 4u;
            words[index] = ((uint32_t)padded[offset] << 24) |
                ((uint32_t)padded[offset + 1] << 16) |
                ((uint32_t)padded[offset + 2] << 8) |
                (uint32_t)padded[offset + 3];
        }
        for (int index = 16; index < 80; index += 1) {
            words[index] = rotate_left(
                words[index - 3] ^ words[index - 8] ^
                words[index - 14] ^ words[index - 16], 1);
        }
        uint32_t a = h0;
        uint32_t b = h1;
        uint32_t c = h2;
        uint32_t d = h3;
        uint32_t e = h4;
        for (int index = 0; index < 80; index += 1) {
            uint32_t function;
            uint32_t constant;
            if (index < 20) {
                function = (b & c) | ((~b) & d);
                constant = UINT32_C(0x5a827999);
            } else if (index < 40) {
                function = b ^ c ^ d;
                constant = UINT32_C(0x6ed9eba1);
            } else if (index < 60) {
                function = (b & c) | (b & d) | (c & d);
                constant = UINT32_C(0x8f1bbcdc);
            } else {
                function = b ^ c ^ d;
                constant = UINT32_C(0xca62c1d6);
            }
            uint32_t temporary =
                rotate_left(a, 5) + function + e + constant + words[index];
            e = d;
            d = c;
            c = rotate_left(b, 30);
            b = a;
            a = temporary;
        }
        h0 += a;
        h1 += b;
        h2 += c;
        h3 += d;
        h4 += e;
    }
    uint32_t digest[5] = {h0, h1, h2, h3, h4};
    for (int word = 0; word < 5; word += 1) {
        for (int byte = 0; byte < 4; byte += 1) {
            output[word * 4 + byte] =
                (unsigned char)(digest[word] >> (24 - byte * 8));
        }
    }
}

static char base64_char(unsigned int value) {
    static const char alphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    return alphabet[value & 63u];
}

static void websocket_accept(char output[KOOKIE_WEB_ACCEPT_BYTES]) {
    static const unsigned char guid[] =
        "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    unsigned char input[KOOKIE_WEB_KEY_BYTES + sizeof(guid) - 1];
    unsigned char digest[20];
    memcpy(input, websocket_key, KOOKIE_WEB_KEY_BYTES);
    memcpy(input + KOOKIE_WEB_KEY_BYTES, guid, sizeof(guid) - 1);
    sha1(input, sizeof(input), digest);
    int write_index = 0;
    for (int index = 0; index < 18; index += 3) {
        unsigned int first = digest[index];
        unsigned int second = digest[index + 1];
        unsigned int third = digest[index + 2];
        output[write_index++] = base64_char(first >> 2);
        output[write_index++] = base64_char((first << 4 | second >> 4));
        output[write_index++] = base64_char((second << 2 | third >> 6));
        output[write_index++] = base64_char(third);
    }
    unsigned int first = digest[18];
    unsigned int second = digest[19];
    output[write_index++] = base64_char(first >> 2);
    output[write_index++] = base64_char((first << 4 | second >> 4));
    output[write_index++] = base64_char(second << 2);
    output[write_index++] = '=';
}

bool kookie_web_server_open(int port) {
    if (!web_socket_runtime_open() || !valid_port(port) ||
        listener != KOOKIE_WEB_INVALID_SOCKET) {
        return false;
    }
    listener = socket(AF_INET, SOCK_STREAM, 0);
    if (listener == KOOKIE_WEB_INVALID_SOCKET) {
        return false;
    }
    int reuse = 1;
    if (setsockopt(listener, SOL_SOCKET, SO_REUSEADDR,
            (const char *)&reuse, sizeof(reuse)) != 0) {
        web_socket_close(listener);
        listener = KOOKIE_WEB_INVALID_SOCKET;
        return false;
    }
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons((unsigned short)port);
    if (bind(listener, (const struct sockaddr *)&address, sizeof(address)) != 0 ||
        listen(listener, 8) != 0) {
        web_socket_close(listener);
        listener = KOOKIE_WEB_INVALID_SOCKET;
        return false;
    }
    return true;
}

bool kookie_web_server_accept(void) {
    if (listener == KOOKIE_WEB_INVALID_SOCKET ||
        client != KOOKIE_WEB_INVALID_SOCKET) {
        return false;
    }
    struct sockaddr_in address;
    kookie_web_socklen_t address_length = sizeof(address);
    client = accept(listener, (struct sockaddr *)&address, &address_length);
    if (client == KOOKIE_WEB_INVALID_SOCKET) {
        return false;
    }
    struct timeval timeout;
    timeout.tv_sec = 2;
    timeout.tv_usec = 0;
    setsockopt(client, SOL_SOCKET, SO_RCVTIMEO,
        (const char *)&timeout, sizeof(timeout));
    setsockopt(client, SOL_SOCKET, SO_SNDTIMEO,
        (const char *)&timeout, sizeof(timeout));
    return true;
}

int kookie_web_server_read_byte(void) {
    if (client == KOOKIE_WEB_INVALID_SOCKET) {
        return -3;
    }
    unsigned char value = 0;
    kookie_web_io_size_t result = recv(client, (char *)&value, 1, 0);
    if (result == 1) {
        return (int)value;
    }
    if (result == 0) {
        return -1;
    }
    if (web_socket_would_block()) {
        return -2;
    }
    return -3;
}

bool kookie_web_server_send_begin(int length) {
    if (client == KOOKIE_WEB_INVALID_SOCKET || length < 0 ||
        length > KOOKIE_WEB_MAX_RESPONSE_BYTES) {
        return false;
    }
    response_length = length;
    memset(response, 0, (size_t)length);
    return true;
}

bool kookie_web_server_send_byte(int index, int value) {
    if (index < 0 || index >= response_length || value < 0 || value > 255) {
        return false;
    }
    response[index] = (unsigned char)value;
    return true;
}

bool kookie_web_server_send_commit(void) {
    if (client == KOOKIE_WEB_INVALID_SOCKET) {
        return false;
    }
    int sent = 0;
    while (sent < response_length) {
        kookie_web_io_size_t result = send(
            client, (const char *)response + sent,
            (size_t)(response_length - sent), web_socket_send_flags());
        if (result <= 0) {
            return false;
        }
        sent += (int)result;
    }
    return true;
}

bool kookie_web_server_set_websocket_key_byte(int index, int value) {
    if (index < 0 || index >= KOOKIE_WEB_KEY_BYTES ||
        value < 0 || value > 255) {
        return false;
    }
    websocket_key[index] = (unsigned char)value;
    return true;
}

int kookie_web_server_websocket_accept_length(void) {
    return KOOKIE_WEB_ACCEPT_BYTES;
}

int kookie_web_server_websocket_accept_byte(int index) {
    if (index < 0 || index >= KOOKIE_WEB_ACCEPT_BYTES) {
        return -1;
    }
    char output[KOOKIE_WEB_ACCEPT_BYTES];
    websocket_accept(output);
    return (unsigned char)output[index];
}

bool kookie_web_server_close_client(void) {
    if (client != KOOKIE_WEB_INVALID_SOCKET) {
        web_socket_close(client);
        client = KOOKIE_WEB_INVALID_SOCKET;
    }
    return true;
}

bool kookie_web_server_close(void) {
    kookie_web_server_close_client();
    if (listener != KOOKIE_WEB_INVALID_SOCKET) {
        web_socket_close(listener);
        listener = KOOKIE_WEB_INVALID_SOCKET;
    }
    return true;
}

int kookie_web_server_port(void) {
    return environment_int("KOOKIE_WEB_PORT", 8766, 1, 65535);
}

int kookie_web_server_max_connections(void) {
    return environment_int("KOOKIE_WEB_MAX_CONNECTIONS", 0, 0, 1000000);
}
