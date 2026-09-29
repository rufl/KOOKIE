#define _POSIX_C_SOURCE 200809L

#include "kookie_transport.h"

#include <arpa/inet.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <netinet/in.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#define KOOKIE_TRANSPORT_MAX_SLOTS 4
#define KOOKIE_TRANSPORT_MAX_WORDS 300
#define KOOKIE_TRANSPORT_MAGIC 0x4b4f4f4bU
#define KOOKIE_TRANSPORT_VERSION 1U
#define KOOKIE_TRANSPORT_HEADER_WORDS 6
#define KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS 1000

typedef struct {
    int socket_fd;
    int receive_socket_fd;
    struct sockaddr_in peer;
    struct sockaddr_in last_sender;
    bool last_sender_valid;
    uint64_t key0;
    uint64_t key1;
    bool key_configured;
    int send_count;
    uint32_t send_sequence;
    uint32_t send_words[KOOKIE_TRANSPORT_MAX_WORDS];
    int last_send_bytes;
    bool last_send_valid;
    uint32_t last_send_wire[
        KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_TRANSPORT_MAX_WORDS];
    int receive_count;
    uint32_t receive_sequence;
    int last_status;
    int receive_words[KOOKIE_TRANSPORT_MAX_WORDS];
} KookieTransport;
static KookieTransport transport_slots[KOOKIE_TRANSPORT_MAX_SLOTS] = {
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    },
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    },
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    },
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    }
};
static KookieTransport *active_transport = &transport_slots[0];
#define transport (*active_transport)
static uint64_t kookie_rotate_left(uint64_t value, unsigned int shift) {
    return (value << shift) | (value >> (64u - shift));
}

static uint64_t kookie_load_u64_le(const uint8_t *bytes) {
    uint64_t value = 0;
    for (unsigned int index = 0; index < 8; index += 1) {
        value |= ((uint64_t)bytes[index]) << (index * 8u);
    }
    return value;
}

static void kookie_sip_round(
    uint64_t *v0, uint64_t *v1, uint64_t *v2, uint64_t *v3
) {
    *v0 += *v1;
    *v1 = kookie_rotate_left(*v1, 13);
    *v1 ^= *v0;
    *v0 = kookie_rotate_left(*v0, 32);
    *v2 += *v3;
    *v3 = kookie_rotate_left(*v3, 16);
    *v3 ^= *v2;
    *v0 += *v3;
    *v3 = kookie_rotate_left(*v3, 21);
    *v3 ^= *v0;
    *v2 += *v1;
    *v1 = kookie_rotate_left(*v1, 17);
    *v1 ^= *v2;
    *v2 = kookie_rotate_left(*v2, 32);
}

static uint64_t kookie_transport_mac(const uint8_t *bytes, size_t length) {
    const uint64_t key0 = transport.key0;
    const uint64_t key1 = transport.key1;
    uint64_t v0 = UINT64_C(0x736f6d6570736575) ^ key0;
    uint64_t v1 = UINT64_C(0x646f72616e646f6d) ^ key1;
    uint64_t v2 = UINT64_C(0x6c7967656e657261) ^ key0;
    uint64_t v3 = UINT64_C(0x7465646279746573) ^ key1;
    size_t offset = 0;
    while (offset + 8 <= length) {
        uint64_t message = kookie_load_u64_le(bytes + offset);
        v3 ^= message;
        kookie_sip_round(&v0, &v1, &v2, &v3);
        kookie_sip_round(&v0, &v1, &v2, &v3);
        v0 ^= message;
        offset += 8;
    }
    uint64_t final_message = ((uint64_t)length) << 56;
    for (size_t index = 0; offset + index < length; index += 1) {
        final_message |= ((uint64_t)bytes[offset + index]) << (index * 8);
    }
    v3 ^= final_message;
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    v0 ^= final_message;
    v2 ^= UINT64_C(0xff);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    return v0 ^ v1 ^ v2 ^ v3;
}
static int kookie_transport_receive_timeout_milliseconds(void) {
    const char *encoded = getenv("KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS");
    if (encoded == NULL || encoded[0] == '\0') {
        return KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS;
    }
    char *end = NULL;
    long value = strtol(encoded, &end, 10);
    if (end == encoded || *end != '\0' || value < 1 || value > 60000) {
        return KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS;
    }
    return (int)value;
}

