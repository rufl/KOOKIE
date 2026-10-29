#include "kookie_ui_renderer.h"

#include <ft2build.h>
#include FT_FREETYPE_H
#include <hb-ft.h>
#include <hb.h>

#include "kookie_heart_atlas.h"

#include <ctype.h>
#include <errno.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define KOOKIE_UI_FONT_COUNT 2
#define KOOKIE_UI_SVG_SIZE 96
#define KOOKIE_UI_SVG_MAX_BYTES (64u * 1024u)
#define KOOKIE_UI_MAX_SVG_POLYGONS 32
#define KOOKIE_UI_MAX_SVG_POINTS 128
#define KOOKIE_UI_MAX_CODEPOINTS 4096
#define KOOKIE_UI_MAX_SURFACE_PIXELS (4096u * 4096u)
#define KOOKIE_UI_LOGICAL_SPAN 200.0f

static const uint8_t kookie_ui_palette[16][4] = {
    { 71,  85, 105, 255}, { 37,  99, 235, 255},
    { 15, 118, 110, 255}, {124,  58, 237, 255},
    {180,  83,   9, 255}, {220,  38,  38, 255},
    {  8, 145, 178, 255}, {101, 163,  13, 255},
    {203, 213, 225, 255}, { 15,  23,  42, 255},
    { 15,  31,  43, 255}, {220,  38,  38, 255},
    {217, 119,   6, 255}, { 21, 128,  61, 255},
    { 34, 197,  94, 255}, {248, 250, 252, 255}
};

static const int kookie_ui_font_palette[5] = {15, 12, 8, 11, 14};

typedef struct {
    float x;
    float y;
} KookieSvgPoint;

typedef struct {
    KookieSvgPoint points[KOOKIE_UI_MAX_SVG_POINTS];
    size_t count;
    uint8_t color[4];
} KookieSvgPolygon;

typedef struct {
    FT_Face face;
    hb_font_t *hb_font;
} KookieUiFont;

struct KookieUiRenderer {
    FT_Library freetype;
    KookieUiFont fonts[KOOKIE_UI_FONT_COUNT];
    KookieSvgPolygon svg_polygons[KOOKIE_UI_MAX_SVG_POLYGONS];
    size_t svg_polygon_count;
    bool svg_ready;
    uint8_t *svg_pixels;
    uint8_t *pixels;
    uint16_t *depth;
    size_t pixel_capacity;
    uint32_t width;
    uint32_t height;
};

static bool kookie_ui_checked_size(
    uint32_t width, uint32_t height, size_t *pixel_count, size_t *bytes
) {
    if (width == 0 || height == 0 ||
        (uint64_t)width * (uint64_t)height > KOOKIE_UI_MAX_SURFACE_PIXELS) {
        return false;
    }
    size_t count = (size_t)width * (size_t)height;
    if (count > SIZE_MAX / 4u || count * 4u > SIZE_MAX / sizeof(uint16_t)) {
        return false;
    }
    if (pixel_count != NULL) {
        *pixel_count = count;
    }
    if (bytes != NULL) {
        *bytes = count * 4u;
    }
    return true;
}

static char *kookie_ui_join_path(
    const char *directory, const char *name
) {
    if (directory == NULL || directory[0] == '\0' || name == NULL) {
        return NULL;
    }
    size_t directory_length = strlen(directory);
    size_t name_length = strlen(name);
    bool separator = directory[directory_length - 1u] != '/' &&
        directory[directory_length - 1u] != '\\';
    size_t length = directory_length + (separator ? 1u : 0u) + name_length;
    if (length > SIZE_MAX - 1u) {
        return NULL;
    }
    char *path = (char *)malloc(length + 1u);
    if (path == NULL) {
        return NULL;
    }
    int written = snprintf(
        path, length + 1u, "%s%s%s", directory,
        separator ? "/" : "", name);
    if (written < 0 || (size_t)written != length) {
        free(path);
        return NULL;
    }
    return path;
}

