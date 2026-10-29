#ifndef KOOKIE_KUTTER_SYNC_H
#define KOOKIE_KUTTER_SYNC_H
#include <stdbool.h>
/* Nonblocking, bounded kookie.v1 WebSocket client. Set
 * KOOKIE_KUTTER_HOST and KOOKIE_KUTTER_PORT; KOOKIE_KUTTER_PATH defaults to
 * /kutter/session. KOOKIE_KUTTER_SCHEME defaults to wss. Plain ws is accepted
 * only when the scheme is explicitly set to ws and HOST is localhost, an IPv4
 * 127/8 address, or ::1. wss uses libcurl's normal CA and hostname verification;
 * there is no insecure fallback. Use /session for direct loopback Kof access.
 * KOOKIE_KUTTER_TOKEN is optional; when nonempty, it is sent as the bearer.
 * WebSocket subprotocol and must contain 8–128 ASCII letters, digits, '.', '_',
 * '~', or '-'. It is never logged.
 * Build against libcurl 7.86.0 or later for its WebSocket API. */
bool kookie_kutter_sync_open(void);
int kookie_kutter_sync_state(void); /* 0 closed, 1 connecting, 2 open, -1 failed */
bool kookie_kutter_sync_send_begin(int word_count);
bool kookie_kutter_sync_send_word(int index, int word);
bool kookie_kutter_sync_send_commit(void);
int kookie_kutter_sync_receive_available(void);
int kookie_kutter_sync_receive_word(int index);
bool kookie_kutter_sync_close(void);
#endif
