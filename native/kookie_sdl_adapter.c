#include <SDL3/SDL.h>

#include <SDL3/SDL_gpu.h>
#include <SDL3_mixer/SDL_mixer.h>
#if SDL_VERSION != SDL_VERSIONNUM(3, 4, 16)
#error "KOOKIE requires SDL 3.4.16 headers"
#endif
#if SDL_MIXER_VERSION != SDL_VERSIONNUM(3, 2, 4)
#error "KOOKIE requires SDL_mixer 3.2.4 headers"
#endif


#include "kookie_pixel_font.h"
#include "kookie_transport.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#if defined(_WIN32)
#include <windows.h>
#endif
#define KOOKIE_MAX_WINDOWS 8
#define KOOKIE_TRANSPORT_MAX_SLOTS 4
#define KOOKIE_TRANSPORT_MAX_WORDS 300
#define KOOKIE_GPU_SCENE_MAX_VERTICES 4096
#define KOOKIE_GPU_ATLAS_WIDTH 128
#define KOOKIE_GPU_ATLAS_HEIGHT 128
#define KOOKIE_GPU_ATLAS_TILE_SIZE 8
#define KOOKIE_GPU_ATLAS_TILES_PER_ROW 16
#define KOOKIE_GPU_SOLID_COLORS 16
#define KOOKIE_GPU_FONT_COLORS 5
#define KOOKIE_GPU_FONT_GLYPHS_PER_COLOR 48
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
    SDL_AudioStream *effects_stream;
    SDL_AudioStream *music_stream;
    SDL_AudioSpec spec;
    int effects_volume;
    int music_volume;
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
    SDL_GPUShader *scene_vertex_shader;
    SDL_GPUGraphicsPipeline *scene_pipeline;
    SDL_GPUTexture *texture;
    SDL_GPUBuffer *vertex_buffer;
    SDL_GPUBuffer *index_buffer;
    SDL_GPUBuffer *scene_vertex_buffer;
    SDL_GPUTransferBuffer *scene_transfer;
    SDL_GPUSampler *sampler;
    bool ready;
} KookieGpuResources;

typedef struct {
    float vertices[KOOKIE_GPU_SCENE_MAX_VERTICES * 4];
    int expected;
    int count;
    bool open;
    bool committed;
    bool active;
} KookieGpuScene;

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

static KookieGpuResources gpu_resources;
static KookieGpuScene gpu_scene;
static KookieGpuScene gpu_pending_scene;
static int last_gpu_fence_wait_microseconds;
static KookieGpuReload gpu_reload;
static SDL_GPUFence *gpu_scene_frame_fences[3];
static int gpu_scene_frame_slot;
static int last_gpu_scene_draw_calls;

static void kookie_gpu_reload_reset(int active_generation) {
    memset(&gpu_reload, 0, sizeof(gpu_reload));
    memset(&gpu_pending_scene, 0, sizeof(gpu_pending_scene));
    gpu_reload.active_generation = active_generation;
    gpu_reload.active_checksum = active_generation > 0 ? 1 : 0;
}