static bool kookie_transport_bind_socket_configured(
    int *socket_fd,
    uint32_t bind_address,
    int port,
    struct sockaddr_in *address
) {
    if (port < 0 || port > 65535) {
        return false;
    }
    int next_socket = socket(AF_INET, SOCK_DGRAM, 0);
    if (next_socket < 0) {
        return false;
    }
    memset(address, 0, sizeof(*address));
    address->sin_family = AF_INET;
    address->sin_addr.s_addr = htonl(bind_address);
    address->sin_port = htons((uint16_t)port);
    if (bind(
            next_socket,
            (struct sockaddr *)address,
            sizeof(*address)) != 0) {
        close(next_socket);
        return false;
    }
    socklen_t address_length = sizeof(*address);
    if (getsockname(
            next_socket, (struct sockaddr *)address, &address_length) != 0) {
        close(next_socket);
        return false;
    }
    int timeout_milliseconds =
        kookie_transport_receive_timeout_milliseconds();
    struct timeval receive_timeout = {
        .tv_sec = timeout_milliseconds / 1000,
        .tv_usec = (timeout_milliseconds % 1000) * 1000
    };
    if (setsockopt(
            next_socket, SOL_SOCKET, SO_RCVTIMEO,
            &receive_timeout, sizeof(receive_timeout)) != 0) {
        close(next_socket);
        return false;
    }
    *socket_fd = next_socket;
    return true;
}
static bool kookie_transport_bind_socket(
    int *socket_fd,
    struct sockaddr_in *address
) {
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_LOOPBACK, 0, address);
}
static bool kookie_transport_bind_socket_any(
    int *socket_fd,
    struct sockaddr_in *address
) {
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_ANY, 0, address);
}
static bool kookie_transport_bind_socket_at(
    int *socket_fd,
    int port,
    struct sockaddr_in *address
) {
    if (port <= 0 || port > 65535) {
        return false;
    }
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_LOOPBACK, port, address);
}
static bool kookie_transport_bind_socket_any_at(
    int *socket_fd,
    int port,
    struct sockaddr_in *address
) {
    if (port <= 0 || port > 65535) {
        return false;
    }
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_ANY, port, address);
}


bool kookie_transport_select_slot(int slot) {
    if (slot < 0 || slot >= KOOKIE_TRANSPORT_MAX_SLOTS) {
        return false;
    }
    active_transport = &transport_slots[slot];
    return true;
}

static void kookie_transport_reset_counters(void) {
    transport.send_count = 0;
    transport.send_sequence = 0;
    transport.receive_count = 0;
    transport.receive_sequence = 0;
    transport.last_status = 0;
    transport.last_sender_valid = false;
}



bool kookie_transport_set_key(
    int key0_low, int key0_high, int key1_low, int key1_high
) {
    if (transport.socket_fd >= 0) {
        return false;
    }
    uint64_t next_key0 =
        (uint64_t)(uint32_t)key0_low |
        ((uint64_t)(uint32_t)key0_high << 32);
    uint64_t next_key1 =
        (uint64_t)(uint32_t)key1_low |
        ((uint64_t)(uint32_t)key1_high << 32);
    if (next_key0 == 0 && next_key1 == 0) {
        return false;
    }
    transport.key0 = next_key0;
    transport.key1 = next_key1;
    transport.key_configured = true;
    return true;
}
static bool kookie_transport_parse_hex_word(
    const char *text,
    uint32_t *value
) {
    uint32_t parsed = 0;
    for (int index = 0; index < 8; index += 1) {
        char digit = text[index];
        uint32_t nibble;
        if (digit >= '0' && digit <= '9') {
            nibble = (uint32_t)(digit - '0');
        } else if (digit >= 'a' && digit <= 'f') {
            nibble = (uint32_t)(digit - 'a') + 10;
        } else if (digit >= 'A' && digit <= 'F') {
            nibble = (uint32_t)(digit - 'A') + 10;
        } else {
            return false;
        }
        parsed = (parsed << 4) | nibble;
    }
    *value = parsed;
    return true;
}
static bool kookie_transport_set_key_from_encoded(const char *encoded) {
    if (encoded == NULL || strlen(encoded) != 32) {
        return false;
    }
    uint32_t words[4];
    for (int index = 0; index < 4; index += 1) {
        if (!kookie_transport_parse_hex_word(
                encoded + index * 8, &words[index])) {
            return false;
        }
    }
    return kookie_transport_set_key(
        (int)words[0], (int)words[1],
        (int)words[2], (int)words[3]);
}

