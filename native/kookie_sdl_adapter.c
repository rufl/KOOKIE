#include <SDL3/SDL.h>

#include <SDL3/SDL_gpu.h>
#include <SDL3_mixer/SDL_mixer.h>
#if SDL_VERSION != SDL_VERSIONNUM(3, 4, 18)
#error "KOOKIE requires SDL 3.4.18 headers"
#endif
#if SDL_MIXER_VERSION != SDL_VERSIONNUM(3, 2, 4)
#error "KOOKIE requires SDL_mixer 3.2.4 headers"
#endif

#include "kookie_ui_renderer.h"
#include "kookie_transport.h"
#include "kookie_audio_assets.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kookie_shader_manifest.h"
#include <stdint.h>
#include <limits.h>
#if defined(_WIN32)
#include <windows.h>
#endif
#define KOOKIE_MAX_WINDOWS 8
#define KOOKIE_TRANSPORT_MAX_SLOTS 4
#define KOOKIE_TRANSPORT_MAX_WORDS 1740
#define KOOKIE_GPU_UI_TEXTURE_WIDTH 2048
#define KOOKIE_GPU_UI_TEXTURE_HEIGHT 2048
#define KOOKIE_GPU_SCENE_VERTEX_V1_STRIDE 24
#define KOOKIE_GPU_MAX_SCENE_BATCH_VERTICES 65536
#define KOOKIE_GPU_RECOVERY_UNAVAILABLE 0
#define KOOKIE_GPU_RECOVERY_CAPABILITY_REOPEN 1
#define KOOKIE_GPU_RECOVERY_CAPABILITY_LOSS_MARKER 2
#define KOOKIE_TRANSPORT_MAGIC 0x4b4f4f4bU
#define KOOKIE_TRANSPORT_VERSION 1U
#define KOOKIE_TRANSPORT_HEADER_WORDS 6
#define KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS 1000
#define KOOKIE_GPU_RECOVERY_READY 1
#define KOOKIE_GPU_RECOVERY_LOST 2
#define KOOKIE_GPU_RECOVERY_FAILED 3
#define KOOKIE_GPU_MAX_SHADER_BYTES (16u * 1024u * 1024u)
#define KOOKIE_GPU_MAX_MODEL_TEXTURE_BYTES (1024u * 1024u)
#define KOOKIE_GPU_WORLD_TEXTURE_COORDINATE_LIMIT 2000000
#define KOOKIE_GPU_VFX_RESOURCE_BASE 1000
#define KOOKIE_GPU_VFX_RESOURCE_STRIDE 128
#define KOOKIE_GPU_VFX_ASSET_COUNT 16
#define KOOKIE_GPU_VFX_CELL_SIZE 256
#define KOOKIE_GPU_VFX_ATLAS_COLUMNS 4
#define KOOKIE_GPU_VFX_ATLAS_ROWS 4
#define KOOKIE_GPU_VFX_ATLAS_WIDTH \
    (KOOKIE_GPU_VFX_CELL_SIZE * KOOKIE_GPU_VFX_ATLAS_COLUMNS)
#define KOOKIE_GPU_VFX_ATLAS_HEIGHT \
    (KOOKIE_GPU_VFX_CELL_SIZE * KOOKIE_GPU_VFX_ATLAS_ROWS)
#define KOOKIE_GPU_VFX_PATH_MAX 256
#define KOOKIE_GPU_VFX_SURFACE_COUNT KOOKIE_GPU_VFX_ASSET_COUNT
#define KOOKIE_GPU_WATER_STYLE_COUNT 4
#define KOOKIE_WINDOW_KIND 1
#define KOOKIE_AUDIO_KIND 2
#define KOOKIE_GPU_KIND 3

typedef struct {
    SDL_Window *window;
    unsigned int generation;
} KookieWindowSlot;

typedef struct {
    MIX_Mixer *mixer;
    MIX_Track *effects_track;
    MIX_Track *music_track;
    MIX_Audio *music_ogg_audio;
    MIX_Track *music_ogg_track;
    MIX_Audio *ui_audio[KOOKIE_AUDIO_UI_ASSET_COUNT];
    MIX_Track *ui_tracks[KOOKIE_AUDIO_UI_ASSET_COUNT];
    SDL_AudioStream *effects_stream;
    SDL_AudioStream *music_stream;
    SDL_AudioSpec spec;
    Sint64 music_ogg_duration_frames;
    int effects_volume;
    int music_volume;
    bool music_ogg_loaded;
    bool mixer_initialized;
    unsigned int generation;
} KookieAudioSlot;
typedef struct {
    SDL_GPUDevice *device;
    int window_slot;
    unsigned int generation;
} KookieGpuSlot;
typedef struct {
    SDL_GPUDevice *device;
    SDL_GPUTextureFormat target_format;
    SDL_GPUShader *vertex_shader;
    SDL_GPUShader *fragment_shader;
    SDL_GPUGraphicsPipeline *pipeline;
    SDL_GPUShader *world_vertex_shader;
    SDL_GPUShader *world_fragment_shader;
    SDL_GPUGraphicsPipeline *world_pipeline;
    SDL_GPUTexture *texture;
    SDL_GPUTransferBuffer *ui_transfer;
    SDL_GPUTransferBuffer *ui_quad_transfer;
    SDL_GPUTexture *world_texture;
    SDL_GPUTexture *depth_texture;
    Uint32 depth_width;
    Uint32 depth_height;
    SDL_GPUBuffer *vertex_buffer;
    SDL_GPUBuffer *index_buffer;
    SDL_GPUBuffer *world_vertex_buffer;
    SDL_GPUTransferBuffer *world_transfer;
    Uint32 world_texture_width;
    Uint32 world_texture_height;
    Uint32 cat_texture_x;
    Uint32 cat_texture_y;
    Uint32 cat_texture_width;
    Uint32 cat_texture_height;
    int world_vertex_capacity;
    SDL_GPUSampler *sampler;
    bool ready;
} KookieGpuResources;

typedef struct {
    KookieUiVertex *ui_vertices;
    KookieUiTextRun *text_runs;
    size_t *text_run_starts;
    uint32_t *text_codepoints;
    size_t text_capacity;
    size_t text_codepoint_capacity;
    int text_count;
    int text_codepoint_count;
    size_t text_open_start;
    bool text_open;
    size_t capacity;
    int expected;
    int count;
    bool open;
    bool committed;
    bool active;
} KookieGpuScene;
typedef struct {
    float *vertices;
    size_t capacity;
    int expected;
    int count;
    bool open;
    bool committed;
    bool active;
} KookieGpuWorldScene;
typedef struct {
    Uint32 width;
    Uint32 height;
    Uint32 vfx_x;
    Uint32 goose_x;
    Uint32 goose_y;
    Uint32 goose_width;
    Uint32 goose_height;
    Uint32 cat_x;
    Uint32 cat_y;
    Uint32 cat_width;
    Uint32 cat_height;
    bool goose_embedded;
    bool cat_embedded;
    bool ready;
} KookieGpuWorldTextureLayout;
typedef struct {
    Uint8 *bytes;
    size_t length;
    size_t next_byte;
    bool open;
    bool committed;
} KookieGpuModelTextureStaging;
typedef struct {
    Uint8 *pixels;
    size_t bytes;
    Uint32 width;
    Uint32 height;
    Uint32 vfx_x;
    Uint32 goose_x;
    Uint32 goose_y;
    Uint32 goose_width;
    Uint32 goose_height;
    Uint32 cat_x;
    Uint32 cat_y;
    Uint32 cat_width;
    Uint32 cat_height;
    size_t next_word;
    bool open;
    bool committed;
} KookieGpuWorldTextureStaging;
typedef struct {
    int enabled;
    int tint_r;
    int tint_g;
    int tint_b;
    int caustic_scale;
    int caustic_speed;
    int caustic_strength;
    int toon_base;
    int toon_contrast;
    int opacity;
} KookieWaterStyle;

static KookieWaterStyle gpu_water_styles[KOOKIE_GPU_WATER_STYLE_COUNT];
static int gpu_water_time_ticks;
static KookieGpuModelTextureStaging gpu_goose_texture_staging;
static KookieGpuModelTextureStaging gpu_model_texture_staging;
static KookieGpuWorldTextureStaging gpu_world_texture_staging;
static int gpu_world_camera_matrix[16];
static KookieGpuWorldScene gpu_world_scene;
static int gpu_world_camera_stage_count;
static bool gpu_world_camera_stage_open;
static bool gpu_world_camera_matrix_ready;
static bool gpu_render_plan_ready;
static bool gpu_render_world;
static bool gpu_render_scene;
static bool gpu_render_policy_active;

static KookieGpuModelTextureStaging *kookie_gpu_model_texture_staging_for(
    int model
) {
    if (model == 1) {
        return &gpu_goose_texture_staging;
    }
    if (model == 2) {
        return &gpu_model_texture_staging;
    }
    return NULL;
}

static void kookie_gpu_model_texture_staging_release_one(
    KookieGpuModelTextureStaging *staging
) {
    if (staging == NULL) {
        return;
    }
    free(staging->bytes);
    memset(staging, 0, sizeof(*staging));
}

static void kookie_gpu_model_texture_staging_release(void) {
    kookie_gpu_model_texture_staging_release_one(
        &gpu_goose_texture_staging);
    kookie_gpu_model_texture_staging_release_one(
        &gpu_model_texture_staging);
}

static void kookie_gpu_world_texture_staging_release(void) {
    free(gpu_world_texture_staging.pixels);
    memset(&gpu_world_texture_staging, 0, sizeof(gpu_world_texture_staging));
}

static KookieGpuWorldTextureLayout gpu_world_texture_layout;


static void kookie_gpu_scene_release(KookieGpuScene *scene) {
    if (scene == NULL) {
        return;
    }
    free(scene->ui_vertices);
    free(scene->text_runs);
    free(scene->text_run_starts);
    free(scene->text_codepoints);
    memset(scene, 0, sizeof(*scene));
}

/* Screen/HUD counts fluctuate; grow once instead of rebuilding every transition. */
static bool kookie_gpu_growth_target(
    size_t required, size_t *target
) {
    if (target == NULL || required == 0) {
        return false;
    }
    size_t headroom = required / 2u;
    if (headroom < 64u) {
        headroom = 64u;
    }
    if (required > SIZE_MAX - headroom) {
        return false;
    }
    *target = required + headroom;
    return true;
}

static bool kookie_gpu_world_scene_reserve(
    float **vertices, size_t *capacity, int vertex_count, size_t components
) {
    if (vertices == NULL || capacity == NULL || vertex_count <= 0 ||
        components == 0 ||
        (size_t)vertex_count > SIZE_MAX / components) {
        return false;
    }
    if (*capacity >= (size_t)vertex_count) {
        return true;
    }
    size_t target_count = 0;
    if (!kookie_gpu_growth_target(
            (size_t)vertex_count, &target_count) ||
        target_count > SIZE_MAX / components ||
        target_count * components > SIZE_MAX / sizeof(float)) {
        return false;
    }
    size_t float_count = target_count * components;
    float *resized = realloc(*vertices, float_count * sizeof(float));
    if (resized == NULL) {
        return false;
    }
    *vertices = resized;
    *capacity = target_count;
    return true;
}
static bool kookie_gpu_scene_reserve_data(
    KookieGpuScene *scene, int vertex_count
) {
    if (scene == NULL || vertex_count <= 0 ||
        (size_t)vertex_count > SIZE_MAX / sizeof(KookieUiVertex)) {
        return false;
    }
    if (scene->capacity >= (size_t)vertex_count) {
        return true;
    }
    size_t target_count = 0;
    if (!kookie_gpu_growth_target(
            (size_t)vertex_count, &target_count) ||
        target_count > SIZE_MAX / sizeof(KookieUiVertex)) {
        return false;
    }
    KookieUiVertex *ui_vertices = (KookieUiVertex *)malloc(
        target_count * sizeof(KookieUiVertex));
    if (ui_vertices == NULL) {
        return false;
    }
    if (scene->count > 0) {
        memcpy(ui_vertices, scene->ui_vertices,
            (size_t)scene->count * sizeof(KookieUiVertex));
    }
    free(scene->ui_vertices);
    scene->ui_vertices = ui_vertices;
    scene->capacity = target_count;
    return true;
}
static bool kookie_gpu_scene_reserve_text_runs(
    KookieGpuScene *scene, size_t required
) {
    if (scene == NULL || required == 0 || scene->text_capacity >= required) {
        return scene != NULL && required > 0;
    }
    size_t target = 0;
    if (!kookie_gpu_growth_target(required, &target) ||
        target > SIZE_MAX / sizeof(KookieUiTextRun) ||
        target > SIZE_MAX / sizeof(size_t)) {
        return false;
    }
    KookieUiTextRun *runs = (KookieUiTextRun *)malloc(
        target * sizeof(KookieUiTextRun));
    size_t *starts = (size_t *)malloc(target * sizeof(size_t));
    if (runs == NULL || starts == NULL) {
        free(runs);
        free(starts);
        return false;
    }
    if (scene->text_count > 0) {
        memcpy(runs, scene->text_runs,
            (size_t)scene->text_count * sizeof(KookieUiTextRun));
        memcpy(starts, scene->text_run_starts,
            (size_t)scene->text_count * sizeof(size_t));
    }
    free(scene->text_runs);
    free(scene->text_run_starts);
    scene->text_runs = runs;
    scene->text_run_starts = starts;
    scene->text_capacity = target;
    return true;
}

static bool kookie_gpu_scene_reserve_codepoints(
    KookieGpuScene *scene, size_t required
) {
    if (scene == NULL || required == 0 || required <= scene->text_codepoint_capacity) {
        return scene != NULL && required > 0;
    }
    size_t target = 0;
    if (!kookie_gpu_growth_target(required, &target) ||
        target > SIZE_MAX / sizeof(uint32_t)) {
        return false;
    }
    uint32_t *codepoints = (uint32_t *)malloc(target * sizeof(uint32_t));
    if (codepoints == NULL) {
        return false;
    }
    if (scene->text_codepoint_count > 0) {
        memcpy(codepoints, scene->text_codepoints,
            (size_t)scene->text_codepoint_count * sizeof(uint32_t));
    }
    free(scene->text_codepoints);
    scene->text_codepoints = codepoints;
    scene->text_codepoint_capacity = target;
    for (int index = 0; index < scene->text_count; index += 1) {
        scene->text_runs[index].codepoints =
            scene->text_codepoints + scene->text_run_starts[index];
    }
    return true;
}

static void kookie_gpu_world_release(KookieGpuWorldScene *scene) {
    if (scene == NULL) {
        return;
    }
    free(scene->vertices);
    memset(scene, 0, sizeof(*scene));
}
static bool kookie_gpu_prepare_world_texture_layout(void) {
    if (gpu_world_texture_layout.ready) {
        return true;
    }
    if (!gpu_world_texture_staging.committed) {
        if (gpu_world_scene.committed && gpu_world_scene.count > 0) {
            return false;
        }
        gpu_world_texture_layout.width = 256u;
        gpu_world_texture_layout.height = 256u;
        gpu_world_texture_layout.vfx_x = 0;
        gpu_world_texture_layout.goose_x = 0;
        gpu_world_texture_layout.goose_y = 0;
        gpu_world_texture_layout.goose_width = 0;
        gpu_world_texture_layout.goose_height = 0;
        gpu_world_texture_layout.cat_x = 0;
        gpu_world_texture_layout.cat_y = 0;
        gpu_world_texture_layout.cat_width = 0;
        gpu_world_texture_layout.cat_height = 0;
        gpu_world_texture_layout.goose_embedded = false;
        gpu_world_texture_layout.cat_embedded = false;
        gpu_world_texture_layout.ready = true;
        return true;
    }
    if (gpu_world_texture_staging.width < 256u ||
        gpu_world_texture_staging.height < 256u ||
        gpu_world_texture_staging.width > 4096u ||
        gpu_world_texture_staging.height > 4096u ||
        (gpu_world_texture_staging.goose_width > 0u &&
            gpu_world_texture_staging.goose_height == 0u) ||
        (gpu_world_texture_staging.goose_width == 0u &&
            gpu_world_texture_staging.goose_height > 0u) ||
        (gpu_world_texture_staging.cat_width > 0u &&
            gpu_world_texture_staging.cat_height == 0u) ||
        (gpu_world_texture_staging.cat_width == 0u &&
            gpu_world_texture_staging.cat_height > 0u) ||
        (gpu_world_texture_staging.vfx_x > 0u &&
            (gpu_world_texture_staging.vfx_x >=
                gpu_world_texture_staging.width ||
             KOOKIE_GPU_VFX_ATLAS_WIDTH >
                gpu_world_texture_staging.width -
                    gpu_world_texture_staging.vfx_x ||
             gpu_world_texture_staging.height <
                KOOKIE_GPU_VFX_ATLAS_HEIGHT))) {
        return false;
    }
    if (gpu_world_texture_staging.goose_width > 0u &&
        (gpu_world_texture_staging.goose_x >= gpu_world_texture_staging.width ||
         gpu_world_texture_staging.goose_y >= gpu_world_texture_staging.height ||
         gpu_world_texture_staging.goose_width >
             gpu_world_texture_staging.width -
                 gpu_world_texture_staging.goose_x ||
         gpu_world_texture_staging.goose_height >
             gpu_world_texture_staging.height -
                 gpu_world_texture_staging.goose_y)) {
        return false;
    }
    if (gpu_world_texture_staging.cat_width > 0u &&
        (gpu_world_texture_staging.cat_x >= gpu_world_texture_staging.width ||
         gpu_world_texture_staging.cat_y >= gpu_world_texture_staging.height ||
         gpu_world_texture_staging.cat_width >
             gpu_world_texture_staging.width - gpu_world_texture_staging.cat_x ||
         gpu_world_texture_staging.cat_height >
             gpu_world_texture_staging.height - gpu_world_texture_staging.cat_y)) {
        return false;
    }
    gpu_world_texture_layout.width = gpu_world_texture_staging.width;
    gpu_world_texture_layout.height = gpu_world_texture_staging.height;
    gpu_world_texture_layout.vfx_x = gpu_world_texture_staging.vfx_x;
    gpu_world_texture_layout.goose_x = gpu_world_texture_staging.goose_x;
    gpu_world_texture_layout.goose_y = gpu_world_texture_staging.goose_y;
    gpu_world_texture_layout.goose_width =
        gpu_world_texture_staging.goose_width;
    gpu_world_texture_layout.goose_height =
        gpu_world_texture_staging.goose_height;
    gpu_world_texture_layout.cat_x = gpu_world_texture_staging.cat_x;
    gpu_world_texture_layout.cat_y = gpu_world_texture_staging.cat_y;
    gpu_world_texture_layout.cat_width = gpu_world_texture_staging.cat_width;
    gpu_world_texture_layout.cat_height = gpu_world_texture_staging.cat_height;
    gpu_world_texture_layout.goose_embedded =
        gpu_world_texture_staging.goose_width > 0u;
    gpu_world_texture_layout.cat_embedded =
        gpu_world_texture_staging.cat_width > 0u;
    gpu_world_texture_layout.ready = true;
    return true;
}


typedef struct {
    int active_generation;
    int active_checksum;
    int pending_generation;
    int pending_checksum;
    int scene_generation;
    int retired_generation;
    int completed_fence;
    bool pending_scene_committed;
} KookieGpuReload;

static int gpu_recovery_state = KOOKIE_GPU_RECOVERY_UNAVAILABLE;
static int kookie_elapsed_microseconds(Uint64 elapsed, Uint64 frequency) {
    if (frequency == 0) {
        return 0;
    }
    long double value =
        ((long double)elapsed * 1000000.0L) / (long double)frequency;
    if (value >= (long double)INT_MAX) {
        return INT_MAX;
    }
    if (value < 1.0L) {
        return 1;
    }
    return (int)value;
}


static KookieGpuResources gpu_resources;
static KookieGpuScene gpu_scene;
static KookieGpuScene gpu_pending_scene;
static KookieUiRenderer *gpu_ui_renderer;
static int last_gpu_fence_wait_microseconds;
static KookieGpuReload gpu_reload;
static SDL_GPUFence *gpu_scene_frame_fences[3];
static int gpu_scene_frame_slot;
static int last_gpu_scene_draw_calls;
static int gpu_scene_batch_calls;
static int gpu_scene_scalar_calls;

static void kookie_gpu_reload_reset(int active_generation) {
    memset(&gpu_reload, 0, sizeof(gpu_reload));
    kookie_gpu_scene_release(&gpu_pending_scene);
    gpu_reload.active_generation = active_generation;
    gpu_reload.active_checksum = active_generation > 0 ? 1 : 0;
}

static KookieWindowSlot window_slots[KOOKIE_MAX_WINDOWS];
static KookieAudioSlot audio_slot;
static void kookie_audio_release_music_ogg(void) {
    if (audio_slot.music_ogg_track != NULL) {
        MIX_DestroyTrack(audio_slot.music_ogg_track);
        audio_slot.music_ogg_track = NULL;
    }
    if (audio_slot.music_ogg_audio != NULL) {
        MIX_DestroyAudio(audio_slot.music_ogg_audio);
        audio_slot.music_ogg_audio = NULL;
    }
    audio_slot.music_ogg_duration_frames = 0;
    audio_slot.music_ogg_loaded = false;
}

