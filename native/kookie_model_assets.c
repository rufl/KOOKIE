#include "kookie_model_assets.h"

#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <float.h>
#include <limits.h>

#define KOOKIE_MODEL_GLTF_MAGIC 0x46546c67u
#define KOOKIE_MODEL_GLTF_VERSION 2u
#define KOOKIE_MODEL_JSON_CHUNK 0x4e4f534au
#define KOOKIE_MODEL_BIN_CHUNK 0x004e4942u
#define KOOKIE_MODEL_TRIANGLE_MODE 4
#define KOOKIE_MODEL_TARGET_HEIGHT 7.0f

#define KOOKIE_MODEL_INVALID_INDEX (-1)
#define KOOKIE_MODEL_MAX_FILE_BYTES (16u * 1024u * 1024u)
#define KOOKIE_MODEL_MAX_ACCESSORS 4096
#define KOOKIE_MODEL_MAX_BUFFER_VIEWS 4096
#define KOOKIE_MODEL_MAX_MESHES 1024
#define KOOKIE_MODEL_MAX_NODES 4096
#define KOOKIE_MODEL_MAX_PRIMITIVES 8192
#define KOOKIE_MODEL_MAX_JSON_DEPTH 128

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

typedef struct {
    const char *text;
    size_t length;
} KookieJson;

typedef struct {
    float value[16];
} KookieModelMatrix;

typedef struct {
    int buffer_view;
    int byte_offset;
    int component_type;
    int count;
    int component_count;
} KookieModelAccessor;

typedef struct {
    int byte_offset;
    int byte_length;
    int byte_stride;
} KookieModelBufferView;

typedef struct {
    int position_accessor;
    int index_accessor;
    int texcoord_accessor;
    int mode;
    int material;
} KookieModelPrimitive;

typedef struct {
    int first_primitive;
    int primitive_count;
} KookieModelMesh;

typedef struct {
    int mesh;
    int parent;
    KookieModelMatrix local;
    KookieModelMatrix world;
    bool world_ready;
} KookieModelNode;

typedef struct {
    float position[3][3];
    int uv[3][2];
    int material_slot;
} KookieModelTriangle;

typedef struct {
    bool attempted;
    bool loaded;
    int model;
    int triangle_count;
    size_t texture_png_length;
    uint8_t *texture_png;
    KookieModelTriangle *triangles;
} KookieModelAsset;
static void model_asset_release(KookieModelAsset *asset) {
    if (asset == NULL) {
        return;
    }
    free(asset->texture_png);
    free(asset->triangles);
    asset->texture_png = NULL;
    asset->triangles = NULL;
    asset->texture_png_length = 0;
    asset->triangle_count = 0;
    asset->loaded = false;
}

static KookieModelAsset model_assets[2];

static size_t json_skip_whitespace(const KookieJson *json, size_t position) {
    while (position < json->length) {
        char value = json->text[position];
        if (value != ' ' && value != '\t' && value != '\r' && value != '\n') {
            break;
        }
        position += 1;
    }
    return position;
}

static bool json_string_end(
    const KookieJson *json, size_t start, size_t *end
) {
    if (start >= json->length || json->text[start] != '"' || end == NULL) {
        return false;
    }
    size_t position = start + 1;
    while (position < json->length) {
        char value = json->text[position];
        if (value == '\\') {
            position += 2;
            continue;
        }
        if (value == '"') {
            *end = position + 1;
            return true;
        }
        position += 1;
    }
    return false;
}

static bool json_string_equals(
    const KookieJson *json,
    size_t start,
    size_t end,
    const char *expected
) {
    if (start >= end || json->text[start] != '"' || json->text[end - 1] != '"') {
        return false;
    }
    size_t expected_length = strlen(expected);
    return end - start - 2 == expected_length &&
        memcmp(json->text + start + 1, expected, expected_length) == 0;
}

static bool json_value_end_nested(
    const KookieJson *json, size_t start, size_t *end,
    unsigned int depth
) {
    if (start >= json->length || end == NULL ||
        depth > KOOKIE_MODEL_MAX_JSON_DEPTH) {
        return false;
    }
    size_t position = json_skip_whitespace(json, start);
    if (position >= json->length) {
        return false;
    }
    char opening = json->text[position];
    if (opening == '"') {
        return json_string_end(json, position, end);
    }
    if (opening == '{' || opening == '[') {
        char closing = opening == '{' ? '}' : ']';
        position += 1;
        position = json_skip_whitespace(json, position);
        if (position < json->length && json->text[position] == closing) {
            *end = position + 1;
            return true;
        }
        while (position < json->length) {
            size_t item_end = 0;
            if (opening == '{') {
                if (json->text[position] != '"' ||
                    !json_string_end(json, position, &item_end)) {
                    return false;
                }
                position = json_skip_whitespace(json, item_end);
                if (position >= json->length || json->text[position] != ':') {
                    return false;
                }
                position = json_skip_whitespace(json, position + 1);
            }
            if (!json_value_end_nested(
                    json, position, &item_end, depth + 1)) {
                return false;
            }
            position = json_skip_whitespace(json, item_end);
            if (position >= json->length) {
                return false;
            }
            if (json->text[position] == closing) {
                *end = position + 1;
                return true;
            }
            if (json->text[position] != ',') {
                return false;
            }
            position = json_skip_whitespace(json, position + 1);
        }
        return false;
    }
    position += 1;
    while (position < json->length) {
        char value = json->text[position];
        if (value == ',' || value == ']' || value == '}' ||
            value == ' ' || value == '\t' || value == '\r' || value == '\n') {
            break;
        }
        position += 1;
    }
    *end = position;
    return position > start;
}

static bool json_value_end(
    const KookieJson *json, size_t start, size_t *end
) {
    return json_value_end_nested(json, start, end, 0);
}


static bool json_field_value_fixed(
    const KookieJson *json,
    size_t object_start,
    size_t object_end,
    const char *key,
    size_t *value_start,
    size_t *value_end
) {
    if (object_start >= object_end || json->text[object_start] != '{' ||
        json->text[object_end - 1] != '}' || value_start == NULL ||
        value_end == NULL) {
        return false;
    }
    size_t position = json_skip_whitespace(json, object_start + 1);
    while (position < object_end - 1) {
        if (json->text[position] != '"') {
            return false;
        }
        size_t key_start = position;
        size_t key_end = 0;
        if (!json_string_end(json, key_start, &key_end)) {
            return false;
        }
        position = json_skip_whitespace(json, key_end);
        if (position >= object_end || json->text[position] != ':') {
            return false;
        }
        size_t current_start = json_skip_whitespace(json, position + 1);
        size_t current_end = 0;
        if (!json_value_end(json, current_start, &current_end) ||
            current_end > object_end) {
            return false;
        }
        if (json_string_equals(json, key_start, key_end, key)) {
            *value_start = current_start;
            *value_end = current_end;
            return true;
        }
        position = json_skip_whitespace(json, current_end);
        if (position >= object_end - 1) {
            return false;
        }
        if (json->text[position] != ',') {
            return false;
        }
        position = json_skip_whitespace(json, position + 1);
    }
    return false;
}