static FILE *kookie_ui_open_asset(
    const char *environment_name,
    const char *relative_name,
    char *resolved_path,
    size_t resolved_path_size
) {
    const char *environment = getenv(environment_name);
    const char *candidates[8] = {0};
    char *environment_path = NULL;
    size_t candidate_count = 0;
    if (environment != NULL && environment[0] != '\0') {
        environment_path = kookie_ui_join_path(environment, relative_name);
        if (environment_path != NULL) {
            candidates[candidate_count++] = environment_path;
        }
    }
    candidates[candidate_count++] = relative_name;
    char *parent_path = kookie_ui_join_path("../", relative_name);
    if (parent_path != NULL) {
        candidates[candidate_count++] = parent_path;
    }
    char *package_path = kookie_ui_join_path("assets", relative_name);
    if (package_path != NULL) {
        candidates[candidate_count++] = package_path;
    }

    FILE *file = NULL;
    for (size_t index = 0; index < candidate_count; index += 1u) {
        if (candidates[index] == NULL) {
            continue;
        }
        file = fopen(candidates[index], "rb");
        if (file != NULL) {
            if (resolved_path != NULL && resolved_path_size > 0u) {
                int written = snprintf(
                    resolved_path, resolved_path_size, "%s", candidates[index]);
                if (written < 0 || (size_t)written >= resolved_path_size) {
                    fclose(file);
                    file = NULL;
                }
            }
            break;
        }
    }
    free(environment_path);
    free(parent_path);
    free(package_path);
    return file;
}

static bool kookie_ui_load_font(
    KookieUiRenderer *renderer, size_t index, const char *name
) {
    char path[512] = {0};
    FILE *probe = kookie_ui_open_asset(
        "KOOKIE_FONT_DIR", name, path, sizeof(path));
    if (probe == NULL) {
        char relative_name[128] = {0};
        int written = snprintf(
            relative_name, sizeof(relative_name), "fonts/%s", name);
        if (written < 0 || (size_t)written >= sizeof(relative_name)) {
            return false;
        }
        probe = kookie_ui_open_asset(
            "KOOKIE_ASSET_DIR", relative_name, path, sizeof(path));
    }
    if (probe == NULL) {
        return false;
    }
    fclose(probe);
    FT_Face face = NULL;
    if (FT_New_Face(renderer->freetype, path, 0, &face) != 0 || face == NULL) {
        return false;
    }
    hb_font_t *hb_font = hb_ft_font_create_referenced(face);
    if (hb_font == NULL) {
        FT_Done_Face(face);
        return false;
    }
    renderer->fonts[index].face = face;
    renderer->fonts[index].hb_font = hb_font;
    return true;
}

static void kookie_ui_skip_space(const char **cursor, const char *end) {
    while (*cursor < end &&
        (isspace((unsigned char)**cursor) || **cursor == ',')) {
        *cursor += 1;
    }
}

static bool kookie_ui_parse_float(
    const char **cursor, const char *end, float *value
) {
    kookie_ui_skip_space(cursor, end);
    if (*cursor >= end || value == NULL) {
        return false;
    }
    char buffer[64];
    size_t length = 0;
    const char *start = *cursor;
    bool sign_allowed = true;
    while (*cursor < end && length + 1u < sizeof(buffer)) {
        char character = **cursor;
        if (isdigit((unsigned char)character) || character == '.') {
            sign_allowed = false;
        } else if (character == 'e' || character == 'E') {
            sign_allowed = true;
        } else if (character == '-' || character == '+') {
            if (!sign_allowed) {
                break;
            }
            sign_allowed = false;
        } else {
            break;
        }
        buffer[length++] = character;
        *cursor += 1;
    }
    if (*cursor == start || length == 0u) {
        return false;
    }
    buffer[length] = '\0';
    char *end_number = NULL;
    errno = 0;
    float parsed = strtof(buffer, &end_number);
    if (errno == ERANGE || end_number == buffer || *end_number != '\0') {
        return false;
    }
    *value = parsed;
    return true;
}

static const char *kookie_ui_attribute(
    const char *tag, const char *end, const char *name, size_t *length
) {
    size_t name_length = strlen(name);
    const char *cursor = tag;
    while (cursor < end) {
        while (cursor < end && (isspace((unsigned char)*cursor) || *cursor == '<' ||
            *cursor == '/' || *cursor == '>')) {
            cursor += 1;
        }
        if (cursor + name_length >= end ||
            strncmp(cursor, name, name_length) != 0 ||
            (cursor > tag && (isalnum((unsigned char)cursor[-1]) ||
                cursor[-1] == '_' || cursor[-1] == '-')) ||
            (cursor + name_length < end &&
                (isalnum((unsigned char)cursor[name_length]) ||
                    cursor[name_length] == '_' || cursor[name_length] == '-'))) {
            while (cursor < end && !isspace((unsigned char)*cursor) &&
                *cursor != '=') {
                cursor += 1;
            }
            if (cursor < end && *cursor == '=') {
                cursor += 1;
                while (cursor < end && isspace((unsigned char)*cursor)) {
                    cursor += 1;
                }
                if (cursor < end && (*cursor == '\'' || *cursor == '"')) {
                    char quote = *cursor++;
                    while (cursor < end && *cursor != quote) {
                        cursor += 1;
                    }
                    if (cursor < end) {
                        cursor += 1;
                    }
                } else {
                    while (cursor < end && !isspace((unsigned char)*cursor) &&
                        *cursor != '>') {
                        cursor += 1;
                    }
                }
            }
            continue;
        }
        cursor += name_length;
        while (cursor < end && isspace((unsigned char)*cursor)) {
            cursor += 1;
        }
        if (cursor >= end || *cursor != '=') {
            continue;
        }
        cursor += 1;
        while (cursor < end && isspace((unsigned char)*cursor)) {
            cursor += 1;
        }
        if (cursor >= end || (*cursor != '\'' && *cursor != '"')) {
            continue;
        }
        char quote = *cursor++;
        const char *value = cursor;
        while (cursor < end && *cursor != quote) {
            cursor += 1;
        }
        if (length != NULL) {
            *length = (size_t)(cursor - value);
        }
        return value;
    }
    return NULL;
}