bool kookie_transport_set_key_from_environment(void) {
    if (transport.socket_fd >= 0) {
        return false;
    }
    return kookie_transport_set_key_from_encoded(
        getenv("KOOKIE_TRANSPORT_KEY_HEX"));
}

bool kookie_transport_set_key_from_file(void) {
    if (transport.socket_fd >= 0) {
        return false;
    }
    const char *path = getenv("KOOKIE_TRANSPORT_KEY_FILE");
    if (path == NULL || path[0] == '\0') {
        return false;
    }
    struct stat info;
    if (stat(path, &info) != 0 || !S_ISREG(info.st_mode) ||
        (info.st_mode & 0077) != 0) {
        return false;
    }
    int file_descriptor = open(path, O_RDONLY);
    if (file_descriptor < 0) {
        return false;
    }
    char encoded[33];
    ssize_t length = read(file_descriptor, encoded, sizeof(encoded));
    close(file_descriptor);
    if (length != 32) {
        return false;
    }
    encoded[32] = '\0';
    return kookie_transport_set_key_from_encoded(encoded);
}

bool kookie_transport_rotate_key_from_file(void) {
    return kookie_transport_set_key_from_file();
}


bool kookie_transport_open(void) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in peer;
    if (!kookie_transport_bind_socket(&socket_fd, &peer)) {
        return false;
    }
    peer.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = peer;
    kookie_transport_reset_counters();
    return true;
}

bool kookie_transport_open_pair(void) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    int receive_socket_fd = -1;
    struct sockaddr_in peer;
    struct sockaddr_in receive_address;
    if (!kookie_transport_bind_socket(&socket_fd, &peer) ||
        !kookie_transport_bind_socket(&receive_socket_fd, &receive_address)) {
        if (socket_fd >= 0) {
            close(socket_fd);
        }
        if (receive_socket_fd >= 0) {
            close(receive_socket_fd);
        }
        return false;
    }
    receive_address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = receive_socket_fd;
    transport.peer = receive_address;
    kookie_transport_reset_counters();
    return true;
}
bool kookie_transport_open_remote_ipv4(
    int first_octet, int second_octet, int third_octet,
    int fourth_octet, int port
) {
    if (transport.socket_fd >= 0 || !transport.key_configured ||
        first_octet < 0 || first_octet > 255 ||
        second_octet < 0 || second_octet > 255 ||
        third_octet < 0 || third_octet > 255 ||
        fourth_octet < 0 || fourth_octet > 255 ||
        port <= 0 || port > 65535) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in local;
    if (!kookie_transport_bind_socket_any(&socket_fd, &local)) {
        return false;
    }
    uint32_t address =
        ((uint32_t)first_octet << 24) |
        ((uint32_t)second_octet << 16) |
        ((uint32_t)third_octet << 8) |
        (uint32_t)fourth_octet;
    local.sin_addr.s_addr = htonl(address);
    local.sin_port = htons((uint16_t)port);
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = local;
    kookie_transport_reset_counters();
    return true;
}
static bool kookie_transport_external_host_address(
    struct in_addr *address
) {
    const char *encoded = getenv("KOOKIE_EXTERNAL_LAN_HOST_IPV4");
    if (encoded == NULL || encoded[0] == '\0') {
        encoded = "127.0.0.1";
    }
    return inet_pton(AF_INET, encoded, address) == 1;
}

bool kookie_transport_open_remote_environment(int port) {
    struct in_addr address;
    if (!kookie_transport_external_host_address(&address)) {
        return false;
    }
    uint32_t host_order = ntohl(address.s_addr);
    return kookie_transport_open_remote_ipv4(
        (int)((host_order >> 24) & 0xffU),
        (int)((host_order >> 16) & 0xffU),
        (int)((host_order >> 8) & 0xffU),
        (int)(host_order & 0xffU),
        port);
}

int kookie_transport_external_host_octet(int index) {
    if (index < 0 || index > 3) {
        return -1;
    }
    struct in_addr address;
    if (!kookie_transport_external_host_address(&address)) {
        return -1;
    }
    uint32_t host_order = ntohl(address.s_addr);
    return (int)((host_order >> ((3 - index) * 8)) & 0xffU);
}