static bool json_array_item(
    const KookieJson *json,
    size_t array_start,
    size_t array_end,
    int wanted_index,
    size_t *item_start,
    size_t *item_end
) {
    if (array_start >= array_end || json->text[array_start] != '[' ||
        json->text[array_end - 1] != ']' || wanted_index < 0 ||
        item_start == NULL || item_end == NULL) {
        return false;
    }
    size_t position = json_skip_whitespace(json, array_start + 1);
    int index = 0;
    while (position < array_end - 1) {
        size_t current_end = 0;
        if (!json_value_end(json, position, &current_end) ||
            current_end > array_end) {
            return false;
        }
        if (index == wanted_index) {
            *item_start = position;
            *item_end = current_end;
            return true;
        }
        index += 1;
        position = json_skip_whitespace(json, current_end);
        if (position >= array_end - 1) {
            return false;
        }
        if (json->text[position] != ',') {
            return false;
        }
        position = json_skip_whitespace(json, position + 1);
    }
    return false;
}

static int json_array_count(
    const KookieJson *json, size_t array_start, size_t array_end
) {
    if (array_start >= array_end || json->text[array_start] != '[' ||
        json->text[array_end - 1] != ']') {
        return -1;
    }
    size_t position = json_skip_whitespace(json, array_start + 1);
    if (position < array_end && json->text[position] == ']') {
        return 0;
    }
    int count = 0;
    while (position < array_end - 1) {
        size_t current_end = 0;
        if (!json_value_end(json, position, &current_end) ||
            current_end > array_end) {
            return -1;
        }
        count += 1;
        position = json_skip_whitespace(json, current_end);
        if (position >= array_end) {
            return -1;
        }
        if (json->text[position] == ']') {
            return count;
        }
        if (json->text[position] != ',') {
            return -1;
        }
        position = json_skip_whitespace(json, position + 1);
    }
    return -1;
}

static bool json_int(
    const KookieJson *json,
    size_t start,
    size_t end,
    int *result
) {
    if (start >= end || result == NULL) {
        return false;
    }
    char *parsed_end = NULL;
    long value = strtol(json->text + start, &parsed_end, 10);
    if (parsed_end == NULL || parsed_end != json->text + end ||
        parsed_end <= json->text + start ||
        value < INT32_MIN || value > INT32_MAX) {
        return false;
    }
    *result = (int)value;
    return true;
}

static bool json_float(
    const KookieJson *json,
    size_t start,
    size_t end,
    float *result
) {
    if (start >= end || result == NULL) {
        return false;
    }
    char *parsed_end = NULL;
    float value = strtof(json->text + start, &parsed_end);
    if (parsed_end == NULL || parsed_end != json->text + end ||
        parsed_end <= json->text + start || !isfinite(value)) {
        return false;
    }
    *result = value;
    return true;
}

static bool json_object_int(
    const KookieJson *json,
    size_t object_start,
    size_t object_end,
    const char *key,
    int *result,
    bool *present
) {
    size_t start = 0;
    size_t end = 0;
    if (!json_field_value_fixed(
            json, object_start, object_end, key, &start, &end)) {
        if (present != NULL) {
            *present = false;
        }
        return true;
    }
    if (present != NULL) {
        *present = true;
    }
    return json_int(json, start, end, result);
}
static bool json_accessor_component_count(
    const KookieJson *json,
    size_t object_start,
    size_t object_end,
    int *component_count
) {
    if (component_count == NULL) {
        return false;
    }
    size_t start = 0;
    size_t end = 0;
    if (!json_field_value_fixed(
            json, object_start, object_end, "type", &start, &end)) {
        return false;
    }
    if (json_string_equals(json, start, end, "SCALAR")) {
        *component_count = 1;
        return true;
    }
    if (json_string_equals(json, start, end, "VEC2")) {
        *component_count = 2;
        return true;
    }
    if (json_string_equals(json, start, end, "VEC3")) {
        *component_count = 3;
        return true;
    }
    if (json_string_equals(json, start, end, "VEC4") ||
        json_string_equals(json, start, end, "MAT2")) {
        *component_count = 4;
        return true;
    }
    if (json_string_equals(json, start, end, "MAT3")) {
        *component_count = 9;
        return true;
    }
    if (json_string_equals(json, start, end, "MAT4")) {
        *component_count = 16;
        return true;
    }
    return false;
}


static bool json_object_float_array(
    const KookieJson *json,
    size_t object_start,
    size_t object_end,
    const char *key,
    float *result,
    int expected_count,
    bool *present
) {
    size_t start = 0;
    size_t end = 0;
    if (!json_field_value_fixed(
            json, object_start, object_end, key, &start, &end)) {
        if (present != NULL) {
            *present = false;
        }
        return true;
    }
    if (present != NULL) {
        *present = true;
    }
    int count = json_array_count(json, start, end);
    if (count != expected_count) {
        return false;
    }
    for (int index = 0; index < expected_count; index += 1) {
        size_t item_start = 0;
        size_t item_end = 0;
        if (!json_array_item(
                json, start, end, index, &item_start, &item_end) ||
            !json_float(json, item_start, item_end, &result[index])) {
            return false;
        }
    }
    return true;
}


static void model_matrix_identity(KookieModelMatrix *matrix) {
    memset(matrix, 0, sizeof(*matrix));
    matrix->value[0] = 1.0f;
    matrix->value[5] = 1.0f;
    matrix->value[10] = 1.0f;
    matrix->value[15] = 1.0f;
}

static KookieModelMatrix model_matrix_multiply(
    KookieModelMatrix left, KookieModelMatrix right
) {
    KookieModelMatrix result;
    for (int row = 0; row < 4; row += 1) {
        for (int column = 0; column < 4; column += 1) {
            float value = 0.0f;
            for (int inner = 0; inner < 4; inner += 1) {
                value += left.value[row * 4 + inner] *
                    right.value[inner * 4 + column];
            }
            result.value[row * 4 + column] = value;
        }
    }
    return result;
}

