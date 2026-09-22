#include <SDL3/SDL.h>
#include <SDL3/SDL_gpu.h>

#include <stdbool.h>
#include <stddef.h>
#define KOOKIE_MAX_WINDOWS 8
#define KOOKIE_WINDOW_KIND 1
#define KOOKIE_AUDIO_KIND 2
#define KOOKIE_GPU_KIND 3

typedef struct {
    SDL_Window *window;
    unsigned int generation;
} KookieWindowSlot;

typedef struct {
    SDL_AudioStream *stream;
    SDL_AudioSpec spec;
    unsigned int generation;
} KookieAudioSlot;

typedef struct {
    SDL_GPUDevice *device;
    int window_slot;
    unsigned int generation;
} KookieGpuSlot;

static KookieWindowSlot window_slots[KOOKIE_MAX_WINDOWS];
static KookieAudioSlot audio_slot;
static KookieGpuSlot gpu_slot;
static int last_event_a;
static int last_event_b;

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

bool kookie_sdl_init(int flags) {
    if (flags < 0) {
        return false;
    }
    return SDL_Init((SDL_InitFlags)flags);
}

void kookie_sdl_shutdown(void) {
    if (gpu_slot.device != NULL) {
        if (gpu_slot.window_slot >= 0 && gpu_slot.window_slot < KOOKIE_MAX_WINDOWS &&
            window_slots[gpu_slot.window_slot].window != NULL) {
            SDL_ReleaseWindowFromGPUDevice(gpu_slot.device, window_slots[gpu_slot.window_slot].window);
        }
        SDL_DestroyGPUDevice(gpu_slot.device);
        gpu_slot.device = NULL;
        gpu_slot.window_slot = -1;
        gpu_slot.generation += 1;
    }
    for (int i = 0; i < KOOKIE_MAX_WINDOWS; i += 1) {
        if (window_slots[i].window != NULL) {
            SDL_DestroyWindow(window_slots[i].window);
            window_slots[i].window = NULL;
            window_slots[i].generation += 1;
        }
    }
    if (audio_slot.stream != NULL) {
        SDL_DestroyAudioStream(audio_slot.stream);
        audio_slot.stream = NULL;
        audio_slot.generation += 1;
    }
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

    SDL_WindowFlags flags = hidden ? SDL_WINDOW_HIDDEN : 0;
    SDL_Window *window = SDL_CreateWindow("KOOKIE G0", width, height, flags);
    if (window == NULL) {
        return 0;
    }

    if (window_slots[slot].generation == 0) {
        window_slots[slot].generation = 1;
    }
    window_slots[slot].window = window;
    return make_token(slot, window_slots[slot].generation, KOOKIE_WINDOW_KIND);
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

    SDL_GPUDevice *device = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, NULL);
    if (device == NULL || !SDL_ClaimWindowForGPUDevice(device, window_slots[window_slot].window)) {
        if (device != NULL) {
            SDL_DestroyGPUDevice(device);
        }
        return 0;
    }

    if (gpu_slot.generation == 0) {
        gpu_slot.generation = 1;
    }
    gpu_slot.device = device;
    gpu_slot.window_slot = window_slot;
    return make_token(0, gpu_slot.generation, KOOKIE_GPU_KIND);
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
    SDL_DestroyGPUDevice(gpu_slot.device);
    gpu_slot.device = NULL;
    gpu_slot.window_slot = -1;
    gpu_slot.generation += 1;
    return true;
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
    SDL_Event event = {0};
    event.type = focused ? SDL_EVENT_WINDOW_FOCUS_GAINED : SDL_EVENT_WINDOW_FOCUS_LOST;
    return SDL_PushEvent(&event);
}

int kookie_poll_event(void) {
    SDL_Event event;
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
            default:
                break;
        }
    }
    return 0;
}

int kookie_last_event_a(void) {
    return last_event_a;
}

int kookie_last_event_b(void) {
    return last_event_b;
}

int kookie_audio_open(void) {
    if (audio_slot.stream != NULL) {
        return 0;
    }

    audio_slot.spec.format = SDL_AUDIO_F32LE;
    audio_slot.spec.channels = 2;
    audio_slot.spec.freq = 48000;
    SDL_AudioStream *stream = SDL_OpenAudioDeviceStream(
        SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK,
        &audio_slot.spec,
        NULL,
        NULL);
    if (stream == NULL || !SDL_ResumeAudioStreamDevice(stream)) {
        if (stream != NULL) {
            SDL_DestroyAudioStream(stream);
        }
        return 0;
    }
    if (audio_slot.generation == 0) {
        audio_slot.generation = 1;
    }
    audio_slot.stream = stream;
    return make_token(0, audio_slot.generation, KOOKIE_AUDIO_KIND);
}

bool kookie_audio_queue_silence(int frames) {
    static unsigned char silence[4096 * 8];
    if (audio_slot.stream == NULL || frames <= 0 || frames > 4096) {
        return false;
    }
    int bytes = frames * audio_slot.spec.channels * (int)sizeof(float);
    return SDL_PutAudioStreamData(audio_slot.stream, silence, bytes);
}

bool kookie_audio_close(int token) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_AUDIO_KIND, &slot, &generation) || slot != 0) {
        return false;
    }
    if (audio_slot.stream == NULL || audio_slot.generation != generation) {
        return false;
    }

    SDL_DestroyAudioStream(audio_slot.stream);
    audio_slot.stream = NULL;
    audio_slot.generation += 1;
    return true;
}
