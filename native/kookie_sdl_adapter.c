#include <SDL3/SDL.h>

#include <stdbool.h>
#include <stddef.h>

#define KOOKIE_MAX_WINDOWS 8
#define KOOKIE_WINDOW_KIND 1
#define KOOKIE_AUDIO_KIND 2

typedef struct {
    SDL_Window *window;
    unsigned int generation;
} KookieWindowSlot;

typedef struct {
    SDL_AudioDeviceID device;
    unsigned int generation;
} KookieAudioSlot;

static KookieWindowSlot window_slots[KOOKIE_MAX_WINDOWS];
static KookieAudioSlot audio_slot;
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
    for (int i = 0; i < KOOKIE_MAX_WINDOWS; i += 1) {
        if (window_slots[i].window != NULL) {
            SDL_DestroyWindow(window_slots[i].window);
            window_slots[i].window = NULL;
            window_slots[i].generation += 1;
        }
    }
    if (audio_slot.device != 0) {
        SDL_CloseAudioDevice(audio_slot.device);
        audio_slot.device = 0;
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
    if (audio_slot.device != 0) {
        return 0;
    }

    SDL_AudioDeviceID device = SDL_OpenAudioDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, NULL);
    if (device == 0) {
        return 0;
    }
    if (audio_slot.generation == 0) {
        audio_slot.generation = 1;
    }
    audio_slot.device = device;
    return make_token(0, audio_slot.generation, KOOKIE_AUDIO_KIND);
}

bool kookie_audio_close(int token) {
    int slot;
    unsigned int generation;
    if (!decode_token(token, KOOKIE_AUDIO_KIND, &slot, &generation) || slot != 0) {
        return false;
    }
    if (audio_slot.device == 0 || audio_slot.generation != generation) {
        return false;
    }

    SDL_CloseAudioDevice(audio_slot.device);
    audio_slot.device = 0;
    audio_slot.generation += 1;
    return true;
}
