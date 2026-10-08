#ifndef KOOKIE_MODEL_ASSETS_H
#define KOOKIE_MODEL_ASSETS_H

#include <stdbool.h>

#define KOOKIE_MODEL_GOOSE 1
#define KOOKIE_MODEL_CAT 2

typedef bool (*KookieModelEmitVertex)(
    void *context, int resource, int x, int y, int z, int u, int v);

bool kookie_model_assets_available(int model);
int kookie_model_assets_vertex_count(int model);
bool kookie_model_assets_emit(
    int model,
    int resource_base,
    int x,
    int y,
    int z,
    int facing,
    int phase,
    int animation_state,
    int animation_tick,
    int moving,
    int attacking,
    KookieModelEmitVertex emit,
    void *context);

#endif