static int kookie_transport_external_role(void) {
    const char *role = getenv("KOOKIE_EXTERNAL_LAN_ROLE");
    if (role == NULL) {
        return 0;
    }
    if (strcmp(role, "host") == 0) {
        return 1;
    }
    if (strcmp(role, "client-a") == 0) {
        return 2;
    }
    if (strcmp(role, "client-b") == 0) {
        return 3;
    }
    return 0;
}
bool kookie_transport_external_is_host(void) {
    return kookie_transport_external_role() == 1;
}

bool kookie_transport_external_is_client_a(void) {
    return kookie_transport_external_role() == 2;
}

bool kookie_transport_external_is_client_b(void) {
    return kookie_transport_external_role() == 3;
}
bool kookie_transport_open_local_ipv4(int port) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in local;
    if (!kookie_transport_bind_socket_at(&socket_fd, port, &local)) {
        return false;
    }
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = local;
    kookie_transport_reset_counters();
    return true;
}
bool kookie_transport_open_listen_ipv4(int port) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in local;
    if (!kookie_transport_bind_socket_any_at(&socket_fd, port, &local)) {
        return false;
    }
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = local;
    kookie_transport_reset_counters();
    return true;
}


bool kookie_transport_set_peer_ipv4(
    int first_octet, int second_octet, int third_octet,
    int fourth_octet, int port
) {
    if (transport.socket_fd < 0 ||
        first_octet < 0 || first_octet > 255 ||
        second_octet < 0 || second_octet > 255 ||
        third_octet < 0 || third_octet > 255 ||
        fourth_octet < 0 || fourth_octet > 255 ||
        port <= 0 || port > 65535) {
        return false;
    }
    uint32_t address =
        ((uint32_t)first_octet << 24) |
        ((uint32_t)second_octet << 16) |
        ((uint32_t)third_octet << 8) |
        (uint32_t)fourth_octet;
    transport.peer.sin_family = AF_INET;
    transport.peer.sin_addr.s_addr = htonl(address);
    transport.peer.sin_port = htons((uint16_t)port);
    return true;
}
bool kookie_transport_set_peer_last_sender(void) {
    if (transport.socket_fd < 0 || !transport.last_sender_valid) {
        return false;
    }
    transport.peer = transport.last_sender;
    return true;
}

bool kookie_transport_received_sequence_at_least(int minimum) {
    return minimum >= 0 &&
        transport.receive_sequence >= (uint32_t)minimum;
}


int kookie_transport_peer_port(void) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    return (int)ntohs(transport.peer.sin_port);
}

int kookie_transport_local_port(void) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    struct sockaddr_in local;
    socklen_t address_length = sizeof(local);
    if (getsockname(
            transport.socket_fd,
            (struct sockaddr *)&local,
            &address_length) != 0) {
        return 0;
    }
    return (int)ntohs(local.sin_port);
}

int kookie_transport_max_words(void) {
    return KOOKIE_TRANSPORT_MAX_WORDS;
}


bool kookie_transport_send_begin(int word_count) {
    if (transport.socket_fd < 0 ||
        word_count <= 0 ||
        word_count > KOOKIE_TRANSPORT_MAX_WORDS) {
        return false;
    }
    transport.send_count = word_count;
    return true;
}

bool kookie_transport_send_word(int index, int word) {
    if (transport.socket_fd < 0 ||
        index < 0 ||
        index >= transport.send_count) {
        return false;
    }
    transport.send_words[index] = (uint32_t)word;
    return true;
}

