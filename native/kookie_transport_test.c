#define _POSIX_C_SOURCE 200809L
#include "kookie_transport.h"

#include <arpa/inet.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/socket.h>
#include <unistd.h>


static void require_condition(bool condition, const char *message) {
    if (!condition) {
        fprintf(stderr, "transport-test-failed: %s\n", message);
        _exit(1);
    }
}

static int reserve_port(void) {
    int socket_fd = socket(AF_INET, SOCK_DGRAM, 0);
    require_condition(socket_fd >= 0, "reserve socket");
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(0);
    require_condition(bind(socket_fd, (struct sockaddr *)&address, sizeof(address)) == 0,
        "reserve bind");
    socklen_t length = sizeof(address);
    require_condition(getsockname(socket_fd, (struct sockaddr *)&address, &length) == 0,
        "reserve getsockname");
    int port = (int)ntohs(address.sin_port);
    close(socket_fd);
    return port;
}
static void write_key_file(char *path) {
    int file_descriptor = mkstemp(path);
    require_condition(file_descriptor >= 0, "create key file");
    const char key[] = "00000001000000020000000300000004";
    require_condition(fchmod(file_descriptor, 0600) == 0 &&
        write(file_descriptor, key, sizeof(key) - 1) ==
            (ssize_t)(sizeof(key) - 1),
        "write key file");
    require_condition(close(file_descriptor) == 0, "close key file");
}