static void kookie_audio_release_ui_assets(void) {
    for (int index = 0; index < KOOKIE_AUDIO_UI_ASSET_COUNT; index += 1) {
        if (audio_slot.ui_tracks[index] != NULL) {
            MIX_DestroyTrack(audio_slot.ui_tracks[index]);
            audio_slot.ui_tracks[index] = NULL;
        }
        if (audio_slot.ui_audio[index] != NULL) {
            MIX_DestroyAudio(audio_slot.ui_audio[index]);
            audio_slot.ui_audio[index] = NULL;
        }
    }
}
static void kookie_audio_release(void) {
    unsigned int generation = audio_slot.generation;
    bool mixer_initialized = audio_slot.mixer_initialized;
    kookie_audio_release_music_ogg();
    kookie_audio_release_ui_assets();
    if (audio_slot.effects_track != NULL) {
        MIX_DestroyTrack(audio_slot.effects_track);
    }
    if (audio_slot.music_track != NULL) {
        MIX_DestroyTrack(audio_slot.music_track);
    }
    if (audio_slot.effects_stream != NULL) {
        SDL_DestroyAudioStream(audio_slot.effects_stream);
    }
    if (audio_slot.music_stream != NULL) {
        SDL_DestroyAudioStream(audio_slot.music_stream);
    }
    if (audio_slot.mixer != NULL) {
        MIX_DestroyMixer(audio_slot.mixer);
    }
    memset(&audio_slot, 0, sizeof(audio_slot));
    audio_slot.generation = generation;
    if (mixer_initialized) {
        MIX_Quit();
    }
}
static bool kookie_gpu_wait_fence_and_release(
    SDL_GPUDevice *device, SDL_GPUFence **fence
) {
    if (device == NULL || fence == NULL || *fence == NULL) {
        return false;
    }
    bool success = SDL_WaitForGPUIdle(device);
    SDL_ReleaseGPUFence(device, *fence);
    *fence = NULL;
    return success;
}

static bool kookie_gpu_wait_scene_fences(SDL_GPUDevice *device) {
    if (device == NULL) {
        return false;
    }
    bool success = true;
    for (int slot = 0; slot < 3; slot += 1) {
        if (gpu_scene_frame_fences[slot] != NULL &&
            !kookie_gpu_wait_fence_and_release(
                device, &gpu_scene_frame_fences[slot])) {
            success = false;
        }
    }
    return success;
}

static bool kookie_gpu_submit_and_wait_fence(
    SDL_GPUDevice *device,
    SDL_GPUCommandBuffer *command_buffer
) {
    Uint64 start = SDL_GetPerformanceCounter();
    SDL_GPUFence *fence =
        SDL_SubmitGPUCommandBufferAndAcquireFence(command_buffer);
    if (fence == NULL) {
        return false;
    }
    bool success = SDL_WaitForGPUIdle(device);
    Uint64 elapsed = SDL_GetPerformanceCounter() - start;
    Uint64 frequency = SDL_GetPerformanceFrequency();
    last_gpu_fence_wait_microseconds =
        kookie_elapsed_microseconds(elapsed, frequency);
    SDL_ReleaseGPUFence(device, fence);
    return success;
}
static void kookie_gpu_release_resources(SDL_GPUDevice *device) {
    if (device != NULL) {
        SDL_WaitForGPUIdle(device);
        for (int slot = 0; slot < 3; slot += 1) {
            if (gpu_scene_frame_fences[slot] != NULL) {
                SDL_ReleaseGPUFence(
                    device, gpu_scene_frame_fences[slot]);
                gpu_scene_frame_fences[slot] = NULL;
            }
        }
    } else {
        memset(gpu_scene_frame_fences, 0, sizeof(gpu_scene_frame_fences));
    }
    gpu_scene_frame_slot = 0;
    if (device == NULL || !gpu_resources.ready) {
        memset(&gpu_resources, 0, sizeof(gpu_resources));
        return;
    }
    if (gpu_resources.ui_transfer != NULL) {
        SDL_ReleaseGPUTransferBuffer(device, gpu_resources.ui_transfer);
    }
    if (gpu_resources.ui_quad_transfer != NULL) {
        SDL_ReleaseGPUTransferBuffer(device, gpu_resources.ui_quad_transfer);
    }
    if (gpu_resources.world_transfer != NULL) {
        SDL_ReleaseGPUTransferBuffer(device, gpu_resources.world_transfer);
    }
    if (gpu_resources.world_vertex_buffer != NULL) {
        SDL_ReleaseGPUBuffer(device, gpu_resources.world_vertex_buffer);
    }
    if (gpu_resources.index_buffer != NULL) {
        SDL_ReleaseGPUBuffer(device, gpu_resources.index_buffer);
    }
    if (gpu_resources.vertex_buffer != NULL) {
        SDL_ReleaseGPUBuffer(device, gpu_resources.vertex_buffer);
    }
    if (gpu_resources.texture != NULL) {
        SDL_ReleaseGPUTexture(device, gpu_resources.texture);
    }
    if (gpu_resources.world_texture != NULL) {
        SDL_ReleaseGPUTexture(device, gpu_resources.world_texture);
    }
    if (gpu_resources.depth_texture != NULL) {
        SDL_ReleaseGPUTexture(device, gpu_resources.depth_texture);
    }
    if (gpu_resources.sampler != NULL) {
        SDL_ReleaseGPUSampler(device, gpu_resources.sampler);
    }
    if (gpu_resources.pipeline != NULL) {
        SDL_ReleaseGPUGraphicsPipeline(device, gpu_resources.pipeline);
    }
    if (gpu_resources.world_pipeline != NULL) {
        SDL_ReleaseGPUGraphicsPipeline(device, gpu_resources.world_pipeline);
    }
    if (gpu_resources.fragment_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.fragment_shader);
    }
    if (gpu_resources.world_vertex_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.world_vertex_shader);
    }
    if (gpu_resources.world_fragment_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.world_fragment_shader);
    }
    if (gpu_resources.vertex_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.vertex_shader);
    }
    memset(&gpu_resources, 0, sizeof(gpu_resources));
}
static void kookie_gpu_retire_resources(
    SDL_GPUDevice *device, bool device_lost
) {
    if (device_lost) {
        memset(&gpu_resources, 0, sizeof(gpu_resources));
        memset(gpu_scene_frame_fences, 0, sizeof(gpu_scene_frame_fences));
        gpu_scene_frame_slot = 0;
        return;
    }
    kookie_gpu_release_resources(device);
}




static KookieGpuSlot gpu_slot;
static bool kookie_gpu_handle_device_event(SDL_EventType event_type) {
    if (gpu_slot.device == NULL ||
        gpu_recovery_state != KOOKIE_GPU_RECOVERY_READY) {
        return false;
    }
    if (event_type == SDL_EVENT_RENDER_DEVICE_LOST) {
        kookie_gpu_retire_resources(gpu_slot.device, true);
        gpu_recovery_state = KOOKIE_GPU_RECOVERY_LOST;
        return true;
    }
    if (event_type == SDL_EVENT_RENDER_DEVICE_RESET) {
        kookie_gpu_retire_resources(gpu_slot.device, false);
        gpu_recovery_state = KOOKIE_GPU_RECOVERY_READY;
        return true;
    }
    return false;
}
static int last_event_a;
static int last_event_b;
static int pending_focus_event = -1;

static int gameplay_mouse_delta_x;
static int gameplay_mouse_delta_y;
static int gameplay_mouse_wheel_y;

static void kookie_clear_mouse_state(void) {
    gameplay_mouse_delta_x = 0;
    gameplay_mouse_delta_y = 0;
    gameplay_mouse_wheel_y = 0;
}

static void kookie_reset_event_state(void) {
    last_event_a = 0;
    last_event_b = 0;
    pending_focus_event = -1;
    kookie_clear_mouse_state();
}

static int kookie_clamp_mouse_delta(int value) {
    if (value < -100) {
        return -100;
    }
    if (value > 100) {
        return 100;
    }
    return value;
}

static int make_token(int slot, unsigned int generation, int kind) {
    return (((int)generation * 100) + slot + 1) * 10 + kind;
}

static bool decode_token(int token, int expected_kind, int *slot, unsigned int *generation) {
    if (token <= 0 || token % 10 != expected_kind) {
        return false;
    }

    int packed = token / 10;
    int encoded_slot = packed % 100;
    int encoded_generation = packed / 100;
    if (encoded_slot <= 0 || encoded_slot > KOOKIE_MAX_WINDOWS || encoded_generation <= 0) {
        return false;
    }

    *slot = encoded_slot - 1;
    *generation = (unsigned int)encoded_generation;
    return true;
}

#if defined(_WIN32)
/*
 * Kof's JVM FFI closes its per-call library arena after every extern call.
 * Pinning this module keeps SDL state alive between those calls on Windows.
 */
static bool kookie_pin_module(void) {
    HMODULE module = NULL;
    return GetModuleHandleExA(
        GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
            GET_MODULE_HANDLE_EX_FLAG_PIN,
        (LPCSTR)(uintptr_t)&kookie_pin_module, &module) != 0;
}
#endif
bool kookie_sdl_init(int flags) {

    if (flags < 0 || SDL_GetVersion() != SDL_VERSION ||
        MIX_Version() != SDL_MIXER_VERSION) {
        return false;
    }
#if defined(_WIN32)
    if (!kookie_pin_module()) {
        return false;
    }
#endif
    kookie_reset_event_state();
    kookie_gpu_scene_release(&gpu_scene);
    kookie_gpu_world_release(&gpu_world_scene);
    memset(&gpu_world_texture_layout, 0, sizeof(gpu_world_texture_layout));
    kookie_gpu_world_texture_staging_release();
    kookie_gpu_model_texture_staging_release();
    gpu_world_camera_stage_count = 0;
    gpu_world_camera_stage_open = false;
    gpu_world_camera_matrix_ready = false;
    gpu_render_plan_ready = false;
    gpu_render_world = false;
    gpu_render_scene = false;
    gpu_render_policy_active = false;
    bool initialized = SDL_Init((SDL_InitFlags)flags);
    return initialized;
}

void kookie_sdl_shutdown(void) {
    if (gpu_slot.device != NULL) {
        if (gpu_slot.window_slot >= 0 && gpu_slot.window_slot < KOOKIE_MAX_WINDOWS &&
            window_slots[gpu_slot.window_slot].window != NULL) {
            SDL_ReleaseWindowFromGPUDevice(gpu_slot.device, window_slots[gpu_slot.window_slot].window);
        }
        kookie_gpu_release_resources(gpu_slot.device);
        SDL_DestroyGPUDevice(gpu_slot.device);
        gpu_slot.device = NULL;
        gpu_slot.window_slot = -1;
        gpu_slot.generation += 1;
        gpu_recovery_state = KOOKIE_GPU_RECOVERY_UNAVAILABLE;
    }
    for (int i = 0; i < KOOKIE_MAX_WINDOWS; i += 1) {
        if (window_slots[i].window != NULL) {
            SDL_DestroyWindow(window_slots[i].window);
            window_slots[i].window = NULL;
            window_slots[i].generation += 1;
        }
    }
    if (audio_slot.mixer != NULL) {
        kookie_audio_release();
    }
    (void)kookie_transport_close();
    kookie_gpu_scene_release(&gpu_scene);
    kookie_gpu_world_release(&gpu_world_scene);
    memset(&gpu_world_texture_layout, 0, sizeof(gpu_world_texture_layout));
    kookie_gpu_world_texture_staging_release();
    kookie_gpu_model_texture_staging_release();
    gpu_world_camera_stage_count = 0;
    gpu_world_camera_stage_open = false;
    gpu_world_camera_matrix_ready = false;
    gpu_render_plan_ready = false;
    gpu_render_world = false;
    gpu_render_scene = false;
    gpu_render_policy_active = false;
    if (gpu_ui_renderer != NULL) {
        kookie_ui_renderer_destroy(gpu_ui_renderer);
        gpu_ui_renderer = NULL;
    }
    SDL_Quit();
    kookie_reset_event_state();
}

int kookie_window_create(int width, int height, int hidden) {
    if (width <= 0 || height <= 0) {
        return 0;
    }

    int slot = -1;
    for (int i = 0; i < KOOKIE_MAX_WINDOWS; i += 1) {
        if (window_slots[i].window == NULL) {
            slot = i;
            break;
        }
    }
    if (slot < 0) {
        return 0;
    }

    SDL_WindowFlags flags =
        SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY;
    if (hidden) {
        flags |= SDL_WINDOW_HIDDEN;
    }
    SDL_Window *window = SDL_CreateWindow(
        "GatoGanso", width, height, flags);
    bool minimum_size = window != NULL &&
        SDL_SetWindowMinimumSize(window, 320, 180);
    if (window == NULL || !minimum_size) {
        if (window != NULL) {
            SDL_DestroyWindow(window);
        }
        return 0;
    }

    if (window_slots[slot].generation == 0) {
        window_slots[slot].generation = 1;
    }
    window_slots[slot].window = window;
    return make_token(slot, window_slots[slot].generation, KOOKIE_WINDOW_KIND);
}

bool kookie_window_is_resizable(int token) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_WINDOW_KIND, &slot, &generation) ||
        window_slots[slot].window == NULL ||
        window_slots[slot].generation != generation) {
        return false;
    }
    return (SDL_GetWindowFlags(window_slots[slot].window) &
        SDL_WINDOW_RESIZABLE) != 0;
}
bool kookie_window_set_gameplay_mouse_mode(int token, int enabled) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_WINDOW_KIND, &slot, &generation) ||
        window_slots[slot].window == NULL ||
        window_slots[slot].generation != generation ||
        (enabled != 0 && enabled != 1)) {
        return false;
    }
    SDL_Window *window = window_slots[slot].window;
    bool relative = enabled != 0;
    if (SDL_GetWindowRelativeMouseMode(window) == relative) {
        return true;
    }
    return SDL_SetWindowRelativeMouseMode(window, relative);
}

bool kookie_window_apply_display(
    int token, int mode, int width, int height
) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_WINDOW_KIND, &slot, &generation) ||
        window_slots[slot].window == NULL ||
        window_slots[slot].generation != generation ||
        mode < 0 || mode > 2 ||
        width < 320 || width > 7680 ||
        height < 180 || height > 4320) {
        return false;
    }
    SDL_Window *window = window_slots[slot].window;
    if ((SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN) != 0 &&
        (!SDL_SetWindowFullscreen(window, false) ||
         !SDL_SyncWindow(window))) {
        return false;
    }
    if (mode == 0 || mode == 1) {
        if (!SDL_SetWindowBordered(window, mode == 0) ||
            !SDL_SetWindowResizable(window, mode == 0) ||
            !SDL_SetWindowSize(window, width, height) ||
            !SDL_SetWindowPosition(
                window, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED) ||
            !SDL_SyncWindow(window)) {
            return false;
        }
        int applied_width = 0;
        int applied_height = 0;
        if (!SDL_GetWindowSize(window, &applied_width, &applied_height)) {
            return false;
        }
        Uint32 flags = SDL_GetWindowFlags(window);
        return applied_width == width && applied_height == height &&
            (flags & SDL_WINDOW_FULLSCREEN) == 0;
    }
    SDL_DisplayID display = SDL_GetDisplayForWindow(window);
    SDL_DisplayMode closest;
    if (display == 0 ||
        !SDL_GetClosestFullscreenDisplayMode(
            display, width, height, 0.0f, true, &closest) ||
        !SDL_SetWindowFullscreenMode(window, &closest) ||
        !SDL_SetWindowFullscreen(window, true) ||
        !SDL_SyncWindow(window)) {
        return false;
    }
    return (SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN) != 0;
}

bool kookie_window_destroy(int token) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_WINDOW_KIND, &slot, &generation)) {
        return false;
    }
    if (window_slots[slot].window == NULL || window_slots[slot].generation != generation) {
        return false;
    }

    SDL_DestroyWindow(window_slots[slot].window);
    window_slots[slot].window = NULL;
    window_slots[slot].generation += 1;
    return true;
}

int kookie_gpu_open(int window_token) {
    if (gpu_slot.device != NULL) {
        return 0;
    }

    int window_slot;
    unsigned int window_generation;
    if (!decode_token(window_token, KOOKIE_WINDOW_KIND, &window_slot, &window_generation)) {
        return 0;
    }
    if (window_slots[window_slot].window == NULL ||
        window_slots[window_slot].generation != window_generation) {
        return 0;
    }

    SDL_GPUDevice *device = SDL_CreateGPUDevice(
        SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL,
        false,
        NULL);
    if (device == NULL) {
        fprintf(stderr, "kookie_gpu_open: %s\n", SDL_GetError());
        return 0;
    }
    if (!SDL_ClaimWindowForGPUDevice(
            device, window_slots[window_slot].window)) {
        fprintf(stderr, "kookie_gpu_open: %s\n", SDL_GetError());
        SDL_DestroyGPUDevice(device);
        return 0;
    }

    if (gpu_slot.generation == 0) {
        gpu_slot.generation = 1;
    }
    gpu_slot.device = device;
    gpu_slot.window_slot = window_slot;
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_READY;
    kookie_gpu_reload_reset(1);
    return make_token(0, gpu_slot.generation, KOOKIE_GPU_KIND);
}
int kookie_gpu_window_present_capabilities(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot < 0 ||
        gpu_slot.window_slot >= KOOKIE_MAX_WINDOWS ||
        window_slots[gpu_slot.window_slot].window == NULL) {
        return 0;
    }
    SDL_Window *window = window_slots[gpu_slot.window_slot].window;
    int capabilities = 0;
    if (SDL_GetGPUSwapchainTextureFormat(gpu_slot.device, window) !=
        SDL_GPU_TEXTUREFORMAT_INVALID) {
        capabilities |= 1;
    }
    if (SDL_WindowSupportsGPUPresentMode(
            gpu_slot.device, window, SDL_GPU_PRESENTMODE_VSYNC)) {
        capabilities |= 2;
    }
    if (SDL_WindowSupportsGPUPresentMode(
            gpu_slot.device, window, SDL_GPU_PRESENTMODE_IMMEDIATE)) {
        capabilities |= 4;
    }
    if (SDL_WindowSupportsGPUPresentMode(
            gpu_slot.device, window, SDL_GPU_PRESENTMODE_MAILBOX)) {
        capabilities |= 8;
    }
    return capabilities;
}

int kookie_gpu_open_headless(void) {
    if (gpu_slot.device != NULL) {
        return 0;
    }

    SDL_GPUDevice *device = SDL_CreateGPUDevice(
        SDL_GPU_SHADERFORMAT_SPIRV | SDL_GPU_SHADERFORMAT_DXIL,
        false,
        NULL);
    if (device == NULL) {
        gpu_recovery_state = KOOKIE_GPU_RECOVERY_FAILED;
        return 0;
    }
    if (gpu_slot.generation == 0) {
        gpu_slot.generation = 1;
    }
    gpu_slot.device = device;
    gpu_slot.window_slot = -1;
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_READY;
    kookie_gpu_reload_reset(1);
    int token = make_token(0, gpu_slot.generation, KOOKIE_GPU_KIND);
    return token;
}

int kookie_gpu_recovery_state(void) {
    return gpu_recovery_state;
}
int kookie_gpu_recovery_capabilities(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1) {
        return 0;
    }
    if (gpu_recovery_state == KOOKIE_GPU_RECOVERY_READY) {
        return KOOKIE_GPU_RECOVERY_CAPABILITY_REOPEN |
            KOOKIE_GPU_RECOVERY_CAPABILITY_LOSS_MARKER;
    }
    if (gpu_recovery_state == KOOKIE_GPU_RECOVERY_LOST) {
        return KOOKIE_GPU_RECOVERY_CAPABILITY_REOPEN;
    }
    return 0;
}

bool kookie_gpu_push_headless_device_reset(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1 ||
        gpu_recovery_state != KOOKIE_GPU_RECOVERY_READY) {
        return false;
    }
    SDL_Event event = {0};
    event.type = SDL_EVENT_RENDER_DEVICE_RESET;
    return SDL_PushEvent(&event);
}

bool kookie_gpu_push_headless_device_lost(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1 ||
        gpu_recovery_state != KOOKIE_GPU_RECOVERY_READY) {
        return false;
    }
    SDL_Event event = {0};
    event.type = SDL_EVENT_RENDER_DEVICE_LOST;
    return SDL_PushEvent(&event);
}

bool kookie_gpu_recover_headless(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1 ||
        gpu_recovery_state != KOOKIE_GPU_RECOVERY_LOST) {
        return false;
    }
    int active_generation = gpu_reload.active_generation;
    int active_checksum = gpu_reload.active_checksum;
    int retired_generation = gpu_reload.retired_generation;
    int completed_fence = gpu_reload.completed_fence;
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_FAILED;
    kookie_gpu_release_resources(gpu_slot.device);
    SDL_DestroyGPUDevice(gpu_slot.device);
    gpu_slot.device = NULL;
    gpu_slot.generation += 1;
    if (kookie_gpu_open_headless() <= 0) {
        return false;
    }
    gpu_reload.active_generation = active_generation;
    gpu_reload.active_checksum = active_checksum;
    gpu_reload.retired_generation = retired_generation;
    gpu_reload.completed_fence = completed_fence;
    return true;
}
bool kookie_gpu_open_headless_ready(void) {
    return kookie_gpu_open_headless() > 0;
}

bool kookie_gpu_close_headless(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1) {
        return false;
    }
    kookie_gpu_release_resources(gpu_slot.device);
    SDL_DestroyGPUDevice(gpu_slot.device);
    gpu_slot.device = NULL;
    gpu_slot.window_slot = -1;
    gpu_slot.generation += 1;
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_UNAVAILABLE;
    kookie_gpu_reload_reset(0);
    return true;
}

bool kookie_gpu_close(int token) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_GPU_KIND, &slot, &generation) || slot != 0) {
        return false;
    }
    if (gpu_slot.device == NULL || gpu_slot.generation != generation) {
        return false;
    }

    if (gpu_slot.window_slot >= 0 && gpu_slot.window_slot < KOOKIE_MAX_WINDOWS &&
        window_slots[gpu_slot.window_slot].window != NULL) {
        SDL_ReleaseWindowFromGPUDevice(gpu_slot.device, window_slots[gpu_slot.window_slot].window);
    }
    kookie_gpu_release_resources(gpu_slot.device);
    SDL_DestroyGPUDevice(gpu_slot.device);
    gpu_slot.device = NULL;
    gpu_slot.window_slot = -1;
    gpu_slot.generation += 1;
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_UNAVAILABLE;
    kookie_gpu_reload_reset(0);
    return true;
}
static SDL_GPUShaderFormat kookie_gpu_shader_format(
    SDL_GPUDevice *device
) {
    SDL_GPUShaderFormat formats = SDL_GetGPUShaderFormats(device);
    if ((formats & SDL_GPU_SHADERFORMAT_DXIL) != 0) {
        return SDL_GPU_SHADERFORMAT_DXIL;
    }
    if ((formats & SDL_GPU_SHADERFORMAT_SPIRV) != 0) {
        return SDL_GPU_SHADERFORMAT_SPIRV;
    }
    return SDL_GPU_SHADERFORMAT_INVALID;
}