static bool kookie_ui_parse_color(
    const char *tag, const char *end, uint8_t color[4]
) {
    size_t length = 0;
    const char *value = kookie_ui_attribute(tag, end, "fill", &length);
    if (value == NULL || (length != 4u && length != 7u) || value[0] != '#') {
        return false;
    }
    for (size_t channel = 0; channel < 3u; channel += 1u) {
        char component[3];
        if (length == 4u) {
            component[0] = value[1u + channel];
            component[1] = component[0];
        } else {
            component[0] = value[1u + channel * 2u];
            component[1] = value[2u + channel * 2u];
        }
        component[2] = '\0';
        char *component_end = NULL;
        unsigned long parsed = strtoul(component, &component_end, 16);
        if (component_end == component || *component_end != '\0') {
            return false;
        }
        color[channel] = (uint8_t)parsed;
    }
    color[3] = 255;
    return true;
}

static bool kookie_ui_polygon_push(
    KookieSvgPolygon *polygon, float x, float y
) {
    if (polygon == NULL || polygon->count >= KOOKIE_UI_MAX_SVG_POINTS ||
        !isfinite(x) || !isfinite(y)) {
        return false;
    }
    polygon->points[polygon->count].x = x;
    polygon->points[polygon->count].y = y;
    polygon->count += 1u;
    return true;
}

static bool kookie_ui_parse_path(
    const char *value, size_t length, KookieSvgPolygon *polygon
) {
    const char *cursor = value;
    const char *end = value + length;
    char command = 0;
    float current_x = 0.0f;
    float current_y = 0.0f;
    float start_x = 0.0f;
    float start_y = 0.0f;
    while (cursor < end) {
        kookie_ui_skip_space(&cursor, end);
        if (cursor >= end) {
            break;
        }
        if (isalpha((unsigned char)*cursor)) {
            command = *cursor++;
            if (command == 'Z' || command == 'z') {
                if (polygon->count > 2u) {
                    kookie_ui_polygon_push(polygon, start_x, start_y);
                }
                current_x = start_x;
                current_y = start_y;
                continue;
            }
        } else if (command == 0) {
            return false;
        }
        bool relative = command >= 'a' && command <= 'z';
        char operation = (char)tolower((unsigned char)command);
        float first = 0.0f;
        float second = 0.0f;
        if (operation == 'h' || operation == 'v') {
            if (!kookie_ui_parse_float(&cursor, end, &first)) {
                return false;
            }
            if (operation == 'h') {
                current_x = relative ? current_x + first : first;
            } else {
                current_y = relative ? current_y + first : first;
            }
            if (!kookie_ui_polygon_push(polygon, current_x, current_y)) {
                return false;
            }
            continue;
        }
        if (operation != 'm' && operation != 'l') {
            return false;
        }
        if (!kookie_ui_parse_float(&cursor, end, &first) ||
            !kookie_ui_parse_float(&cursor, end, &second)) {
            return false;
        }
        float x = relative ? current_x + first : first;
        float y = relative ? current_y + second : second;
        if (operation == 'm') {
            if (polygon->count > 2u) {
                return false;
            }
            start_x = x;
            start_y = y;
        }
        if (!kookie_ui_polygon_push(polygon, x, y)) {
            return false;
        }
        current_x = x;
        current_y = y;
        if (operation == 'm') {
            command = relative ? 'l' : 'L';
        }
    }
    return polygon->count >= 3u;
}

static bool kookie_ui_parse_point_list(
    const char *value, size_t length, KookieSvgPolygon *polygon
) {
    const char *cursor = value;
    const char *end = value + length;
    while (cursor < end) {
        float x = 0.0f;
        float y = 0.0f;
        if (!kookie_ui_parse_float(&cursor, end, &x) ||
            !kookie_ui_parse_float(&cursor, end, &y) ||
            !kookie_ui_polygon_push(polygon, x, y)) {
            return false;
        }
    }
    return polygon->count >= 3u;
}