static KookieWindowSlot window_slots[KOOKIE_MAX_WINDOWS];
static KookieAudioSlot audio_slot;
static void kookie_audio_release(void) {
    unsigned int generation = audio_slot.generation;
    bool mixer_initialized = audio_slot.mixer_initialized;
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
static void kookie_gpu_release_resources(SDL_GPUDevice *device) {
    if (device != NULL) {
        SDL_WaitForGPUIdle(device);
        for (int slot = 0; slot < 3; slot += 1) {
            if (gpu_scene_frame_fences[slot] != NULL) {
                SDL_ReleaseGPUFence(device, gpu_scene_frame_fences[slot]);
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
    if (gpu_resources.scene_transfer != NULL) {
        SDL_ReleaseGPUTransferBuffer(device, gpu_resources.scene_transfer);
    }
    if (gpu_resources.scene_vertex_buffer != NULL) {
        SDL_ReleaseGPUBuffer(device, gpu_resources.scene_vertex_buffer);
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
    if (gpu_resources.sampler != NULL) {
        SDL_ReleaseGPUSampler(device, gpu_resources.sampler);
    }
    if (gpu_resources.scene_pipeline != NULL) {
        SDL_ReleaseGPUGraphicsPipeline(device, gpu_resources.scene_pipeline);
    }
    if (gpu_resources.pipeline != NULL) {
        SDL_ReleaseGPUGraphicsPipeline(device, gpu_resources.pipeline);
    }
    if (gpu_resources.fragment_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.fragment_shader);
    }
    if (gpu_resources.scene_vertex_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.scene_vertex_shader);
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


static bool kookie_gpu_submit_and_wait_fence(
    SDL_GPUDevice *device,
    SDL_GPUCommandBuffer *command_buffer
) {
    Uint64 start = SDL_GetPerformanceCounter();
    SDL_GPUFence *fence = SDL_SubmitGPUCommandBufferAndAcquireFence(command_buffer);
    if (fence == NULL) {
        return false;
    }
    bool success = SDL_WaitForGPUIdle(device);
    Uint64 elapsed = SDL_GetPerformanceCounter() - start;
    Uint64 frequency = SDL_GetPerformanceFrequency();
    if (frequency == 0) {
        last_gpu_fence_wait_microseconds = 0;
    } else {
        Uint64 microseconds = (elapsed * 1000000u) / frequency;
        if (microseconds == 0) {
            microseconds = 1;
        }
        last_gpu_fence_wait_microseconds = (int)microseconds;
    }
    SDL_ReleaseGPUFence(device, fence);
    return success;
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
    memset(&gpu_scene, 0, sizeof(gpu_scene));
    kookie_gpu_reload_reset(0);
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
    memset(&gpu_scene, 0, sizeof(gpu_scene));
    kookie_gpu_reload_reset(0);
    SDL_Quit();
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
    SDL_Window *window = SDL_CreateWindow("KOOKIE", width, height, flags);
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
    if (mode == 0) {
        return SDL_SetWindowFullscreen(window, false) &&
            SDL_SetWindowFullscreenMode(window, NULL) &&
            SDL_SetWindowBordered(window, true) &&
            SDL_SetWindowResizable(window, true) &&
            SDL_SetWindowSize(window, width, height) &&
            SDL_SetWindowPosition(
                window, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED);
    }
    if (mode == 1) {
        return SDL_SetWindowFullscreenMode(window, NULL) &&
            SDL_SetWindowFullscreen(window, true);
    }
    SDL_DisplayID display = SDL_GetDisplayForWindow(window);
    SDL_DisplayMode closest;
    if (display == 0 ||
        !SDL_GetClosestFullscreenDisplayMode(
            display, width, height, 0.0f, true, &closest)) {
        return false;
    }
    return SDL_SetWindowFullscreenMode(window, &closest) &&
        SDL_SetWindowFullscreen(window, true);
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
    if (snprintf(
            path, sizeof(path), "%s/%s.%s",
            directory, name, extension) < 0) {
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
    if (length <= 0 || fseek(file, 0, SEEK_SET) != 0) {
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
static void kookie_gpu_build_atlas(Uint8 *pixels) {
    static const Uint8 palette[KOOKIE_GPU_SOLID_COLORS][4] = {
        { 71,  85, 105, 255}, { 37,  99, 235, 255},
        { 15, 118, 110, 255}, {124,  58, 237, 255},
        {180,  83,   9, 255}, {220,  38,  38, 255},
        {  8, 145, 178, 255}, {101, 163,  13, 255},
        {100, 116, 139, 255}, { 15,  23,  42, 255},
        { 30,  41,  59, 255}, {239,  68,  68, 255},
        {245, 158,  11, 255}, { 56, 189, 248, 255},
        { 34, 197,  94, 255}, {248, 250, 252, 255}
    };
    static const int font_palette[KOOKIE_GPU_FONT_COLORS] = {
        15, 13, 12, 11, 14
    };
    memset(
        pixels, 0,
        KOOKIE_GPU_ATLAS_WIDTH * KOOKIE_GPU_ATLAS_HEIGHT * 4u);
    for (int color = 0; color < KOOKIE_GPU_SOLID_COLORS; color += 1) {
        int tile_x = (color % KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
            KOOKIE_GPU_ATLAS_TILE_SIZE;
        int tile_y = (color / KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
            KOOKIE_GPU_ATLAS_TILE_SIZE;
        for (int y = 0; y < KOOKIE_GPU_ATLAS_TILE_SIZE; y += 1) {
            for (int x = 0; x < KOOKIE_GPU_ATLAS_TILE_SIZE; x += 1) {
                size_t offset = (size_t)(
                    (tile_y + y) * KOOKIE_GPU_ATLAS_WIDTH + tile_x + x) * 4u;
                memcpy(pixels + offset, palette[color], 4u);
            }
        }
    }
    for (int color = 0; color < KOOKIE_GPU_FONT_COLORS; color += 1) {
        for (int glyph = 1; glyph <= KOOKIE_PIXEL_GLYPH_COUNT; glyph += 1) {
            int tile = KOOKIE_GPU_SOLID_COLORS +
                color * KOOKIE_GPU_FONT_GLYPHS_PER_COLOR + glyph - 1;
            int tile_x = (tile % KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
                KOOKIE_GPU_ATLAS_TILE_SIZE;
            int tile_y = (tile / KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
                KOOKIE_GPU_ATLAS_TILE_SIZE;
            for (int y = 0; y < KOOKIE_PIXEL_GLYPH_HEIGHT; y += 1) {
                uint8_t row = kookie_pixel_glyph_rows[glyph][y];
                for (int x = 0; x < KOOKIE_PIXEL_GLYPH_WIDTH; x += 1) {
                    if ((row & (uint8_t)(1u << (4 - x))) == 0) {
                        continue;
                    }
                    size_t offset = (size_t)(
                        (tile_y + y) * KOOKIE_GPU_ATLAS_WIDTH + tile_x + x) *
                        4u;
                    memcpy(
                        pixels + offset,
                        palette[font_palette[color]],
                        4u);
                }
            }
        }
    }
}
static bool kookie_gpu_prepare_resources(
    SDL_GPUDevice *device,
    SDL_GPUTextureFormat target_format
) {
    if (gpu_resources.ready && gpu_resources.device == device &&
        gpu_resources.target_format == target_format) {
        return true;
    }
    if (gpu_resources.ready) {
        kookie_gpu_release_resources(gpu_resources.device);
    }

    gpu_resources.device = device;
    gpu_resources.target_format = target_format;
    gpu_resources.ready = true;
    Uint8 *vertex_code = NULL;
    Uint8 *fragment_code = NULL;
    Uint8 *scene_vertex_code = NULL;
    size_t vertex_size = 0;
    size_t fragment_size = 0;
    size_t scene_vertex_size = 0;
    SDL_GPUTransferBuffer *transfer = NULL;
    SDL_GPUCommandBuffer *command_buffer = NULL;
    bool success = false;

    SDL_GPUShaderFormat shader_format =
        kookie_gpu_shader_format(device);
    if (shader_format == SDL_GPU_SHADERFORMAT_INVALID ||
        !read_shader_binary(
            "g0_triangle.vert",
            shader_format,
            &vertex_code,
            &vertex_size) ||
        !read_shader_binary(
            "g5_triangle_instance.vert",
            shader_format,
            &scene_vertex_code,
            &scene_vertex_size) ||
        !read_shader_binary(
            "g0_triangle.frag",
            shader_format,
            &fragment_code,
            &fragment_size)) {
        goto cleanup;
    }

    SDL_GPUShaderCreateInfo vertex_info = {0};
    vertex_info.code_size = vertex_size;
    vertex_info.code = vertex_code;
    vertex_info.entrypoint = "main";
    vertex_info.format = shader_format;
    vertex_info.stage = SDL_GPU_SHADERSTAGE_VERTEX;
    gpu_resources.vertex_shader = SDL_CreateGPUShader(device, &vertex_info);
    if (gpu_resources.vertex_shader == NULL) {
        goto cleanup;
    }
    SDL_GPUShaderCreateInfo scene_shader_info = vertex_info;
    scene_shader_info.code_size = scene_vertex_size;
    scene_shader_info.code = scene_vertex_code;
    gpu_resources.scene_vertex_shader =
        SDL_CreateGPUShader(device, &scene_shader_info);
    if (gpu_resources.scene_vertex_shader == NULL) {
        goto cleanup;
    }

    SDL_GPUShaderCreateInfo fragment_info = {0};
    fragment_info.code_size = fragment_size;
    fragment_info.code = fragment_code;
    fragment_info.entrypoint = "main";
    fragment_info.format = shader_format;
    fragment_info.stage = SDL_GPU_SHADERSTAGE_FRAGMENT;
    fragment_info.num_samplers = 1;
    gpu_resources.fragment_shader = SDL_CreateGPUShader(device, &fragment_info);
    if (gpu_resources.fragment_shader == NULL) {
        goto cleanup;
    }

    SDL_GPUTextureCreateInfo texture_info = {0};
    texture_info.type = SDL_GPU_TEXTURETYPE_2D;
    texture_info.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    texture_info.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;
    texture_info.width = KOOKIE_GPU_ATLAS_WIDTH;
    texture_info.height = KOOKIE_GPU_ATLAS_HEIGHT;
    texture_info.layer_count_or_depth = 1;
    texture_info.num_levels = 1;
    texture_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    gpu_resources.texture = SDL_CreateGPUTexture(device, &texture_info);
    if (gpu_resources.texture == NULL) {
        goto cleanup;
    }

    SDL_GPUBufferCreateInfo mesh_vertex_info = {0};
    mesh_vertex_info.usage = SDL_GPU_BUFFERUSAGE_VERTEX;
    mesh_vertex_info.size = 96;
    gpu_resources.vertex_buffer = SDL_CreateGPUBuffer(device, &mesh_vertex_info);
    if (gpu_resources.vertex_buffer == NULL) {
        goto cleanup;
    }

    SDL_GPUBufferCreateInfo scene_vertex_info = {0};
    scene_vertex_info.usage = SDL_GPU_BUFFERUSAGE_VERTEX;
    scene_vertex_info.size =
        KOOKIE_GPU_SCENE_MAX_VERTICES * 4u * (Uint32)sizeof(float);
    gpu_resources.scene_vertex_buffer =
        SDL_CreateGPUBuffer(device, &scene_vertex_info);
    if (gpu_resources.scene_vertex_buffer == NULL) {
        goto cleanup;
    }

    SDL_GPUBufferCreateInfo mesh_index_info = {0};
    mesh_index_info.usage = SDL_GPU_BUFFERUSAGE_INDEX;
    mesh_index_info.size = 12;
    gpu_resources.index_buffer = SDL_CreateGPUBuffer(device, &mesh_index_info);
    if (gpu_resources.index_buffer == NULL) {
        goto cleanup;
    }

    SDL_GPUTransferBufferCreateInfo scene_transfer_info = {0};
    scene_transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    scene_transfer_info.size =
        KOOKIE_GPU_SCENE_MAX_VERTICES * 4u * (Uint32)sizeof(float);
    gpu_resources.scene_transfer =
        SDL_CreateGPUTransferBuffer(device, &scene_transfer_info);
    if (gpu_resources.scene_transfer == NULL) {
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
        goto cleanup;
    }
    SDL_GPUVertexBufferDescription scene_vertex_description = {0};
    scene_vertex_description.slot = 0;
    scene_vertex_description.pitch = 12u * (Uint32)sizeof(float);
    scene_vertex_description.input_rate = SDL_GPU_VERTEXINPUTRATE_INSTANCE;
    SDL_GPUVertexAttribute scene_vertex_attributes[3] = {0};
    for (Uint32 index = 0; index < 3; index += 1) {
        scene_vertex_attributes[index].location = index;
        scene_vertex_attributes[index].buffer_slot = 0;
        scene_vertex_attributes[index].format =
            SDL_GPU_VERTEXELEMENTFORMAT_FLOAT4;
        scene_vertex_attributes[index].offset =
            index * 4u * (Uint32)sizeof(float);
    }
    pipeline_info.vertex_shader = gpu_resources.scene_vertex_shader;
    pipeline_info.vertex_input_state.vertex_buffer_descriptions =
        &scene_vertex_description;
    pipeline_info.vertex_input_state.vertex_attributes =
        scene_vertex_attributes;
    pipeline_info.vertex_input_state.num_vertex_attributes = 3;
    gpu_resources.scene_pipeline =
        SDL_CreateGPUGraphicsPipeline(device, &pipeline_info);
    if (gpu_resources.scene_pipeline == NULL) {
        goto cleanup;
    }

    const Uint32 atlas_bytes =
        KOOKIE_GPU_ATLAS_WIDTH * KOOKIE_GPU_ATLAS_HEIGHT * 4u;
    const Uint32 vertex_offset = atlas_bytes;
    const Uint32 index_offset = vertex_offset + 96u;
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
        -0.8f, -0.8f, 0.0f, 1.0f,
         0.8f, -0.8f, 1.0f, 1.0f,
         0.8f,  0.8f, 1.0f, 0.0f,
        -0.8f, -0.8f, 0.0f, 1.0f,
         0.8f,  0.8f, 1.0f, 0.0f,
        -0.8f,  0.8f, 0.0f, 1.0f
    };
    const Uint16 indices[6] = {0, 1, 2, 3, 4, 5};
    kookie_gpu_build_atlas(pixels);
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
    destination.w = KOOKIE_GPU_ATLAS_WIDTH;
    destination.h = KOOKIE_GPU_ATLAS_HEIGHT;
    destination.d = 1;
    SDL_UploadToGPUTexture(copy_pass, &source, &destination, false);
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
    if (!SDL_SubmitGPUCommandBuffer(command_buffer) ||
        !SDL_WaitForGPUIdle(device)) {
        command_buffer = NULL;
        goto cleanup;
    }
    command_buffer = NULL;
    success = true;

cleanup:
    if (command_buffer != NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
    }
    if (transfer != NULL) {
        SDL_ReleaseGPUTransferBuffer(device, transfer);
    }
    free(fragment_code);
    free(scene_vertex_code);
    free(vertex_code);
    if (!success) {
        kookie_gpu_release_resources(device);
    }
    return success;
}

int kookie_gpu_scene_capacity(void) {
    return KOOKIE_GPU_SCENE_MAX_VERTICES;
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

bool kookie_gpu_reload_stage(int generation, int product_checksum) {
    if (gpu_slot.device == NULL || gpu_scene.open || gpu_pending_scene.open ||
        generation <= gpu_reload.active_generation || generation > 1000000 ||
        product_checksum <= 0 || product_checksum > 1000002 ||
        gpu_reload.pending_generation != 0) {
        return false;
    }
    memset(&gpu_pending_scene, 0, sizeof(gpu_pending_scene));
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
    memset(&gpu_pending_scene, 0, sizeof(gpu_pending_scene));
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

bool kookie_gpu_scene_begin(int vertex_count) {
    if (vertex_count <= 0 ||
        vertex_count > KOOKIE_GPU_SCENE_MAX_VERTICES ||
        vertex_count % 3 != 0) {
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
    scene->expected = vertex_count;
    scene->count = 0;
    scene->open = true;
    scene->committed = false;
    scene->active = false;
    gpu_reload.scene_generation = gpu_reload.pending_generation != 0
        ? gpu_reload.pending_generation
        : gpu_reload.active_generation;
    return true;
}

bool kookie_gpu_scene_push_vertex(
    int resource, int x, int y, int u, int v
) {
    KookieGpuScene *scene = NULL;
    if (gpu_pending_scene.open) {
        scene = &gpu_pending_scene;
    } else if (gpu_scene.open) {
        scene = &gpu_scene;
    }
    if (scene == NULL || scene->count >= scene->expected ||
        resource <= 0 || x < -100 || x > 100 || y < -100 || y > 100 ||
        u < 0 || u > 100 || v < 0 || v > 100) {
        return false;
    }
    int tile = 0;
    float texture_x = 0.0f;
    float texture_y = 0.0f;
    if (resource < 101) {
        tile = (resource - 1) % KOOKIE_GPU_SOLID_COLORS;
        texture_x = (float)(
            (tile % KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
            KOOKIE_GPU_ATLAS_TILE_SIZE) + 3.5f;
        texture_y = (float)(
            (tile / KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
            KOOKIE_GPU_ATLAS_TILE_SIZE) + 3.5f;
    } else {
        int encoded = resource - 101;
        int color = encoded / KOOKIE_GPU_FONT_GLYPHS_PER_COLOR;
        int glyph = encoded % KOOKIE_GPU_FONT_GLYPHS_PER_COLOR;
        if (color < 0 || color >= KOOKIE_GPU_FONT_COLORS ||
            glyph >= KOOKIE_PIXEL_GLYPH_COUNT) {
            return false;
        }
        tile = KOOKIE_GPU_SOLID_COLORS +
            color * KOOKIE_GPU_FONT_GLYPHS_PER_COLOR + glyph;
        texture_x = (float)(
            (tile % KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
            KOOKIE_GPU_ATLAS_TILE_SIZE) + 0.5f + (float)u * 4.0f / 100.0f;
        texture_y = (float)(
            (tile / KOOKIE_GPU_ATLAS_TILES_PER_ROW) *
            KOOKIE_GPU_ATLAS_TILE_SIZE) + 0.5f + (float)v * 6.0f / 100.0f;
    }
    size_t offset = (size_t)scene->count * 4u;
    scene->vertices[offset] = (float)x / 100.0f;
    scene->vertices[offset + 1u] = (float)y / 100.0f;
    scene->vertices[offset + 2u] =
        texture_x / (float)KOOKIE_GPU_ATLAS_WIDTH;
    scene->vertices[offset + 3u] =
        texture_y / (float)KOOKIE_GPU_ATLAS_HEIGHT;
    scene->count += 1;
    return true;
}

bool kookie_gpu_scene_commit(void) {
    KookieGpuScene *scene = NULL;
    if (gpu_pending_scene.open) {
        scene = &gpu_pending_scene;
    } else if (gpu_scene.open) {
        scene = &gpu_scene;
    }
    if (scene == NULL || scene->count != scene->expected) {
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

static bool kookie_gpu_upload_scene_async(
    SDL_GPUDevice *device, const KookieGpuScene *scene
) {
    if (device == NULL || scene == NULL || !scene->committed ||
        gpu_resources.scene_vertex_buffer == NULL ||
        gpu_resources.scene_transfer == NULL) {
        return false;
    }
    float *vertices = (float *)SDL_MapGPUTransferBuffer(
        device, gpu_resources.scene_transfer, true);
    if (vertices == NULL) {
        return false;
    }
    size_t byte_count = (size_t)scene->count * 4u * sizeof(float);
    memcpy(vertices, scene->vertices, byte_count);
    SDL_UnmapGPUTransferBuffer(device, gpu_resources.scene_transfer);

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
    source.transfer_buffer = gpu_resources.scene_transfer;
    SDL_GPUBufferRegion destination = {0};
    destination.buffer = gpu_resources.scene_vertex_buffer;
    destination.size = (Uint32)byte_count;
    SDL_UploadToGPUBuffer(copy_pass, &source, &destination, true);
    SDL_EndGPUCopyPass(copy_pass);
    return SDL_SubmitGPUCommandBuffer(command_buffer);
}

static bool kookie_gpu_upload_scene(
    SDL_GPUDevice *device, const KookieGpuScene *scene
) {
    return kookie_gpu_upload_scene_async(device, scene) &&
        SDL_WaitForGPUIdle(device);
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
        return false;
    }

    SDL_GPUDevice *device = gpu_slot.device;
    SDL_GPUTextureFormat target_format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    if (window != NULL) {
        target_format = SDL_GetGPUSwapchainTextureFormat(device, window);
        if (target_format == SDL_GPU_TEXTUREFORMAT_INVALID) {
            return false;
        }
    } else if (offscreen_target == NULL) {
        return false;
    }
    if (!kookie_gpu_prepare_resources(device, target_format)) {
        return false;
    }

    SDL_GPUCommandBuffer *command_buffer = SDL_AcquireGPUCommandBuffer(device);
    if (command_buffer == NULL) {
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
            SDL_CancelGPUCommandBuffer(command_buffer);
            return false;
        }
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
        command_buffer, &target, 1, NULL);
    if (render_pass == NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return false;
    }
    SDL_GPUTextureSamplerBinding binding = {0};
    binding.texture = gpu_resources.texture;
    binding.sampler = gpu_resources.sampler;
    bool scene_draw = gpu_scene.active && gpu_scene.committed &&
        gpu_scene.count > 0;
    SDL_GPUBufferBinding vertex_binding = {0};
    vertex_binding.buffer = scene_draw
        ? gpu_resources.scene_vertex_buffer
        : gpu_resources.vertex_buffer;
    SDL_BindGPUGraphicsPipeline(
        render_pass,
        scene_draw ? gpu_resources.scene_pipeline : gpu_resources.pipeline);
    SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
    SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
    last_gpu_scene_draw_calls = 1;
    if (scene_draw) {
        SDL_DrawGPUPrimitives(
            render_pass, 3, (Uint32)(gpu_scene.count / 3), 0, 0);
    } else {
        SDL_GPUBufferBinding index_binding = {0};
        index_binding.buffer = gpu_resources.index_buffer;
        SDL_BindGPUIndexBuffer(
            render_pass, &index_binding, SDL_GPU_INDEXELEMENTSIZE_16BIT);
        SDL_DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0);
    }
    SDL_EndGPURenderPass(render_pass);
    if (out_fence != NULL) {
        *out_fence = SDL_SubmitGPUCommandBufferAndAcquireFence(command_buffer);
        return *out_fence != NULL;
    }
    return kookie_gpu_submit_and_wait_fence(device, command_buffer);
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
    bool activate_pending =
        gpu_reload.pending_generation != 0 &&
        gpu_reload.pending_scene_committed &&
        gpu_reload.scene_generation == gpu_reload.pending_generation;
    KookieGpuScene *scene =
        activate_pending ? &gpu_pending_scene : &gpu_scene;
    if (!scene->committed || gpu_slot.device == NULL ||
        gpu_slot.window_slot < 0 ||
        gpu_slot.window_slot >= KOOKIE_MAX_WINDOWS ||
        window_slots[gpu_slot.window_slot].window == NULL ||
        (activate_pending && gpu_reload.completed_fence >= 1000000)) {
        return false;
    }
    SDL_Window *window = window_slots[gpu_slot.window_slot].window;
    SDL_GPUTextureFormat target_format =
        SDL_GetGPUSwapchainTextureFormat(gpu_slot.device, window);
    if (target_format == SDL_GPU_TEXTUREFORMAT_INVALID ||
        !kookie_gpu_prepare_resources(gpu_slot.device, target_format) ||
        !kookie_gpu_upload_scene_async(gpu_slot.device, scene)) {
        return false;
    }
    if (activate_pending && !kookie_gpu_activate_pending_scene()) {
        return false;
    }
    gpu_scene.active = true;
    int slot = gpu_scene_frame_slot;
    if (gpu_scene_frame_fences[slot] != NULL) {
        Uint64 start = SDL_GetPerformanceCounter();
        SDL_GPUFence *wait_fence = gpu_scene_frame_fences[slot];
        if (!SDL_WaitForGPUFences(
                gpu_slot.device, true, &wait_fence, 1)) {
            gpu_scene.active = false;
            return false;
        }
        Uint64 frequency = SDL_GetPerformanceFrequency();
        Uint64 elapsed = SDL_GetPerformanceCounter() - start;
        last_gpu_fence_wait_microseconds = frequency == 0
            ? 0 : (int)((elapsed * 1000000u) / frequency);
        SDL_ReleaseGPUFence(
            gpu_slot.device, gpu_scene_frame_fences[slot]);
        gpu_scene_frame_fences[slot] = NULL;
    }
    if (!kookie_gpu_draw_test_internal(
            window, NULL, &gpu_scene_frame_fences[slot])) {
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
    SDL_GPUColorTargetInfo target = {0};
    target.texture = render_target;
    target.clear_color.r = 0.05f;
    target.clear_color.g = 0.05f;
    target.clear_color.b = 0.05f;
    target.clear_color.a = 1.0f;
    target.load_op = SDL_GPU_LOADOP_CLEAR;
    target.store_op = SDL_GPU_STOREOP_STORE;
    SDL_GPURenderPass *render_pass = SDL_BeginGPURenderPass(
        command_buffer, &target, 1, NULL);
    if (render_pass == NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
        return 0;
    }
    SDL_GPUTextureSamplerBinding binding = {0};
    binding.texture = gpu_resources.texture;
    binding.sampler = gpu_resources.sampler;
    bool scene_draw = gpu_scene.active && gpu_scene.committed &&
        gpu_scene.count > 0;
    SDL_GPUBufferBinding vertex_binding = {0};
    vertex_binding.buffer = scene_draw
        ? gpu_resources.scene_vertex_buffer
        : gpu_resources.vertex_buffer;
    SDL_BindGPUGraphicsPipeline(
        render_pass,
        scene_draw ? gpu_resources.scene_pipeline : gpu_resources.pipeline);
    SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
    SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
    if (scene_draw) {
        SDL_DrawGPUPrimitives(
            render_pass, 3, (Uint32)(gpu_scene.count / 3), 0, 0);
    } else {
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
    if (fence == NULL || !SDL_WaitForGPUIdle(device)) {
        if (fence != NULL) {
            SDL_ReleaseGPUFence(device, fence);
        }
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        return 0;
    }
    SDL_ReleaseGPUFence(device, fence);
    Uint8 *pixels = (Uint8 *)SDL_MapGPUTransferBuffer(device, transfer, false);
    if (pixels == NULL) {
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        return 0;
    }
    unsigned int checksum = 0;
    for (size_t index = 0; index < byte_count; index += 1) {
        checksum = (checksum + pixels[index]) & 0x7fffffffU;
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
    KookieGpuScene *scene =
        activate_pending ? &gpu_pending_scene : &gpu_scene;
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
    if (!kookie_gpu_upload_scene(device, scene)) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=upload-scene: %s\n",
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
    gpu_scene.active = true;
    if (!kookie_gpu_draw_test_internal(NULL, target, NULL)) {
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
    if (fence == NULL || !SDL_WaitForGPUIdle(device)) {
        fprintf(stderr, "KOOKIE G5 renderer-failure=submit-readback: %s\n",
            SDL_GetError());
        if (fence != NULL) {
            SDL_ReleaseGPUFence(device, fence);
        }
        SDL_ReleaseGPUTransferBuffer(device, transfer);
        SDL_ReleaseGPUTexture(device, target);
        return 0;
    }
    SDL_ReleaseGPUFence(device, fence);
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
            if (!SDL_WaitForGPUIdle(gpu_slot.device)) {
                success = false;
                break;
            }
            SDL_ReleaseGPUFence(gpu_slot.device, fences[slot]);
            fences[slot] = NULL;
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
    if (success && !SDL_WaitForGPUIdle(gpu_slot.device)) {
        success = false;
    }
    for (int slot = 0; slot < slots; slot += 1) {
        if (fences[slot] != NULL) {
            SDL_ReleaseGPUFence(gpu_slot.device, fences[slot]);
            fences[slot] = NULL;
            retired += 1;
        }
    }
    Uint64 elapsed = SDL_GetPerformanceCounter() - start;
    Uint64 frequency = SDL_GetPerformanceFrequency();
    int microseconds = 0;
    if (frequency != 0) {
        microseconds = (int)((elapsed * 1000000u) / frequency);
        if (microseconds == 0) {
            microseconds = 1;
        }
    }
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
    if (gpu_slot.device != NULL) {
        SDL_WaitForGPUIdle(gpu_slot.device);
    }
    for (int slot = 0; slot < slots; slot += 1) {
        if (fences[slot] != NULL) {
            SDL_ReleaseGPUFence(gpu_slot.device, fences[slot]);
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
        if (!kookie_gpu_upload_scene_async(device, &gpu_scene) ||
            !kookie_gpu_draw_test_internal(
                NULL, targets[slot], &fences[slot])) {
            success = false;
            break;
        }
        Uint64 elapsed = SDL_GetPerformanceCounter() - start;
        if (frame >= warmup_frames) {
            Uint64 microseconds = frequency == 0
                ? 0 : (elapsed * 1000000u) / frequency;
            if (microseconds == 0) {
                microseconds = 1;
            }
            samples[frame - warmup_frames] = (int)microseconds;
        }
    }
    if (success && !SDL_WaitForGPUIdle(device)) {
        success = false;
    }
    for (int slot = 0; slot < 3; slot += 1) {
        if (fences[slot] != NULL) {
            SDL_ReleaseGPUFence(device, fences[slot]);
        }
        if (targets[slot] != NULL) {
            SDL_ReleaseGPUTexture(device, targets[slot]);
        }
    }
    if (!success) {
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
    Uint64 microseconds = (elapsed * 1000000u) / frequency;
    if (microseconds == 0) {
        microseconds = 1;
    }
    return (int)microseconds;
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
    Uint64 microseconds = (elapsed * 1000000u) / frequency;
    if (microseconds == 0) {
        microseconds = 1;
    }
    return (int)microseconds;
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
                    if (event.key.repeat) {
                        break;
                    }
                    switch (event.key.key) {
                        case SDLK_UP:
                        case SDLK_W:
                            last_event_a = 1;
                            break;
                        case SDLK_DOWN:
                        case SDLK_S:
                            last_event_a = 2;
                            break;
                        case SDLK_LEFT:
                        case SDLK_A:
                            last_event_a = 3;
                            break;
                        case SDLK_RIGHT:
                        case SDLK_D:
                            last_event_a = 4;
                            break;
                        case SDLK_RETURN:
                        case SDLK_SPACE:
                            last_event_a = 5;
                            break;
                        case SDLK_ESCAPE:
                            last_event_a = 6;
                            break;
                        default:
                            last_event_a = 0;
                            break;
                    }
                    if (last_event_a != 0) {
                        last_event_b = 0;
                        return 7;
                    }
                    break;
                case SDL_EVENT_MOUSE_BUTTON_DOWN: {
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
            audio_slot.music_track, (float)music / 100.0f)) {
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
