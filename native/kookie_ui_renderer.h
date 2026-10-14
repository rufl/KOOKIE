#ifndef KOOKIE_UI_RENDERER_H
#define KOOKIE_UI_RENDERER_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

typedef struct {
    int resource;
    int x;
    int y;
    int depth;
    int u;
    int v;
} KookieUiVertex;

typedef struct {
    int font;
    int color;
    int left;
    int bottom;
    int scale;
    const uint32_t *codepoints;
    size_t codepoint_count;
} KookieUiTextRun;

typedef struct KookieUiRenderer KookieUiRenderer;

KookieUiRenderer *kookie_ui_renderer_create(void);
void kookie_ui_renderer_destroy(KookieUiRenderer *renderer);
bool kookie_ui_renderer_render(
    KookieUiRenderer *renderer,
    const KookieUiVertex *vertices,
    size_t vertex_count,
    const KookieUiTextRun *text_runs,
    size_t text_run_count,
    uint32_t width,
    uint32_t height,
    const uint8_t **pixels,
    size_t *pixel_bytes
);

#endif