static void model_matrix_apply(
    KookieModelMatrix matrix, const float input[3], float output[3]
) {
    output[0] = matrix.value[0] * input[0] +
        matrix.value[1] * input[1] + matrix.value[2] * input[2] +
        matrix.value[3];
    output[1] = matrix.value[4] * input[0] +
        matrix.value[5] * input[1] + matrix.value[6] * input[2] +
        matrix.value[7];
    output[2] = matrix.value[8] * input[0] +
        matrix.value[9] * input[1] + matrix.value[10] * input[2] +
        matrix.value[11];
}

static void model_matrix_from_trs(
    const float translation[3],
    const float rotation[4],
    const float scale[3],
    KookieModelMatrix *matrix
) {
    float x = rotation[0];
    float y = rotation[1];
    float z = rotation[2];
    float w = rotation[3];
    model_matrix_identity(matrix);
    matrix->value[0] = (1.0f - 2.0f * y * y - 2.0f * z * z) * scale[0];
    matrix->value[1] = (2.0f * x * y - 2.0f * z * w) * scale[1];
    matrix->value[2] = (2.0f * x * z + 2.0f * y * w) * scale[2];
    matrix->value[4] = (2.0f * x * y + 2.0f * z * w) * scale[0];
    matrix->value[5] = (1.0f - 2.0f * x * x - 2.0f * z * z) * scale[1];
    matrix->value[6] = (2.0f * y * z - 2.0f * x * w) * scale[2];
    matrix->value[8] = (2.0f * x * z - 2.0f * y * w) * scale[0];
    matrix->value[9] = (2.0f * y * z + 2.0f * x * w) * scale[1];
    matrix->value[10] = (1.0f - 2.0f * x * x - 2.0f * y * y) * scale[2];
    matrix->value[3] = translation[0];
    matrix->value[7] = translation[1];
    matrix->value[11] = translation[2];
}

typedef struct {
    KookieModelAccessor *accessors;
    int accessor_count;
    KookieModelBufferView *views;
    int view_count;
    KookieModelPrimitive *primitives;
    int primitive_count;
    KookieModelMesh *meshes;
    int mesh_count;
    KookieModelNode *nodes;
    int node_count;
} KookieModelScene;

static void model_scene_release(KookieModelScene *scene) {
    if (scene == NULL) {
        return;
    }
    free(scene->accessors);
    free(scene->views);
    free(scene->primitives);
    free(scene->meshes);
    free(scene->nodes);
    memset(scene, 0, sizeof(*scene));
}

static bool json_object_bounds(
    const KookieJson *json,
    size_t array_start,
    size_t array_end,
    int index,
    size_t *object_start,
    size_t *object_end
) {
    if (!json_array_item(
            json, array_start, array_end, index, object_start, object_end)) {
        return false;
    }
    return *object_start < *object_end &&
        json->text[*object_start] == '{' &&
        json->text[*object_end - 1] == '}';
}

static bool model_parse_accessors(
    const KookieJson *json,
    size_t root_start,
    size_t root_end,
    KookieModelScene *scene
) {
    size_t array_start = 0;
    size_t array_end = 0;
    if (!json_field_value_fixed(
            json, root_start, root_end, "accessors", &array_start, &array_end)) {
        return false;
    }
    int count = json_array_count(json, array_start, array_end);
    if (count <= 0 || count > KOOKIE_MODEL_MAX_ACCESSORS) {
        return false;
    }
    scene->accessors = calloc((size_t)count, sizeof(*scene->accessors));
    if (scene->accessors == NULL) {
        return false;
    }
    scene->accessor_count = count;
    for (int index = 0; index < count; index += 1) {
        size_t object_start = 0;
        size_t object_end = 0;
        if (!json_object_bounds(
                json, array_start, array_end, index,
                &object_start, &object_end)) {
            return false;
        }
        KookieModelAccessor *accessor = &scene->accessors[index];
        accessor->buffer_view = KOOKIE_MODEL_INVALID_INDEX;
        accessor->byte_offset = 0;
        accessor->component_type = 0;
        accessor->count = 0;
        accessor->component_count = 0;
        bool present = false;
        if (!json_object_int(
                json, object_start, object_end, "bufferView",
                &accessor->buffer_view, &present) ||
            (present && accessor->buffer_view < 0) ||
            !json_object_int(
                json, object_start, object_end, "byteOffset",
                &accessor->byte_offset, &present) ||
            !json_object_int(
                json, object_start, object_end, "componentType",
                &accessor->component_type, &present) || !present ||
            !json_object_int(
                json, object_start, object_end, "count",
                &accessor->count, &present) || !present ||
            accessor->count <= 0) {
            return false;
        }
        if (!json_accessor_component_count(
                json, object_start, object_end,
                &accessor->component_count)) {
            return false;
        }
        if (accessor->byte_offset < 0 || accessor->buffer_view < 0) {
            return false;
        }
    }
    return true;
}

static bool model_parse_views(
    const KookieJson *json,
    size_t root_start,
    size_t root_end,
    KookieModelScene *scene
) {
    size_t array_start = 0;
    size_t array_end = 0;
    if (!json_field_value_fixed(
            json, root_start, root_end, "bufferViews", &array_start, &array_end)) {
        return false;
    }
    int count = json_array_count(json, array_start, array_end);
    if (count <= 0 || count > KOOKIE_MODEL_MAX_BUFFER_VIEWS) {
        return false;
    }
    scene->views = calloc((size_t)count, sizeof(*scene->views));
    if (scene->views == NULL) {
        return false;
    }
    scene->view_count = count;
    for (int index = 0; index < count; index += 1) {
        size_t object_start = 0;
        size_t object_end = 0;
        if (!json_object_bounds(
                json, array_start, array_end, index,
                &object_start, &object_end)) {
            return false;
        }
        KookieModelBufferView *view = &scene->views[index];
        view->byte_offset = 0;
        view->byte_stride = 0;
        int buffer = -1;
        bool present = false;
        if (!json_object_int(
                json, object_start, object_end, "buffer",
                &buffer, &present) || !present || buffer != 0 ||
            !json_object_int(
                json, object_start, object_end, "byteOffset",
                &view->byte_offset, &present) ||
            (present && view->byte_offset < 0) ||
            !json_object_int(
                json, object_start, object_end, "byteLength",
                &view->byte_length, &present) || !present ||
            !json_object_int(
                json, object_start, object_end, "byteStride",
                &view->byte_stride, &present) ||
            (present && view->byte_stride <= 0) ||
            view->byte_length <= 0) {
            return false;
        }
    }
    return true;
}
static bool model_validate_bin_buffer(
    const KookieJson *json,
    size_t root_start,
    size_t root_end,
    size_t bin_length
) {
    size_t array_start = 0;
    size_t array_end = 0;
    if (!json_field_value_fixed(
            json, root_start, root_end, "buffers",
            &array_start, &array_end) ||
        json_array_count(json, array_start, array_end) != 1) {
        return false;
    }
    size_t object_start = 0;
    size_t object_end = 0;
    int byte_length = 0;
    bool present = false;
    return json_object_bounds(
            json, array_start, array_end, 0,
            &object_start, &object_end) &&
        json_object_int(
            json, object_start, object_end, "byteLength",
            &byte_length, &present) &&
        present && byte_length >= 0 &&
        (size_t)byte_length == bin_length;
}

