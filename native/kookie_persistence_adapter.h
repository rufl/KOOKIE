#ifndef KOOKIE_PERSISTENCE_ADAPTER_H
#define KOOKIE_PERSISTENCE_ADAPTER_H

#include <stdbool.h>

bool kookie_durable_publish(const char *staging_path, const char *target_path);
bool kookie_durable_publish_default(void);
int kookie_durable_trace(void);
int kookie_durable_mode(void);

bool kookie_durable_host_stage_begin(int wire_length);
bool kookie_durable_host_stage_word(int index, int value);
bool kookie_durable_host_stage_commit(void);
bool kookie_durable_host_stage_cancel(void);
bool kookie_durable_host_staging_exists(void);
bool kookie_durable_host_discard_stage(void);
bool kookie_durable_host_target_exists(void);
bool kookie_durable_host_load_begin(void);
int kookie_durable_host_load_length(void);
int kookie_durable_host_load_word(int index);

#endif