static bool read_shader_binary(
    const char *name,
    SDL_GPUShaderFormat format,
    Uint8 **bytes,
    size_t *size
) {
    const char *directory = getenv("KOOKIE_SHADER_DIR");
    const char *extension =
        format == SDL_GPU_SHADERFORMAT_DXIL ? "dxil" : "spv";
    char path[512];
    if (directory == NULL) {
        directory = "build";
    }
    int written = snprintf(
        path, sizeof(path), "%s/%s.%s",
        directory, name, extension);
    if (written < 0 || (size_t)written >= sizeof(path)) {
        return false;
    }

    FILE *file = fopen(path, "rb");
    if (file == NULL || fseek(file, 0, SEEK_END) != 0) {
        if (file != NULL) {
            fclose(file);
        }
        return false;
    }
    long length = ftell(file);
    if (length <= 0 ||
        (uintmax_t)length > KOOKIE_GPU_MAX_SHADER_BYTES ||
        fseek(file, 0, SEEK_SET) != 0) {
        fclose(file);
        return false;
    }

    Uint8 *data = (Uint8 *)malloc((size_t)length);
    if (data == NULL ||
        fread(data, 1, (size_t)length, file) != (size_t)length) {
        free(data);
        fclose(file);
        return false;
    }
    fclose(file);
    *bytes = data;
    *size = (size_t)length;
    return true;
}
static bool kookie_gpu_model_texture_region(
    int model, Uint32 *x, Uint32 *y, Uint32 *width, Uint32 *height,
    bool *embedded
) {
    if (x == NULL || y == NULL || width == NULL || height == NULL ||
        embedded == NULL) {
        return false;
    }
    if (model == 1) {
        *x = gpu_world_texture_layout.goose_x;
        *y = gpu_world_texture_layout.goose_y;
        *width = gpu_world_texture_layout.goose_width;
        *height = gpu_world_texture_layout.goose_height;
        *embedded = gpu_world_texture_layout.goose_embedded;
        return true;
    }
    if (model == 2) {
        *x = gpu_world_texture_layout.cat_x;
        *y = gpu_world_texture_layout.cat_y;
        *width = gpu_world_texture_layout.cat_width;
        *height = gpu_world_texture_layout.cat_height;
        *embedded = gpu_world_texture_layout.cat_embedded;
        return true;
    }
    return false;
}

static const char *kookie_gpu_vfx_relative_paths[
    KOOKIE_GPU_VFX_SURFACE_COUNT
] = {
    "runtime/vfx/particles/circle_01_a.png",
    "runtime/vfx/particles/fire_01_a.png",
    "runtime/vfx/particles/smoke_01_a.png",
    "runtime/vfx/particles/spark_01_a.png",
    "runtime/vfx/particles/magic_01_a.png",
    "runtime/vfx/particles/slash_01_a.png",
    "runtime/vfx/particles/flare_01_a.png",
    "runtime/vfx/particles/scorch_01_a.png",
    "runtime/vfx/flipbooks/explosion_01_8x8.png",
    "runtime/vfx/flipbooks/explosion_smoke_01_8x8.png",
    "runtime/vfx/flipbooks/fire_01_8x8.png",
    "runtime/vfx/flipbooks/wispy_smoke_01_8x8.png",
    "runtime/vfx/predrawn/explosion_6x5.png",
    "runtime/vfx/predrawn/electric_ring_6x5.png",
    "runtime/vfx/predrawn/fire_point_6x5.png",
    "runtime/vfx/predrawn/impact_white_6x4.png"
};

static bool kookie_gpu_vfx_dimensions(
    int asset, int *width, int *height
) {
    if (width == NULL || height == NULL ||
        asset < 0 || asset >= KOOKIE_GPU_VFX_SURFACE_COUNT) {
        return false;
    }
    *width = asset < 8 ? 128 : 256;
    *height = *width;
    return true;
}

static SDL_Surface *kookie_gpu_load_vfx_png_path(
    const char *path, int expected_width, int expected_height
) {
    if (path == NULL || path[0] == '\0') {
        return NULL;
    }
    SDL_IOStream *input = SDL_IOFromFile(path, "rb");
    if (input == NULL) {
        return NULL;
    }
    SDL_Surface *decoded = SDL_LoadPNG_IO(input, true);
    if (decoded == NULL) {
        return NULL;
    }
    SDL_Surface *rgba = SDL_ConvertSurface(
        decoded, SDL_PIXELFORMAT_RGBA32);
    if (rgba == NULL) {
        SDL_DestroySurface(decoded);
        return NULL;
    }
    if (rgba != decoded) {
        SDL_DestroySurface(decoded);
    }
    if (rgba->w != expected_width || rgba->h != expected_height ||
        rgba->pitch < rgba->w * 4) {
        SDL_DestroySurface(rgba);
        return NULL;
    }
    return rgba;
}

static SDL_Surface *kookie_gpu_load_vfx_texture(int asset) {
    if (asset < 0 || asset >= KOOKIE_GPU_VFX_SURFACE_COUNT) {
        return NULL;
    }
    int expected_width = 0;
    int expected_height = 0;
    if (!kookie_gpu_vfx_dimensions(
            asset, &expected_width, &expected_height)) {
        return NULL;
    }
    const char *relative = kookie_gpu_vfx_relative_paths[asset];
    char path[KOOKIE_GPU_VFX_PATH_MAX] = {0};
    const char *content_root = getenv("KOOKIE_CONTENT_DIR");
    if (content_root != NULL && content_root[0] != '\0') {
        int written = snprintf(
            path, sizeof(path), "%s/%s", content_root, relative);
        if (written >= 0 && (size_t)written < sizeof(path)) {
            SDL_Surface *surface = kookie_gpu_load_vfx_png_path(
                path, expected_width, expected_height);
            if (surface != NULL) { return surface; }
        }
    }
    const char *asset_root = getenv("KOOKIE_ASSET_DIR");
    if (asset_root != NULL && asset_root[0] != '\0') {
        int written = snprintf(
            path, sizeof(path), "%s/../content/prototype/%s",
            asset_root, relative);
        if (written >= 0 && (size_t)written < sizeof(path)) {
            SDL_Surface *surface = kookie_gpu_load_vfx_png_path(
                path, expected_width, expected_height);
            if (surface != NULL) { return surface; }
        }
        written = snprintf(
            path, sizeof(path), "%s/prototype/%s", asset_root, relative);
        if (written >= 0 && (size_t)written < sizeof(path)) {
            SDL_Surface *surface = kookie_gpu_load_vfx_png_path(
                path, expected_width, expected_height);
            if (surface != NULL) { return surface; }
        }
    }
    const char *roots[4] = {
        "content/prototype", "assets/prototype",
        "../content/prototype", "../assets/prototype"
    };
    for (size_t index = 0; index < 4u; index += 1u) {
        int written = snprintf(
            path, sizeof(path), "%s/%s", roots[index], relative);
        if (written < 0 || (size_t)written >= sizeof(path)) {
            continue;
        }
        SDL_Surface *surface = kookie_gpu_load_vfx_png_path(
            path, expected_width, expected_height);
        if (surface != NULL) { return surface; }
    }
    return NULL;
}

static bool kookie_gpu_copy_vfx_texture(
    Uint8 *pixels, size_t bytes, const SDL_Surface *texture, int asset
) {
    if (pixels == NULL || texture == NULL ||
        bytes != gpu_world_texture_staging.bytes ||
        gpu_world_texture_staging.vfx_x == 0u) {
        return false;
    }
    int expected_width = 0;
    int expected_height = 0;
    if (!kookie_gpu_vfx_dimensions(
            asset, &expected_width, &expected_height) ||
        texture->w != expected_width || texture->h != expected_height ||
        texture->pitch < texture->w * 4) {
        return false;
    }
    Uint32 x = gpu_world_texture_staging.vfx_x +
        (Uint32)(asset % KOOKIE_GPU_VFX_ATLAS_COLUMNS) *
            KOOKIE_GPU_VFX_CELL_SIZE;
    Uint32 y = (Uint32)(asset / KOOKIE_GPU_VFX_ATLAS_COLUMNS) *
        KOOKIE_GPU_VFX_CELL_SIZE;
    if (x >= gpu_world_texture_staging.width ||
        y >= gpu_world_texture_staging.height ||
        (Uint32)texture->w >
            gpu_world_texture_staging.width - x ||
        (Uint32)texture->h >
            gpu_world_texture_staging.height - y) {
        return false;
    }
    for (int row = 0; row < texture->h; row += 1) {
        size_t destination = (size_t)(y + (Uint32)row) *
            (size_t)gpu_world_texture_staging.width + (size_t)x;
        const Uint8 *source =
            (const Uint8 *)texture->pixels +
            (size_t)row * (size_t)texture->pitch;
        memcpy(
            pixels + destination * 4u,
            source,
            (size_t)texture->w * 4u);
    }
    return true;
}

static SDL_Surface *kookie_gpu_load_model_texture(int model) {
    KookieGpuModelTextureStaging *staging =
        kookie_gpu_model_texture_staging_for(model);
    Uint32 x = 0;
    Uint32 y = 0;
    Uint32 width = 0;
    Uint32 height = 0;
    bool embedded = false;
    if (staging == NULL ||
        !kookie_gpu_model_texture_region(
            model, &x, &y, &width, &height, &embedded) ||
        !embedded) {
        return NULL;
    }
    const unsigned char *encoded = staging->bytes;
    size_t encoded_length = staging->length;
    if (!staging->committed || encoded == NULL || encoded_length == 0) {
        return NULL;
    }
    SDL_IOStream *input = SDL_IOFromConstMem(encoded, encoded_length);
    if (input == NULL) {
        return NULL;
    }
    SDL_Surface *decoded = SDL_LoadPNG_IO(input, true);
    if (decoded == NULL) {
        return NULL;
    }
    SDL_Surface *rgba = SDL_ConvertSurface(
        decoded, SDL_PIXELFORMAT_RGBA32);
    if (rgba == NULL) {
        SDL_DestroySurface(decoded);
        return NULL;
    }
    if (rgba->w <= 0 || rgba->h <= 0 ||
        (Uint32)rgba->w != width || (Uint32)rgba->h != height ||
        rgba->pitch < rgba->w * 4) {
        if (rgba != decoded) {
            SDL_DestroySurface(decoded);
        }
        SDL_DestroySurface(rgba);
        return NULL;
    }
    if (rgba != decoded) {
        SDL_DestroySurface(decoded);
    }
    return rgba;
}

static bool kookie_gpu_copy_model_texture(
    Uint8 *pixels, size_t bytes, const SDL_Surface *texture, int model
) {
    Uint32 x = 0;
    Uint32 y = 0;
    Uint32 width = 0;
    Uint32 height = 0;
    bool embedded = false;
    if (pixels == NULL || texture == NULL ||
        !kookie_gpu_model_texture_region(
            model, &x, &y, &width, &height, &embedded) ||
        !embedded || texture->w <= 0 || texture->h <= 0 ||
        texture->pitch < texture->w * 4 ||
        (Uint32)texture->w != width || (Uint32)texture->h != height ||
        bytes != gpu_world_texture_staging.bytes) {
        return false;
    }
    for (int row = 0; row < texture->h; row += 1) {
        size_t destination = (size_t)(y + (Uint32)row) *
            (size_t)gpu_world_texture_layout.width + (size_t)x;
        const Uint8 *source =
            (const Uint8 *)texture->pixels +
            (size_t)row * (size_t)texture->pitch;
        memcpy(
            pixels + destination * 4u,
            source,
            (size_t)texture->w * 4u);
    }
    return true;
}

static bool kookie_gpu_copy_world_texture(
    Uint8 *pixels, size_t bytes,
    const SDL_Surface *goose_texture, const SDL_Surface *cat_texture,
    SDL_Surface *const *vfx_textures
) {
    if (pixels == NULL) {
        return false;
    }
    if (!gpu_world_texture_staging.committed) {
        if ((gpu_world_scene.committed && gpu_world_scene.count > 0) ||
            goose_texture != NULL || cat_texture != NULL) {
            return false;
        }
        if (vfx_textures != NULL) {
            for (int index = 0; index < KOOKIE_GPU_VFX_SURFACE_COUNT;
                 index += 1) {
                if (vfx_textures[index] != NULL) { return false; }
            }
        }
        memset(pixels, 0, bytes);
        return true;
    }
    if (bytes != gpu_world_texture_staging.bytes) {
        return false;
    }
    memcpy(pixels, gpu_world_texture_staging.pixels, bytes);
    if (goose_texture != NULL &&
        !kookie_gpu_copy_model_texture(pixels, bytes, goose_texture, 1)) {
        return false;
    }
    if (cat_texture != NULL &&
        !kookie_gpu_copy_model_texture(pixels, bytes, cat_texture, 2)) {
        return false;
    }
    if (vfx_textures != NULL) {
        for (int index = 0; index < KOOKIE_GPU_VFX_SURFACE_COUNT;
             index += 1) {
            if (vfx_textures[index] != NULL &&
                !kookie_gpu_copy_vfx_texture(
                    pixels, bytes, vfx_textures[index], index)) {
                return false;
            }
        }
    }
    return true;
}
static bool kookie_gpu_vertex_buffer_size(
    int vertex_count, size_t components, Uint32 *size
) {
    if (vertex_count < 0 || components == 0 || size == NULL ||
        (size_t)(vertex_count > 0 ? vertex_count : 1) >
            SIZE_MAX / components ||
        (size_t)(vertex_count > 0 ? vertex_count : 1) * components >
            SIZE_MAX / sizeof(float)) {
        return false;
    }
    size_t values = (size_t)(vertex_count > 0 ? vertex_count : 1) *
        components;
    size_t bytes = values * sizeof(float);
    if (bytes > UINT32_MAX) {
        return false;
    }
    *size = (Uint32)bytes;
    return true;
}

static bool kookie_gpu_resource_capacity(
    int required, int *capacity
) {
    if (required < 0 || capacity == NULL) {
        return false;
    }
    size_t target = required > 0 ? (size_t)required : 1u;
    if (!kookie_gpu_growth_target(target, &target) ||
        target > (size_t)INT_MAX) {
        return false;
    }
    *capacity = (int)target;
    return true;
}