static bool model_copy_embedded_texture(
    KookieModelAsset *asset,
    const KookieJson *json,
    size_t root_start,
    size_t root_end,
    const KookieModelScene *scene,
    const uint8_t *bin,
    size_t bin_length
) {
    if (asset == NULL || json == NULL || scene == NULL ||
        bin == NULL) {
        return false;
    }
    free(asset->texture_png);
    asset->texture_png = NULL;
    asset->texture_png_length = 0;
    size_t array_start = 0;
    size_t array_end = 0;
    if (!json_field_value_fixed(
            json, root_start, root_end, "images",
            &array_start, &array_end)) {
        return true;
    }
    int count = json_array_count(json, array_start, array_end);
    if (count < 0) {
        return false;
    }
    for (int index = 0; index < count; index += 1) {
        size_t image_start = 0;
        size_t image_end = 0;
        if (!json_object_bounds(
                json, array_start, array_end, index,
                &image_start, &image_end)) {
            return false;
        }
        size_t mime_start = 0;
        size_t mime_end = 0;
        if (!json_field_value_fixed(
                json, image_start, image_end, "mimeType",
                &mime_start, &mime_end) ||
            !json_string_equals(json, mime_start, mime_end, "image/png")) {
            continue;
        }
        int buffer_view = KOOKIE_MODEL_INVALID_INDEX;
        bool present = false;
        if (!json_object_int(
                json, image_start, image_end, "bufferView",
                &buffer_view, &present)) {
            return false;
        }
        if (!present || buffer_view < 0 ||
            buffer_view >= scene->view_count) {
            continue;
        }
        const KookieModelBufferView *view = &scene->views[buffer_view];
        if (view->byte_offset < 0 || view->byte_length <= 0 ||
            (size_t)view->byte_offset > bin_length ||
            (size_t)view->byte_length > bin_length -
                (size_t)view->byte_offset) {
            return false;
        }
        uint8_t *texture = malloc((size_t)view->byte_length);
        if (texture == NULL) {
            return false;
        }
        memcpy(
            texture,
            bin + (size_t)view->byte_offset,
            (size_t)view->byte_length);
        asset->texture_png = texture;
        asset->texture_png_length = (size_t)view->byte_length;
        return true;
    }
    return true;
}

static bool model_parse_meshes(
    const KookieJson *json,
    size_t root_start,
    size_t root_end,
    KookieModelScene *scene
) {
    size_t array_start = 0;
    size_t array_end = 0;
    if (!json_field_value_fixed(
            json, root_start, root_end, "meshes", &array_start, &array_end)) {
        return false;
    }
    int count = json_array_count(json, array_start, array_end);
    if (count <= 0 || count > KOOKIE_MODEL_MAX_MESHES) {
        return false;
    }
    scene->meshes = calloc((size_t)count, sizeof(*scene->meshes));
    if (scene->meshes == NULL) {
        return false;
    }
    scene->mesh_count = count;
    scene->primitive_count = 0;
    for (int mesh_index = 0; mesh_index < count; mesh_index += 1) {
        size_t mesh_start = 0;
        size_t mesh_end = 0;
        if (!json_object_bounds(
                json, array_start, array_end, mesh_index,
                &mesh_start, &mesh_end)) {
            return false;
        }
        size_t primitive_array_start = 0;
        size_t primitive_array_end = 0;
        if (!json_field_value_fixed(
                json, mesh_start, mesh_end, "primitives",
                &primitive_array_start, &primitive_array_end)) {
            return false;
        }
        int primitive_count = json_array_count(
            json, primitive_array_start, primitive_array_end);
        if (primitive_count <= 0 ||
            primitive_count > INT_MAX - scene->primitive_count ||
            scene->primitive_count >
                KOOKIE_MODEL_MAX_PRIMITIVES - primitive_count) {
            return false;
        }
        int next_primitive_count =
            scene->primitive_count + primitive_count;
        KookieModelPrimitive *primitives = realloc(
            scene->primitives,
            (size_t)next_primitive_count * sizeof(*scene->primitives));
        if (primitives == NULL) {
            return false;
        }
        scene->primitives = primitives;
        KookieModelMesh *mesh = &scene->meshes[mesh_index];
        mesh->first_primitive = scene->primitive_count;
        mesh->primitive_count = primitive_count;
        for (int primitive_index = 0;
             primitive_index < primitive_count;
             primitive_index += 1) {
            size_t primitive_start = 0;
            size_t primitive_end = 0;
            if (!json_object_bounds(
                    json, primitive_array_start, primitive_array_end,
                    primitive_index, &primitive_start, &primitive_end)) {
                return false;
            }
            KookieModelPrimitive *primitive =
                &scene->primitives[scene->primitive_count];
            primitive->position_accessor = KOOKIE_MODEL_INVALID_INDEX;
            primitive->index_accessor = KOOKIE_MODEL_INVALID_INDEX;
            primitive->texcoord_accessor = KOOKIE_MODEL_INVALID_INDEX;
            primitive->mode = KOOKIE_MODEL_TRIANGLE_MODE;
            primitive->material = 0;
            size_t attributes_start = 0;
            size_t attributes_end = 0;
            if (!json_field_value_fixed(
                    json, primitive_start, primitive_end, "attributes",
                    &attributes_start, &attributes_end) ||
                !json_object_int(
                    json, attributes_start, attributes_end, "POSITION",
                    &primitive->position_accessor, NULL) ||
                primitive->position_accessor < 0) {
                return false;
            }
            (void)json_object_int(
                json, attributes_start, attributes_end, "TEXCOORD_0",
                &primitive->texcoord_accessor, NULL);
            if (!json_object_int(
                    json, primitive_start, primitive_end, "indices",
                    &primitive->index_accessor, NULL) ||
                primitive->index_accessor < 0 ||
                !json_object_int(
                    json, primitive_start, primitive_end, "mode",
                    &primitive->mode, NULL) ||
                !json_object_int(
                    json, primitive_start, primitive_end, "material",
                    &primitive->material, NULL) ||
                primitive->mode != KOOKIE_MODEL_TRIANGLE_MODE) {
                return false;
            }
            scene->primitive_count += 1;
        }
    }
    return true;
}