static bool kookie_ui_parse_shape(
    KookieUiRenderer *renderer,
    const char *name,
    const char *tag,
    const char *end
) {
    if (renderer->svg_polygon_count >= KOOKIE_UI_MAX_SVG_POLYGONS) {
        return false;
    }
    KookieSvgPolygon polygon = {0};
    if (!kookie_ui_parse_color(tag, end, polygon.color)) {
        return false;
    }
    size_t length = 0;
    const char *value = NULL;
    if (strcmp(name, "path") == 0) {
        value = kookie_ui_attribute(tag, end, "d", &length);
        if (value == NULL || !kookie_ui_parse_path(value, length, &polygon)) {
            return false;
        }
    } else if (strcmp(name, "polygon") == 0 || strcmp(name, "polyline") == 0) {
        value = kookie_ui_attribute(tag, end, "points", &length);
        if (value == NULL || !kookie_ui_parse_point_list(value, length, &polygon)) {
            return false;
        }
    } else if (strcmp(name, "rect") == 0) {
        float x = 0.0f;
        float y = 0.0f;
        float width = 0.0f;
        float height = 0.0f;
        size_t x_length = 0;
        size_t y_length = 0;
        size_t width_length = 0;
        size_t height_length = 0;
        const char *x_value = kookie_ui_attribute(tag, end, "x", &x_length);
        const char *y_value = kookie_ui_attribute(tag, end, "y", &y_length);
        const char *width_value = kookie_ui_attribute(tag, end, "width", &width_length);
        const char *height_value = kookie_ui_attribute(tag, end, "height", &height_length);
        if (x_value == NULL || y_value == NULL || width_value == NULL ||
            height_value == NULL ||
            !kookie_ui_parse_float(&x_value, x_value + x_length, &x) ||
            !kookie_ui_parse_float(&y_value, y_value + y_length, &y) ||
            !kookie_ui_parse_float(&width_value, width_value + width_length, &width) ||
            !kookie_ui_parse_float(&height_value, height_value + height_length, &height)) {
            return false;
        }
        kookie_ui_polygon_push(&polygon, x, y);
        kookie_ui_polygon_push(&polygon, x + width, y);
        kookie_ui_polygon_push(&polygon, x + width, y + height);
        kookie_ui_polygon_push(&polygon, x, y + height);
    } else if (strcmp(name, "line") == 0) {
        float x1 = 0.0f;
        float y1 = 0.0f;
        float x2 = 0.0f;
        float y2 = 0.0f;
        size_t length1 = 0;
        size_t length2 = 0;
        size_t length3 = 0;
        size_t length4 = 0;
        const char *x1_value = kookie_ui_attribute(tag, end, "x1", &length1);
        const char *y1_value = kookie_ui_attribute(tag, end, "y1", &length2);
        const char *x2_value = kookie_ui_attribute(tag, end, "x2", &length3);
        const char *y2_value = kookie_ui_attribute(tag, end, "y2", &length4);
        if (x1_value == NULL || y1_value == NULL || x2_value == NULL ||
            y2_value == NULL ||
            !kookie_ui_parse_float(&x1_value, x1_value + length1, &x1) ||
            !kookie_ui_parse_float(&y1_value, y1_value + length2, &y1) ||
            !kookie_ui_parse_float(&x2_value, x2_value + length3, &x2) ||
            !kookie_ui_parse_float(&y2_value, y2_value + length4, &y2)) {
            return false;
        }
        kookie_ui_polygon_push(&polygon, x1, y1);
        kookie_ui_polygon_push(&polygon, x2, y2);
        kookie_ui_polygon_push(&polygon, x2 + 0.5f, y2 + 0.5f);
    } else {
        return false;
    }
    renderer->svg_polygons[renderer->svg_polygon_count++] = polygon;
    return true;
}

