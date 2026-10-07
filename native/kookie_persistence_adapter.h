#ifndef KOOKIE_PERSISTENCE_ADAPTER_H
#define KOOKIE_PERSISTENCE_ADAPTER_H

#include <stdbool.h>

bool kookie_durable_publish(const char *staging_path, const char *target_path);
bool kookie_durable_publish_default(void);
int kookie_durable_trace(void);
int kookie_durable_mode(void);

#endif