static bool model_parse_nodes(
    const KookieJson *json,
    size_t root_start,
    size_t root_end,
    KookieModelScene *scene
) {
    size_t array_start = 0;
    size_t array_end = 0;
    if (!json_field_value_fixed(
            json, root_start, root_end, "nodes", &array_start, &array_end)) {
        return false;
    }
    int count = json_array_count(json, array_start, array_end);
    if (count <= 0 || count > KOOKIE_MODEL_MAX_NODES) {
        return false;
    }
    scene->nodes = calloc((size_t)count, sizeof(*scene->nodes));
    if (scene->nodes == NULL) {
        return false;
    }
    scene->node_count = count;
    for (int node_index = 0; node_index < count; node_index += 1) {
        size_t node_start = 0;
        size_t node_end = 0;
        if (!json_object_bounds(
                json, array_start, array_end, node_index,
                &node_start, &node_end)) {
            return false;
        }
        KookieModelNode *node = &scene->nodes[node_index];
        node->mesh = KOOKIE_MODEL_INVALID_INDEX;
        node->parent = KOOKIE_MODEL_INVALID_INDEX;
        node->world_ready = false;
        bool present = false;
        if (!json_object_int(
                json, node_start, node_end, "mesh", &node->mesh, &present) ||
            (present && node->mesh < 0)) {
            return false;
        }
        float translation[3] = {0.0f, 0.0f, 0.0f};
        float rotation[4] = {0.0f, 0.0f, 0.0f, 1.0f};
        float scale[3] = {1.0f, 1.0f, 1.0f};
        bool has_matrix = false;
        if (!json_object_float_array(
                json, node_start, node_end, "translation",
                translation, 3, NULL) ||
            !json_object_float_array(
                json, node_start, node_end, "rotation",
                rotation, 4, NULL) ||
            !json_object_float_array(
                json, node_start, node_end, "scale", scale, 3, NULL) ||
            !json_object_float_array(
                json, node_start, node_end, "matrix", node->local.value,
                16, &has_matrix)) {
            return false;
        }
        if (!has_matrix) {
            model_matrix_from_trs(translation, rotation, scale, &node->local);
        } else {
            float column_major[16];
            memcpy(column_major, node->local.value, sizeof(column_major));
            for (int row = 0; row < 4; row += 1) {
                for (int column = 0; column < 4; column += 1) {
                    node->local.value[row * 4 + column] =
                        column_major[column * 4 + row];
                }
            }
        }
    }
    for (int node_index = 0; node_index < count; node_index += 1) {
        size_t node_start = 0;
        size_t node_end = 0;
        if (!json_object_bounds(
                json, array_start, array_end, node_index,
                &node_start, &node_end)) {
            return false;
        }
        size_t children_start = 0;
        size_t children_end = 0;
        if (!json_field_value_fixed(
                json, node_start, node_end, "children",
                &children_start, &children_end)) {
            continue;
        }
        int children_count = json_array_count(json, children_start, children_end);
        if (children_count < 0 || children_count > count) {
            return false;
        }
        for (int child_index = 0; child_index < children_count; child_index += 1) {
            size_t item_start = 0;
            size_t item_end = 0;
            int child = 0;
            if (!json_array_item(
                    json, children_start, children_end, child_index,
                    &item_start, &item_end) ||
                !json_int(json, item_start, item_end, &child) ||
                child < 0 || child >= count ||
                scene->nodes[child].parent != KOOKIE_MODEL_INVALID_INDEX) {
                return false;
            }
            scene->nodes[child].parent = node_index;
        }
    }
    return true;
}

static bool model_node_world(
    KookieModelScene *scene, int node_index, int depth,
    KookieModelMatrix *result
) {
    if (node_index < 0 || node_index >= scene->node_count ||
        depth > scene->node_count || result == NULL) {
        return false;
    }
    KookieModelNode *node = &scene->nodes[node_index];
    if (!node->world_ready) {
        if (node->parent == KOOKIE_MODEL_INVALID_INDEX) {
            node->world = node->local;
        } else {
            KookieModelMatrix parent_world;
            if (!model_node_world(scene, node->parent, depth + 1, &parent_world)) {
                return false;
            }
            node->world = model_matrix_multiply(parent_world, node->local);
        }
        node->world_ready = true;
    }
    *result = node->world;
    return true;
}

static int model_component_bytes(int component_type) {
    if (component_type == 5121) {
        return 1;
    }
    if (component_type == 5123) {
        return 2;
    }
    if (component_type == 5125 || component_type == 5126) {
        return 4;
    }
    return 0;
}

static bool model_accessor_span(
    const KookieModelScene *scene,
    const uint8_t *bin,
    size_t bin_length,
    int accessor_index,
    int expected_component_type,
    int expected_components,
    size_t *base,
    size_t *stride
) {
    if (scene == NULL || bin == NULL || base == NULL || stride == NULL ||
        accessor_index < 0 || accessor_index >= scene->accessor_count) {
        return false;
    }
    const KookieModelAccessor *accessor = &scene->accessors[accessor_index];
    if (accessor->buffer_view < 0 || accessor->buffer_view >= scene->view_count ||
        accessor->component_type != expected_component_type ||
        accessor->component_count != expected_components ||
        accessor->count <= 0 || accessor->byte_offset < 0) {
        return false;
    }
    const KookieModelBufferView *view = &scene->views[accessor->buffer_view];
    int component_bytes = model_component_bytes(accessor->component_type);
    if (component_bytes <= 0) {
        return false;
    }
    size_t element_bytes = (size_t)component_bytes *
        (size_t)expected_components;
    size_t actual_stride = view->byte_stride > 0
        ? (size_t)view->byte_stride : element_bytes;
    if (actual_stride < element_bytes || view->byte_offset < 0 ||
        view->byte_length <= 0 || (size_t)view->byte_offset > bin_length ||
        (size_t)accessor->byte_offset > (size_t)view->byte_length ||
        (size_t)accessor->byte_offset + element_bytes >
            (size_t)view->byte_length ||
        (size_t)(accessor->count - 1) >
            ((size_t)view->byte_length - (size_t)accessor->byte_offset -
                element_bytes) / actual_stride ||
        (size_t)view->byte_offset + (size_t)accessor->byte_offset +
                (size_t)(accessor->count - 1) * actual_stride + element_bytes >
            bin_length) {
        return false;
    }
    *base = (size_t)view->byte_offset + (size_t)accessor->byte_offset;
    *stride = actual_stride;
    return true;
}