static bool kookie_ui_parse_svg(
    KookieUiRenderer *renderer, const char *data, size_t length
) {
    const char *cursor = data;
    const char *end = data + length;
    while (cursor < end) {
        const char *tag = strchr(cursor, '<');
        if (tag == NULL || tag >= end) {
            break;
        }
        const char *tag_end = strchr(tag, '>');
        if (tag_end == NULL || tag_end >= end) {
            return false;
        }
        const char *name_start = tag + 1;
        bool closing_tag = false;
        while (name_start < tag_end && isspace((unsigned char)*name_start)) {
            name_start += 1;
        }
        if (name_start < tag_end && *name_start == '/') {
            closing_tag = true;
            name_start += 1;
        }
        while (name_start < tag_end &&
            isspace((unsigned char)*name_start)) {
            name_start += 1;
        }
        const char *name_end = name_start;
        while (name_end < tag_end &&
            isalpha((unsigned char)*name_end)) {
            name_end += 1;
        }
        size_t name_length = (size_t)(name_end - name_start);
        if (!closing_tag &&
            (name_length == 4u || name_length == 5u || name_length == 6u ||
             name_length == 7u || name_length == 8u)) {
            char name[16] = {0};
            if (name_length < sizeof(name)) {
                memcpy(name, name_start, name_length);
                if ((strcmp(name, "path") == 0 || strcmp(name, "rect") == 0 ||
                    strcmp(name, "line") == 0 || strcmp(name, "polygon") == 0 ||
                    strcmp(name, "polyline") == 0) &&
                    !kookie_ui_parse_shape(renderer, name, tag, tag_end)) {
                    return false;
                }
            }
        }
        cursor = tag_end + 1;
    }
    return renderer->svg_polygon_count > 0u;
}

static bool kookie_ui_load_svg(KookieUiRenderer *renderer) {
    char path[512] = {0};
    FILE *file = kookie_ui_open_asset(
        "KOOKIE_ASSET_DIR", "ui/gatoganso-mark.svg", path, sizeof(path));
    if (file == NULL || fseek(file, 0, SEEK_END) != 0) {
        if (file != NULL) {
            fclose(file);
        }
        return false;
    }
    long length = ftell(file);
    if (length <= 0 || (size_t)length > KOOKIE_UI_SVG_MAX_BYTES ||
        fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return false;
    }
    char *data = (char *)malloc((size_t)length + 1u);
    if (data == NULL || fread(data, 1, (size_t)length, file) != (size_t)length) {
        free(data);
        fclose(file);
        return false;
    }
    fclose(file);
    data[length] = '\0';
    bool parsed = kookie_ui_parse_svg(renderer, data, (size_t)length);
    free(data);
    if (!parsed) {
        return false;
    }
    renderer->svg_pixels = (uint8_t *)calloc(
        KOOKIE_UI_SVG_SIZE * KOOKIE_UI_SVG_SIZE, 4u);
    if (renderer->svg_pixels == NULL) {
        return false;
    }
    for (int y = 0; y < KOOKIE_UI_SVG_SIZE; y += 1) {
        for (int x = 0; x < KOOKIE_UI_SVG_SIZE; x += 1) {
            uint8_t *pixel = renderer->svg_pixels +
                ((size_t)y * KOOKIE_UI_SVG_SIZE + (size_t)x) * 4u;
            for (int sample_y = 0; sample_y < 4; sample_y += 1) {
                for (int sample_x = 0; sample_x < 4; sample_x += 1) {
                    float point_x = ((float)x + ((float)sample_x + 0.5f) / 4.0f);
                    float point_y = ((float)y + ((float)sample_y + 0.5f) / 4.0f);
                    for (size_t shape = 0;
                         shape < renderer->svg_polygon_count; shape += 1u) {
                        const KookieSvgPolygon *polygon =
                            &renderer->svg_polygons[shape];
                        bool inside = false;
                        for (size_t index = 0, previous = polygon->count - 1u;
                             index < polygon->count; previous = index++) {
                            float yi = polygon->points[index].y;
                            float yj = polygon->points[previous].y;
                            float xi = polygon->points[index].x;
                            float xj = polygon->points[previous].x;
                            bool crosses = ((yi > point_y) != (yj > point_y)) &&
                                point_x < (xj - xi) * (point_y - yi) /
                                    (yj - yi) + xi;
                            if (crosses) {
                                inside = !inside;
                            }
                        }
                        if (inside) {
                            pixel[0] = polygon->color[0];
                            pixel[1] = polygon->color[1];
                            pixel[2] = polygon->color[2];
                            pixel[3] = (uint8_t)(pixel[3] +
                                polygon->color[3] / 16u);
                        }
                    }
                }
            }
        }
    }
    renderer->svg_ready = true;
    return true;
}

static float kookie_ui_pixel_x(
    const KookieUiRenderer *renderer, float logical
) {
    return (logical + 100.0f) * (float)renderer->width / KOOKIE_UI_LOGICAL_SPAN;
}

static float kookie_ui_pixel_y(
    const KookieUiRenderer *renderer, float logical
) {
    return (100.0f - logical) * (float)renderer->height / KOOKIE_UI_LOGICAL_SPAN;
}