static bool kookie_gpu_prepare_resources(
    SDL_GPUDevice *device,
    SDL_GPUTextureFormat target_format
) {
    bool success = false;
    SDL_GPUTransferBuffer *transfer = NULL;
    SDL_GPUCommandBuffer *command_buffer = NULL;
    SDL_Surface *goose_texture = NULL;
    SDL_Surface *cat_texture = NULL;
    SDL_Surface *vfx_textures[KOOKIE_GPU_VFX_SURFACE_COUNT] = {0};
    if (!kookie_gpu_prepare_world_texture_layout()) {
        return false;
    }
    int required_world_vertices =
        gpu_world_scene.committed ? gpu_world_scene.count : 0;
    if (gpu_resources.ready && gpu_resources.device == device &&
        gpu_resources.target_format == target_format &&
        gpu_resources.world_vertex_capacity >= required_world_vertices) {
        return true;
    }
    if (gpu_resources.ready) {
        kookie_gpu_release_resources(gpu_resources.device);
    }
    int world_vertex_capacity = 0;
    if (!kookie_gpu_resource_capacity(
            required_world_vertices, &world_vertex_capacity)) {
        return false;
    }
    Uint32 world_vertex_buffer_size = 0;
    if (!kookie_gpu_vertex_buffer_size(
            world_vertex_capacity, 5, &world_vertex_buffer_size)) {
        return false;
    }

    gpu_resources.device = device;
    gpu_resources.target_format = target_format;
    gpu_resources.world_vertex_capacity = world_vertex_capacity;
    gpu_resources.world_texture_width = gpu_world_texture_layout.width;
    gpu_resources.world_texture_height = gpu_world_texture_layout.height;
    gpu_resources.cat_texture_x = gpu_world_texture_layout.cat_x;
    gpu_resources.cat_texture_y = gpu_world_texture_layout.cat_y;
    gpu_resources.cat_texture_width = gpu_world_texture_layout.cat_width;
    gpu_resources.cat_texture_height = gpu_world_texture_layout.cat_height;
    gpu_resources.ready = true;
    Uint8 *vertex_code = NULL;
    Uint8 *fragment_code = NULL;
    Uint8 *world_vertex_code = NULL;
    Uint8 *world_fragment_code = NULL;
    size_t vertex_size = 0;
    size_t fragment_size = 0;
    size_t world_vertex_size = 0;
    size_t world_fragment_size = 0;
    const KookieShaderMetadata *vertex_metadata =
        kookie_shader_metadata_find("g0_triangle.vert");
    const KookieShaderMetadata *world_metadata =
        kookie_shader_metadata_find("g6_world.vert");
    const KookieShaderMetadata *fragment_metadata =
        kookie_shader_metadata_find("g0_triangle.frag");
    const KookieShaderMetadata *world_fragment_metadata =
        kookie_shader_metadata_find("g6_world.frag");
    if (vertex_metadata == NULL ||
        world_metadata == NULL || fragment_metadata == NULL ||
        world_fragment_metadata == NULL ||
        strcmp(vertex_metadata->stage, "vertex") != 0 ||
        strcmp(world_metadata->stage, "vertex") != 0 ||
        strcmp(fragment_metadata->stage, "fragment") != 0 ||
        strcmp(world_fragment_metadata->stage, "fragment") != 0) {
        fprintf(stderr,
            "KOOKIE gpu_prepare shader manifest is incomplete or invalid\n");
        goto cleanup;
    }


    goose_texture = kookie_gpu_load_model_texture(1);
    cat_texture = kookie_gpu_load_model_texture(2);
    if ((gpu_world_texture_layout.goose_embedded &&
            goose_texture == NULL) ||
        (gpu_world_texture_layout.cat_embedded &&
            cat_texture == NULL)) {
        goto cleanup;
    }
    if (gpu_world_texture_layout.vfx_x > 0u) {
        for (int index = 0; index < KOOKIE_GPU_VFX_SURFACE_COUNT;
             index += 1) {
            vfx_textures[index] = kookie_gpu_load_vfx_texture(index);
            if (vfx_textures[index] == NULL) {
                fprintf(stderr,
                    "KOOKIE gpu_prepare VFX asset %d load failed\n", index);
                goto cleanup;
            }
        }
    }

    SDL_GPUShaderFormat shader_format =
        kookie_gpu_shader_format(device);
    if (shader_format == SDL_GPU_SHADERFORMAT_INVALID) {
        fprintf(stderr, "KOOKIE gpu_prepare no supported shader format: %s\n",
            SDL_GetError());
        goto cleanup;
    }
    if (!read_shader_binary(
            "g0_triangle.vert",
            shader_format,
            &vertex_code,
            &vertex_size) ||
        !read_shader_binary(
            "g6_world.vert",
            shader_format,
            &world_vertex_code,
            &world_vertex_size) ||
        !read_shader_binary(
            "g0_triangle.frag",
            shader_format,
            &fragment_code,
            &fragment_size) ||
        !read_shader_binary(
            "g6_world.frag",
            shader_format,
            &world_fragment_code,
            &world_fragment_size)) {
        fprintf(stderr, "KOOKIE gpu_prepare shader binary load failed: %s\n",
            SDL_GetError());
        goto cleanup;
    }

    SDL_GPUShaderCreateInfo vertex_info = {0};
    vertex_info.code_size = vertex_size;
    vertex_info.code = vertex_code;
    vertex_info.entrypoint = vertex_metadata->entrypoint;
    vertex_info.format = shader_format;
    vertex_info.stage = SDL_GPU_SHADERSTAGE_VERTEX;
    vertex_info.num_samplers = vertex_metadata->num_samplers;
    vertex_info.num_storage_textures = vertex_metadata->num_storage_textures;
    vertex_info.num_storage_buffers = vertex_metadata->num_storage_buffers;
    vertex_info.num_uniform_buffers = vertex_metadata->num_uniform_buffers;
    gpu_resources.vertex_shader = SDL_CreateGPUShader(device, &vertex_info);
    if (gpu_resources.vertex_shader == NULL) {
        fprintf(stderr, "KOOKIE gpu_prepare menu vertex shader failed: %s\n",
            SDL_GetError());
        goto cleanup;
    }
    SDL_GPUShaderCreateInfo world_shader_info = vertex_info;
    world_shader_info.code_size = world_vertex_size;
    world_shader_info.code = world_vertex_code;
    world_shader_info.entrypoint = world_metadata->entrypoint;
    world_shader_info.num_samplers = world_metadata->num_samplers;
    world_shader_info.num_storage_textures =
        world_metadata->num_storage_textures;
    world_shader_info.num_storage_buffers =
        world_metadata->num_storage_buffers;
    world_shader_info.num_uniform_buffers =
        world_metadata->num_uniform_buffers;
    gpu_resources.world_vertex_shader =
        SDL_CreateGPUShader(device, &world_shader_info);
    if (gpu_resources.world_vertex_shader == NULL) {
        fprintf(stderr, "KOOKIE gpu_prepare world vertex shader failed: %s\n",
            SDL_GetError());
        goto cleanup;
    }

    SDL_GPUShaderCreateInfo fragment_info = {0};
    fragment_info.code_size = fragment_size;
    fragment_info.code = fragment_code;
    fragment_info.entrypoint = fragment_metadata->entrypoint;
    fragment_info.format = shader_format;
    fragment_info.stage = SDL_GPU_SHADERSTAGE_FRAGMENT;
    fragment_info.num_samplers = fragment_metadata->num_samplers;
    fragment_info.num_storage_textures =
        fragment_metadata->num_storage_textures;
    fragment_info.num_storage_buffers =
        fragment_metadata->num_storage_buffers;
    fragment_info.num_uniform_buffers =
        fragment_metadata->num_uniform_buffers;
    gpu_resources.fragment_shader =
        SDL_CreateGPUShader(device, &fragment_info);
    if (gpu_resources.fragment_shader == NULL) {
        fprintf(stderr, "KOOKIE gpu_prepare fragment shader failed: %s\n",
            SDL_GetError());
        goto cleanup;
    }
    SDL_GPUShaderCreateInfo world_fragment_info = fragment_info;
    world_fragment_info.code_size = world_fragment_size;
    world_fragment_info.code = world_fragment_code;
    world_fragment_info.entrypoint = world_fragment_metadata->entrypoint;
    world_fragment_info.num_samplers = world_fragment_metadata->num_samplers;
    world_fragment_info.num_storage_textures =
        world_fragment_metadata->num_storage_textures;
    world_fragment_info.num_storage_buffers =
        world_fragment_metadata->num_storage_buffers;
    world_fragment_info.num_uniform_buffers =
        world_fragment_metadata->num_uniform_buffers;
    gpu_resources.world_fragment_shader =
        SDL_CreateGPUShader(device, &world_fragment_info);
    if (gpu_resources.world_fragment_shader == NULL) {
        fprintf(stderr, "KOOKIE gpu_prepare world fragment shader failed: %s\n",
            SDL_GetError());
        goto cleanup;
    }

    SDL_GPUTextureCreateInfo texture_info = {0};
    texture_info.type = SDL_GPU_TEXTURETYPE_2D;
    texture_info.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    texture_info.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;
    texture_info.width = KOOKIE_GPU_UI_TEXTURE_WIDTH;
    texture_info.height = KOOKIE_GPU_UI_TEXTURE_HEIGHT;
    texture_info.layer_count_or_depth = 1;
    texture_info.num_levels = 1;
    texture_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    gpu_resources.texture = SDL_CreateGPUTexture(device, &texture_info);
    if (gpu_resources.texture == NULL) {
        goto cleanup;
    }
    SDL_GPUTextureCreateInfo world_texture_info = texture_info;
    world_texture_info.width = gpu_resources.world_texture_width;
    world_texture_info.height = gpu_resources.world_texture_height;
    gpu_resources.world_texture =
        SDL_CreateGPUTexture(device, &world_texture_info);
    if (gpu_resources.world_texture == NULL) {
        goto cleanup;
    }

    SDL_GPUBufferCreateInfo mesh_vertex_info = {0};
    mesh_vertex_info.usage = SDL_GPU_BUFFERUSAGE_VERTEX;
    mesh_vertex_info.size = 96;
    gpu_resources.vertex_buffer = SDL_CreateGPUBuffer(device, &mesh_vertex_info);
    if (gpu_resources.vertex_buffer == NULL) {
        goto cleanup;
    }

    SDL_GPUBufferCreateInfo world_vertex_info = {0};
    world_vertex_info.usage = SDL_GPU_BUFFERUSAGE_VERTEX;
    world_vertex_info.size = world_vertex_buffer_size;
    gpu_resources.world_vertex_buffer =
        SDL_CreateGPUBuffer(device, &world_vertex_info);
    if (gpu_resources.world_vertex_buffer == NULL) {
        goto cleanup;
    }

    SDL_GPUBufferCreateInfo mesh_index_info = {0};
    mesh_index_info.usage = SDL_GPU_BUFFERUSAGE_INDEX;
    mesh_index_info.size = 12;
    gpu_resources.index_buffer = SDL_CreateGPUBuffer(device, &mesh_index_info);
    if (gpu_resources.index_buffer == NULL) {
        goto cleanup;
    }

    SDL_GPUTransferBufferCreateInfo ui_transfer_info = {0};
    ui_transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    ui_transfer_info.size = KOOKIE_GPU_UI_TEXTURE_WIDTH *
        KOOKIE_GPU_UI_TEXTURE_HEIGHT * 4u;
    gpu_resources.ui_transfer =
        SDL_CreateGPUTransferBuffer(device, &ui_transfer_info);
    if (gpu_resources.ui_transfer == NULL) {
        goto cleanup;
    }
    SDL_GPUTransferBufferCreateInfo ui_quad_transfer_info = {0};
    ui_quad_transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    ui_quad_transfer_info.size = 96u;
    gpu_resources.ui_quad_transfer =
        SDL_CreateGPUTransferBuffer(device, &ui_quad_transfer_info);
    if (gpu_resources.ui_quad_transfer == NULL) {
        goto cleanup;
    }
    SDL_GPUTransferBufferCreateInfo world_transfer_info = {0};
    world_transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    world_transfer_info.size = world_vertex_buffer_size;
    gpu_resources.world_transfer =
        SDL_CreateGPUTransferBuffer(device, &world_transfer_info);
    if (gpu_resources.world_transfer == NULL) {
        goto cleanup;
    }

    SDL_GPUSamplerCreateInfo sampler_info = {0};
    sampler_info.min_filter = SDL_GPU_FILTER_NEAREST;
    sampler_info.mag_filter = SDL_GPU_FILTER_NEAREST;
    sampler_info.mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
    sampler_info.address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    sampler_info.address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    sampler_info.address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    sampler_info.max_lod = 1.0f;
    gpu_resources.sampler = SDL_CreateGPUSampler(device, &sampler_info);
    if (gpu_resources.sampler == NULL) {
        goto cleanup;
    }

    SDL_GPUColorTargetDescription color_target = {0};
    color_target.format = target_format;
    color_target.blend_state.src_color_blendfactor =
        SDL_GPU_BLENDFACTOR_SRC_ALPHA;
    color_target.blend_state.dst_color_blendfactor =
        SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    color_target.blend_state.color_blend_op = SDL_GPU_BLENDOP_ADD;
    color_target.blend_state.src_alpha_blendfactor =
        SDL_GPU_BLENDFACTOR_ONE;
    color_target.blend_state.dst_alpha_blendfactor =
        SDL_GPU_BLENDFACTOR_ONE_MINUS_SRC_ALPHA;
    color_target.blend_state.alpha_blend_op = SDL_GPU_BLENDOP_ADD;
    color_target.blend_state.enable_blend = true;
    SDL_GPUGraphicsPipelineCreateInfo pipeline_info = {0};
    pipeline_info.vertex_shader = gpu_resources.vertex_shader;
    pipeline_info.fragment_shader = gpu_resources.fragment_shader;
    pipeline_info.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
    SDL_GPUVertexBufferDescription vertex_description = {0};
    vertex_description.slot = 0;
    vertex_description.pitch = 16;
    vertex_description.input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
    SDL_GPUVertexAttribute vertex_attributes[2] = {0};
    vertex_attributes[0].location = 0;
    vertex_attributes[0].buffer_slot = 0;
    vertex_attributes[0].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
    vertex_attributes[0].offset = 0;
    vertex_attributes[1].location = 1;
    vertex_attributes[1].buffer_slot = 0;
    vertex_attributes[1].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
    vertex_attributes[1].offset = 8;
    pipeline_info.vertex_input_state.vertex_buffer_descriptions = &vertex_description;
    pipeline_info.vertex_input_state.num_vertex_buffers = 1;
    pipeline_info.vertex_input_state.vertex_attributes = vertex_attributes;
    pipeline_info.vertex_input_state.num_vertex_attributes = 2;
    pipeline_info.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
    pipeline_info.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
    pipeline_info.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
    pipeline_info.rasterizer_state.enable_depth_clip = true;
    pipeline_info.multisample_state.sample_count = SDL_GPU_SAMPLECOUNT_1;
    pipeline_info.target_info.color_target_descriptions = &color_target;
    pipeline_info.target_info.num_color_targets = 1;
    gpu_resources.pipeline = SDL_CreateGPUGraphicsPipeline(device, &pipeline_info);
    if (gpu_resources.pipeline == NULL) {
        fprintf(stderr, "KOOKIE gpu_prepare menu pipeline failed: %s\n",
            SDL_GetError());
        goto cleanup;
    }
    pipeline_info.depth_stencil_state.compare_op = SDL_GPU_COMPAREOP_LESS;
    pipeline_info.depth_stencil_state.enable_depth_test = true;
    pipeline_info.depth_stencil_state.enable_depth_write = true;
    pipeline_info.target_info.depth_stencil_format =
        SDL_GPU_TEXTUREFORMAT_D16_UNORM;
    pipeline_info.target_info.has_depth_stencil_target = true;
    SDL_GPUVertexBufferDescription world_vertex_description = {0};
    world_vertex_description.slot = 0;
    world_vertex_description.pitch = 5u * (Uint32)sizeof(float);
    world_vertex_description.input_rate = SDL_GPU_VERTEXINPUTRATE_VERTEX;
    SDL_GPUVertexAttribute world_vertex_attributes[2] = {0};
    world_vertex_attributes[0].location = 0;
    world_vertex_attributes[0].buffer_slot = 0;
    world_vertex_attributes[0].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3;
    world_vertex_attributes[0].offset = 0;
    world_vertex_attributes[1].location = 1;
    world_vertex_attributes[1].buffer_slot = 0;
    world_vertex_attributes[1].format = SDL_GPU_VERTEXELEMENTFORMAT_FLOAT2;
    world_vertex_attributes[1].offset = 3u * (Uint32)sizeof(float);
    pipeline_info.vertex_shader = gpu_resources.world_vertex_shader;
    pipeline_info.fragment_shader = gpu_resources.world_fragment_shader;
    pipeline_info.vertex_input_state.vertex_buffer_descriptions =
        &world_vertex_description;
    pipeline_info.vertex_input_state.vertex_attributes =
        world_vertex_attributes;
    pipeline_info.vertex_input_state.num_vertex_attributes = 2;
    gpu_resources.world_pipeline =
        SDL_CreateGPUGraphicsPipeline(device, &pipeline_info);
    if (gpu_resources.world_pipeline == NULL) {
        fprintf(stderr, "KOOKIE gpu_prepare world pipeline failed: %s\n",
            SDL_GetError());
        goto cleanup;
    }

    const Uint32 ui_texture_bytes =
        KOOKIE_GPU_UI_TEXTURE_WIDTH * KOOKIE_GPU_UI_TEXTURE_HEIGHT * 4u;
    if ((size_t)gpu_resources.world_texture_width >
            SIZE_MAX / (size_t)gpu_resources.world_texture_height) {
        goto cleanup;
    }
    size_t world_texture_pixels = (size_t)gpu_resources.world_texture_width *
        (size_t)gpu_resources.world_texture_height;
    if (world_texture_pixels > SIZE_MAX / 4u ||
        world_texture_pixels * 4u > UINT32_MAX) {
        goto cleanup;
    }
    const Uint32 world_texture_bytes = (Uint32)(world_texture_pixels * 4u);
    const Uint32 world_texture_offset = ui_texture_bytes;
    if (world_texture_bytes > UINT32_MAX - world_texture_offset) {
        goto cleanup;
    }
    const Uint32 vertex_offset = world_texture_offset + world_texture_bytes;
    if (96u > UINT32_MAX - vertex_offset) {
        goto cleanup;
    }
    const Uint32 index_offset = vertex_offset + 96u;
    if (12u > UINT32_MAX - index_offset) {
        goto cleanup;
    }
    SDL_GPUTransferBufferCreateInfo transfer_info = {0};
    transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    transfer_info.size = index_offset + 12u;
    transfer = SDL_CreateGPUTransferBuffer(device, &transfer_info);
    if (transfer == NULL) {
        goto cleanup;
    }
    Uint8 *pixels = (Uint8 *)SDL_MapGPUTransferBuffer(device, transfer, false);
    if (pixels == NULL) {
        goto cleanup;
    }
    const float vertices[24] = {
        -1.0f, -1.0f, 0.0f, 1.0f,
         1.0f, -1.0f, 1.0f, 1.0f,
         1.0f,  1.0f, 1.0f, 0.0f,
        -1.0f, -1.0f, 0.0f, 1.0f,
         1.0f,  1.0f, 1.0f, 0.0f,
        -1.0f,  1.0f, 0.0f, 0.0f
    };
    const Uint16 indices[6] = {0, 1, 2, 3, 4, 5};
    memset(pixels, 0, ui_texture_bytes);
    if (!kookie_gpu_copy_world_texture(
            pixels + world_texture_offset,
            world_texture_bytes,
            goose_texture, cat_texture, vfx_textures)) {
        SDL_UnmapGPUTransferBuffer(device, transfer);
        goto cleanup;
    }
    memcpy(pixels + vertex_offset, vertices, sizeof(vertices));
    memcpy(pixels + index_offset, indices, sizeof(indices));
    SDL_UnmapGPUTransferBuffer(device, transfer);

    command_buffer = SDL_AcquireGPUCommandBuffer(device);
    if (command_buffer == NULL) {
        goto cleanup;
    }
    SDL_GPUCopyPass *copy_pass = SDL_BeginGPUCopyPass(command_buffer);
    if (copy_pass == NULL) {
        goto cleanup;
    }
    SDL_GPUTextureTransferInfo source = {0};
    source.transfer_buffer = transfer;
    SDL_GPUTextureRegion destination = {0};
    destination.texture = gpu_resources.texture;
    destination.w = KOOKIE_GPU_UI_TEXTURE_WIDTH;
    destination.h = KOOKIE_GPU_UI_TEXTURE_HEIGHT;
    destination.d = 1;
    SDL_UploadToGPUTexture(copy_pass, &source, &destination, false);
    SDL_GPUTextureTransferInfo world_source = source;
    world_source.offset = world_texture_offset;
    SDL_GPUTextureRegion world_destination = {0};
    world_destination.texture = gpu_resources.world_texture;
    world_destination.w = gpu_resources.world_texture_width;
    world_destination.h = gpu_resources.world_texture_height;
    world_destination.d = 1;
    SDL_UploadToGPUTexture(
        copy_pass, &world_source, &world_destination, false);
    SDL_GPUTransferBufferLocation vertex_source = {0};
    vertex_source.transfer_buffer = transfer;
    vertex_source.offset = vertex_offset;
    SDL_GPUBufferRegion vertex_destination = {0};
    vertex_destination.buffer = gpu_resources.vertex_buffer;
    vertex_destination.size = 96;
    SDL_UploadToGPUBuffer(copy_pass, &vertex_source, &vertex_destination, false);
    SDL_GPUTransferBufferLocation index_source = {0};
    index_source.transfer_buffer = transfer;
    index_source.offset = index_offset;
    SDL_GPUBufferRegion index_destination = {0};
    index_destination.buffer = gpu_resources.index_buffer;
    index_destination.size = 12;
    SDL_UploadToGPUBuffer(copy_pass, &index_source, &index_destination, false);
    SDL_EndGPUCopyPass(copy_pass);
    if (!kookie_gpu_submit_and_wait_fence(device, command_buffer)) {
        command_buffer = NULL;
        goto cleanup;
    }
    command_buffer = NULL;
    success = true;

cleanup:
    for (int index = 0; index < KOOKIE_GPU_VFX_SURFACE_COUNT;
         index += 1) {
        if (vfx_textures[index] != NULL) {
            SDL_DestroySurface(vfx_textures[index]);
        }
    }
    if (goose_texture != NULL) {
        SDL_DestroySurface(goose_texture);
    }
    if (cat_texture != NULL) {
        SDL_DestroySurface(cat_texture);
    }
    if (command_buffer != NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
    }
    if (transfer != NULL) {
        SDL_ReleaseGPUTransferBuffer(device, transfer);
    }
    free(fragment_code);
    free(world_vertex_code);
    free(world_fragment_code);
    free(vertex_code);
    if (!success) {
        kookie_gpu_release_resources(device);
    }
    return success;
}
static bool kookie_gpu_ensure_depth_texture(
    SDL_GPUDevice *device, Uint32 width, Uint32 height
) {
    if (gpu_resources.depth_texture != NULL &&
        gpu_resources.depth_width == width &&
        gpu_resources.depth_height == height) {
        return true;
    }
    if (gpu_resources.depth_texture != NULL) {
        if (!kookie_gpu_wait_scene_fences(device)) {
            return false;
        }
        SDL_ReleaseGPUTexture(device, gpu_resources.depth_texture);
        gpu_resources.depth_texture = NULL;
        gpu_resources.depth_width = 0;
        gpu_resources.depth_height = 0;
    }
    SDL_GPUTextureCreateInfo depth_info = {0};
    depth_info.type = SDL_GPU_TEXTURETYPE_2D;
    depth_info.format = SDL_GPU_TEXTUREFORMAT_D16_UNORM;
    depth_info.usage = SDL_GPU_TEXTUREUSAGE_DEPTH_STENCIL_TARGET;
    depth_info.width = width;
    depth_info.height = height;
    depth_info.layer_count_or_depth = 1;
    depth_info.num_levels = 1;
    depth_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    gpu_resources.depth_texture = SDL_CreateGPUTexture(device, &depth_info);
    if (gpu_resources.depth_texture == NULL) {
        fprintf(stderr, "KOOKIE gpu depth texture failed: %s\n",
            SDL_GetError());
        return false;
    }
    gpu_resources.depth_width = width;
    gpu_resources.depth_height = height;
    return true;
}

int kookie_gpu_scene_capacity(void) {
    size_t capacity = gpu_reload.pending_generation != 0
        ? gpu_pending_scene.capacity : gpu_scene.capacity;
    return capacity > (size_t)INT_MAX ? INT_MAX : (int)capacity;
}

int kookie_gpu_scene_count(void) {
    if (gpu_reload.pending_generation != 0) {
        return gpu_pending_scene.committed ? gpu_pending_scene.count : 0;
    }
    return gpu_scene.committed ? gpu_scene.count : 0;
}

int kookie_gpu_scene_instances(void) {
    int count = kookie_gpu_scene_count();
    return count > 0 && count % 3 == 0 ? count / 3 : 0;
}

int kookie_gpu_scene_draw_calls(void) {
    return last_gpu_scene_draw_calls;
}

int kookie_gpu_scene_batch_calls(void) {
    return gpu_scene_batch_calls;
}

int kookie_gpu_scene_scalar_calls(void) {
    return gpu_scene_scalar_calls;
}

bool kookie_gpu_reload_stage(int generation, int product_checksum) {
    if (gpu_slot.device == NULL || gpu_scene.open || gpu_pending_scene.open ||
        generation <= gpu_reload.active_generation || generation > 1000000 ||
        product_checksum <= 0 || product_checksum > 1000002 ||
        gpu_reload.pending_generation != 0) {
        return false;
    }
    kookie_gpu_scene_release(&gpu_pending_scene);
    gpu_reload.pending_generation = generation;
    gpu_reload.pending_checksum = product_checksum;
    gpu_reload.scene_generation = 0;
    gpu_reload.pending_scene_committed = false;
    return true;
}

bool kookie_gpu_reload_cancel(int generation) {
    if (gpu_reload.pending_generation != generation) {
        return false;
    }
    kookie_gpu_scene_release(&gpu_pending_scene);
    gpu_reload.pending_generation = 0;
    gpu_reload.pending_checksum = 0;
    gpu_reload.scene_generation = 0;
    gpu_reload.pending_scene_committed = false;
    return true;
}

int kookie_gpu_reload_active_generation(void) {
    return gpu_reload.active_generation;
}

int kookie_gpu_reload_active_checksum(void) {
    return gpu_reload.active_checksum;
}

int kookie_gpu_reload_pending_generation(void) {
    return gpu_reload.pending_generation;
}

int kookie_gpu_reload_retired_generation(void) {
    return gpu_reload.retired_generation;
}

int kookie_gpu_reload_completed_fence(void) {
    return gpu_reload.completed_fence;
}

static bool kookie_gpu_pending_scene_ready(void) {
    return gpu_reload.pending_generation != 0 &&
        gpu_reload.pending_scene_committed &&
        gpu_reload.scene_generation == gpu_reload.pending_generation;
}

static bool kookie_gpu_activate_pending_scene(void) {
    if (!kookie_gpu_pending_scene_ready() ||
        gpu_reload.completed_fence >= 1000000) {
        return false;
    }
    kookie_gpu_scene_release(&gpu_scene);
    gpu_scene = gpu_pending_scene;
    memset(&gpu_pending_scene, 0, sizeof(gpu_pending_scene));
    gpu_reload.completed_fence += 1;
    gpu_reload.retired_generation = gpu_reload.active_generation;
    gpu_reload.active_generation = gpu_reload.pending_generation;
    gpu_reload.active_checksum = gpu_reload.pending_checksum;
    gpu_reload.pending_generation = 0;
    gpu_reload.pending_checksum = 0;
    gpu_reload.pending_scene_committed = false;
    return true;
}

int kookie_gpu_world_capacity(void) {
    return gpu_world_scene.capacity > (size_t)INT_MAX
        ? INT_MAX : (int)gpu_world_scene.capacity;
}

int kookie_gpu_world_count(void) {
    return gpu_world_scene.committed ? gpu_world_scene.count : 0;
}

bool kookie_gpu_world_set_water_style(
    int style_id, int enabled, int time_ticks,
    int tint_r, int tint_g, int tint_b,
    int caustic_scale, int caustic_speed, int caustic_strength,
    int toon_base, int toon_contrast, int opacity
) {
    if (style_id < 0 || style_id >= KOOKIE_GPU_WATER_STYLE_COUNT ||
        (enabled != 0 && enabled != 1) || time_ticks < 0 ||
        tint_r < 0 || tint_r > 1000 ||
        tint_g < 0 || tint_g > 1000 ||
        tint_b < 0 || tint_b > 1000 ||
        caustic_scale <= 0 || caustic_speed < 0 ||
        caustic_strength < 0 || caustic_strength > 1000 ||
        toon_base < 0 || toon_base > 1000 ||
        toon_contrast < 0 || toon_contrast > 1000 ||
        opacity < 0 || opacity > 1000) {
        return false;
    }
    KookieWaterStyle *style = &gpu_water_styles[style_id];
    style->enabled = enabled;
    style->tint_r = tint_r;
    style->tint_g = tint_g;
    style->tint_b = tint_b;
    style->caustic_scale = caustic_scale;
    style->caustic_speed = caustic_speed;
    style->caustic_strength = caustic_strength;
    style->toon_base = toon_base;
    style->toon_contrast = toon_contrast;
    style->opacity = opacity;
    gpu_water_time_ticks = time_ticks;
    return true;
}