static bool model_read_position(
    const KookieModelScene *scene,
    const uint8_t *bin,
    size_t bin_length,
    int accessor_index,
    int index,
    float result[3]
) {
    size_t base = 0;
    size_t stride = 0;
    if (index < 0 || !model_accessor_span(
            scene, bin, bin_length, accessor_index, 5126, 3, &base, &stride) ||
        index >= scene->accessors[accessor_index].count) {
        return false;
    }
    size_t offset = base + (size_t)index * stride;
    for (int component = 0; component < 3; component += 1) {
        uint32_t bits = 0;
        memcpy(&bits, bin + offset + (size_t)component * sizeof(float),
            sizeof(bits));
        memcpy(&result[component], &bits, sizeof(float));
        if (!isfinite(result[component])) {
            return false;
        }
    }
    return true;
}

static bool model_read_uv(
    const KookieModelScene *scene,
    const uint8_t *bin,
    size_t bin_length,
    int accessor_index,
    int index,
    int result[2]
) {
    result[0] = 0;
    result[1] = 0;
    if (accessor_index < 0) {
        return true;
    }
    size_t base = 0;
    size_t stride = 0;
    if (index < 0 || !model_accessor_span(
            scene, bin, bin_length, accessor_index, 5126, 2, &base, &stride) ||
        index >= scene->accessors[accessor_index].count) {
        return false;
    }
    size_t offset = base + (size_t)index * stride;
    for (int component = 0; component < 2; component += 1) {
        float value = 0.0f;
        uint32_t bits = 0;
        memcpy(&bits, bin + offset + (size_t)component * sizeof(float),
            sizeof(bits));
        memcpy(&value, &bits, sizeof(float));
        if (!isfinite(value)) {
            return false;
        }
        int encoded = 0;
        if (value <= 0.0f) {
            encoded = 0;
        } else if (value >= 1.0f) {
            encoded = 100;
        } else {
            encoded = (int)lrintf(value * 100.0f);
        }
        result[component] = encoded;
    }
    return true;
}

static bool model_read_index(
    const KookieModelScene *scene,
    const uint8_t *bin,
    size_t bin_length,
    int accessor_index,
    int index,
    int *result
) {
    if (result == NULL || index < 0 || accessor_index < 0 ||
        accessor_index >= scene->accessor_count ||
        index >= scene->accessors[accessor_index].count) {
        return false;
    }
    const KookieModelAccessor *accessor = &scene->accessors[accessor_index];
    size_t base = 0;
    size_t stride = 0;
    if (!model_accessor_span(
            scene, bin, bin_length, accessor_index,
            accessor->component_type, 1, &base, &stride)) {
        return false;
    }
    size_t offset = base + (size_t)index * stride;
    if (accessor->component_type == 5121) {
        *result = bin[offset];
        return true;
    }
    if (accessor->component_type == 5123) {
        uint16_t value = 0;
        memcpy(&value, bin + offset, sizeof(value));
        *result = (int)value;
        return true;
    }
    if (accessor->component_type == 5125) {
        uint32_t value = 0;
        memcpy(&value, bin + offset, sizeof(value));
        if (value > INT32_MAX) {
            return false;
        }
        *result = (int)value;
        return true;
    }
    return false;
}


static int model_material_slot(int model, int mesh_index) {
    if (model == KOOKIE_MODEL_CAT) {
        return 3;
    }
    if (mesh_index == 1) {
        return 1;
    }
    if (mesh_index == 4) {
        return 2;
    }
    return 0;
}

static bool model_build_asset(
    KookieModelAsset *asset,
    int model,
    const uint8_t *bin,
    size_t bin_length,
    const KookieJson *json,
    size_t root_start,
    size_t root_end
) {
    KookieModelScene scene;
    memset(&scene, 0, sizeof(scene));
    bool success = false;
    if (!model_parse_accessors(json, root_start, root_end, &scene) ||
        !model_parse_views(json, root_start, root_end, &scene) ||
        !model_parse_meshes(json, root_start, root_end, &scene) ||
        !model_parse_nodes(json, root_start, root_end, &scene)) {
        goto cleanup;
    }
    free(asset->triangles);
    asset->triangles = NULL;
    asset->triangle_count = 0;
    if (!model_copy_embedded_texture(
            asset, json, root_start, root_end,
            &scene, bin, bin_length)) {
        goto cleanup;
    }
    size_t total_triangles = 0;
    float minimum[3] = {FLT_MAX, FLT_MAX, FLT_MAX};
    float maximum[3] = {-FLT_MAX, -FLT_MAX, -FLT_MAX};
    for (int node_index = 0; node_index < scene.node_count; node_index += 1) {
        KookieModelNode *node = &scene.nodes[node_index];
        if (node->mesh < 0 || node->mesh >= scene.mesh_count) {
            continue;
        }
        KookieModelMatrix world;
        if (!model_node_world(&scene, node_index, 0, &world)) {
            goto cleanup;
        }
        KookieModelMesh *mesh = &scene.meshes[node->mesh];
        for (int primitive_offset = 0;
             primitive_offset < mesh->primitive_count;
             primitive_offset += 1) {
            KookieModelPrimitive *primitive = &scene.primitives[
                mesh->first_primitive + primitive_offset];
            if (primitive->index_accessor < 0 ||
                primitive->index_accessor >= scene.accessor_count ||
                primitive->position_accessor < 0 ||
                primitive->position_accessor >= scene.accessor_count) {
                goto cleanup;
            }
            const KookieModelAccessor *indices =
                &scene.accessors[primitive->index_accessor];
            if (indices->count <= 0 || indices->count % 3 != 0) {
                goto cleanup;
            }
            size_t primitive_triangles = (size_t)indices->count / 3u;
            if (total_triangles > SIZE_MAX - primitive_triangles) {
                goto cleanup;
            }
            total_triangles += primitive_triangles;
            const KookieModelAccessor *positions =
                &scene.accessors[primitive->position_accessor];
            for (int vertex = 0; vertex < positions->count; vertex += 1) {
                float source[3];
                float transformed[3];
                if (!model_read_position(
                        &scene, bin, bin_length,
                        primitive->position_accessor, vertex, source)) {
                    goto cleanup;
                }
                model_matrix_apply(world, source, transformed);
                for (int component = 0; component < 3; component += 1) {
                    if (!isfinite(transformed[component])) {
                        goto cleanup;
                    }
                }
                for (int component = 0; component < 3; component += 1) {
                    if (transformed[component] < minimum[component]) {
                        minimum[component] = transformed[component];
                    }
                    if (transformed[component] > maximum[component]) {
                        maximum[component] = transformed[component];
                    }
                }
            }
        }
    }
    if (total_triangles == 0 || total_triangles > (size_t)INT_MAX ||
        total_triangles > SIZE_MAX / sizeof(*asset->triangles) ||
        maximum[1] <= minimum[1]) {
        goto cleanup;
    }
    float center_x = (minimum[0] + maximum[0]) * 0.5f;
    float center_z = (minimum[2] + maximum[2]) * 0.5f;
    float height = maximum[1] - minimum[1];
    if (!isfinite(center_x) || !isfinite(center_z) ||
        !isfinite(height) || height <= 0.0f) {
        goto cleanup;
    }
    float scale = KOOKIE_MODEL_TARGET_HEIGHT / height;
    if (!isfinite(scale)) {
        goto cleanup;
    }
    asset->triangles = malloc(
        total_triangles * sizeof(*asset->triangles));
    if (asset->triangles == NULL) {
        goto cleanup;
    }
    for (int node_index = 0; node_index < scene.node_count; node_index += 1) {
        KookieModelNode *node = &scene.nodes[node_index];
        if (node->mesh < 0 || node->mesh >= scene.mesh_count) {
            continue;
        }
        KookieModelMatrix world;
        if (!model_node_world(&scene, node_index, 0, &world)) {
            goto cleanup;
        }
        KookieModelMesh *mesh = &scene.meshes[node->mesh];
        for (int primitive_offset = 0;
             primitive_offset < mesh->primitive_count;
             primitive_offset += 1) {
            KookieModelPrimitive *primitive = &scene.primitives[
                mesh->first_primitive + primitive_offset];
            const KookieModelAccessor *indices =
                &scene.accessors[primitive->index_accessor];
            int primitive_triangles = indices->count / 3;
            for (int triangle = 0;
                 triangle < primitive_triangles;
                 triangle += 1) {
                if ((size_t)asset->triangle_count >= total_triangles) {
                    goto cleanup;
                }
                KookieModelTriangle *output =
                    &asset->triangles[asset->triangle_count];
                for (int corner = 0; corner < 3; corner += 1) {
                    int source_index = 0;
                    if (!model_read_index(
                            &scene, bin, bin_length,
                            primitive->index_accessor,
                            triangle * 3 + corner, &source_index)) {
                        goto cleanup;
                    }
                    float source[3];
                    float transformed[3];
                    if (!model_read_position(
                            &scene, bin, bin_length,
                            primitive->position_accessor,
                            source_index, source)) {
                        goto cleanup;
                    }
                    model_matrix_apply(world, source, transformed);
                    for (int component = 0; component < 3; component += 1) {
                        if (!isfinite(transformed[component])) {
                            goto cleanup;
                        }
                    }
                    output->position[corner][0] =
                        (transformed[0] - center_x) * scale;
                    output->position[corner][1] =
                        (transformed[1] - minimum[1]) * scale;
                    output->position[corner][2] =
                        (transformed[2] - center_z) * scale;
                    if (!isfinite(output->position[corner][0]) ||
                        !isfinite(output->position[corner][1]) ||
                        !isfinite(output->position[corner][2])) {
                        goto cleanup;
                    }
                    if (!model_read_uv(
                            &scene, bin, bin_length,
                            primitive->texcoord_accessor,
                            source_index, output->uv[corner])) {
                        goto cleanup;
                    }
                }
                output->material_slot = model_material_slot(model, node->mesh);
                asset->triangle_count += 1;
            }
        }
    }
    success = (size_t)asset->triangle_count == total_triangles;
cleanup:
    model_scene_release(&scene);
    if (!success) {
        model_asset_release(asset);
    }
    return success;
}

