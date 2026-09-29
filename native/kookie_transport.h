#ifndef KOOKIE_TRANSPORT_H
#define KOOKIE_TRANSPORT_H

#include <stdbool.h>

bool kookie_transport_select_slot(int slot);
bool kookie_transport_set_key(
    int key0_low, int key0_high, int key1_low, int key1_high);
bool kookie_transport_set_key_from_environment(void);
bool kookie_transport_set_key_from_file(void);
bool kookie_transport_rotate_key_from_file(void);
bool kookie_transport_open(void);
bool kookie_transport_open_pair(void);
bool kookie_transport_open_remote_ipv4(
    int first_octet, int second_octet, int third_octet,
    int fourth_octet, int port);
bool kookie_transport_open_remote_environment(int port);
int kookie_transport_external_host_octet(int index);
bool kookie_transport_external_is_host(void);
bool kookie_transport_external_is_client_a(void);
bool kookie_transport_external_is_client_b(void);
bool kookie_transport_open_local_ipv4(int port);
bool kookie_transport_open_listen_ipv4(int port);
bool kookie_transport_set_peer_ipv4(
    int first_octet, int second_octet, int third_octet,
    int fourth_octet, int port);
bool kookie_transport_set_peer_last_sender(void);
bool kookie_transport_received_sequence_at_least(int minimum);
int kookie_transport_peer_port(void);
int kookie_transport_local_port(void);
int kookie_transport_max_words(void);
bool kookie_transport_send_begin(int word_count);
bool kookie_transport_send_word(int index, int word);
bool kookie_transport_send_commit(void);
bool kookie_transport_replay_last_datagram(void);
int kookie_transport_receive(void);
int kookie_transport_receive_available(void);
int kookie_transport_receive_word(int index);
int kookie_transport_receive_sum(void);
int kookie_transport_last_status(void);
int kookie_transport_timeout_milliseconds(void);
bool kookie_transport_close(void);

bool kookie_headless_measure_begin(void);
int kookie_headless_measure_elapsed_microseconds(void);
int kookie_headless_rss_kib(void);
bool kookie_headless_sleep_microseconds(int microseconds);
int kookie_headless_requested_ticks(void);
int kookie_headless_warmup_ticks(void);
int kookie_headless_sample_interval(void);
bool kookie_headless_realtime(void);

#endif
