#ifndef KOOKIE_WEB_SERVER_H
#define KOOKIE_WEB_SERVER_H

#include <stdbool.h>

bool kookie_web_server_open(int port);
bool kookie_web_server_accept(void);
int kookie_web_server_read_byte(void);
bool kookie_web_server_send_begin(int length);
bool kookie_web_server_send_byte(int index, int value);
bool kookie_web_server_send_commit(void);
bool kookie_web_server_set_websocket_key_byte(int index, int value);
int kookie_web_server_websocket_accept_length(void);
int kookie_web_server_websocket_accept_byte(int index);
bool kookie_web_server_close_client(void);
bool kookie_web_server_close(void);
int kookie_web_server_port(void);
int kookie_web_server_max_connections(void);

#endif