static void kookie_ui_blend_pixel(
    KookieUiRenderer *renderer, int x, int y, const uint8_t source[4]
) {
    if (x < 0 || y < 0 || (uint32_t)x >= renderer->width ||
        (uint32_t)y >= renderer->height || source[3] == 0) {
        return;
    }
    uint8_t *destination = renderer->pixels +
        ((size_t)y * renderer->width + (size_t)x) * 4u;
    unsigned int source_alpha = source[3];
    unsigned int inverse_alpha = 255u - source_alpha;
    destination[0] = (uint8_t)((source[0] * source_alpha +
        destination[0] * inverse_alpha) / 255u);
    destination[1] = (uint8_t)((source[1] * source_alpha +
        destination[1] * inverse_alpha) / 255u);
    destination[2] = (uint8_t)((source[2] * source_alpha +
        destination[2] * inverse_alpha) / 255u);
    destination[3] = (uint8_t)(source_alpha +
        (destination[3] * inverse_alpha) / 255u);
}

static bool kookie_ui_sample_resource(
    const KookieUiRenderer *renderer,
    int resource,
    float u,
    float v,
    uint8_t color[4]
) {
    if (resource == 17) {
        if (!renderer->svg_ready || renderer->svg_pixels == NULL) {
            return false;
        }
        int x = (int)lrintf(fminf(100.0f, fmaxf(0.0f, u)) * 0.95f);
        int y = (int)lrintf((100.0f - fminf(100.0f, fmaxf(0.0f, v))) * 0.95f);
        const uint8_t *source = renderer->svg_pixels +
            ((size_t)y * KOOKIE_UI_SVG_SIZE + (size_t)x) * 4u;
        memcpy(color, source, 4u);
        return true;
    }
    if (resource >= 600 && resource < 605) {
        int state = resource - 600;
        int x = (int)lrintf(fminf(100.0f, fmaxf(0.0f, u)) * 0.07f);
        int y = (int)lrintf(fminf(100.0f, fmaxf(0.0f, v)) * 0.07f);
        memcpy(color, kookie_heart_tiles[state][y][x], 4u);
        return true;
    }
    if (resource <= 0 || resource >= 101) {
        return false;
    }
    memcpy(color, kookie_ui_palette[(resource - 1) % 16], 4u);
    return true;
}

static float kookie_ui_edge(
    float ax, float ay, float bx, float by, float px, float py
) {
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax);
}

static bool kookie_ui_raster_triangle(
    KookieUiRenderer *renderer,
    const KookieUiVertex *a,
    const KookieUiVertex *b,
    const KookieUiVertex *c
) {
    float ax = kookie_ui_pixel_x(renderer, (float)a->x);
    float ay = kookie_ui_pixel_y(renderer, (float)a->y);
    float bx = kookie_ui_pixel_x(renderer, (float)b->x);
    float by = kookie_ui_pixel_y(renderer, (float)b->y);
    float cx = kookie_ui_pixel_x(renderer, (float)c->x);
    float cy = kookie_ui_pixel_y(renderer, (float)c->y);
    float area = kookie_ui_edge(ax, ay, bx, by, cx, cy);
    if (fabsf(area) < 0.001f) {
        return true;
    }
    float min_x = fminf(ax, fminf(bx, cx));
    float max_x = fmaxf(ax, fmaxf(bx, cx));
    float min_y = fminf(ay, fminf(by, cy));
    float max_y = fmaxf(ay, fmaxf(by, cy));
    int left = (int)floorf(fmaxf(0.0f, min_x));
    int right = (int)ceilf(fminf((float)renderer->width, max_x));
    int top = (int)floorf(fmaxf(0.0f, min_y));
    int bottom = (int)ceilf(fminf((float)renderer->height, max_y));
    for (int y = top; y < bottom; y += 1) {
        for (int x = left; x < right; x += 1) {
            float px = (float)x + 0.5f;
            float py = (float)y + 0.5f;
            float w0 = kookie_ui_edge(bx, by, cx, cy, px, py) / area;
            float w1 = kookie_ui_edge(cx, cy, ax, ay, px, py) / area;
            float w2 = kookie_ui_edge(ax, ay, bx, by, px, py) / area;
            if (w0 < -0.0001f || w1 < -0.0001f || w2 < -0.0001f) {
                continue;
            }
            int depth = (int)lrintf(w0 * (float)a->depth +
                w1 * (float)b->depth + w2 * (float)c->depth);
            size_t pixel_index = (size_t)y * renderer->width + (size_t)x;
            if (depth < 0 || depth > 100 ||
                (uint16_t)depth > renderer->depth[pixel_index]) {
                continue;
            }
            float u = w0 * (float)a->u + w1 * (float)b->u + w2 * (float)c->u;
            float v = w0 * (float)a->v + w1 * (float)b->v + w2 * (float)c->v;
            uint8_t color[4] = {0};
            if (!kookie_ui_sample_resource(renderer, a->resource, u, v, color)) {
                return false;
            }
            if (color[3] > 0) {
                renderer->depth[pixel_index] = (uint16_t)depth;
                kookie_ui_blend_pixel(renderer, x, y, color);
            }
        }
    }
    return true;
}