bool kookie_gpu_world_begin(int vertex_count) {
    if (!gpu_world_texture_staging.committed) {
        return false;
    }
    if (!kookie_gpu_prepare_world_texture_layout()) {
        return false;
    }
    if (vertex_count <= 0 || vertex_count % 3 != 0 ||
        gpu_world_scene.open ||
        !kookie_gpu_world_scene_reserve(
            &gpu_world_scene.vertices, &gpu_world_scene.capacity,
            vertex_count, 5)) {
        return false;
    }
    gpu_world_scene.expected = vertex_count;
    gpu_world_scene.count = 0;
    gpu_world_scene.open = true;
    gpu_world_scene.committed = false;
    gpu_world_scene.active = false;
    return true;
}

bool kookie_gpu_world_push_vertex_uv(
    int x, int y, int z, int texture_u, int texture_v
) {
    if (!gpu_world_scene.open ||
        gpu_world_scene.count >= gpu_world_scene.expected ||
        x < -1000 || x > 1000 ||
        y < -1000 || y > 1000 ||
        z < -1000 || z > 1000 ||
        texture_u < 0 || texture_u > KOOKIE_GPU_WORLD_TEXTURE_COORDINATE_LIMIT ||
        texture_v < 0 || texture_v > KOOKIE_GPU_WORLD_TEXTURE_COORDINATE_LIMIT) {
        return false;
    }
    size_t offset = (size_t)gpu_world_scene.count * 5u;
    gpu_world_scene.vertices[offset] = (float)x;
    gpu_world_scene.vertices[offset + 1u] = (float)y;
    gpu_world_scene.vertices[offset + 2u] = (float)z;
    gpu_world_scene.vertices[offset + 3u] =
        (float)texture_u / 1000000.0f;
    gpu_world_scene.vertices[offset + 4u] =
        (float)texture_v / 1000000.0f;
    gpu_world_scene.count += 1;
    return true;
}
bool kookie_gpu_model_texture_stage_begin(int model, int byte_length) {
    KookieGpuModelTextureStaging *staging =
        kookie_gpu_model_texture_staging_for(model);
    if (gpu_world_texture_layout.ready ||
        staging == NULL || staging->open ||
        byte_length <= 0 ||
        byte_length > (int)KOOKIE_GPU_MAX_MODEL_TEXTURE_BYTES) {
        return false;
    }
    kookie_gpu_model_texture_staging_release_one(staging);
    staging->bytes = (Uint8 *)malloc((size_t)byte_length);
    if (staging->bytes == NULL) {
        return false;
    }
    staging->length = (size_t)byte_length;
    staging->next_byte = 0;
    staging->open = true;
    staging->committed = false;
    return true;
}

bool kookie_gpu_model_texture_stage_byte(int model, int index, int value) {
    KookieGpuModelTextureStaging *staging =
        kookie_gpu_model_texture_staging_for(model);
    if (staging == NULL || !staging->open ||
        index < 0 || (size_t)index != staging->next_byte ||
        staging->next_byte >= staging->length ||
        value < 0 || value > 255) {
        return false;
    }
    staging->bytes[staging->next_byte] = (Uint8)value;
    staging->next_byte += 1;
    return true;
}

bool kookie_gpu_model_texture_stage_commit(int model) {
    KookieGpuModelTextureStaging *staging =
        kookie_gpu_model_texture_staging_for(model);
    if (staging == NULL || !staging->open ||
        staging->next_byte != staging->length) {
        return false;
    }
    staging->open = false;
    staging->committed = true;
    return true;
}

bool kookie_gpu_world_texture_stage_begin(
    int width, int height, int vfx_x,
    int goose_x, int goose_y, int goose_width, int goose_height,
    int cat_x, int cat_y, int cat_width, int cat_height
) {
    if (gpu_world_texture_layout.ready ||
        gpu_world_texture_staging.open ||
        width < 256 || height < 256 ||
        width > 4096 || height > 4096 ||
        vfx_x < 0 ||
        (vfx_x > 0 &&
            (vfx_x >= width ||
             KOOKIE_GPU_VFX_ATLAS_WIDTH > width - vfx_x ||
             height < KOOKIE_GPU_VFX_ATLAS_HEIGHT)) ||
        goose_x < 0 || goose_y < 0 ||
        goose_width < 0 || goose_height < 0 ||
        (goose_width == 0) != (goose_height == 0) ||
        (goose_width > 0 &&
            (goose_x >= width || goose_y >= height ||
             goose_width > width - goose_x ||
             goose_height > height - goose_y)) ||
        cat_x < 0 || cat_y < 0 ||
        cat_width < 0 || cat_height < 0 ||
        (cat_width == 0) != (cat_height == 0) ||
        (cat_width > 0 &&
            (cat_x >= width || cat_y >= height ||
             cat_width > width - cat_x ||
             cat_height > height - cat_y)) ||
        (size_t)width > SIZE_MAX / (size_t)height) {
        return false;
    }
    size_t pixels = (size_t)width * (size_t)height;
    if (pixels > 16777216u || pixels > SIZE_MAX / 4u) {
        return false;
    }
    kookie_gpu_world_texture_staging_release();
    gpu_world_texture_staging.pixels = (Uint8 *)malloc(pixels * 4u);
    if (gpu_world_texture_staging.pixels == NULL) {
        return false;
    }
    gpu_world_texture_staging.bytes = pixels * 4u;
    gpu_world_texture_staging.width = (Uint32)width;
    gpu_world_texture_staging.height = (Uint32)height;
    gpu_world_texture_staging.vfx_x = (Uint32)vfx_x;
    gpu_world_texture_staging.goose_x = (Uint32)goose_x;
    gpu_world_texture_staging.goose_y = (Uint32)goose_y;
    gpu_world_texture_staging.goose_width = (Uint32)goose_width;
    gpu_world_texture_staging.goose_height = (Uint32)goose_height;
    gpu_world_texture_staging.cat_x = (Uint32)cat_x;
    gpu_world_texture_staging.cat_y = (Uint32)cat_y;
    gpu_world_texture_staging.cat_width = (Uint32)cat_width;
    gpu_world_texture_staging.cat_height = (Uint32)cat_height;
    gpu_world_texture_staging.next_word = 0;
    gpu_world_texture_staging.open = true;
    gpu_world_texture_staging.committed = false;
    return true;
}

bool kookie_gpu_world_texture_stage_word(int index, int value) {
    if (!gpu_world_texture_staging.open ||
        index < 0 ||
        (size_t)index != gpu_world_texture_staging.next_word ||
        gpu_world_texture_staging.next_word >=
            gpu_world_texture_staging.bytes / 4u) {
        return false;
    }
    Uint32 packed = (Uint32)(uint32_t)value;
    size_t offset = gpu_world_texture_staging.next_word * 4u;
    gpu_world_texture_staging.pixels[offset] = (Uint8)(packed & 255u);
    gpu_world_texture_staging.pixels[offset + 1u] =
        (Uint8)((packed >> 8) & 255u);
    gpu_world_texture_staging.pixels[offset + 2u] =
        (Uint8)((packed >> 16) & 255u);
    gpu_world_texture_staging.pixels[offset + 3u] =
        (Uint8)((packed >> 24) & 255u);
    gpu_world_texture_staging.next_word += 1;
    return true;
}

bool kookie_gpu_world_texture_stage_commit(void) {
    if (!gpu_world_texture_staging.open ||
        gpu_world_texture_staging.next_word !=
            gpu_world_texture_staging.bytes / 4u) {
        return false;
    }
    gpu_world_texture_staging.open = false;
    gpu_world_texture_staging.committed = true;
    return true;
}

/*
 * GPU_WORLD_TEXTURE_V1 uses the world texture descriptor followed by a
 * tightly packed little-endian i32 pixel-word payload. The adapter copies
 * the payload before publishing the staging generation.
 */
bool kookie_gpu_world_texture_stage_batch_v1(
    const uint8_t *values, int32_t schema_version, int32_t byte_length,
    int32_t width, int32_t height, int32_t vfx_x,
    int32_t goose_x, int32_t goose_y, int32_t goose_width,
    int32_t goose_height, int32_t cat_x, int32_t cat_y,
    int32_t cat_width, int32_t cat_height, int64_t checksum
) {
    if (values == NULL || schema_version != 1 || byte_length <= 0 ||
        width <= 0 || height <= 0 || width > 4096 || height > 4096 ||
        (size_t)width > SIZE_MAX / (size_t)height ||
        (size_t)width * (size_t)height > 16777216u ||
        (size_t)width * (size_t)height > SIZE_MAX / 4u ||
        (size_t)byte_length !=
            (size_t)width * (size_t)height * 4u) {
        return false;
    }
    int64_t actual_checksum = 0;
    for (size_t offset = 0; offset < (size_t)byte_length; offset += 4u) {
        uint32_t encoded =
            ((uint32_t)values[offset]) |
            ((uint32_t)values[offset + 1u] << 8) |
            ((uint32_t)values[offset + 2u] << 16) |
            ((uint32_t)values[offset + 3u] << 24);
        actual_checksum += (int64_t)(int32_t)encoded;
    }
    if (actual_checksum != checksum ||
        !kookie_gpu_world_texture_stage_begin(
            width, height, vfx_x, goose_x, goose_y, goose_width,
            goose_height, cat_x, cat_y, cat_width, cat_height)) {
        return false;
    }
    memcpy(
        gpu_world_texture_staging.pixels, values,
        gpu_world_texture_staging.bytes);
    gpu_world_texture_staging.next_word =
        gpu_world_texture_staging.bytes / 4u;
    gpu_world_texture_staging.open = false;
    gpu_world_texture_staging.committed = true;
    return true;
}


bool kookie_gpu_world_commit(void) {
    if (!gpu_world_scene.open ||
        gpu_world_scene.count != gpu_world_scene.expected) {
        return false;
    }
    gpu_world_scene.open = false;
    gpu_world_scene.committed = true;
    return true;
}

bool kookie_gpu_world_camera_stage_begin(void) {
    if (gpu_world_camera_stage_open) {
        return false;
    }
    gpu_world_camera_stage_count = 0;
    gpu_world_camera_stage_open = true;
    gpu_world_camera_matrix_ready = false;
    return true;
}

bool kookie_gpu_world_camera_stage_word(int index, int value) {
    if (!gpu_world_camera_stage_open ||
        index < 0 || index != gpu_world_camera_stage_count ||
        index >= 16) {
        return false;
    }
    gpu_world_camera_matrix[index] = value;
    gpu_world_camera_stage_count += 1;
    return true;
}

bool kookie_gpu_world_camera_stage_commit(void) {
    if (!gpu_world_camera_stage_open ||
        gpu_world_camera_stage_count != 16) {
        return false;
    }
    gpu_world_camera_stage_open = false;
    gpu_world_camera_matrix_ready = true;
    return true;
}
bool kookie_gpu_render_set_passes(int world, int scene) {
    if ((world != 0 && world != 1) || (scene != 0 && scene != 1)) {
        return false;
    }
    gpu_render_world = world != 0;
    gpu_render_scene = scene != 0;
    gpu_render_plan_ready = true;
    return true;
}


static bool kookie_gpu_world_upload(
    SDL_GPUDevice *device, const KookieGpuWorldScene *scene
) {
    if (device == NULL || scene == NULL || !scene->committed ||
        gpu_resources.world_vertex_buffer == NULL ||
        gpu_resources.world_transfer == NULL) {
        return false;
    }
    float *vertices = (float *)SDL_MapGPUTransferBuffer(
        device, gpu_resources.world_transfer, true);
    if (vertices == NULL) {
        return false;
    }
    size_t byte_count = (size_t)scene->count * 5u * sizeof(float);
    memcpy(vertices, scene->vertices, byte_count);
    SDL_UnmapGPUTransferBuffer(device, gpu_resources.world_transfer);
    SDL_GPUCommandBuffer *command_buffer =
        SDL_AcquireGPUCommandBuffer(device);
    if (command_buffer == NULL) {
        return false;
    }
    SDL_GPUCopyPass *copy_pass = SDL_BeginGPUCopyPass(command_buffer);
    if (copy_pass == NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return false;
    }
    SDL_GPUTransferBufferLocation source = {0};
    source.transfer_buffer = gpu_resources.world_transfer;
    SDL_GPUBufferRegion destination = {0};
    destination.buffer = gpu_resources.world_vertex_buffer;
    destination.size = (Uint32)byte_count;
    SDL_UploadToGPUBuffer(copy_pass, &source, &destination, true);
    SDL_EndGPUCopyPass(copy_pass);
    return kookie_gpu_submit_and_wait_fence(device, command_buffer);
}

bool kookie_gpu_scene_begin(int vertex_count) {
    if (vertex_count < 0 || vertex_count % 3 != 0) {
        return false;
    }
    KookieGpuScene *scene = &gpu_scene;
    if (gpu_reload.pending_generation != 0) {
        if (gpu_pending_scene.open || gpu_pending_scene.committed) {
            return false;
        }
        scene = &gpu_pending_scene;
    } else if (gpu_scene.open) {
        return false;
    }
    if (vertex_count > 0 &&
        !kookie_gpu_scene_reserve_data(scene, vertex_count)) {
        return false;
    }
    scene->expected = vertex_count;
    scene->count = 0;
    gpu_scene_batch_calls = 0;
    gpu_scene_scalar_calls = 0;
    scene->text_count = 0;
    scene->text_codepoint_count = 0;
    scene->text_open_start = 0;
    scene->text_open = false;
    scene->open = true;
    scene->committed = false;
    scene->active = false;
    gpu_reload.scene_generation = gpu_reload.pending_generation != 0
        ? gpu_reload.pending_generation
        : gpu_reload.active_generation;
    return true;
}
bool kookie_gpu_scene_reserve_capacity(int vertex_capacity) {
    if (vertex_capacity <= 0 || gpu_reload.pending_generation != 0) {
        return false;
    }
    return kookie_gpu_scene_reserve_data(&gpu_scene, vertex_capacity);
}

static bool kookie_gpu_scene_push_vertex_internal(
    int resource, int x, int y, int depth, int u, int v
) {
    KookieGpuScene *scene = NULL;
    if (gpu_pending_scene.open) {
        scene = &gpu_pending_scene;
    } else if (gpu_scene.open) {
        scene = &gpu_scene;
    }
    if (scene == NULL || scene->count >= scene->expected ||
        resource <= 0 || x < -100 || x > 100 || y < -100 || y > 100 ||
        depth < 0 || depth > 100 || u < 0 || u > 100 || v < 0 || v > 100) {
        return false;
    }
    scene->ui_vertices[scene->count] = (KookieUiVertex){
        resource, x, y, depth, u, v
    };
    scene->count += 1;
    gpu_scene_scalar_calls += 1;
    return true;
}
static bool kookie_gpu_world_camera_matrix_floats(float out[16]) {
    if (out == NULL || !gpu_world_camera_matrix_ready) {
        return false;
    }
    for (int index = 0; index < 16; index += 1) {
        out[index] = (float)gpu_world_camera_matrix[index] / 1000000.0f;
    }
    return true;
}


bool kookie_gpu_scene_push_vertex_resource(
    int resource, int x, int y, int depth, int u, int v
) {
    return kookie_gpu_scene_push_vertex_internal(
        resource, x, y, depth, u, v);
}

static int32_t kookie_gpu_scene_batch_read_i32(
    const uint8_t *values, size_t offset
) {
    uint32_t encoded =
        ((uint32_t)values[offset]) |
        ((uint32_t)values[offset + 1] << 8) |
        ((uint32_t)values[offset + 2] << 16) |
        ((uint32_t)values[offset + 3] << 24);
    return (int32_t)encoded;
}

/*
 * GPU_SCENE_VERTEX_V1 uses the common descriptor: schemaVersion, byteLength,
 * vertexCount, stride, generation and checksum. The payload contains six
 * little-endian i32 values per vertex: resource, x, y, depth, u, v.
 */
bool kookie_gpu_scene_push_vertex_batch_v1(
    const uint8_t *values, int32_t schema_version, int32_t byte_length,
    int32_t vertex_count, int32_t stride, int32_t generation,
    int64_t checksum
) {
    if (values == NULL || schema_version != 1 || byte_length <= 0 ||
        vertex_count <= 0 || vertex_count > KOOKIE_GPU_MAX_SCENE_BATCH_VERTICES ||
        vertex_count > INT32_MAX / KOOKIE_GPU_SCENE_VERTEX_V1_STRIDE ||
        stride != KOOKIE_GPU_SCENE_VERTEX_V1_STRIDE ||
        generation <= 0 || generation != gpu_reload.scene_generation ||
        byte_length != vertex_count * KOOKIE_GPU_SCENE_VERTEX_V1_STRIDE) {
        return false;
    }
    KookieGpuScene *scene = NULL;
    if (gpu_pending_scene.open) {
        scene = &gpu_pending_scene;
    } else if (gpu_scene.open) {
        scene = &gpu_scene;
    }
    if (scene == NULL || scene->count < 0 ||
        vertex_count > scene->expected - scene->count) {
        return false;
    }
    int64_t actual_checksum = 0;
    for (int32_t index = 0; index < vertex_count; index += 1) {
        size_t offset = (size_t)index *
            (size_t)KOOKIE_GPU_SCENE_VERTEX_V1_STRIDE;
        int32_t resource = kookie_gpu_scene_batch_read_i32(values, offset);
        int32_t x = kookie_gpu_scene_batch_read_i32(values, offset + 4u);
        int32_t y = kookie_gpu_scene_batch_read_i32(values, offset + 8u);
        int32_t depth = kookie_gpu_scene_batch_read_i32(values, offset + 12u);
        int32_t u = kookie_gpu_scene_batch_read_i32(values, offset + 16u);
        int32_t v = kookie_gpu_scene_batch_read_i32(values, offset + 20u);
        if (resource <= 0 || x < -100 || x > 100 ||
            y < -100 || y > 100 || depth < 0 || depth > 100 ||
            u < 0 || u > 100 || v < 0 || v > 100) {
            return false;
        }
        actual_checksum += (int64_t)resource + (int64_t)x + (int64_t)y +
            (int64_t)depth + (int64_t)u + (int64_t)v;
    }
    if (actual_checksum != checksum) {
        return false;
    }
    for (int32_t index = 0; index < vertex_count; index += 1) {
        size_t offset = (size_t)index *
            (size_t)KOOKIE_GPU_SCENE_VERTEX_V1_STRIDE;
        scene->ui_vertices[scene->count + index] = (KookieUiVertex){
            kookie_gpu_scene_batch_read_i32(values, offset),
            kookie_gpu_scene_batch_read_i32(values, offset + 4u),
            kookie_gpu_scene_batch_read_i32(values, offset + 8u),
            kookie_gpu_scene_batch_read_i32(values, offset + 12u),
            kookie_gpu_scene_batch_read_i32(values, offset + 16u),
            kookie_gpu_scene_batch_read_i32(values, offset + 20u)
        };
    }
    scene->count += vertex_count;
    gpu_scene_batch_calls += 1;
    return true;
}

static KookieGpuScene *kookie_gpu_open_scene(void) {
    if (gpu_pending_scene.open) {
        return &gpu_pending_scene;
    }
    if (gpu_scene.open) {
        return &gpu_scene;
    }
    return NULL;
}

bool kookie_gpu_scene_text_run_begin(
    int font, int color, int left, int bottom, int scale
) {
    KookieGpuScene *scene = kookie_gpu_open_scene();
    if (scene == NULL || scene->text_open || font < 0 || font > 1 ||
        color < 0 || color > 4 || left < -100 || left > 100 ||
        bottom < -100 || bottom > 100 || scale <= 0 || scale > 100 ||
        !kookie_gpu_scene_reserve_text_runs(
            scene, (size_t)scene->text_count + 1u)) {
        return false;
    }
    size_t index = (size_t)scene->text_count;
    scene->text_runs[index] = (KookieUiTextRun){
        font, color, left, bottom, scale, NULL, 0
    };
    scene->text_run_starts[index] = (size_t)scene->text_codepoint_count;
    scene->text_open_start = scene->text_run_starts[index];
    scene->text_open = true;
    return true;
}

bool kookie_gpu_scene_text_codepoint(int codepoint) {
    KookieGpuScene *scene = kookie_gpu_open_scene();
    if (scene == NULL || !scene->text_open || codepoint < 0 ||
        codepoint > 0x10ffff ||
        !kookie_gpu_scene_reserve_codepoints(
            scene, (size_t)scene->text_codepoint_count + 1u)) {
        return false;
    }
    scene->text_codepoints[scene->text_codepoint_count] = (uint32_t)codepoint;
    scene->text_codepoint_count += 1;
    return true;
}

bool kookie_gpu_scene_text_run_commit(void) {
    KookieGpuScene *scene = kookie_gpu_open_scene();
    if (scene == NULL || !scene->text_open ||
        scene->text_codepoint_count <= (int)scene->text_open_start) {
        return false;
    }
    size_t index = (size_t)scene->text_count;
    scene->text_runs[index].codepoints =
        scene->text_codepoints + scene->text_open_start;
    scene->text_runs[index].codepoint_count =
        (size_t)scene->text_codepoint_count - scene->text_open_start;
    scene->text_count += 1;
    scene->text_open = false;
    return true;
}

bool kookie_gpu_scene_commit(void) {
    KookieGpuScene *scene = NULL;
    if (gpu_pending_scene.open) {
        scene = &gpu_pending_scene;
    } else if (gpu_scene.open) {
        scene = &gpu_scene;
    }
    if (scene == NULL || scene->text_open ||
        scene->count != scene->expected) {
        return false;
    }
    scene->open = false;
    scene->committed = true;
    if (scene == &gpu_pending_scene &&
        gpu_reload.pending_generation != 0 &&
        gpu_reload.scene_generation == gpu_reload.pending_generation) {
        gpu_reload.pending_scene_committed = true;
    }
    return true;
}




