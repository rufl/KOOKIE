#ifndef KOOKIE_WEB_SERVER_H
#define KOOKIE_WEB_SERVER_H

#include <stdbool.h>

/*
 * C-owned asynchronous socket adapter. All functions below except open/close
 * are called by the Kof main thread. Worker threads never call Kof or retain
 * Kof memory. IDs are positive, monotonically increasing connection tokens;
 * they are not array indices and are not reused during one open lifetime.
 *
 * Limits: 12 connections, 64 queued events, 8192-byte HTTP requests,
 * 1104-byte WebSocket payloads, and 16384 bytes per committed output.
 * Event data is copied into the current event and remains valid until the
 * next poll_event call. Connection slots are not reused until its disconnect
 * event is consumed. poll_event returns 0 for timeout, otherwise event kinds:
 * 1 accept, 2 complete HTTP request, 3 complete WebSocket frame,
 * 4 disconnect. -1 means adapter closed/error. WebSocket opcode and payload
 * accessors apply to kind 3; request payload accessors apply to kind 2.
 *
 * upgrade_websocket accepts an HTTP connection whose request has a valid
 * 24-byte Sec-WebSocket-Key and queues the RFC6455 101 response. Unmasked,
 * fragmented, reserved-bit, oversized, or unsupported frames disconnect;
 * close frames receive a close reply before disconnect. Output is staged with
 * output_begin/write_byte/commit; output overflow/backpressure disconnects.
 * Idle sockets expire after 30 seconds. close_client disconnects immediately;
 * close_client_after_output drains queued bytes before disconnecting. close
 * shuts down the adapter. Functions fail for stale IDs or invalid arguments.
 */
bool kookie_web_server_open(int port);
int kookie_web_server_poll_event(int timeout_ms);
int kookie_web_server_event_connection_id(void);
int kookie_web_server_event_opcode(void);
int kookie_web_server_event_payload_length(void);
int kookie_web_server_event_payload_byte(int index);
bool kookie_web_server_upgrade_websocket(int connection_id);
bool kookie_web_server_output_begin(int connection_id, int length);
bool kookie_web_server_output_write_byte(int index, int value);
bool kookie_web_server_output_commit(void);
bool kookie_web_server_close_client(int connection_id);
bool kookie_web_server_close_client_after_output(int connection_id);
bool kookie_web_server_close(void);
long long kookie_web_server_monotonic_nanoseconds(void);
int kookie_web_server_port(void);
int kookie_web_server_max_connections(void);

#endif