static bool kookie_ui_decode_utf16(
    const uint32_t *input, size_t length, uint32_t *output, size_t *output_length
) {
    if (input == NULL || output == NULL || output_length == NULL ||
        length > KOOKIE_UI_MAX_CODEPOINTS) {
        return false;
    }
    size_t count = 0;
    for (size_t index = 0; index < length; index += 1u) {
        uint32_t value = input[index];
        if (value >= 0xd800u && value <= 0xdbffu) {
            if (index + 1u >= length || input[index + 1u] < 0xdc00u ||
                input[index + 1u] > 0xdfffu) {
                return false;
            }
            value = 0x10000u + ((value - 0xd800u) << 10u) +
                (input[++index] - 0xdc00u);
        } else if (value >= 0xdc00u && value <= 0xdfffu) {
            return false;
        }
        if (value > 0x10ffffu || count >= KOOKIE_UI_MAX_CODEPOINTS) {
            return false;
        }
        output[count++] = value;
    }
    *output_length = count;
    return true;
}

static void kookie_ui_render_text_bitmap(
    KookieUiRenderer *renderer,
    const FT_Bitmap *bitmap,
    int left,
    int top,
    const uint8_t color[4]
) {
    if (bitmap == NULL || bitmap->buffer == NULL) {
        return;
    }
    for (unsigned int row = 0; row < bitmap->rows; row += 1u) {
        for (unsigned int column = 0; column < bitmap->width; column += 1u) {
            uint8_t alpha = bitmap->buffer[row * (size_t)bitmap->pitch + column];
            if (alpha == 0) {
                continue;
            }
            uint8_t source[4] = {color[0], color[1], color[2],
                (uint8_t)((alpha * color[3]) / 255u)};
            kookie_ui_blend_pixel(renderer, left + (int)column,
                top + (int)row, source);
        }
    }
}

static bool kookie_ui_render_text_run(
    KookieUiRenderer *renderer, const KookieUiTextRun *run
) {
    if (run == NULL || run->font < 0 || run->font >= KOOKIE_UI_FONT_COUNT ||
        run->color < 0 || run->color >= 5 || run->scale <= 0 ||
        run->codepoints == NULL || run->codepoint_count == 0 ||
        run->codepoint_count > KOOKIE_UI_MAX_CODEPOINTS) {
        return false;
    }
    KookieUiFont *font = &renderer->fonts[run->font];
    int pixel_size = (int)lrintf(
        ((float)renderer->height * 7.0f * (float)run->scale) /
            KOOKIE_UI_LOGICAL_SPAN);
    if (pixel_size < 1) {
        pixel_size = 1;
    }
    if (FT_Set_Pixel_Sizes(font->face, 0, (FT_UInt)pixel_size) != 0) {
        return false;
    }
    hb_ft_font_changed(font->hb_font);
    uint32_t *codepoints = (uint32_t *)malloc(
        run->codepoint_count * sizeof(uint32_t));
    if (codepoints == NULL) {
        return false;
    }
    size_t codepoint_count = 0;
    bool decoded = kookie_ui_decode_utf16(
        run->codepoints, run->codepoint_count, codepoints, &codepoint_count);
    if (!decoded || codepoint_count == 0) {
        free(codepoints);
        return false;
    }
    hb_buffer_t *buffer = hb_buffer_create();
    if (buffer == NULL) {
        free(codepoints);
        return false;
    }
    hb_buffer_add_codepoints(buffer, codepoints, (int)codepoint_count, 0, -1);
    hb_buffer_guess_segment_properties(buffer);
    hb_shape(font->hb_font, buffer, NULL, 0);
    unsigned int glyph_count = 0;
    hb_glyph_info_t *glyphs = hb_buffer_get_glyph_infos(buffer, &glyph_count);
    hb_glyph_position_t *positions = hb_buffer_get_glyph_positions(
        buffer, &glyph_count);
    int pen_x = (int)lrintf(kookie_ui_pixel_x(renderer, (float)run->left));
    int bottom_y = (int)lrintf(
        kookie_ui_pixel_y(renderer,
            (float)run->bottom));
    int descender = (int)(font->face->size->metrics.descender / 64);
    int baseline_y = bottom_y + descender;
    uint8_t color[4] = {
        kookie_ui_palette[kookie_ui_font_palette[run->color]][0],
        kookie_ui_palette[kookie_ui_font_palette[run->color]][1],
        kookie_ui_palette[kookie_ui_font_palette[run->color]][2],
        255
    };
    for (unsigned int index = 0; index < glyph_count; index += 1u) {
        FT_UInt glyph_index = glyphs[index].codepoint;
        if (FT_Load_Glyph(font->face, glyph_index, FT_LOAD_DEFAULT) != 0 ||
            FT_Render_Glyph(font->face->glyph, FT_RENDER_MODE_NORMAL) != 0) {
            hb_buffer_destroy(buffer);
            free(codepoints);
            return false;
        }
        const hb_glyph_position_t *position = &positions[index];
        int glyph_x = pen_x + (int)(position->x_offset / 64) +
            font->face->glyph->bitmap_left;
        int glyph_y = baseline_y - (int)(position->y_offset / 64) -
            font->face->glyph->bitmap_top;
        kookie_ui_render_text_bitmap(
            renderer, &font->face->glyph->bitmap, glyph_x, glyph_y, color);
        pen_x += (int)(position->x_advance / 64);
    }
    hb_buffer_destroy(buffer);
    free(codepoints);
    return true;
}