static bool kookie_gpu_upload_ui_texture(
    SDL_GPUCommandBuffer *command_buffer,
    const KookieGpuScene *scene,
    Uint32 width,
    Uint32 height
) {
    if (command_buffer == NULL || scene == NULL || !scene->committed ||
        width == 0 || height == 0 ||
        width > KOOKIE_GPU_UI_TEXTURE_WIDTH ||
        height > KOOKIE_GPU_UI_TEXTURE_HEIGHT ||
        gpu_resources.ui_transfer == NULL ||
        gpu_resources.ui_quad_transfer == NULL) {
        return false;
    }
    if (gpu_ui_renderer == NULL) {
        gpu_ui_renderer = kookie_ui_renderer_create();
        if (gpu_ui_renderer == NULL) {
            return false;
        }
    }
    const uint8_t *pixels = NULL;
    size_t pixel_bytes = 0;
    if (!kookie_ui_renderer_render(
            gpu_ui_renderer, scene->ui_vertices, (size_t)scene->count,
            scene->text_runs, (size_t)scene->text_count,
            width, height, &pixels, &pixel_bytes)) {
        return false;
    }
    size_t row_bytes = (size_t)width * 4u;
    size_t transfer_row_bytes =
        (size_t)KOOKIE_GPU_UI_TEXTURE_WIDTH * 4u;
    if (pixel_bytes < row_bytes * (size_t)height) {
        return false;
    }
    Uint8 *texture_transfer = (Uint8 *)SDL_MapGPUTransferBuffer(
        gpu_slot.device, gpu_resources.ui_transfer, true);
    float *quad_transfer = (float *)SDL_MapGPUTransferBuffer(
        gpu_slot.device, gpu_resources.ui_quad_transfer, true);
    if (texture_transfer == NULL || quad_transfer == NULL) {
        if (texture_transfer != NULL) {
            SDL_UnmapGPUTransferBuffer(gpu_slot.device, gpu_resources.ui_transfer);
        }
        if (quad_transfer != NULL) {
            SDL_UnmapGPUTransferBuffer(
                gpu_slot.device, gpu_resources.ui_quad_transfer);
        }
        return false;
    }
    for (Uint32 row = 0; row < height; row += 1u) {
        memcpy(texture_transfer + (size_t)row * transfer_row_bytes,
            pixels + (size_t)row * row_bytes, row_bytes);
    }
    float u_max = (float)width / (float)KOOKIE_GPU_UI_TEXTURE_WIDTH;
    float v_max = (float)height / (float)KOOKIE_GPU_UI_TEXTURE_HEIGHT;
    const float quad[24] = {
        -1.0f, -1.0f, 0.0f, v_max,
         1.0f, -1.0f, u_max, v_max,
         1.0f,  1.0f, u_max, 0.0f,
        -1.0f, -1.0f, 0.0f, v_max,
         1.0f,  1.0f, u_max, 0.0f,
        -1.0f,  1.0f, 0.0f, 0.0f
    };
    memcpy(quad_transfer, quad, sizeof(quad));
    SDL_UnmapGPUTransferBuffer(gpu_slot.device, gpu_resources.ui_transfer);
    SDL_UnmapGPUTransferBuffer(gpu_slot.device, gpu_resources.ui_quad_transfer);

    SDL_GPUCopyPass *copy_pass = SDL_BeginGPUCopyPass(command_buffer);
    if (copy_pass == NULL) {
        return false;
    }
    SDL_GPUTextureTransferInfo texture_source = {0};
    texture_source.transfer_buffer = gpu_resources.ui_transfer;
    texture_source.pixels_per_row = KOOKIE_GPU_UI_TEXTURE_WIDTH;
    texture_source.rows_per_layer = height;
    SDL_GPUTextureRegion texture_destination = {0};
    texture_destination.texture = gpu_resources.texture;
    texture_destination.w = width;
    texture_destination.h = height;
    texture_destination.d = 1;
    SDL_UploadToGPUTexture(
        copy_pass, &texture_source, &texture_destination, true);
    SDL_GPUTransferBufferLocation quad_source = {0};
    quad_source.transfer_buffer = gpu_resources.ui_quad_transfer;
    SDL_GPUBufferRegion quad_destination = {0};
    quad_destination.buffer = gpu_resources.vertex_buffer;
    quad_destination.size = sizeof(quad);
    SDL_UploadToGPUBuffer(
        copy_pass, &quad_source, &quad_destination, true);
    SDL_EndGPUCopyPass(copy_pass);
    return true;
}

static void kookie_gpu_world_lighting_floats(
    float out[64], bool animate
) {
    memset(out, 0, sizeof(float) * 64u);
    out[0] = 160.0f;
    out[1] = 72.0f;
    out[2] = 140.0f;
    out[3] = 260.0f;
    out[4] = 1.0f;
    out[5] = 0.78f;
    out[6] = 0.56f;
    out[7] = 1.0f;
    out[8] = 0.42f;
    out[9] = 0.48f;
    out[10] = 0.58f;
    out[11] = 1.0f;
    if (animate) {
        Uint32 phase = (SDL_GetTicks() / 32u) % 512u;
        Uint32 sweep = phase < 256u ? phase : 512u - phase;
        out[0] = 64.0f + (float)sweep * 0.75f;
        out[2] = 96.0f + (float)(256u - sweep) * 0.5f;
    }
    out[12] = (float)gpu_water_time_ticks / 60.0f;
    for (int style_index = 0;
         style_index < KOOKIE_GPU_WATER_STYLE_COUNT;
         style_index++) {
        const KookieWaterStyle *style = &gpu_water_styles[style_index];
        int base = 16 + style_index * 12;
        out[base] = style->enabled ? 1.0f : 0.0f;
        out[base + 1] = (float)style->caustic_scale / 10.0f;
        out[base + 2] = (float)style->caustic_speed / 100.0f;
        out[base + 3] = (float)style->caustic_strength / 1000.0f;
        out[base + 4] = (float)style->tint_r / 1000.0f;
        out[base + 5] = (float)style->tint_g / 1000.0f;
        out[base + 6] = (float)style->tint_b / 1000.0f;
        out[base + 8] = (float)style->toon_base / 1000.0f;
        out[base + 9] = (float)style->toon_contrast / 1000.0f;
        out[base + 10] = (float)style->opacity / 1000.0f;
    }
}

static bool kookie_gpu_draw_test_internal(
    SDL_Window *window,
    SDL_GPUTexture *offscreen_target,
    SDL_GPUFence **out_fence
) {
    if (out_fence != NULL) {
        *out_fence = NULL;
    }
    if (gpu_slot.device == NULL) {
        fprintf(stderr, "KOOKIE gpu_draw device unavailable: %s\n",
            SDL_GetError());
        return false;
    }

    SDL_GPUDevice *device = gpu_slot.device;
    SDL_GPUTextureFormat target_format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    if (window != NULL) {
        target_format = SDL_GetGPUSwapchainTextureFormat(device, window);
        if (target_format == SDL_GPU_TEXTUREFORMAT_INVALID) {
            fprintf(stderr, "KOOKIE gpu_draw invalid swapchain format: %s\n",
                SDL_GetError());
            return false;
        }
    } else if (offscreen_target == NULL) {
        fprintf(stderr, "KOOKIE gpu_draw missing offscreen target: %s\n",
            SDL_GetError());
        return false;
    }
    if (!kookie_gpu_prepare_resources(device, target_format)) {
        fprintf(stderr, "KOOKIE gpu_draw resource preparation failed: %s\n",
            SDL_GetError());
        return false;
    }

    SDL_GPUCommandBuffer *command_buffer = SDL_AcquireGPUCommandBuffer(device);
    if (command_buffer == NULL) {
        fprintf(stderr, "KOOKIE gpu_draw acquire command buffer failed: %s\n",
            SDL_GetError());
        return false;
    }
    SDL_GPUTexture *render_target = offscreen_target;
    Uint32 target_width = 320;
    Uint32 target_height = 240;
    if (window != NULL) {
        if (!SDL_WaitAndAcquireGPUSwapchainTexture(
                command_buffer, window, &render_target,
                &target_width, &target_height) ||
            render_target == NULL || target_width == 0 || target_height == 0) {
            fprintf(stderr, "KOOKIE gpu_draw acquire swapchain failed: %s\n",
                SDL_GetError());
            SDL_CancelGPUCommandBuffer(command_buffer);
            return false;
        }
    }
    bool world_draw = (gpu_render_policy_active
        ? gpu_render_world : true) &&
        gpu_world_scene.committed && gpu_world_scene.count > 0;
    bool scene_draw = (gpu_render_policy_active
        ? gpu_render_scene : true) &&
        gpu_scene.active && gpu_scene.committed &&
        (gpu_scene.count > 0 || gpu_scene.text_count > 0);
    float world_camera_matrix[16] = {0};
    if (world_draw &&
        !kookie_gpu_world_camera_matrix_floats(world_camera_matrix)) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return false;
    }
    SDL_GPUDepthStencilTargetInfo depth_target = {0};
    SDL_GPUDepthStencilTargetInfo *depth_target_ptr = NULL;
    if (world_draw || scene_draw) {
        if (!kookie_gpu_ensure_depth_texture(
                device, target_width, target_height)) {
            SDL_CancelGPUCommandBuffer(command_buffer);
            return false;
        }
        depth_target.texture = gpu_resources.depth_texture;
        depth_target.clear_depth = 1.0f;
        depth_target.load_op = SDL_GPU_LOADOP_CLEAR;
        depth_target.store_op = SDL_GPU_STOREOP_DONT_CARE;
        depth_target.stencil_load_op = SDL_GPU_LOADOP_DONT_CARE;
        depth_target.stencil_store_op = SDL_GPU_STOREOP_DONT_CARE;
        depth_target_ptr = &depth_target;
    }
    if (scene_draw &&
        !kookie_gpu_upload_ui_texture(
            command_buffer, &gpu_scene, target_width, target_height)) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return false;
    }
    SDL_GPUColorTargetInfo target = {0};

    target.texture = render_target;
    target.clear_color.r = 0.08f;
    target.clear_color.g = 0.18f;
    target.clear_color.b = 0.32f;
    target.clear_color.a = 1.0f;
    target.load_op = SDL_GPU_LOADOP_CLEAR;
    target.store_op = SDL_GPU_STOREOP_STORE;
    SDL_GPURenderPass *render_pass = SDL_BeginGPURenderPass(
        command_buffer, &target, 1, depth_target_ptr);
    float world_lighting[64];
    kookie_gpu_world_lighting_floats(world_lighting, world_draw);
    if (render_pass == NULL) {
        fprintf(stderr, "KOOKIE gpu_draw begin render pass failed: %s\n",
            SDL_GetError());
        SDL_CancelGPUCommandBuffer(command_buffer);
        return false;
    }
    SDL_GPUTextureSamplerBinding binding = {0};
    SDL_GPUBufferBinding vertex_binding = {0};
    last_gpu_scene_draw_calls = 0;
    if (world_draw) {
        SDL_PushGPUVertexUniformData(
            command_buffer, 0, world_camera_matrix,
            sizeof(world_camera_matrix));
        SDL_PushGPUFragmentUniformData(
            command_buffer, 0, world_lighting,
            sizeof(world_lighting));
        binding.texture = gpu_resources.world_texture;
        binding.sampler = gpu_resources.sampler;
        vertex_binding.buffer = gpu_resources.world_vertex_buffer;
        SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.world_pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
        SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
        SDL_DrawGPUPrimitives(
            render_pass, (Uint32)gpu_world_scene.count, 1, 0, 0);
        last_gpu_scene_draw_calls += 1;
    }
    if (scene_draw) {
        binding.texture = gpu_resources.texture;
        binding.sampler = gpu_resources.sampler;
        vertex_binding.buffer = gpu_resources.vertex_buffer;
        SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
        SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
        SDL_GPUBufferBinding index_binding = {0};
        index_binding.buffer = gpu_resources.index_buffer;
        SDL_BindGPUIndexBuffer(
            render_pass, &index_binding, SDL_GPU_INDEXELEMENTSIZE_16BIT);
        SDL_DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0);
        last_gpu_scene_draw_calls += 1;
    }
    if (!world_draw && !scene_draw && !gpu_render_policy_active) {
        binding.texture = gpu_resources.texture;
        binding.sampler = gpu_resources.sampler;
        vertex_binding.buffer = gpu_resources.vertex_buffer;
        SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
        SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
        SDL_GPUBufferBinding index_binding = {0};
        index_binding.buffer = gpu_resources.index_buffer;
        SDL_BindGPUIndexBuffer(
            render_pass, &index_binding, SDL_GPU_INDEXELEMENTSIZE_16BIT);
        SDL_DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0);
        last_gpu_scene_draw_calls = 1;
    }
    SDL_EndGPURenderPass(render_pass);
    if (out_fence != NULL) {
        *out_fence = SDL_SubmitGPUCommandBufferAndAcquireFence(command_buffer);
        if (*out_fence == NULL) {
            fprintf(stderr, "KOOKIE gpu_draw submit fence failed: %s\n",
                SDL_GetError());
        }
        return *out_fence != NULL;
    }
    if (!kookie_gpu_submit_and_wait_fence(device, command_buffer)) {
        fprintf(stderr, "KOOKIE gpu_draw submit wait failed: %s\n",
            SDL_GetError());
        return false;
    }
    return true;
}

bool kookie_gpu_draw_test(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot < 0 ||
        gpu_slot.window_slot >= KOOKIE_MAX_WINDOWS ||
        window_slots[gpu_slot.window_slot].window == NULL) {
        return false;
    }
    gpu_scene.active = false;
    bool success = kookie_gpu_draw_test_internal(
        window_slots[gpu_slot.window_slot].window, NULL, NULL);
    if (!success) {
        fprintf(stderr, "kookie_gpu_draw_test: %s\n", SDL_GetError());
    }
    return success;
}

bool kookie_gpu_draw_scene(void) {
    if (!gpu_render_plan_ready) {
        return false;
    }
    bool activate_pending =
        gpu_reload.pending_generation != 0 &&
        gpu_reload.pending_scene_committed &&
        gpu_reload.scene_generation == gpu_reload.pending_generation;
    KookieGpuScene *scene =
        activate_pending ? &gpu_pending_scene : &gpu_scene;
    bool requested_world = gpu_render_world &&
        gpu_world_scene.committed && gpu_world_scene.count > 0;
    bool requested_scene = gpu_render_scene &&
        scene->committed &&
        (scene->count > 0 || scene->text_count > 0);
    if ((!requested_scene && !requested_world) ||
        gpu_slot.device == NULL ||
        gpu_slot.window_slot < 0 ||
        gpu_slot.window_slot >= KOOKIE_MAX_WINDOWS ||
        window_slots[gpu_slot.window_slot].window == NULL ||
        (activate_pending && gpu_reload.completed_fence >= 1000000)) {
        return false;
    }
    SDL_Window *window = window_slots[gpu_slot.window_slot].window;
    SDL_GPUTextureFormat target_format =
        SDL_GetGPUSwapchainTextureFormat(gpu_slot.device, window);
    if (target_format == SDL_GPU_TEXTUREFORMAT_INVALID) {
        fprintf(stderr, "KOOKIE gpu_draw_scene invalid swapchain format: %s\n",
            SDL_GetError());
        return false;
    }
    if (!kookie_gpu_prepare_resources(gpu_slot.device, target_format)) {
        fprintf(stderr, "KOOKIE gpu_draw_scene prepare resources failed: %s\n",
            SDL_GetError());
        return false;
    }
    int slot = gpu_scene_frame_slot;
    for (int pending_slot = 0; pending_slot < 3; pending_slot += 1) {
        if (gpu_scene_frame_fences[pending_slot] == NULL) {
            continue;
        }
        Uint64 start = SDL_GetPerformanceCounter();
        SDL_GPUFence *wait_fence = gpu_scene_frame_fences[pending_slot];
        if (!SDL_WaitForGPUFences(
                gpu_slot.device, true, &wait_fence, 1)) {
            fprintf(stderr,
                "KOOKIE gpu_draw_scene fence wait failed slot=%d: %s\n",
                pending_slot, SDL_GetError());
            gpu_scene.active = false;
            return false;
        }
        Uint64 frequency = SDL_GetPerformanceFrequency();
        Uint64 elapsed = SDL_GetPerformanceCounter() - start;
        last_gpu_fence_wait_microseconds =
            kookie_elapsed_microseconds(elapsed, frequency);
        SDL_ReleaseGPUFence(
            gpu_slot.device, gpu_scene_frame_fences[pending_slot]);
        gpu_scene_frame_fences[pending_slot] = NULL;
    }
    if (requested_world &&
        !kookie_gpu_world_upload(gpu_slot.device, &gpu_world_scene)) {
        fprintf(stderr, "KOOKIE gpu_draw_scene world upload failed: %s\n",
            SDL_GetError());
        return false;
    }
    if (activate_pending && !kookie_gpu_activate_pending_scene()) {
        return false;
    }
    gpu_scene.active = requested_scene;
    gpu_render_policy_active = true;
    bool drawn = kookie_gpu_draw_test_internal(
        window, NULL, &gpu_scene_frame_fences[slot]);
    gpu_render_policy_active = false;
    if (!drawn) {
        fprintf(stderr, "KOOKIE gpu_draw_scene draw failed: %s\n",
            SDL_GetError());
        gpu_scene.active = false;
        return false;
    }
    gpu_scene_frame_slot = (gpu_scene_frame_slot + 1) % 3;
    return true;
}
static bool kookie_gpu_write_window_screenshot_ppm(
    const char *path,
    const Uint8 *pixels,
    size_t byte_count,
    Uint32 width,
    Uint32 height,
    SDL_GPUTextureFormat format
) {
    if (path == NULL || path[0] == '\0' || pixels == NULL ||
        width == 0 || height == 0 ||
        (format != SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM &&
            format != SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM &&
            format != SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM_SRGB &&
            format != SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB) ||
        byte_count < (size_t)width * (size_t)height * 4u) {
        return false;
    }
    FILE *file = fopen(path, "wb");
    if (file == NULL) {
        return false;
    }
    bool success = fprintf(
        file, "P6\n%u %u\n255\n", (unsigned int)width, (unsigned int)height) >= 0;
    bool blueFirst =
        format == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM ||
        format == SDL_GPU_TEXTUREFORMAT_B8G8R8A8_UNORM_SRGB;
    size_t pixel_count = (size_t)width * (size_t)height;
    for (size_t index = 0; index < pixel_count && success; index += 1) {
        const Uint8 *pixel = pixels + index * 4u;
        Uint8 rgb[3] = {
            pixel[blueFirst ? 2 : 0],
            pixel[1],
            pixel[blueFirst ? 0 : 2]
        };
        success = fwrite(rgb, 1, sizeof(rgb), file) == sizeof(rgb);
    }
    if (fclose(file) != 0) {
        success = false;
    }
    if (!success) {
        remove(path);
    }
    return success;
}