bool kookie_transport_send_commit(void) {
    if (transport.socket_fd < 0 ||
        transport.send_count <= 0 ||
        transport.send_sequence == UINT32_MAX) {
        return false;
    }
    uint32_t wire[
        KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_TRANSPORT_MAX_WORDS];
    int frame_words = KOOKIE_TRANSPORT_HEADER_WORDS + transport.send_count;
    wire[0] = htonl(KOOKIE_TRANSPORT_MAGIC);
    wire[1] = htonl(KOOKIE_TRANSPORT_VERSION);
    wire[2] = htonl((uint32_t)transport.send_count);
    wire[3] = htonl(transport.send_sequence + 1);
    wire[4] = 0;
    wire[5] = 0;
    for (int index = 0; index < transport.send_count; index += 1) {
        wire[KOOKIE_TRANSPORT_HEADER_WORDS + index] =
            htonl(transport.send_words[index]);
    }
    size_t bytes = (size_t)frame_words * sizeof(uint32_t);
    uint64_t mac = kookie_transport_mac((const uint8_t *)wire, bytes);
    wire[4] = htonl((uint32_t)mac);
    wire[5] = htonl((uint32_t)(mac >> 32));
    ssize_t sent = sendto(
        transport.socket_fd,
        wire,
        bytes,
        0,
        (struct sockaddr *)&transport.peer,
        sizeof(transport.peer));
    transport.send_count = 0;
    if (sent != (ssize_t)bytes) {
        return false;
    }
    memcpy(transport.last_send_wire, wire, bytes);
    transport.last_send_bytes = (int)bytes;
    transport.last_send_valid = true;
    transport.send_sequence += 1;
    return true;
}
bool kookie_transport_replay_last_datagram(void) {
    if (transport.socket_fd < 0 ||
        !transport.last_send_valid ||
        transport.last_send_bytes <= 0) {
        return false;
    }
    ssize_t sent = sendto(
        transport.socket_fd,
        transport.last_send_wire,
        (size_t)transport.last_send_bytes,
        0,
        (struct sockaddr *)&transport.peer,
        sizeof(transport.peer));
    return sent == (ssize_t)transport.last_send_bytes;
}

static int kookie_transport_receive_with_flags(int flags) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    uint32_t wire[
        KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_TRANSPORT_MAX_WORDS];
    struct sockaddr_in sender;
    memset(&sender, 0, sizeof(sender));
    socklen_t sender_length = sizeof(sender);
    ssize_t bytes = recvfrom(
        transport.receive_socket_fd,
        wire,
        sizeof(wire),
        flags,
        (struct sockaddr *)&sender,
        &sender_length);
    if (bytes < 0) {
        transport.receive_count = 0;
        transport.last_sender_valid = false;
        transport.last_status =
            errno == EAGAIN || errno == EWOULDBLOCK ? 2 : 3;
        return 0;
    }
    transport.last_sender = sender;
    transport.last_sender_valid = true;
    if (bytes <= 0 ||
        bytes % (ssize_t)sizeof(uint32_t) != 0 ||
        bytes > (ssize_t)sizeof(wire)) {
        transport.receive_count = 0;
        transport.last_status = 3;
        return 0;
    }
    int frame_words = (int)(bytes / (ssize_t)sizeof(uint32_t));
    uint32_t payload_count = ntohl(wire[2]);
    uint32_t sequence = ntohl(wire[3]);
    if (ntohl(wire[0]) != KOOKIE_TRANSPORT_MAGIC ||
        ntohl(wire[1]) != KOOKIE_TRANSPORT_VERSION ||
        payload_count == 0 ||
        payload_count > KOOKIE_TRANSPORT_MAX_WORDS ||
        frame_words != KOOKIE_TRANSPORT_HEADER_WORDS + (int)payload_count ||
        sequence == 0 ||
        sequence <= transport.receive_sequence) {
        transport.receive_count = 0;
        transport.last_status = 3;
        return 0;
    }
    uint64_t expected_mac =
        (uint64_t)ntohl(wire[4]) |
        ((uint64_t)ntohl(wire[5]) << 32);
    uint32_t received_mac_low = wire[4];
    uint32_t received_mac_high = wire[5];
    wire[4] = 0;
    wire[5] = 0;
    uint64_t actual_mac = kookie_transport_mac(
        (const uint8_t *)wire, (size_t)bytes);
    wire[4] = received_mac_low;
    wire[5] = received_mac_high;
    if (actual_mac != expected_mac) {
        transport.receive_count = 0;
        transport.last_status = 3;
        return 0;
    }
    transport.receive_count = (int)payload_count;
    transport.receive_sequence = sequence;
    for (int index = 0; index < transport.receive_count; index += 1) {
        transport.receive_words[index] =
            (int)ntohl(wire[KOOKIE_TRANSPORT_HEADER_WORDS + index]);
    }
    transport.last_status = 1;
    return transport.receive_count;
}

int kookie_transport_receive(void) {
    return kookie_transport_receive_with_flags(0);
}

int kookie_transport_receive_available(void) {
    return kookie_transport_receive_with_flags(MSG_DONTWAIT);
}