KookieUiRenderer *kookie_ui_renderer_create(void) {
    KookieUiRenderer *renderer = (KookieUiRenderer *)calloc(1, sizeof(*renderer));
    if (renderer == NULL || FT_Init_FreeType(&renderer->freetype) != 0) {
        free(renderer);
        return NULL;
    }
    if (!kookie_ui_load_font(renderer, 0, "jared-lite.ttf") ||
        !kookie_ui_load_font(renderer, 1, "pixand.ttf")) {
        kookie_ui_renderer_destroy(renderer);
        return NULL;
    }
    if (!kookie_ui_load_svg(renderer)) {
        kookie_ui_renderer_destroy(renderer);
        return NULL;
    }
    return renderer;
}

void kookie_ui_renderer_destroy(KookieUiRenderer *renderer) {
    if (renderer == NULL) {
        return;
    }
    for (size_t index = 0; index < KOOKIE_UI_FONT_COUNT; index += 1u) {
        if (renderer->fonts[index].hb_font != NULL) {
            hb_font_destroy(renderer->fonts[index].hb_font);
        }
        if (renderer->fonts[index].face != NULL) {
            FT_Done_Face(renderer->fonts[index].face);
        }
    }
    if (renderer->freetype != NULL) {
        FT_Done_FreeType(renderer->freetype);
    }
    free(renderer->svg_pixels);
    free(renderer->pixels);
    free(renderer->depth);
    free(renderer);
}

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
) {
    if (renderer == NULL || pixels == NULL || pixel_bytes == NULL ||
        (vertex_count > 0 && vertices == NULL) ||
        (text_run_count > 0 && text_runs == NULL) || vertex_count % 3u != 0u) {
        return false;
    }
    size_t pixel_count = 0;
    size_t bytes = 0;
    if (!kookie_ui_checked_size(width, height, &pixel_count, &bytes)) {
        return false;
    }
    if (pixel_count > renderer->pixel_capacity) {
        uint8_t *pixels_resized = (uint8_t *)malloc(bytes);
        uint16_t *depth_resized = (uint16_t *)malloc(
            pixel_count * sizeof(uint16_t));
        if (pixels_resized == NULL || depth_resized == NULL) {
            free(pixels_resized);
            free(depth_resized);
            return false;
        }
        free(renderer->pixels);
        free(renderer->depth);
        renderer->pixels = pixels_resized;
        renderer->depth = depth_resized;
        renderer->pixel_capacity = pixel_count;
    }
    renderer->width = width;
    renderer->height = height;
    memset(renderer->pixels, 0, bytes);
    for (size_t index = 0; index < pixel_count; index += 1u) {
        renderer->depth[index] = UINT16_MAX;
    }
    for (size_t index = 0; index < vertex_count; index += 3u) {
        if (vertices[index].resource != vertices[index + 1u].resource ||
            vertices[index].resource != vertices[index + 2u].resource ||
            !kookie_ui_raster_triangle(
                renderer, &vertices[index], &vertices[index + 1u],
                &vertices[index + 2u])) {
            return false;
        }
    }
    for (size_t index = 0; index < text_run_count; index += 1u) {
        if (!kookie_ui_render_text_run(renderer, &text_runs[index])) {
            return false;
        }
    }
    *pixels = renderer->pixels;
    *pixel_bytes = bytes;
    return true;
}