int main(void) {
    require_condition(setenv(
        "KOOKIE_EXTERNAL_LAN_HOST_IPV4", "127.0.0.1", 1) == 0 &&
        kookie_transport_external_host_octet(0) == 127 &&
        kookie_transport_external_host_octet(1) == 0 &&
        kookie_transport_external_host_octet(2) == 0 &&
        kookie_transport_external_host_octet(3) == 1,
        "parse valid IPv4 environment");
    require_condition(setenv(
        "KOOKIE_EXTERNAL_LAN_HOST_IPV4", "127.0.0.999", 1) == 0 &&
        kookie_transport_external_host_octet(0) == -1,
        "reject out-of-range IPv4 environment");
    require_condition(setenv(
        "KOOKIE_EXTERNAL_LAN_HOST_IPV4",
        "999999999999999999999999.0.0.1", 1) == 0 &&
        kookie_transport_external_host_octet(0) == -1,
        "reject overflowing IPv4 environment");
    unsetenv("KOOKIE_EXTERNAL_LAN_HOST_IPV4");
    require_condition(
        kookie_transport_select_slot(3) &&
        !kookie_transport_set_key(0, 0, 0, 0),
        "reject all-zero transport key");

    int listener_port = reserve_port();
    require_condition(kookie_transport_select_slot(0), "select listener slot");
    require_condition(kookie_transport_set_key(1, 2, 3, 4), "configure listener key");
    require_condition(kookie_transport_open_listen_ipv4(listener_port), "open listener");
    require_condition(kookie_transport_send_begin(1) &&
        kookie_transport_send_word(0, 7) &&
        !kookie_transport_send_commit(),
        "reject send without a configured peer");


    int raw_socket = socket(AF_INET, SOCK_DGRAM, 0);
    require_condition(raw_socket >= 0, "open unauthenticated sender");
    struct sockaddr_in listener;
    memset(&listener, 0, sizeof(listener));
    listener.sin_family = AF_INET;
    listener.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    listener.sin_port = htons((uint16_t)listener_port);
    const uint8_t invalid_wire[] = {0, 0, 0, 0};
    require_condition(sendto(raw_socket, invalid_wire, sizeof(invalid_wire), 0,
        (struct sockaddr *)&listener, sizeof(listener)) == (ssize_t)sizeof(invalid_wire),
        "send unauthenticated datagram");
    struct sockaddr_in raw_local;
    socklen_t raw_local_length = sizeof(raw_local);
    require_condition(
        getsockname(raw_socket, (struct sockaddr *)&raw_local, &raw_local_length) == 0,
        "inspect unauthenticated sender port");
    int raw_port = (int)ntohs(raw_local.sin_port);
    int explicit_listener_port = reserve_port();
    require_condition(
        kookie_transport_select_slot(2) &&
        kookie_transport_set_key(1, 2, 3, 4) &&
        kookie_transport_open_listen_ipv4(explicit_listener_port) &&
        kookie_transport_send_begin(1) &&
        kookie_transport_send_word(0, 9) &&
        !kookie_transport_send_commit() &&
        kookie_transport_set_peer_ipv4(127, 0, 0, 1, raw_port) &&
        kookie_transport_send_begin(1) &&
        kookie_transport_send_word(0, 9) &&
        kookie_transport_send_commit() &&
        kookie_transport_close() &&
        kookie_transport_select_slot(0),
        "send after explicit peer configuration");
    require_condition(kookie_transport_receive_available() == 0 &&
        kookie_transport_last_status() == 3 &&
        !kookie_transport_set_peer_last_sender(),
        "reject unauthenticated datagram and do not promote sender");

    require_condition(kookie_transport_select_slot(1), "select authenticated sender slot");
    require_condition(kookie_transport_set_key(1, 2, 3, 4), "configure sender key");
    require_condition(kookie_transport_open_remote_ipv4(127, 0, 0, 1, listener_port),
        "open authenticated sender");
    require_condition(kookie_transport_send_begin(1) &&
        kookie_transport_send_word(0, 42) &&
        kookie_transport_send_commit(), "send authenticated datagram");

    require_condition(kookie_transport_select_slot(0), "return to listener slot");
    require_condition(kookie_transport_receive() == 1 &&
        kookie_transport_last_status() == 1 &&
        kookie_transport_receive_word(0) == 42,
        "accept authenticated datagram");
    require_condition(kookie_transport_set_peer_last_sender(),
        "promote authenticated sender");
    require_condition(
        kookie_transport_select_slot(2) &&
        kookie_transport_set_key(1, 2, 3, 4) &&
        kookie_transport_open_remote_ipv4(127, 0, 0, 1, listener_port) &&
        kookie_transport_send_begin(1) &&
        kookie_transport_send_word(0, 43) &&
        kookie_transport_send_commit() &&
        kookie_transport_select_slot(0) &&
        kookie_transport_receive_available() == 0 &&
        kookie_transport_last_status() == 3 &&
        !kookie_transport_set_peer_last_sender() &&
        kookie_transport_select_slot(2) &&
        kookie_transport_close() &&
        kookie_transport_select_slot(0),
        "reject authenticated datagram from a different endpoint");

    require_condition(sendto(raw_socket, invalid_wire, sizeof(invalid_wire), 0,
        (struct sockaddr *)&listener, sizeof(listener)) == (ssize_t)sizeof(invalid_wire),
        "send second invalid datagram");
    require_condition(kookie_transport_receive_available() == 0 &&
        kookie_transport_last_status() == 3 &&
        !kookie_transport_set_peer_last_sender(),
        "clear sender after rejected datagram");

    close(raw_socket);
    require_condition(kookie_transport_close(), "close listener");
    require_condition(kookie_transport_select_slot(1) && kookie_transport_close(),
        "close sender");
    char key_path[] = "/tmp/kookie-transport-key-XXXXXX";
    write_key_file(key_path);
    require_condition(
        setenv("KOOKIE_TRANSPORT_KEY_FILE", key_path, 1) == 0 &&
        kookie_transport_select_slot(2) &&
        kookie_transport_set_key_from_file(),
        "load regular key file");
    char extra_path[] = "/tmp/kookie-transport-key-extra-XXXXXX";
    write_key_file(extra_path);
    int extra_descriptor = open(extra_path, O_WRONLY | O_APPEND);
    require_condition(extra_descriptor >= 0 &&
        write(extra_descriptor, "x", 1) == 1 &&
        close(extra_descriptor) == 0 &&
        setenv("KOOKIE_TRANSPORT_KEY_FILE", extra_path, 1) == 0 &&
        !kookie_transport_set_key_from_file(),
        "reject key file with extra bytes");
    unlink(extra_path);


    char link_path[] = "/tmp/kookie-transport-key-link-XXXXXX";
    int link_descriptor = mkstemp(link_path);
    require_condition(link_descriptor >= 0 &&
        close(link_descriptor) == 0 &&
        unlink(link_path) == 0 &&
        symlink(key_path, link_path) == 0,
        "create key symlink");
    require_condition(
        setenv("KOOKIE_TRANSPORT_KEY_FILE", link_path, 1) == 0 &&
        !kookie_transport_set_key_from_file(),
        "reject key symlink");
    unsetenv("KOOKIE_TRANSPORT_KEY_FILE");
    unlink(link_path);
    unlink(key_path);

    puts("transport-sender-authentication-regression: passed");
    return 0;
}