static bool model_read_file(
    const char *path, uint8_t **data, size_t *length
) {
    if (path == NULL || data == NULL || length == NULL) {
        return false;
    }
    FILE *file = fopen(path, "rb");
    if (file == NULL || fseek(file, 0, SEEK_END) != 0) {
        if (file != NULL) {
            fclose(file);
        }
        return false;
    }
    long file_length = ftell(file);
    if (file_length < 20 ||
        (uintmax_t)file_length > KOOKIE_MODEL_MAX_FILE_BYTES ||
        fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return false;
    }
    uint8_t *buffer = (uint8_t *)malloc((size_t)file_length);
    if (buffer == NULL || fread(buffer, 1, (size_t)file_length, file) !=
            (size_t)file_length) {
        free(buffer);
        fclose(file);
        return false;
    }
    fclose(file);
    *data = buffer;
    *length = (size_t)file_length;
    return true;
}

static uint32_t model_u32(const uint8_t *data) {
    return (uint32_t)data[0] | (uint32_t)data[1] << 8 |
        (uint32_t)data[2] << 16 | (uint32_t)data[3] << 24;
}

static bool model_load_file(KookieModelAsset *asset, int model, const char *path) {
    uint8_t *data = NULL;
    size_t data_length = 0;
    if (!model_read_file(path, &data, &data_length)) {
        return false;
    }
    bool success = false;
    char *json_data = NULL;
    size_t json_length = 0;
    const uint8_t *bin = NULL;
    size_t bin_length = 0;
    if (model_u32(data) != KOOKIE_MODEL_GLTF_MAGIC ||
        model_u32(data + 4) != KOOKIE_MODEL_GLTF_VERSION ||
        model_u32(data + 8) != data_length) {
        goto cleanup;
    }
    size_t offset = 12;
    bool json_found = false;
    bool bin_found = false;
    while (offset + 8 <= data_length) {
        uint32_t chunk_length = model_u32(data + offset);
        uint32_t chunk_type = model_u32(data + offset + 4);
        offset += 8;
        if ((size_t)chunk_length > data_length - offset ||
            (chunk_length & 3u) != 0) {
            goto cleanup;
        }
        if (chunk_type == KOOKIE_MODEL_JSON_CHUNK) {
            if (json_found || chunk_length == 0) {
                goto cleanup;
            }
            json_data = (char *)malloc((size_t)chunk_length + 1u);
            if (json_data == NULL) {
                goto cleanup;
            }
            memcpy(json_data, data + offset, chunk_length);
            json_data[chunk_length] = '\0';
            json_length = chunk_length;
            json_found = true;
        } else if (chunk_type == KOOKIE_MODEL_BIN_CHUNK) {
            if (bin_found) {
                goto cleanup;
            }
            bin = data + offset;
            bin_length = chunk_length;
            bin_found = true;
        } else {
            goto cleanup;
        }
        offset += chunk_length;
    }
    if (offset != data_length || !json_found || !bin_found) {
        goto cleanup;
    }
    KookieJson json = {json_data, json_length};
    size_t root_end = 0;
    if (!json_value_end(&json, 0, &root_end) ||
        json_skip_whitespace(&json, root_end) != json_length ||
        json.text[0] != '{') {
        goto cleanup;
    }
    if (!model_validate_bin_buffer(&json, 0, root_end, bin_length)) {
        goto cleanup;
    }
    asset->model = model;
    success = model_build_asset(asset, model, bin, bin_length, &json, 0, root_end);
cleanup:
    free(json_data);
    free(data);
    return success;
}