int kookie_gpu_window_screenshot_checksum(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot < 0 ||
        gpu_slot.window_slot >= KOOKIE_MAX_WINDOWS ||
        window_slots[gpu_slot.window_slot].window == NULL ||
        kookie_gpu_window_present_capabilities() < 1) {
        return 0;
    }
    SDL_GPUDevice *device = gpu_slot.device;
    SDL_Window *window = window_slots[gpu_slot.window_slot].window;
    SDL_GPUTextureFormat target_format =
        SDL_GetGPUSwapchainTextureFormat(device, window);
    if (target_format == SDL_GPU_TEXTUREFORMAT_INVALID ||
        !kookie_gpu_prepare_resources(device, target_format)) {
        return 0;
    }
    SDL_GPUCommandBuffer *command_buffer = SDL_AcquireGPUCommandBuffer(device);
    if (command_buffer == NULL) {
        return 0;
    }
    SDL_GPUTexture *render_target = NULL;
    Uint32 target_width = 0;
    Uint32 target_height = 0;
    if (!SDL_WaitAndAcquireGPUSwapchainTexture(
            command_buffer, window, &render_target,
            &target_width, &target_height) ||
        render_target == NULL || target_width == 0 || target_height == 0 ||
        target_width > 4096 || target_height > 4096) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return 0;
    }
    bool world_draw = gpu_world_scene.committed &&
        gpu_world_scene.count > 0;
    bool scene_draw = gpu_scene.active && gpu_scene.committed &&
        (gpu_scene.count > 0 || gpu_scene.text_count > 0);
    float world_camera_matrix[16] = {0};
    if (world_draw &&
        !kookie_gpu_world_camera_matrix_floats(world_camera_matrix)) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return 0;
    }
    SDL_GPUDepthStencilTargetInfo depth_target = {0};
    SDL_GPUDepthStencilTargetInfo *depth_target_ptr = NULL;
    if (world_draw || scene_draw) {
        if (!kookie_gpu_ensure_depth_texture(
                device, target_width, target_height)) {
            SDL_CancelGPUCommandBuffer(command_buffer);
            return 0;
        }
        depth_target.texture = gpu_resources.depth_texture;
        depth_target.clear_depth = 1.0f;
        depth_target.load_op = SDL_GPU_LOADOP_CLEAR;
        depth_target.store_op = SDL_GPU_STOREOP_DONT_CARE;
        depth_target.stencil_load_op = SDL_GPU_LOADOP_DONT_CARE;
        depth_target.stencil_store_op = SDL_GPU_STOREOP_DONT_CARE;
        depth_target_ptr = &depth_target;
    }
    if (scene_draw &&
        !kookie_gpu_upload_ui_texture(
            command_buffer, &gpu_scene, target_width, target_height)) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return 0;
    }
    SDL_GPUColorTargetInfo target = {0};
    target.texture = render_target;
    target.clear_color.r = 0.05f;
    target.clear_color.g = 0.05f;
    target.clear_color.b = 0.05f;
    target.clear_color.a = 1.0f;
    target.load_op = SDL_GPU_LOADOP_CLEAR;
    target.store_op = SDL_GPU_STOREOP_STORE;
    SDL_GPURenderPass *render_pass = SDL_BeginGPURenderPass(
        command_buffer, &target, 1, depth_target_ptr);
    if (render_pass == NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return 0;
    }
    SDL_GPUTextureSamplerBinding binding = {0};
    SDL_GPUBufferBinding vertex_binding = {0};
    float world_lighting[64];
    if (world_draw) {
        SDL_PushGPUVertexUniformData(
            command_buffer, 0, world_camera_matrix,
            sizeof(world_camera_matrix));
        kookie_gpu_world_lighting_floats(world_lighting, true);
        SDL_PushGPUFragmentUniformData(
            command_buffer, 0, world_lighting,
            sizeof(world_lighting));
        binding.texture = gpu_resources.world_texture;
        binding.sampler = gpu_resources.sampler;
        vertex_binding.buffer = gpu_resources.world_vertex_buffer;
        SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.world_pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
        SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
        SDL_DrawGPUPrimitives(
            render_pass, (Uint32)gpu_world_scene.count, 1, 0, 0);
    }
    if (scene_draw) {
        binding.texture = gpu_resources.texture;
        binding.sampler = gpu_resources.sampler;
        vertex_binding.buffer = gpu_resources.vertex_buffer;
        SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
        SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
        SDL_GPUBufferBinding index_binding = {0};
        index_binding.buffer = gpu_resources.index_buffer;
        SDL_BindGPUIndexBuffer(
            render_pass, &index_binding, SDL_GPU_INDEXELEMENTSIZE_16BIT);
        SDL_DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0);
    }
    if (!world_draw && !scene_draw) {
        binding.texture = gpu_resources.texture;
        binding.sampler = gpu_resources.sampler;
        vertex_binding.buffer = gpu_resources.vertex_buffer;
        SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.pipeline);
        SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
        SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
        SDL_GPUBufferBinding index_binding = {0};
        index_binding.buffer = gpu_resources.index_buffer;
        SDL_BindGPUIndexBuffer(
            render_pass, &index_binding, SDL_GPU_INDEXELEMENTSIZE_16BIT);
        SDL_DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0);
    }
    SDL_EndGPURenderPass(render_pass);

    size_t byte_count = (size_t)target_width * (size_t)target_height * 4u;
    SDL_GPUTransferBufferCreateInfo transfer_info = {0};
    transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD;
    transfer_info.size = (Uint32)byte_count;
    SDL_GPUTransferBuffer *transfer = SDL_CreateGPUTransferBuffer(
        device, &transfer_info);
    if (transfer == NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return 0;
    }
    SDL_GPUCopyPass *copy_pass = SDL_BeginGPUCopyPass(command_buffer);
    if (copy_pass == NULL) {
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        SDL_CancelGPUCommandBuffer(command_buffer);
        return 0;
    }
    SDL_GPUTextureRegion source = {0};
    source.texture = render_target;
    source.w = target_width;
    source.h = target_height;
    source.d = 1;
    SDL_GPUTextureTransferInfo destination = {0};
    destination.transfer_buffer = transfer;
    destination.pixels_per_row = target_width;
    destination.rows_per_layer = target_height;
    SDL_DownloadFromGPUTexture(copy_pass, &source, &destination);
    SDL_EndGPUCopyPass(copy_pass);
    SDL_GPUFence *fence =
        SDL_SubmitGPUCommandBufferAndAcquireFence(command_buffer);
    bool fence_ready = fence != NULL &&
        kookie_gpu_wait_fence_and_release(device, &fence);
    if (!fence_ready) {
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        return 0;
    }
    Uint8 *pixels = (Uint8 *)SDL_MapGPUTransferBuffer(device, transfer, false);
    if (pixels == NULL) {
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        return 0;
    }
    unsigned int checksum = 0;
    bool varied = false;
    for (size_t index = 0; index < byte_count; index += 1) {
        checksum = (checksum + pixels[index]) & 0x7fffffffU;
    }
    for (size_t index = 4; index < byte_count; index += 4) {
        if (pixels[index] != pixels[0] ||
            pixels[index + 1u] != pixels[1] ||
            pixels[index + 2u] != pixels[2] ||
            pixels[index + 3u] != pixels[3]) {
            varied = true;
            break;
        }
    }
    if (!varied) {
        fprintf(stderr,
            "KOOKIE gpu screenshot has no visible pixel variation\n");
        const char *empty_path = getenv("KOOKIE_SCREENSHOT_PATH");
        if (empty_path != NULL && empty_path[0] != '\0') {
            remove(empty_path);
        }
        SDL_UnmapGPUTransferBuffer(device, transfer);
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        return 0;
    }
    const char *screenshot_path = getenv("KOOKIE_SCREENSHOT_PATH");
    bool export_success = screenshot_path == NULL || screenshot_path[0] == '\0' ||
        kookie_gpu_write_window_screenshot_ppm(
            screenshot_path, pixels, byte_count,
            target_width, target_height, target_format);
    SDL_UnmapGPUTransferBuffer(device, transfer);
    SDL_ReleaseGPUTransferBuffer(device, transfer);
    if (!export_success) {
        return 0;
    }
    return checksum == 0 ? 1 : (int)checksum;
}
bool kookie_gpu_capture_window(void) {
    int checksum = kookie_gpu_window_screenshot_checksum();
    if (checksum <= 0) {
        return false;
    }
    fprintf(stderr, "gpu-window-screenshot-checksum\n%d\n", checksum);
    return true;
}
bool kookie_gpu_report_window_present_capabilities(void) {
    int capabilities = kookie_gpu_window_present_capabilities();
    if (capabilities < 1) {
        return false;
    }
    fprintf(stderr, "gpu-present-capabilities\n%d\n", capabilities);
    return true;
}

int kookie_gpu_capture_headless_scene(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1 ||
        !gpu_scene.committed) {
        return 0;
    }
    bool activate_pending = kookie_gpu_pending_scene_ready();
    if (activate_pending && gpu_reload.completed_fence >= 1000000) {
        return 0;
    }
    SDL_GPUDevice *device = gpu_slot.device;
    SDL_GPUTextureFormat format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    if (!kookie_gpu_prepare_resources(device, format)) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=prepare-resources: %s\n",
            SDL_GetError());
        return 0;
    }
    if (activate_pending && !kookie_gpu_activate_pending_scene()) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=activate-scene\n");
        return 0;
    }
    SDL_GPUTextureCreateInfo target_info = {0};
    target_info.type = SDL_GPU_TEXTURETYPE_2D;
    target_info.format = format;
    target_info.usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
    target_info.width = 320;
    target_info.height = 240;
    target_info.layer_count_or_depth = 1;
    target_info.num_levels = 1;
    target_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    SDL_GPUTexture *target = SDL_CreateGPUTexture(device, &target_info);
    if (target == NULL) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=create-target: %s\n",
            SDL_GetError());
        return 0;
    }
    bool previous_render_policy = gpu_render_policy_active;
    gpu_scene.active = true;
    gpu_render_policy_active = gpu_render_plan_ready;
    if (gpu_world_scene.committed && gpu_world_scene.count > 0 &&
        !kookie_gpu_world_upload(device, &gpu_world_scene)) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=upload-world: %s\n",
            SDL_GetError());
        gpu_render_policy_active = previous_render_policy;
        SDL_ReleaseGPUTexture(device, target);
        return 0;
    }
    bool scene_drawn = kookie_gpu_draw_test_internal(NULL, target, NULL);
    gpu_render_policy_active = previous_render_policy;
    if (!scene_drawn) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=draw-scene: %s\n",
            SDL_GetError());
        SDL_ReleaseGPUTexture(device, target);
        return 0;
    }

    size_t byte_count = 320u * 240u * 4u;
    SDL_GPUTransferBufferCreateInfo transfer_info = {0};
    transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_DOWNLOAD;
    transfer_info.size = (Uint32)byte_count;
    SDL_GPUTransferBuffer *transfer =
        SDL_CreateGPUTransferBuffer(device, &transfer_info);
    SDL_GPUCommandBuffer *command_buffer =
        SDL_AcquireGPUCommandBuffer(device);
    if (transfer == NULL || command_buffer == NULL) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=create-readback: %s\n",
            SDL_GetError());
        if (command_buffer != NULL) {
            SDL_CancelGPUCommandBuffer(command_buffer);
        }
        if (transfer != NULL) {
            SDL_ReleaseGPUTransferBuffer(device, transfer);
        }
        SDL_ReleaseGPUTexture(device, target);
        return 0;
    }
    SDL_GPUCopyPass *copy_pass = SDL_BeginGPUCopyPass(command_buffer);
    if (copy_pass == NULL) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=begin-readback: %s\n",
            SDL_GetError());
        SDL_CancelGPUCommandBuffer(command_buffer);
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        SDL_ReleaseGPUTexture(device, target);
        return 0;
    }
    SDL_GPUTextureRegion source = {0};
    source.texture = target;
    source.w = 320;
    source.h = 240;
    source.d = 1;
    SDL_GPUTextureTransferInfo destination = {0};
    destination.transfer_buffer = transfer;
    destination.pixels_per_row = 320;
    destination.rows_per_layer = 240;
    SDL_DownloadFromGPUTexture(copy_pass, &source, &destination);
    SDL_EndGPUCopyPass(copy_pass);
    SDL_GPUFence *fence =
        SDL_SubmitGPUCommandBufferAndAcquireFence(command_buffer);
    bool fence_ready = fence != NULL &&
        kookie_gpu_wait_fence_and_release(device, &fence);
    if (!fence_ready) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=submit-readback: %s\n",
            SDL_GetError());
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        SDL_ReleaseGPUTexture(device, target);
        return 0;
    }
    Uint8 *pixels = (Uint8 *)SDL_MapGPUTransferBuffer(
        device, transfer, false);
    if (pixels == NULL) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=map-readback: %s\n",
            SDL_GetError());
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        SDL_ReleaseGPUTexture(device, target);
        return 0;
    }
    unsigned int checksum = 0;
    for (size_t index = 0; index < byte_count; index += 1) {
        checksum = (checksum + pixels[index]) & 0x7fffffffU;
    }
    const char *screenshot_path = getenv("KOOKIE_SCREENSHOT_PATH");
    bool export_success = screenshot_path == NULL ||
        screenshot_path[0] == '\0' ||
        kookie_gpu_write_window_screenshot_ppm(
            screenshot_path, pixels, byte_count, 320, 240, format);
    SDL_UnmapGPUTransferBuffer(device, transfer);
    SDL_ReleaseGPUTransferBuffer(device, transfer);
    SDL_ReleaseGPUTexture(device, target);
    if (!export_success) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=write-capture\n");
        return 0;
    }
    int result = checksum == 0 ? 1 : (int)checksum;
    fprintf(stderr, "gpu-headless-scene-checksum\n%d\n", result);
    return result;
}



bool kookie_gpu_draw_headless_test(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1) {
        return false;
    }
    gpu_scene.active = false;

    SDL_GPUTextureCreateInfo target_info = {0};
    target_info.type = SDL_GPU_TEXTURETYPE_2D;
    target_info.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    target_info.usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
    target_info.width = 320;
    target_info.height = 240;
    target_info.layer_count_or_depth = 1;
    target_info.num_levels = 1;
    target_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    SDL_GPUTexture *target = SDL_CreateGPUTexture(gpu_slot.device, &target_info);
    if (target == NULL) {
        return false;
    }
    bool success = kookie_gpu_draw_test_internal(NULL, target, NULL);
    SDL_ReleaseGPUTexture(gpu_slot.device, target);
    return success;
}
int kookie_gpu_measure_headless_overlap(int frames, int slots) {
    if (frames <= 0 || frames > 8 || slots <= 0 || slots > 2 ||
        gpu_slot.device == NULL || gpu_slot.window_slot != -1) {
        return 0;
    }
    gpu_scene.active = false;
    SDL_GPUTexture *targets[2] = {NULL, NULL};
    SDL_GPUFence *fences[2] = {NULL, NULL};
    SDL_GPUTextureCreateInfo target_info = {0};
    target_info.type = SDL_GPU_TEXTURETYPE_2D;
    target_info.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    target_info.usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
    target_info.width = 320;
    target_info.height = 240;
    target_info.layer_count_or_depth = 1;
    target_info.num_levels = 1;
    target_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    for (int slot = 0; slot < slots; slot += 1) {
        targets[slot] = SDL_CreateGPUTexture(gpu_slot.device, &target_info);
        if (targets[slot] == NULL) {
            goto cleanup;
        }
    }

    Uint64 start = SDL_GetPerformanceCounter();
    int submitted = 0;
    int retired = 0;
    int peak_in_flight = 0;
    bool success = true;
    for (int frame = 0; frame < frames; frame += 1) {
        int slot = frame % slots;
        if (fences[slot] != NULL) {
            if (!kookie_gpu_wait_fence_and_release(
                    gpu_slot.device, &fences[slot])) {
                success = false;
                break;
            }
            retired += 1;
        }
        if (!kookie_gpu_draw_test_internal(NULL, targets[slot], &fences[slot])) {
            success = false;
            break;
        }
        submitted += 1;
        int in_flight = submitted - retired;
        if (in_flight > peak_in_flight) {
            peak_in_flight = in_flight;
        }
    }
    for (int slot = 0; slot < slots; slot += 1) {
        if (fences[slot] != NULL) {
            if (!kookie_gpu_wait_fence_and_release(
                    gpu_slot.device, &fences[slot])) {
                success = false;
            }
            retired += 1;
        }
    }
    Uint64 elapsed = SDL_GetPerformanceCounter() - start;
    Uint64 frequency = SDL_GetPerformanceFrequency();
    int microseconds =
        kookie_elapsed_microseconds(elapsed, frequency);
    fprintf(stderr,
        "KOOKIE gpu-overlap-frames=%d slots=%d submitted=%d retired=%d peak-inflight=%d elapsed-us=%d\n",
        frames, slots, submitted, retired, peak_in_flight, microseconds);
    for (int slot = 0; slot < slots; slot += 1) {
        if (targets[slot] != NULL) {
            SDL_ReleaseGPUTexture(gpu_slot.device, targets[slot]);
        }
    }
    if (!success || submitted != frames || retired != submitted) {
        return 0;
    }
    return microseconds;

cleanup:
    for (int slot = 0; slot < slots; slot += 1) {
        if (fences[slot] != NULL) {
            kookie_gpu_wait_fence_and_release(
                gpu_slot.device, &fences[slot]);
        }
        if (targets[slot] != NULL) {
            SDL_ReleaseGPUTexture(gpu_slot.device, targets[slot]);
        }
    }
    return 0;
}

static int kookie_compare_frame_microseconds(
    const void *left, const void *right
) {
    int first = *(const int *)left;
    int second = *(const int *)right;
    return (first > second) - (first < second);
}

static int kookie_frame_percentile_index(int count, int percentile) {
    int rank = (count * percentile + 99) / 100;
    if (rank < 1) {
        rank = 1;
    }
    if (rank > count) {
        rank = count;
    }
    return rank - 1;
}

int kookie_gpu_measure_reference_scene(
    int warmup_frames, int measured_frames, int width, int height
) {
    if (warmup_frames < 0 || warmup_frames > 1000 ||
        measured_frames <= 0 || measured_frames > 2000 ||
        width <= 0 || width > 7680 || height <= 0 || height > 4320 ||
        gpu_slot.device == NULL || gpu_slot.window_slot != -1 ||
        !gpu_scene.committed || gpu_scene.count <= 0) {
        return 0;
    }
    SDL_GPUDevice *device = gpu_slot.device;
    SDL_GPUTextureFormat format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    if (!kookie_gpu_prepare_resources(device, format)) {
        return 0;
    }
    SDL_GPUTexture *targets[3] = {NULL, NULL, NULL};
    SDL_GPUFence *fences[3] = {NULL, NULL, NULL};
    int *samples = (int *)calloc((size_t)measured_frames, sizeof(int));
    if (samples == NULL) {
        return 0;
    }
    bool previous_render_policy = gpu_render_policy_active;
    bool previous_render_world = gpu_render_world;
    bool previous_render_scene = gpu_render_scene;
    gpu_render_policy_active = true;
    gpu_render_world = false;
    gpu_render_scene = true;
    SDL_GPUTextureCreateInfo target_info = {0};
    target_info.type = SDL_GPU_TEXTURETYPE_2D;
    target_info.format = format;
    target_info.usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET;
    target_info.width = (Uint32)width;
    target_info.height = (Uint32)height;
    target_info.layer_count_or_depth = 1;
    target_info.num_levels = 1;
    target_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    bool success = true;
    for (int slot = 0; slot < 3; slot += 1) {
        targets[slot] = SDL_CreateGPUTexture(device, &target_info);
        if (targets[slot] == NULL) {
            success = false;
            break;
        }
    }
    gpu_scene.active = true;
    Uint64 frequency = SDL_GetPerformanceFrequency();
    int total_frames = warmup_frames + measured_frames;
    for (int frame = 0; frame < total_frames && success; frame += 1) {
        int slot = frame % 3;
        Uint64 start = SDL_GetPerformanceCounter();
        if (fences[slot] != NULL) {
            SDL_GPUFence *wait_fence = fences[slot];
            if (!SDL_WaitForGPUFences(device, true, &wait_fence, 1)) {
                success = false;
                break;
            }
            SDL_ReleaseGPUFence(device, fences[slot]);
            fences[slot] = NULL;
        }
        if (!kookie_gpu_draw_test_internal(
                NULL, targets[slot], &fences[slot])) {
            success = false;
            break;
        }
        Uint64 elapsed = SDL_GetPerformanceCounter() - start;
        if (frame >= warmup_frames) {
            samples[frame - warmup_frames] =
                kookie_elapsed_microseconds(elapsed, frequency);
        }
    }
    for (int slot = 0; slot < 3; slot += 1) {
        if (fences[slot] != NULL &&
            !kookie_gpu_wait_fence_and_release(
                device, &fences[slot])) {
            success = false;
        }
        if (targets[slot] != NULL) {
            SDL_ReleaseGPUTexture(device, targets[slot]);
        }
    }
    if (!success) {
        gpu_render_policy_active = previous_render_policy;
        gpu_render_world = previous_render_world;
        gpu_render_scene = previous_render_scene;
        free(samples);
        return 0;
    }
    qsort(
        samples, (size_t)measured_frames, sizeof(int),
        kookie_compare_frame_microseconds);
    int p50 = samples[kookie_frame_percentile_index(measured_frames, 50)];
    int p95 = samples[kookie_frame_percentile_index(measured_frames, 95)];
    int p99 = samples[kookie_frame_percentile_index(measured_frames, 99)];
    int maximum = samples[measured_frames - 1];
    const char *driver = SDL_GetGPUDeviceDriver(device);
    SDL_PropertiesID properties = SDL_GetGPUDeviceProperties(device);
    const char *device_name = SDL_GetStringProperty(
        properties, SDL_PROP_GPU_DEVICE_NAME_STRING, "unknown");
    const char *driver_version = SDL_GetStringProperty(
        properties, SDL_PROP_GPU_DEVICE_DRIVER_VERSION_STRING, "unknown");
    fprintf(stderr, "KOOKIE G5 renderer-driver=%s\n",
        driver == NULL ? "unknown" : driver);
    fprintf(stderr, "KOOKIE G5 renderer-device=%s\n", device_name);
    fprintf(stderr, "KOOKIE G5 renderer-driver-version=%s\n", driver_version);
    fprintf(stderr, "KOOKIE G5 renderer-resolution=%dx%d\n", width, height);
    fprintf(stderr, "KOOKIE G5 renderer-frames=%d\n", measured_frames);
    fprintf(stderr, "KOOKIE G5 renderer-vertices=%d\n", gpu_scene.count);
    fprintf(stderr, "KOOKIE G5 renderer-instances=%d\n",
        kookie_gpu_scene_instances());
    fprintf(stderr, "KOOKIE G5 renderer-draw-calls=%d\n",
        last_gpu_scene_draw_calls);
    fprintf(stderr, "KOOKIE G5 renderer-p50-us=%d\n", p50);
    fprintf(stderr, "KOOKIE G5 renderer-p95-us=%d\n", p95);
    fprintf(stderr, "KOOKIE G5 renderer-p99-us=%d\n", p99);
    fprintf(stderr, "KOOKIE G5 renderer-max-us=%d\n", maximum);
    gpu_render_policy_active = previous_render_policy;
    gpu_render_world = previous_render_world;
    gpu_render_scene = previous_render_scene;
    free(samples);
    return p95;
}


int kookie_gpu_measure_draw(int frames) {
    if (frames <= 0 || frames > 8 || gpu_slot.device == NULL) {
        return 0;
    }
    Uint64 start = SDL_GetPerformanceCounter();
    for (int frame = 0; frame < frames; frame += 1) {
        if (!kookie_gpu_draw_test()) {
            return 0;
        }
    }
    Uint64 elapsed = SDL_GetPerformanceCounter() - start;
    Uint64 frequency = SDL_GetPerformanceFrequency();
    if (frequency == 0) {
        return 0;
    }
    return kookie_elapsed_microseconds(elapsed, frequency);
}
bool kookie_gpu_report_window_draw(void) {
    int microseconds = kookie_gpu_measure_draw(3);
    if (microseconds <= 0) {
        return false;
    }
    fprintf(stderr, "gpu-draw-us\n%d\n", microseconds);
    return true;
}