int kookie_transport_receive_word(int index) {
    if (index < 0 || index >= transport.receive_count) {
        return 0;
    }
    return transport.receive_words[index];
}

int kookie_transport_receive_sum(void) {
    int sum = 0;
    for (int index = 0; index < transport.receive_count; index += 1) {
        sum += transport.receive_words[index];
    }
    return sum;
}

int kookie_transport_last_status(void) {
    return transport.last_status;
}

int kookie_transport_timeout_milliseconds(void) {
    return kookie_transport_receive_timeout_milliseconds();
}

bool kookie_transport_close(void) {
    if (transport.socket_fd < 0) {
        return false;
    }
    close(transport.socket_fd);
    if (transport.receive_socket_fd >= 0 &&
        transport.receive_socket_fd != transport.socket_fd) {
        close(transport.receive_socket_fd);
    }
    memset(&transport, 0, sizeof(transport));
    transport.socket_fd = -1;
    transport.receive_socket_fd = -1;
    transport.key0 = 0;
    transport.key1 = 0;
    transport.key_configured = false;
    return true;
}

static struct timespec kookie_measurement_start;
static bool kookie_measurement_started;

static int kookie_headless_environment_int(
    const char *name, int fallback, int minimum, int maximum
) {
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

bool kookie_headless_measure_begin(void) {
    if (clock_gettime(CLOCK_MONOTONIC, &kookie_measurement_start) != 0) {
        kookie_measurement_started = false;
        return false;
    }
    kookie_measurement_started = true;
    return true;
}

int kookie_headless_measure_elapsed_microseconds(void) {
    if (!kookie_measurement_started) {
        return -1;
    }
    struct timespec end;
    if (clock_gettime(CLOCK_MONOTONIC, &end) != 0) {
        return -1;
    }
    int64_t seconds = (int64_t)end.tv_sec - (int64_t)kookie_measurement_start.tv_sec;
    int64_t nanoseconds = (int64_t)end.tv_nsec - (int64_t)kookie_measurement_start.tv_nsec;
    if (nanoseconds < 0) {
        seconds -= 1;
        nanoseconds += INT64_C(1000000000);
    }
    int64_t microseconds = seconds * INT64_C(1000000) + nanoseconds / 1000;
    if (microseconds < 0) {
        return -1;
    }
    if (microseconds > INT_MAX) {
        return INT_MAX;
    }
    return (int)microseconds;
}

int kookie_headless_rss_kib(void) {
    FILE *status = fopen("/proc/self/statm", "r");
    if (status == NULL) {
        return -1;
    }
    unsigned long total_pages = 0;
    unsigned long resident_pages = 0;
    int fields = fscanf(status, "%lu %lu", &total_pages, &resident_pages);
    fclose(status);
    if (fields != 2) {
        return -1;
    }
    long page_size = sysconf(_SC_PAGESIZE);
    if (page_size <= 0) {
        return -1;
    }
    uint64_t kib = ((uint64_t)resident_pages * (uint64_t)page_size) / 1024U;
    if (kib > INT_MAX) {
        return INT_MAX;
    }
    return (int)kib;
}

bool kookie_headless_sleep_microseconds(int microseconds) {
    if (microseconds < 0 || microseconds > 1000000) {
        return false;
    }
    struct timespec remaining = {
        .tv_sec = microseconds / 1000000,
        .tv_nsec = (long)(microseconds % 1000000) * 1000L
    };
    while (nanosleep(&remaining, &remaining) != 0) {
        if (errno != EINTR) {
            return false;
        }
    }
    return true;
}

int kookie_headless_requested_ticks(void) {
    return kookie_headless_environment_int(
        "KOOKIE_SERVER_TICKS", 2048, 1, 10000000);
}

int kookie_headless_warmup_ticks(void) {
    return kookie_headless_environment_int(
        "KOOKIE_SERVER_WARMUP_TICKS", 256, 0, 1000000);
}

int kookie_headless_sample_interval(void) {
    return kookie_headless_environment_int(
        "KOOKIE_SERVER_RSS_SAMPLE_TICKS", 64, 1, 1000000);
}

bool kookie_headless_realtime(void) {
    const char *encoded = getenv("KOOKIE_SERVER_REALTIME");
    return encoded != NULL && strcmp(encoded, "1") == 0;
}