static const char *model_relative_path(int model) {
    if (model == KOOKIE_MODEL_GOOSE) {
        return "models/goose/goose.glb";
    }
    if (model == KOOKIE_MODEL_CAT) {
        return "models/cat/cat.glb";
    }
    return NULL;
}

static bool model_try_load(KookieModelAsset *asset, int model) {
    if (asset == NULL || model_relative_path(model) == NULL) {
        return false;
    }
    if (asset->attempted) {
        return asset->loaded;
    }
    asset->attempted = true;
    const char *relative = model_relative_path(model);
    const char *environment_root = getenv("KOOKIE_PROTOTYPE_CONTENT_ROOT");
    const char *roots[3] = {environment_root, "content/prototype", "assets/prototype"};
    char path[1024];
    for (int index = 0; index < 3; index += 1) {
        if (roots[index] == NULL || roots[index][0] == '\0' ||
            (index > 0 && roots[index - 1] != NULL &&
                strcmp(roots[index], roots[index - 1]) == 0)) {
            continue;
        }
        int written = snprintf(path, sizeof(path), "%s/%s", roots[index], relative);
        if (written < 0 || (size_t)written >= sizeof(path)) {
            continue;
        }
        if (model_load_file(asset, model, path)) {
            asset->loaded = true;
            return true;
        }
    }
    return false;
}
static bool model_profile_manifest_exists(const char *root) {
    if (root == NULL || root[0] == '\0') {
        return false;
    }
    char path[1024];
    int written = snprintf(path, sizeof(path), "%s/manifest.json", root);
    if (written < 0 || (size_t)written >= sizeof(path)) {
        return false;
    }
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return false;
    }
    return fclose(file) == 0;
}

bool kookie_model_assets_required(void) {
    const char *explicit_requirement =
        getenv("KOOKIE_REQUIRE_NATIVE_ANIMAL_MODELS");
    if (explicit_requirement != NULL &&
        strcmp(explicit_requirement, "1") == 0) {
        return true;
    }
    const char *profile = getenv("KOOKIE_CONTENT_PROFILE");
    if (profile != NULL && strcmp(profile, "none") == 0) {
        return false;
    }
    if (profile != NULL && strcmp(profile, "prototype") == 0) {
        return true;
    }
    if (explicit_requirement != NULL &&
        strcmp(explicit_requirement, "0") == 0) {
        return false;
    }
    const char *environment_root = getenv("KOOKIE_PROTOTYPE_CONTENT_ROOT");
    const char *roots[3] = {
        environment_root, "content/prototype", "assets/prototype"
    };
    for (int index = 0; index < 3; index += 1) {
        if (roots[index] == NULL ||
            (index > 0 && roots[index - 1] != NULL &&
                strcmp(roots[index], roots[index - 1]) == 0)) {
            continue;
        }
        if (model_profile_manifest_exists(roots[index])) {
            return true;
        }
    }
    return false;
}


static KookieModelAsset *model_asset_for(int model) {
    if (model == KOOKIE_MODEL_GOOSE) {
        return &model_assets[0];
    }
    if (model == KOOKIE_MODEL_CAT) {
        return &model_assets[1];
    }
    return NULL;
}

bool kookie_model_assets_available(int model) {
    KookieModelAsset *asset = model_asset_for(model);
    return asset != NULL && model_try_load(asset, model);
}

int kookie_model_assets_vertex_count(int model) {
    KookieModelAsset *asset = model_asset_for(model);
    if (asset == NULL || !model_try_load(asset, model)) {
        return 0;
    }
    return asset->triangle_count * 3;
}
bool kookie_model_assets_texture_png(
    int model, const unsigned char **data, size_t *length
) {
    if (data == NULL || length == NULL) {
        return false;
    }
    *data = NULL;
    *length = 0;
    KookieModelAsset *asset = model_asset_for(model);
    if (asset == NULL || !model_try_load(asset, model) ||
        asset->texture_png_length == 0) {
        return false;
    }
    *data = asset->texture_png;
    *length = asset->texture_png_length;
    return true;
}

static int model_phase_wave(int phase, int period) {
    int value = phase % period;
    if (value < 0) {
        value += period;
    }
    return value < period / 2 ? -1 : 1;
}

static int model_round(float value) {
    long rounded = lroundf(value);
    if (rounded < INT32_MIN) {
        return INT32_MIN;
    }
    if (rounded > INT32_MAX) {
        return INT32_MAX;
    }
    return (int)rounded;
}

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
    void *context
) {
    KookieModelAsset *asset = model_asset_for(model);
    if (asset == NULL || !model_try_load(asset, model) || resource_base <= 0 ||
        emit == NULL || facing == 0 || x < -1000 || x > 1000 ||
        y < -1000 || y > 1000 || z < -1000 || z > 1000) {
        return false;
    }
    int idle_bob = animation_state == 1 &&
            model_phase_wave(animation_tick, 8) > 0 ? 1 : 0;
    int gait_bob = moving != 0 && model_phase_wave(phase, 8) > 0 ? 1 : 0;
    int bob = idle_bob + gait_bob;
    float attack_lift = 0.0f;
    if (attacking != 0 || animation_state == 3) {
        int tick = animation_tick;
        if (tick < 0) {
            tick = 0;
        }
        if (tick > 6) {
            tick = 6;
        }
        attack_lift = (float)tick * 0.08f;
    }
    float gait = moving != 0 && model_phase_wave(phase, 4) > 0 ? 0.045f : -0.045f;
    float yaw = facing > 0 ? -(float)M_PI * 0.5f : (float)M_PI * 0.5f;
    yaw += gait;
    float sine = sinf(yaw);
    float cosine = cosf(yaw);
    for (int triangle = 0; triangle < asset->triangle_count; triangle += 1) {
        const KookieModelTriangle *source = &asset->triangles[triangle];
        int resource = resource_base + source->material_slot;
        for (int corner = 0; corner < 3; corner += 1) {
            float local_x = source->position[corner][0];
            float local_y = source->position[corner][1] + (float)bob + attack_lift;
            float local_z = source->position[corner][2];
            if (attacking != 0 || animation_state == 3) {
                local_z -= attack_lift * 0.5f;
            }
            float world_x = (float)x + local_x * cosine + local_z * sine;
            float world_z = (float)z - local_x * sine + local_z * cosine;
            if (!emit(
                    context, resource,
                    model_round(world_x), model_round((float)y + local_y),
                    model_round(world_z),
                    source->uv[corner][0], source->uv[corner][1])) {
                return false;
            }
        }
    }
    return true;
}