int kookie_gpu_measure_headless_draw(int frames) {
    if (frames <= 0 || frames > 8 || gpu_slot.device == NULL ||
        gpu_slot.window_slot != -1) {
        return 0;
    }
    Uint64 start = SDL_GetPerformanceCounter();
    for (int frame = 0; frame < frames; frame += 1) {
        if (!kookie_gpu_draw_headless_test()) {
            return 0;
        }
    }
    Uint64 elapsed = SDL_GetPerformanceCounter() - start;
    Uint64 frequency = SDL_GetPerformanceFrequency();
    if (frequency == 0) {
        return 0;
    }
    return kookie_elapsed_microseconds(elapsed, frequency);
}
bool kookie_gpu_headless_budget(int frames, int budget_microseconds) {
    int microseconds = kookie_gpu_measure_headless_draw(frames);
    if (microseconds <= 0 || budget_microseconds <= 0) {
        return false;
    }
    if (kookie_gpu_measure_headless_overlap(4, 2) <= 0) {
        return false;
    }
    fprintf(stderr, "KOOKIE gpu-headless-draw-us=%d budget-us=%d\n",
        microseconds, budget_microseconds);
    fprintf(stderr, "KOOKIE gpu-headless-fence-wait-us=%d\n",
        last_gpu_fence_wait_microseconds);
    return microseconds <= budget_microseconds;
}


bool kookie_push_resize_event(int width, int height) {
    if (width <= 0 || height <= 0) {
        return false;
    }
    SDL_Event event = {0};
    event.type = SDL_EVENT_WINDOW_RESIZED;
    event.window.data1 = width;
    event.window.data2 = height;
    return SDL_PushEvent(&event);
}
bool kookie_push_key_event(int key) {
    if (key < 0) {
        return false;
    }
    SDL_Event event = {0};
    event.type = SDL_EVENT_KEY_DOWN;
    event.key.key = (SDL_Keycode)key;
    event.key.repeat = false;
    return SDL_PushEvent(&event);
}

bool kookie_push_quit_event(void) {
    SDL_Event event = {0};
    event.type = SDL_EVENT_QUIT;
    return SDL_PushEvent(&event);
}


bool kookie_push_focus_event(int focused) {
    if (focused != 0 && focused != 1) {
        return false;
    }
    pending_focus_event = focused;
    return true;
}
bool kookie_delay(int milliseconds) {
    if (milliseconds < 0) {
        return false;
    }
    SDL_Delay((Uint32)milliseconds);
    return true;
}

bool kookie_presentation_smoke_requested(void) {
    const char *value = getenv("KOOKIE_PRESENTATION_SMOKE");
    return value != NULL && strcmp(value, "1") == 0;
}

int kookie_poll_event(void) {
    SDL_Event event;
    for (int poll_attempt = 0; poll_attempt < 4; poll_attempt += 1) {
        SDL_PumpEvents();
        if (pending_focus_event >= 0) {
            last_event_a = pending_focus_event;
            last_event_b = 0;
            pending_focus_event = -1;
            return 3;
        }
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
                case SDL_EVENT_QUIT:
                    last_event_a = 0;
                    last_event_b = 0;
                    return 1;
                case SDL_EVENT_WINDOW_RESIZED:
                case SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED:
                    last_event_a = event.window.data1;
                    last_event_b = event.window.data2;
                    return 2;
                case SDL_EVENT_WINDOW_FOCUS_GAINED:
                    last_event_a = 1;
                    last_event_b = 0;
                    return 3;
                case SDL_EVENT_WINDOW_FOCUS_LOST:
                    last_event_a = 0;
                    last_event_b = 0;
                    return 3;
                case SDL_EVENT_WINDOW_CLOSE_REQUESTED:
                    last_event_a = 0;
                    last_event_b = 0;
                    return 4;
                case SDL_EVENT_KEY_DOWN:
                    last_event_a = (int)event.key.key;
                    last_event_b = event.key.repeat ? 2 : 1;
                    return 7;
                case SDL_EVENT_KEY_UP:
                    last_event_a = (int)event.key.key;
                    last_event_b = 0;
                    return 7;
                case SDL_EVENT_MOUSE_BUTTON_DOWN: {
                    if (event.button.button == SDL_BUTTON_RIGHT) {
                        last_event_a = SDL_BUTTON_RIGHT;
                        last_event_b = 1;
                        return 10;
                    }
                    if (event.button.button != SDL_BUTTON_LEFT) {
                        break;
                    }
                    SDL_Window *event_window =
                        SDL_GetWindowFromID(event.button.windowID);
                    int width = 0;
                    int height = 0;
                    if (event_window == NULL ||
                        !SDL_GetWindowSize(event_window, &width, &height) ||
                        width <= 0 || height <= 0) {
                        break;
                    }
                    last_event_a =
                        (int)(event.button.x * 200.0f / (float)width) - 100;
                    last_event_b =
                        100 - (int)(event.button.y * 200.0f / (float)height);
                    return 8;
                }
                case SDL_EVENT_MOUSE_BUTTON_UP:
                    if (event.button.button == SDL_BUTTON_LEFT) {
                        last_event_a = SDL_BUTTON_LEFT;
                        last_event_b = 0;
                        return 9;
                    }
                    if (event.button.button == SDL_BUTTON_RIGHT) {
                        last_event_a = SDL_BUTTON_RIGHT;
                        last_event_b = 0;
                        return 10;
                    }
                    break;
                case SDL_EVENT_MOUSE_MOTION:
                    gameplay_mouse_delta_x = kookie_clamp_mouse_delta(
                        gameplay_mouse_delta_x + (int)event.motion.xrel);
                    gameplay_mouse_delta_y = kookie_clamp_mouse_delta(
                        gameplay_mouse_delta_y + (int)event.motion.yrel);
                    if ((SDL_GetMouseState(NULL, NULL) &
                            SDL_BUTTON_LMASK) != 0) {
                        SDL_Window *motion_window =
                            SDL_GetWindowFromID(event.motion.windowID);
                        int width = 0;
                        int height = 0;
                        if (motion_window != NULL &&
                            SDL_GetWindowSize(motion_window, &width, &height) &&
                            width > 0 && height > 0) {
                            last_event_a =
                                (int)(event.motion.x * 200.0f /
                                    (float)width) - 100;
                            last_event_b =
                                100 - (int)(event.motion.y * 200.0f /
                                    (float)height);
                            return 11;
                        }
                    }
                    break;
                case SDL_EVENT_MOUSE_WHEEL: {
                    int wheel = (int)event.wheel.y;
                    if (wheel == 0 && event.wheel.y != 0.0f) {
                        wheel = event.wheel.y > 0.0f ? 1 : -1;
                    }
                    gameplay_mouse_wheel_y = kookie_clamp_mouse_delta(
                        gameplay_mouse_wheel_y + wheel);
                    break;
                }
                case SDL_EVENT_RENDER_DEVICE_RESET:
                    if (kookie_gpu_handle_device_event(event.type)) {
                        last_event_a = 0;
                        last_event_b = KOOKIE_GPU_RECOVERY_READY;
                        return 5;
                    }
                    break;
                case SDL_EVENT_RENDER_DEVICE_LOST:
                    if (kookie_gpu_handle_device_event(event.type)) {
                        last_event_a = 0;
                        last_event_b = KOOKIE_GPU_RECOVERY_LOST;
                        return 6;
                    }
                    break;
                default:
                    break;
            }
        }
    }
    return 0;
}

int kookie_drain_events(int max_events) {
    if (max_events <= 0) {
        return 0;
    }
    int drained = 0;
    while (drained < max_events && kookie_poll_event() != 0) {
        drained += 1;
    }
    return drained;
}

int kookie_last_event_a(void) {
    return last_event_a;
}

int kookie_last_event_b(void) {
    return last_event_b;
}


int kookie_consume_mouse_delta_x(void) {
    int value = gameplay_mouse_delta_x;
    gameplay_mouse_delta_x = 0;
    return value;
}

int kookie_consume_mouse_delta_y(void) {
    int value = gameplay_mouse_delta_y;
    gameplay_mouse_delta_y = 0;
    return value;
}
int kookie_consume_mouse_wheel_y(void) {
    int value = gameplay_mouse_wheel_y;
    gameplay_mouse_wheel_y = 0;
    return value;
}

static bool kookie_audio_play_predecoded_track(
    MIX_Track *track,
    MIX_Audio *audio,
    float gain,
    int loops,
    int loop_start_frame,
    int loop_end_frame
) {
    if (track == NULL || audio == NULL || loops < -1 ||
        loop_start_frame < 0) {
        return false;
    }
    Sint64 duration = MIX_GetAudioDuration(audio);
    if (duration <= 0 || loop_start_frame >= duration) {
        return false;
    }
    Sint64 loop_end = loop_end_frame < 0 ?
        duration : (Sint64)loop_end_frame;
    if (loop_end <= loop_start_frame || loop_end > duration) {
        return false;
    }
    SDL_PropertiesID options = SDL_CreateProperties();
    if (options == 0 ||
        !SDL_SetNumberProperty(
            options, MIX_PROP_PLAY_LOOPS_NUMBER, (Sint64)loops) ||
        !SDL_SetNumberProperty(
            options, MIX_PROP_PLAY_LOOP_START_FRAME_NUMBER,
            (Sint64)loop_start_frame) ||
        !(loop_end == duration ||
            SDL_SetNumberProperty(
                options, MIX_PROP_PLAY_MAX_FRAME_NUMBER, loop_end)) ||
        !MIX_SetTrackGain(track, gain) ||
        !MIX_PlayTrack(track, options)) {
        if (options != 0) {
            SDL_DestroyProperties(options);
        }
        return false;
    }
    SDL_DestroyProperties(options);
    return true;
}

static bool kookie_audio_music_path_configured(void) {
    const char *path = getenv("KOOKIE_AUDIO_MUSIC_OGG");
    return path != NULL && path[0] != '\0';
}

static bool kookie_audio_load_music_ogg_asset(void) {
    const char *path = getenv("KOOKIE_AUDIO_MUSIC_OGG");
    if (audio_slot.mixer == NULL || path == NULL || path[0] == '\0') {
        return false;
    }
    MIX_Audio *audio = MIX_LoadAudio(audio_slot.mixer, path, true);
    MIX_Track *track = audio == NULL ?
        NULL : MIX_CreateTrack(audio_slot.mixer);
    Sint64 duration = audio == NULL ? 0 : MIX_GetAudioDuration(audio);
    if (audio == NULL || track == NULL || duration <= 0 ||
        !MIX_SetTrackAudio(track, audio) ||
        !MIX_SetTrackGain(
            track, (float)audio_slot.music_volume / 100.0f)) {
        if (track != NULL) {
            MIX_DestroyTrack(track);
        }
        if (audio != NULL) {
            MIX_DestroyAudio(audio);
        }
        return false;
    }
    kookie_audio_release_music_ogg();
    audio_slot.music_ogg_audio = audio;
    audio_slot.music_ogg_track = track;
    audio_slot.music_ogg_duration_frames = duration;
    audio_slot.music_ogg_loaded = true;
    return true;
}

bool kookie_audio_load_music_ogg(void) {
    return kookie_audio_load_music_ogg_asset();
}

bool kookie_audio_play_music_loop(
    int loops,
    int loop_start_frame,
    int loop_end_frame
) {
    if (!audio_slot.music_ogg_loaded) {
        return false;
    }
    return kookie_audio_play_predecoded_track(
        audio_slot.music_ogg_track,
        audio_slot.music_ogg_audio,
        (float)audio_slot.music_volume / 100.0f,
        loops,
        loop_start_frame,
        loop_end_frame);
}

bool kookie_audio_stop_music(void) {
    return audio_slot.music_ogg_track != NULL &&
        MIX_StopTrack(audio_slot.music_ogg_track, 0);
}

static bool kookie_audio_load_ui_assets(void) {
    for (int index = 0; index < KOOKIE_AUDIO_UI_ASSET_COUNT; index += 1) {
        int clip_id = kookie_audio_ui_clip_id_at(index);
        audio_slot.ui_audio[index] = MIX_LoadAudio(
            audio_slot.mixer, kookie_audio_ui_clip_path(clip_id), true);
        audio_slot.ui_tracks[index] = MIX_CreateTrack(audio_slot.mixer);
        if (audio_slot.ui_audio[index] == NULL ||
            audio_slot.ui_tracks[index] == NULL ||
            !MIX_SetTrackAudio(
                audio_slot.ui_tracks[index], audio_slot.ui_audio[index]) ||
            !MIX_SetTrackGain(
                audio_slot.ui_tracks[index],
                (float)audio_slot.effects_volume / 100.0f)) {
            kookie_audio_release_ui_assets();
            memset(
                audio_slot.ui_audio, 0, sizeof(audio_slot.ui_audio));
            memset(
                audio_slot.ui_tracks, 0, sizeof(audio_slot.ui_tracks));
            return false;
        }
    }
    return true;
}

static bool kookie_audio_set_ui_gain(int effects) {
    for (int index = 0; index < KOOKIE_AUDIO_UI_ASSET_COUNT; index += 1) {
        if (audio_slot.ui_tracks[index] != NULL &&
            !MIX_SetTrackGain(
                audio_slot.ui_tracks[index], (float)effects / 100.0f)) {
            return false;
        }
    }
    return true;
}

int kookie_audio_open(void) {
    if (audio_slot.mixer != NULL) {
        return 0;
    }
    if (audio_slot.generation == 0) {
        audio_slot.generation = 1;
    }
    if (!MIX_Init()) {
        return 0;
    }
    audio_slot.mixer_initialized = true;
    audio_slot.spec.format = SDL_AUDIO_F32LE;
    audio_slot.spec.channels = 2;
    audio_slot.spec.freq = 48000;
    audio_slot.mixer = MIX_CreateMixerDevice(
        SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &audio_slot.spec);
    audio_slot.effects_stream = SDL_CreateAudioStream(
        &audio_slot.spec, &audio_slot.spec);
    audio_slot.music_stream = SDL_CreateAudioStream(
        &audio_slot.spec, &audio_slot.spec);
    if (audio_slot.mixer == NULL ||
        audio_slot.effects_stream == NULL ||
        audio_slot.music_stream == NULL) {
        kookie_audio_release();
        return 0;
    }
    audio_slot.effects_track = MIX_CreateTrack(audio_slot.mixer);
    audio_slot.music_track = MIX_CreateTrack(audio_slot.mixer);
    if (audio_slot.effects_track == NULL ||
        audio_slot.music_track == NULL ||
        !MIX_SetTrackAudioStream(
            audio_slot.effects_track, audio_slot.effects_stream) ||
        !MIX_SetTrackAudioStream(
            audio_slot.music_track, audio_slot.music_stream)) {
        kookie_audio_release();
        return 0;
    }
    SDL_PropertiesID play_options = SDL_CreateProperties();
    if (play_options == 0 ||
        !SDL_SetBooleanProperty(
            play_options,
            MIX_PROP_PLAY_HALT_WHEN_EXHAUSTED_BOOLEAN,
            false) ||
        !MIX_PlayTrack(audio_slot.effects_track, play_options) ||
        !MIX_PlayTrack(audio_slot.music_track, play_options)) {
        if (play_options != 0) {
            SDL_DestroyProperties(play_options);
        }
        kookie_audio_release();
        return 0;
    }
    SDL_DestroyProperties(play_options);
    audio_slot.effects_volume = 80;
    audio_slot.music_volume = 60;
    if (!MIX_SetTrackGain(audio_slot.effects_track, 0.8f) ||
        !MIX_SetTrackGain(audio_slot.music_track, 0.6f)) {
        kookie_audio_release();
        return 0;
    }
    (void)kookie_audio_load_ui_assets();
    if (kookie_audio_music_path_configured() &&
        (!kookie_audio_load_music_ogg_asset() ||
            !kookie_audio_play_music_loop(-1, 0, -1))) {
        kookie_audio_release();
        return 0;
    }
    return make_token(0, audio_slot.generation, KOOKIE_AUDIO_KIND);
}

bool kookie_audio_set_volumes(int effects, int music) {
    if (audio_slot.mixer == NULL ||
        effects < 0 || effects > 100 ||
        music < 0 || music > 100) {
        return false;
    }
    if (!MIX_SetTrackGain(
            audio_slot.effects_track, (float)effects / 100.0f) ||
        !MIX_SetTrackGain(
            audio_slot.music_track, (float)music / 100.0f) ||
        !kookie_audio_set_ui_gain(effects) ||
        (audio_slot.music_ogg_track != NULL &&
            !MIX_SetTrackGain(
                audio_slot.music_ogg_track, (float)music / 100.0f))) {
        return false;
    }
    audio_slot.effects_volume = effects;
    audio_slot.music_volume = music;
    return true;
}

int kookie_audio_effects_volume(void) {
    return audio_slot.mixer == NULL ? -1 : audio_slot.effects_volume;
}

int kookie_audio_music_volume(void) {
    return audio_slot.mixer == NULL ? -1 : audio_slot.music_volume;
}

int kookie_audio_mixer_version(void) {
    return MIX_Version();
}
int kookie_audio_music_ogg_loaded(void) {
    return audio_slot.music_ogg_loaded ? 1 : 0;
}

int kookie_audio_music_ogg_duration_frames(void) {
    if (!audio_slot.music_ogg_loaded ||
        audio_slot.music_ogg_duration_frames <= 0) {
        return -1;
    }
    return (int)audio_slot.music_ogg_duration_frames;
}

int kookie_audio_music_ogg_loops(void) {
    if (audio_slot.music_ogg_track == NULL) {
        return 0;
    }
    return MIX_GetTrackLoops(audio_slot.music_ogg_track);
}

int kookie_audio_ui_assets_loaded(void) {
    if (audio_slot.mixer == NULL) {
        return 0;
    }
    int loaded = 0;
    for (int index = 0; index < KOOKIE_AUDIO_UI_ASSET_COUNT; index += 1) {
        if (audio_slot.ui_audio[index] != NULL &&
            audio_slot.ui_tracks[index] != NULL) {
            loaded += 1;
        }
    }
    return loaded;
}

bool kookie_audio_queue_silence(int frames) {
    static unsigned char silence[4096 * 8];
    if (audio_slot.effects_stream == NULL ||
        frames <= 0 || frames > 4096) {
        return false;
    }
    int bytes = frames * audio_slot.spec.channels * (int)sizeof(float);
    return SDL_PutAudioStreamData(
        audio_slot.effects_stream, silence, bytes);
}

bool kookie_audio_queue_spatial_clip(
    int clip_id,
    int frames,
    int left_gain,
    int right_gain
) {
    static float clips[4][480];
    static float stereo[480 * 2];
    static bool initialized[4];
    int variant = 0;
    if (clip_id == 201) {
        variant = 1;
    } else if (clip_id == 202) {
        variant = 2;
    } else if (clip_id == 203) {
        variant = 3;
    } else if (clip_id != 1) {
        return false;
    }
    if (audio_slot.effects_stream == NULL ||
        frames <= 0 || frames > 480 ||
        left_gain < 0 || left_gain > 100 ||
        right_gain < 0 || right_gain > 100) {
        return false;
    }
    if (!initialized[variant]) {
        for (int frame = 0; frame < 480; frame += 1) {
            int phase = frame % 24;
            clips[variant][frame] =
                ((float)phase / 23.0f) *
                    (0.25f + (float)variant * 0.05f) -
                0.125f;
        }
        initialized[variant] = true;
    }
    float left_scale = (float)left_gain / 100.0f;
    float right_scale = (float)right_gain / 100.0f;
    for (int frame = 0; frame < frames; frame += 1) {
        stereo[frame * 2] = clips[variant][frame] * left_scale;
        stereo[frame * 2 + 1] =
            clips[variant][frame] * right_scale;
    }
    return SDL_PutAudioStreamData(
        audio_slot.effects_stream,
        stereo,
        frames * audio_slot.spec.channels * (int)sizeof(float));
}

bool kookie_audio_queue_clip(int clip_id, int frames) {
    return kookie_audio_queue_spatial_clip(
        clip_id, frames, 100, 100);
}
bool kookie_audio_play_ui_clip_loop(
    int clip_id,
    int loops,
    int loop_start_frame,
    int loop_end_frame
) {
    int index = kookie_audio_ui_clip_index(clip_id);
    if (audio_slot.mixer == NULL || index < 0) {
        return false;
    }
    if (audio_slot.ui_tracks[index] == NULL) {
        return loops == 0 && kookie_audio_queue_clip(1, 120);
    }
    if (!MIX_SetTrackStereo(audio_slot.ui_tracks[index], NULL)) {
        return false;
    }
    return kookie_audio_play_predecoded_track(
        audio_slot.ui_tracks[index],
        audio_slot.ui_audio[index],
        (float)audio_slot.effects_volume / 100.0f,
        loops,
        loop_start_frame,
        loop_end_frame);
}

bool kookie_audio_play_ui_clip_spatial(
    int clip_id,
    int left_gain,
    int right_gain
) {
    int index = kookie_audio_ui_clip_index(clip_id);
    if (audio_slot.mixer == NULL || index < 0 ||
        left_gain < 0 || left_gain > 100 ||
        right_gain < 0 || right_gain > 100 ||
        audio_slot.ui_tracks[index] == NULL ||
        audio_slot.ui_audio[index] == NULL) {
        return false;
    }
    MIX_StereoGains gains = {
        (float)left_gain / 100.0f,
        (float)right_gain / 100.0f
    };
    if (!MIX_SetTrackStereo(audio_slot.ui_tracks[index], &gains)) {
        return false;
    }
    return kookie_audio_play_predecoded_track(
        audio_slot.ui_tracks[index],
        audio_slot.ui_audio[index],
        (float)audio_slot.effects_volume / 100.0f,
        0,
        0,
        -1);
}

int kookie_audio_ui_clip_loops(int clip_id) {
    int index = kookie_audio_ui_clip_index(clip_id);
    if (audio_slot.mixer == NULL || index < 0 ||
        audio_slot.ui_tracks[index] == NULL) {
        return 0;
    }
    return MIX_GetTrackLoops(audio_slot.ui_tracks[index]);
}

bool kookie_audio_play_ui_clip(int clip_id) {
    return kookie_audio_play_ui_clip_loop(clip_id, 0, 0, -1);
}


bool kookie_audio_close(int token) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_AUDIO_KIND, &slot, &generation) ||
        slot != 0 ||
        audio_slot.mixer == NULL ||
        audio_slot.generation != generation) {
        return false;
    }
    kookie_audio_release();
    audio_slot.generation += 1;
    return true;
}
