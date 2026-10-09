#define WIN32_LEAN_AND_MEAN
#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

#include <SDL3/SDL.h>
#include <SDL3_mixer/SDL_mixer.h>
#if SDL_VERSION != SDL_VERSIONNUM(3, 4, 16)
#error "KOOKIE requires SDL 3.4.16 headers"
#endif
#if SDL_MIXER_VERSION != SDL_VERSIONNUM(3, 2, 4)
#error "KOOKIE requires SDL_mixer 3.2.4 headers"
#endif


#include "../native/kookie_pixel_font.h"
#include "../native/kookie_audio_assets.h"

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define KOOKIE_LOGICAL_WIDTH 1280
#define KOOKIE_LOGICAL_HEIGHT 720
#define KOOKIE_LOBBY_PORT 47101
#define KOOKIE_TRANSPORT_MAGIC UINT32_C(0x4b4f4f4b)
#define KOOKIE_TRANSPORT_VERSION UINT32_C(1)
#define KOOKIE_TRANSPORT_HEADER_WORDS 6
#define KOOKIE_LOBBY_WORDS 4
#define KOOKIE_LOBBY_HELLO UINT32_C(1)
#define KOOKIE_LOBBY_ACCEPT UINT32_C(2)
#define KOOKIE_LOBBY_LEAVE UINT32_C(3)
int kookie_kof_gameplay_main(void);

typedef enum {
    SCREEN_MAIN,
    SCREEN_OPTIONS,
    SCREEN_ACCESSIBILITY,
    SCREEN_MULTIPLAYER,
    SCREEN_GAME
} Screen;

typedef enum {
    NETWORK_OFFLINE,
    NETWORK_HOSTING,
    NETWORK_JOINING,
    NETWORK_CONNECTED,
    NETWORK_FAILED
} NetworkStatus;

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
    bool initialized;
} AudioState;

typedef struct {
    SOCKET socket_fd;
    struct sockaddr_in peer;
    uint64_t key0;
    uint64_t key1;
    uint32_t send_sequence;
    uint32_t receive_sequence;
} LobbyTransport;

typedef struct {
    Screen screen;
    int selection;
    bool quit;
    int resolution;
    int display_mode;
    int effects_volume;
    int music_volume;
    int text_size;
    int hud_scale;
    bool tactical_map;
    bool high_contrast;
    int display_result;
    NetworkStatus network_status;
    bool network_editing;
    int address_field;
    int address[4];
    int port;
} AppState;

static const Uint8 palette[16][4] = {
    { 71,  85, 105, 255}, { 37,  99, 235, 255},
    { 15, 118, 110, 255}, {124,  58, 237, 255},
    {180,  83,   9, 255}, {220,  38,  38, 255},
    {  8, 145, 178, 255}, {101, 163,  13, 255},
    {100, 116, 139, 255}, { 15,  23,  42, 255},
    { 30,  41,  59, 255}, {239,  68,  68, 255},
    {245, 158,  11, 255}, { 56, 189, 248, 255},
    { 34, 197,  94, 255}, {248, 250, 252, 255}
};

static LobbyTransport lobby = {.socket_fd = INVALID_SOCKET};

static void set_color(SDL_Renderer *renderer, int color) {
    const Uint8 *rgba = palette[color & 15];
    SDL_SetRenderDrawColor(renderer, rgba[0], rgba[1], rgba[2], rgba[3]);
}

static void fill_rect(
    SDL_Renderer *renderer, float x, float y, float width, float height,
    int color
) {
    SDL_FRect rect = {x, y, width, height};
    set_color(renderer, color);
    SDL_RenderFillRect(renderer, &rect);
}

static int text_width(const char *text, int scale) {
    size_t length = strlen(text);
    return length == 0 ? 0 :
        (int)length * (KOOKIE_PIXEL_GLYPH_WIDTH + 1) * scale - scale;
}

static void draw_text_font(
    SDL_Renderer *renderer, const char *text, int x, int y,
    int scale, int color, int font
) {
    const Uint8 *rgba = palette[color & 15];
    for (const unsigned char *cursor = (const unsigned char *)text;
         *cursor != '\0'; cursor += 1) {
        int glyph = kookie_pixel_glyph_for_ascii(*cursor);
        if (glyph > 0) {
            for (int row = 0; row < KOOKIE_PIXEL_GLYPH_HEIGHT; row += 1) {
                for (int column = 0;
                     column < KOOKIE_PIXEL_GLYPH_WIDTH; column += 1) {
                    Uint8 alpha = kookie_pixel_glyph_alpha(
                        font, glyph, row, column);
                    if (alpha == 0) {
                        continue;
                    }
                    SDL_SetRenderDrawColor(
                        renderer, rgba[0], rgba[1], rgba[2], alpha);
                    SDL_FRect pixel = {
                        (float)(x + column * scale),
                        (float)(y + row * scale),
                        (float)scale,
                        (float)scale
                    };
                    SDL_RenderFillRect(renderer, &pixel);
                }
            }
        }
        x += (KOOKIE_PIXEL_GLYPH_WIDTH + 1) * scale;
    }
}

static void draw_text(
    SDL_Renderer *renderer, const char *text, int x, int y,
    int scale, int color
) {
    draw_text_font(
        renderer, text, x, y, scale, color, KOOKIE_PIXEL_FONT_JARED_LITE);
}

static void draw_centered_text_font(
    SDL_Renderer *renderer, const char *text, int y,
    int scale, int color, int font
) {
    draw_text_font(
        renderer, text,
        (KOOKIE_LOGICAL_WIDTH - text_width(text, scale)) / 2,
        y, scale, color, font);
}

static void draw_centered_text(
    SDL_Renderer *renderer, const char *text, int y, int scale, int color
) {
    draw_centered_text_font(
        renderer, text, y, scale, color, KOOKIE_PIXEL_FONT_JARED_LITE);
}

static void draw_frame(SDL_Renderer *renderer) {
    fill_rect(renderer, 0, 0, 1280, 720, 9);
    fill_rect(renderer, 24, 24, 1232, 672, 10);
    fill_rect(renderer, 30, 30, 1220, 660, 9);
}

static void draw_selection(
    SDL_Renderer *renderer, int y, bool selected
) {
    fill_rect(renderer, 130, (float)y, 1020, 54, selected ? 12 : 10);
    fill_rect(renderer, 136, (float)y + 6, 1008, 42, 9);
}
static int ui_text_color(const AppState *app, int color) {
    if (!app->high_contrast) return color;
    if (color == 11 || color == 12 || color == 13 || color == 14) return 15;
    return color;
}

static void draw_main(SDL_Renderer *renderer, const AppState *app) {
    draw_frame(renderer);
    draw_centered_text_font(
        renderer, "GATOGANSO", 76, 10, 13, KOOKIE_PIXEL_FONT_PIXAND);
    draw_centered_text(renderer, "OLD SCHOOL COOP", 164, 3, 12);
    static const char *items[] = {
        "PLAY", "MULTIPLAYER", "OPTIONS", "ACCESSIBILITY", "QUIT"
    };
    int item_scale = app->text_size + 3;
    for (int index = 0; index < 5; index += 1) {
        int y = 202 + index * 76;
        draw_selection(renderer, y, app->selection == index);
        draw_centered_text(
            renderer, items[index], y + (54 - 7 * item_scale) / 2,
            item_scale,
            ui_text_color(app, app->selection == index ?
                (index == 4 ? 11 : 12) : 15));
    }
    draw_centered_text(renderer, "ARROWS ENTER ESC", 654, 2, 8);
}

static const char *resolution_label(int resolution) {
    static const char *labels[] = {
        "1280X720", "1600X900", "1920X1080", "2560X1440"
    };
    return labels[resolution];
}

static const char *display_mode_label(int mode) {
    static const char *labels[] = {"WINDOWED", "BORDERLESS", "FULLSCREEN"};
    return labels[mode];
}

static const char *text_size_label(int size) {
    static const char *labels[] = {"SMALL", "MEDIUM", "LARGE"};
    return labels[size];
}
static const char *hud_scale_label(int scale) {
    static const char *labels[] = {"SMALL", "MEDIUM", "LARGE"};
    return labels[scale];
}

static const char *toggle_label(bool enabled) {
    return enabled ? "ON" : "OFF";
}

static void draw_volume(
    SDL_Renderer *renderer, int volume, int x, int y, int scale
) {
    char text[8];
    snprintf(text, sizeof(text), "%d%%", volume);
    draw_text(renderer, text, x, y + (54 - 7 * scale) / 2, scale, 13);
    for (int index = 0; index < 10; index += 1) {
        fill_rect(
            renderer, (float)(x + 170 + index * 25), (float)(y + 9),
            17, 24, index < volume / 10 ? 14 : 8);
    }
}

static void draw_option_row(
    SDL_Renderer *renderer, const AppState *app, int row,
    const char *label, const char *value, int scale
) {
    int y = 142 + row * 64;
    draw_selection(renderer, y, app->selection == row);
    int text_y = y + (54 - 7 * scale) / 2;
    draw_text(renderer, label, 170, text_y, scale, ui_text_color(app, 15));
    draw_text(renderer, value, 690, text_y, scale, ui_text_color(app, 13));
}

static void draw_options(SDL_Renderer *renderer, const AppState *app) {
    int text_scale = app->text_size + 3;
    draw_frame(renderer);
    draw_centered_text(renderer, "OPTIONS", 62, 7, 13);
    draw_option_row(
        renderer, app, 0, "RESOLUTION", resolution_label(app->resolution),
        text_scale);
    draw_option_row(
        renderer, app, 1, "DISPLAY MODE", display_mode_label(app->display_mode),
        text_scale);
    int fx_y = 142 + 2 * 64;
    draw_selection(renderer, fx_y, app->selection == 2);
    draw_text(
        renderer, "FX VOLUME", 170, fx_y + (54 - 7 * text_scale) / 2,
        text_scale, 15);
    draw_volume(renderer, app->effects_volume, 690, fx_y, text_scale);
    int music_y = 142 + 3 * 64;
    draw_selection(renderer, music_y, app->selection == 3);
    draw_text(
        renderer, "MUSIC VOLUME", 170,
        music_y + (54 - 7 * text_scale) / 2, text_scale, 15);
    draw_volume(renderer, app->music_volume, 690, music_y, text_scale);
    draw_option_row(
        renderer, app, 4, "TEXT SIZE", text_size_label(app->text_size),
        text_scale);
    int apply_y = 142 + 5 * 64;
    draw_selection(renderer, apply_y, app->selection == 5);
    const char *apply = app->display_result == 1 ? "APPLIED" :
        (app->display_result == 2 ? "FAILED" : "APPLY");
    draw_centered_text(
        renderer, apply, apply_y + (54 - 7 * text_scale) / 2, text_scale,
        app->display_result == 2 ? 11 : (app->selection == 5 ? 12 : 14));
    int back_y = 142 + 6 * 64;
    draw_selection(renderer, back_y, app->selection == 6);
    draw_centered_text(
        renderer, "BACK", back_y + (54 - 7 * text_scale) / 2, text_scale,
        app->selection == 6 ? 12 : 15);
    draw_centered_text(renderer, "LEFT RIGHT CHANGE", 670, 2, 8);
}
static void draw_accessibility(
    SDL_Renderer *renderer, const AppState *app
) {
    int text_scale = app->text_size + 3;
    draw_frame(renderer);
    draw_centered_text(renderer, "ACCESSIBILITY", 62, 7, 13);
    draw_centered_text(renderer, "CLEARER CONTROL", 112, 3, 14);
    draw_option_row(
        renderer, app, 0, "HUD SCALE", hud_scale_label(app->hud_scale),
        text_scale);
    draw_option_row(
        renderer, app, 1, "TACTICAL MAP", toggle_label(app->tactical_map),
        text_scale);
    draw_option_row(
        renderer, app, 2, "HIGH CONTRAST", toggle_label(app->high_contrast),
        text_scale);
    int back_y = 142 + 3 * 64;
    draw_selection(renderer, back_y, app->selection == 3);
    draw_centered_text(
        renderer, "BACK", back_y + (54 - 7 * text_scale) / 2, text_scale,
        ui_text_color(app, app->selection == 3 ? 12 : 15));
    draw_centered_text(renderer, "LEFT RIGHT CHANGE", 654, 2, 8);
}

static const char *network_status_label(NetworkStatus status) {
    switch (status) {
        case NETWORK_HOSTING: return "HOSTING";
        case NETWORK_JOINING: return "CONNECTING";
        case NETWORK_CONNECTED: return "CONNECTED";
        case NETWORK_FAILED: return "FAILED CHECK ADDRESS";
        default: return "OFFLINE";
    }
}

static int network_status_color(NetworkStatus status) {
    if (status == NETWORK_CONNECTED) return 14;
    if (status == NETWORK_FAILED) return 11;
    if (status == NETWORK_HOSTING || status == NETWORK_JOINING) return 12;
    return 15;
}

static void draw_address(
    SDL_Renderer *renderer, const AppState *app, int x, int y
) {
    int cursor = x;
    for (int index = 0; index < 4; index += 1) {
        char value[4];
        snprintf(value, sizeof(value), "%d", app->address[index]);
        int color = app->network_editing && app->address_field == index ? 12 : 13;
        draw_text(renderer, value, cursor, y, 3, color);
        cursor += text_width(value, 3) + 12;
        if (index != 3) {
            draw_text(renderer, ".", cursor, y, 3, 13);
            cursor += 24;
        }
    }
}

static void draw_multiplayer(SDL_Renderer *renderer, const AppState *app) {
    draw_frame(renderer);
    draw_centered_text(renderer, "MULTIPLAYER", 52, 7, 13);
    draw_centered_text(
        renderer, network_status_label(app->network_status), 112, 3,
        network_status_color(app->network_status));
    static const char *actions[] = {"HOST GAME", "JOIN GAME", "LEAVE GAME"};
    for (int index = 0; index < 3; index += 1) {
        int y = 178 + index * 68;
        draw_selection(renderer, y, app->selection == index);
        draw_centered_text(
            renderer, actions[index], y + 16, 3,
            app->selection == index ? (index == 2 ? 11 : 12) : 15);
    }
    int address_y = 396;
    draw_selection(renderer, address_y, app->selection == 3);
    draw_text(renderer, "ADDRESS", 170, address_y + 16, 3, 15);
    draw_address(renderer, app, 620, address_y + 16);
    int port_y = 464;
    draw_selection(renderer, port_y, app->selection == 4);
    draw_text(renderer, "PORT", 170, port_y + 16, 3, 15);
    char port[8];
    snprintf(port, sizeof(port), "%d", app->port);
    draw_text(
        renderer, port, 620, port_y + 16, 3,
        app->network_editing && app->selection == 4 ? 12 : 13);
    int back_y = 550;
    draw_selection(renderer, back_y, app->selection == 5);
    draw_centered_text(
        renderer, "BACK", back_y + 16, 3,
        app->selection == 5 ? 12 : 15);
    draw_centered_text(
        renderer,
        app->network_editing ? "ARROWS CHANGE ENTER DONE" :
            "ENTER SELECT ESC BACK",
        654, 2, 8);
}

static void draw_game(SDL_Renderer *renderer, const AppState *app) {
    fill_rect(renderer, 0, 0, 1280, 320, 1);
    fill_rect(renderer, 0, 320, 1280, 400, 10);
    fill_rect(renderer, 90, 180, 320, 390, 8);
    fill_rect(renderer, 870, 180, 320, 390, 8);
    fill_rect(renderer, 470, 250, 340, 300, 9);
    fill_rect(renderer, 606, 344, 68, 206, 4);
    for (int index = 0; index < 8; index += 1) {
        fill_rect(renderer, (float)(index * 180 - 40), 560, 120, 5, 8);
    }
    fill_rect(renderer, 634, 350, 12, 40, 15);
    fill_rect(renderer, 620, 364, 40, 12, 15);
    int hud_percent = app->hud_scale == 0 ? 85 :
        (app->hud_scale == 2 ? 115 : 100);
    int panel_height = 66 * hud_percent / 100;
    int health_width = 330 * hud_percent / 100;
    int ammo_width = 334 * hud_percent / 100;
    int health_y = 694 - panel_height;
    int ammo_x = 1254 - ammo_width;
    fill_rect(renderer, 26, health_y, health_width, panel_height, 9);
    fill_rect(renderer, ammo_x, health_y, ammo_width, panel_height, 9);
    int label_color = app->high_contrast ? 15 : 14;
    draw_text(renderer, "HEALTH 100", 48, health_y + 20, 3, label_color);
    draw_text(renderer, "AMMO 30/120", ammo_x + 26, health_y + 20, 3, 12);
    if (app->tactical_map) {
        fill_rect(renderer, 1034, 36, 210, 156, 9);
        fill_rect(renderer, 1044, 46, 190, 136, 8);
        fill_rect(renderer, 1125, 102, 28, 8, label_color);
        fill_rect(renderer, 1135, 92, 8, 28, label_color);
        draw_text(renderer, "MAP", 1050, 52, 2, label_color);
    }
    draw_text(renderer, "ESC MENU", 1080, 24, 2, 15);
}

static void render(SDL_Renderer *renderer, const AppState *app) {
    set_color(renderer, 9);
    SDL_RenderClear(renderer);
    switch (app->screen) {
        case SCREEN_OPTIONS: draw_options(renderer, app); break;
        case SCREEN_ACCESSIBILITY: draw_accessibility(renderer, app); break;
        case SCREEN_MULTIPLAYER: draw_multiplayer(renderer, app); break;
        case SCREEN_GAME: draw_game(renderer, app); break;
        default: draw_main(renderer, app); break;
    }
}


static void audio_release_music_ogg(AudioState *audio) {
    if (audio->music_ogg_track != NULL) {
        MIX_DestroyTrack(audio->music_ogg_track);
        audio->music_ogg_track = NULL;
    }
    if (audio->music_ogg_audio != NULL) {
        MIX_DestroyAudio(audio->music_ogg_audio);
        audio->music_ogg_audio = NULL;
    }
    audio->music_ogg_duration_frames = 0;
    audio->music_ogg_loaded = false;
}

static bool audio_play_predecoded_track(
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
        if (options != 0) SDL_DestroyProperties(options);
        return false;
    }
    SDL_DestroyProperties(options);
    return true;
}

static bool audio_load_music_ogg(AudioState *audio) {
    const char *path = getenv("KOOKIE_AUDIO_MUSIC_OGG");
    if (audio->mixer == NULL || path == NULL || path[0] == '\0') {
        return false;
    }
    MIX_Audio *loaded_audio = MIX_LoadAudio(audio->mixer, path, true);
    MIX_Track *loaded_track = loaded_audio == NULL ?
        NULL : MIX_CreateTrack(audio->mixer);
    Sint64 duration = loaded_audio == NULL ?
        0 : MIX_GetAudioDuration(loaded_audio);
    if (loaded_audio == NULL || loaded_track == NULL || duration <= 0 ||
        !MIX_SetTrackAudio(loaded_track, loaded_audio) ||
        !MIX_SetTrackGain(
            loaded_track, (float)audio->music_volume / 100.0f)) {
        if (loaded_track != NULL) MIX_DestroyTrack(loaded_track);
        if (loaded_audio != NULL) MIX_DestroyAudio(loaded_audio);
        return false;
    }
    audio_release_music_ogg(audio);
    audio->music_ogg_audio = loaded_audio;
    audio->music_ogg_track = loaded_track;
    audio->music_ogg_duration_frames = duration;
    audio->music_ogg_loaded = true;
    return true;
}

static bool audio_play_music_loop(AudioState *audio) {
    if (!audio->music_ogg_loaded) return false;
    return audio_play_predecoded_track(
        audio->music_ogg_track,
        audio->music_ogg_audio,
        (float)audio->music_volume / 100.0f,
        -1, 0, -1);
}

static void audio_close(AudioState *audio) {
    audio_release_music_ogg(audio);
    for (int index = 0; index < KOOKIE_AUDIO_UI_ASSET_COUNT; index += 1) {
        if (audio->ui_tracks[index] != NULL) {
            MIX_DestroyTrack(audio->ui_tracks[index]);
        }
        if (audio->ui_audio[index] != NULL) {
            MIX_DestroyAudio(audio->ui_audio[index]);
        }
    }
    if (audio->effects_track != NULL) MIX_DestroyTrack(audio->effects_track);
    if (audio->music_track != NULL) MIX_DestroyTrack(audio->music_track);
    if (audio->effects_stream != NULL) SDL_DestroyAudioStream(audio->effects_stream);
    if (audio->music_stream != NULL) SDL_DestroyAudioStream(audio->music_stream);
    if (audio->mixer != NULL) MIX_DestroyMixer(audio->mixer);
    if (audio->initialized) MIX_Quit();
    memset(audio, 0, sizeof(*audio));
}

static bool audio_load_ui_assets(AudioState *audio) {
    for (int index = 0; index < KOOKIE_AUDIO_UI_ASSET_COUNT; index += 1) {
        int clip_id = kookie_audio_ui_clip_id_at(index);
        audio->ui_audio[index] = MIX_LoadAudio(
            audio->mixer, kookie_audio_ui_clip_path(clip_id), true);
        audio->ui_tracks[index] = MIX_CreateTrack(audio->mixer);
        if (audio->ui_audio[index] == NULL ||
            audio->ui_tracks[index] == NULL ||
            !MIX_SetTrackAudio(
                audio->ui_tracks[index], audio->ui_audio[index]) ||
            !MIX_SetTrackGain(audio->ui_tracks[index], 0.8f)) {
            for (int cleanup = 0;
                 cleanup <= index && cleanup < KOOKIE_AUDIO_UI_ASSET_COUNT;
                 cleanup += 1) {
                if (audio->ui_tracks[cleanup] != NULL) {
                    MIX_DestroyTrack(audio->ui_tracks[cleanup]);
                    audio->ui_tracks[cleanup] = NULL;
                }
                if (audio->ui_audio[cleanup] != NULL) {
                    MIX_DestroyAudio(audio->ui_audio[cleanup]);
                    audio->ui_audio[cleanup] = NULL;
                }
            }
            return false;
        }
    }
    return true;
}

static bool audio_set_ui_gain(AudioState *audio, int effects_volume) {
    for (int index = 0; index < KOOKIE_AUDIO_UI_ASSET_COUNT; index += 1) {
        if (audio->ui_tracks[index] != NULL &&
            !MIX_SetTrackGain(
                audio->ui_tracks[index], effects_volume / 100.0f)) {
            return false;
        }
    }
    return true;
}

static bool audio_open(AudioState *audio) {
    memset(audio, 0, sizeof(*audio));
    if (!MIX_Init()) return false;
    audio->initialized = true;
    audio->spec.format = SDL_AUDIO_F32LE;
    audio->spec.channels = 2;
    audio->spec.freq = 48000;
    audio->mixer = MIX_CreateMixerDevice(
        SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, &audio->spec);
    audio->effects_stream = SDL_CreateAudioStream(&audio->spec, &audio->spec);
    audio->music_stream = SDL_CreateAudioStream(&audio->spec, &audio->spec);
    if (audio->mixer == NULL || audio->effects_stream == NULL ||
        audio->music_stream == NULL) {
        audio_close(audio);
        return false;
    }
    audio->effects_track = MIX_CreateTrack(audio->mixer);
    audio->music_track = MIX_CreateTrack(audio->mixer);
    SDL_PropertiesID options = SDL_CreateProperties();
    if (audio->effects_track == NULL || audio->music_track == NULL ||
        options == 0 ||
        !MIX_SetTrackAudioStream(audio->effects_track, audio->effects_stream) ||
        !MIX_SetTrackAudioStream(audio->music_track, audio->music_stream) ||
        !SDL_SetBooleanProperty(
            options, MIX_PROP_PLAY_HALT_WHEN_EXHAUSTED_BOOLEAN, false) ||
        !MIX_PlayTrack(audio->effects_track, options) ||
        !MIX_PlayTrack(audio->music_track, options)) {
        if (options != 0) SDL_DestroyProperties(options);
        audio_close(audio);
        return false;
    }
    SDL_DestroyProperties(options);
    if (!MIX_SetTrackGain(audio->effects_track, 0.8f) ||
        !MIX_SetTrackGain(audio->music_track, 0.6f)) {
        audio_close(audio);
        return false;
    }
    audio->effects_volume = 80;
    audio->music_volume = 60;
    (void)audio_load_ui_assets(audio);
    const char *music_path = getenv("KOOKIE_AUDIO_MUSIC_OGG");
    if (music_path != NULL && music_path[0] != '\0' &&
        (!audio_load_music_ogg(audio) || !audio_play_music_loop(audio))) {
        audio_close(audio);
        return false;
    }
    return true;
}

static bool audio_set_volumes(
    AudioState *audio, int effects_volume, int music_volume
) {
    if (audio->mixer == NULL ||
        effects_volume < 0 || effects_volume > 100 ||
        music_volume < 0 || music_volume > 100) {
        return false;
    }
    if (!MIX_SetTrackGain(
            audio->effects_track, effects_volume / 100.0f) ||
        !MIX_SetTrackGain(
            audio->music_track, music_volume / 100.0f) ||
        !audio_set_ui_gain(audio, effects_volume) ||
        (audio->music_ogg_track != NULL &&
            !MIX_SetTrackGain(
                audio->music_ogg_track, music_volume / 100.0f))) {
        return false;
    }
    audio->effects_volume = effects_volume;
    audio->music_volume = music_volume;
    return true;
}

static void audio_fallback_click(AudioState *audio) {
    static float samples[120 * 2];
    static bool initialized;
    if (audio->effects_stream == NULL) return;
    if (!initialized) {
        for (int frame = 0; frame < 120; frame += 1) {
            float sample = ((frame % 16) / 15.0f - 0.5f) * 0.12f;
            samples[frame * 2] = sample;
            samples[frame * 2 + 1] = sample;
        }
        initialized = true;
    }
    SDL_PutAudioStreamData(audio->effects_stream, samples, sizeof(samples));
}

static bool audio_play_ui_clip_loop(
    AudioState *audio,
    int clip_id,
    int loops,
    int loop_start_frame,
    int loop_end_frame
) {
    int index = kookie_audio_ui_clip_index(clip_id);
    if (audio->mixer == NULL || index < 0) return false;
    if (audio->ui_tracks[index] == NULL) {
        if (loops != 0) return false;
        audio_fallback_click(audio);
        return true;
    }
    return audio_play_predecoded_track(
        audio->ui_tracks[index],
        audio->ui_audio[index],
        audio->effects_volume / 100.0f,
        loops,
        loop_start_frame,
        loop_end_frame);
}

static bool audio_play_ui_clip(AudioState *audio, int clip_id) {
    return audio_play_ui_clip_loop(audio, clip_id, 0, 0, -1);
}

static uint64_t rotate_left(uint64_t value, unsigned int shift) {
    return (value << shift) | (value >> (64u - shift));
}

static uint64_t load_u64_le(const uint8_t *bytes) {
    uint64_t value = 0;
    for (unsigned int index = 0; index < 8; index += 1) {
        value |= ((uint64_t)bytes[index]) << (index * 8u);
    }
    return value;
}

static void sip_round(
    uint64_t *v0, uint64_t *v1, uint64_t *v2, uint64_t *v3
) {
    *v0 += *v1;
    *v1 = rotate_left(*v1, 13);
    *v1 ^= *v0;
    *v0 = rotate_left(*v0, 32);
    *v2 += *v3;
    *v3 = rotate_left(*v3, 16);
    *v3 ^= *v2;
    *v0 += *v3;
    *v3 = rotate_left(*v3, 21);
    *v3 ^= *v0;
    *v2 += *v1;
    *v1 = rotate_left(*v1, 17);
    *v1 ^= *v2;
    *v2 = rotate_left(*v2, 32);
}

static uint64_t transport_mac(const uint8_t *bytes, size_t length) {
    uint64_t v0 = UINT64_C(0x736f6d6570736575) ^ lobby.key0;
    uint64_t v1 = UINT64_C(0x646f72616e646f6d) ^ lobby.key1;
    uint64_t v2 = UINT64_C(0x6c7967656e657261) ^ lobby.key0;
    uint64_t v3 = UINT64_C(0x7465646279746573) ^ lobby.key1;
    size_t offset = 0;
    while (offset + 8 <= length) {
        uint64_t message = load_u64_le(bytes + offset);
        v3 ^= message;
        sip_round(&v0, &v1, &v2, &v3);
        sip_round(&v0, &v1, &v2, &v3);
        v0 ^= message;
        offset += 8;
    }
    uint64_t final_message = ((uint64_t)length) << 56;
    for (size_t index = 0; offset + index < length; index += 1) {
        final_message |= ((uint64_t)bytes[offset + index]) << (index * 8u);
    }
    v3 ^= final_message;
    sip_round(&v0, &v1, &v2, &v3);
    sip_round(&v0, &v1, &v2, &v3);
    v0 ^= final_message;
    v2 ^= UINT64_C(0xff);
    for (int index = 0; index < 4; index += 1) {
        sip_round(&v0, &v1, &v2, &v3);
    }
    return v0 ^ v1 ^ v2 ^ v3;
}

static bool parse_key_word(const char *text, uint32_t *value) {
    uint32_t parsed = 0;
    for (int index = 0; index < 8; index += 1) {
        char digit = text[index];
        uint32_t nibble;
        if (digit >= '0' && digit <= '9') nibble = (uint32_t)(digit - '0');
        else if (digit >= 'a' && digit <= 'f') nibble = (uint32_t)(digit - 'a') + 10;
        else if (digit >= 'A' && digit <= 'F') nibble = (uint32_t)(digit - 'A') + 10;
        else return false;
        parsed = (parsed << 4) | nibble;
    }
    *value = parsed;
    return true;
}

static void configure_lobby_key(void) {
    const char *encoded = getenv("KOOKIE_TRANSPORT_KEY_HEX");
    uint32_t words[4] = {
        UINT32_C(1263488843), UINT32_C(1330332754),
        UINT32_C(1229737803), UINT32_C(1162760019)
    };
    if (encoded != NULL && strlen(encoded) == 32) {
        uint32_t parsed[4];
        bool valid = true;
        for (int index = 0; index < 4; index += 1) {
            valid = valid && parse_key_word(encoded + index * 8, &parsed[index]);
        }
        if (valid) memcpy(words, parsed, sizeof(words));
    }
    lobby.key0 = (uint64_t)words[0] | ((uint64_t)words[1] << 32);
    lobby.key1 = (uint64_t)words[2] | ((uint64_t)words[3] << 32);
}

static void close_lobby(void) {
    if (lobby.socket_fd != INVALID_SOCKET) closesocket(lobby.socket_fd);
    lobby.socket_fd = INVALID_SOCKET;
    lobby.send_sequence = 0;
    lobby.receive_sequence = 0;
    memset(&lobby.peer, 0, sizeof(lobby.peer));
}

static bool open_lobby_socket(int port, bool host, const int address[4]) {
    close_lobby();
    configure_lobby_key();
    SOCKET socket_fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if (socket_fd == INVALID_SOCKET) return false;
    u_long nonblocking = 1;
    if (ioctlsocket(socket_fd, FIONBIO, &nonblocking) != 0) {
        closesocket(socket_fd);
        return false;
    }
    struct sockaddr_in local;
    memset(&local, 0, sizeof(local));
    local.sin_family = AF_INET;
    local.sin_addr.s_addr = htonl(INADDR_ANY);
    local.sin_port = htons((u_short)(host ? port : 0));
    if (bind(socket_fd, (const struct sockaddr *)&local, sizeof(local)) != 0) {
        closesocket(socket_fd);
        return false;
    }
    lobby.socket_fd = socket_fd;
    if (!host) {
        uint32_t remote = ((uint32_t)address[0] << 24) |
            ((uint32_t)address[1] << 16) |
            ((uint32_t)address[2] << 8) | (uint32_t)address[3];
        lobby.peer.sin_family = AF_INET;
        lobby.peer.sin_addr.s_addr = htonl(remote);
        lobby.peer.sin_port = htons((u_short)port);
    }
    return true;
}

static bool send_lobby_message(uint32_t operation, int port) {
    if (lobby.socket_fd == INVALID_SOCKET || lobby.peer.sin_family != AF_INET ||
        lobby.send_sequence == UINT32_MAX) return false;
    uint32_t wire[KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_LOBBY_WORDS];
    memset(wire, 0, sizeof(wire));
    wire[0] = htonl(KOOKIE_TRANSPORT_MAGIC);
    wire[1] = htonl(KOOKIE_TRANSPORT_VERSION);
    wire[2] = htonl(KOOKIE_LOBBY_WORDS);
    wire[3] = htonl(lobby.send_sequence + 1);
    wire[6] = htonl(KOOKIE_TRANSPORT_MAGIC);
    wire[7] = htonl(1);
    wire[8] = htonl(operation);
    wire[9] = htonl((uint32_t)port);
    uint64_t mac = transport_mac((const uint8_t *)wire, sizeof(wire));
    wire[4] = htonl((uint32_t)mac);
    wire[5] = htonl((uint32_t)(mac >> 32));
    int sent = sendto(
        lobby.socket_fd, (const char *)wire, sizeof(wire), 0,
        (const struct sockaddr *)&lobby.peer, sizeof(lobby.peer));
    if (sent != (int)sizeof(wire)) return false;
    lobby.send_sequence += 1;
    return true;
}

static int receive_lobby_message(struct sockaddr_in *sender) {
    if (lobby.socket_fd == INVALID_SOCKET) return 0;
    uint32_t wire[KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_LOBBY_WORDS];
    int sender_size = sizeof(*sender);
    int bytes = recvfrom(
        lobby.socket_fd, (char *)wire, sizeof(wire), 0,
        (struct sockaddr *)sender, &sender_size);
    if (bytes == SOCKET_ERROR) {
        return WSAGetLastError() == WSAEWOULDBLOCK ? 0 : -1;
    }
    if (bytes != (int)sizeof(wire) ||
        ntohl(wire[0]) != KOOKIE_TRANSPORT_MAGIC ||
        ntohl(wire[1]) != KOOKIE_TRANSPORT_VERSION ||
        ntohl(wire[2]) != KOOKIE_LOBBY_WORDS) return -1;
    uint32_t sequence = ntohl(wire[3]);
    if (sequence == 0 || sequence <= lobby.receive_sequence) return -1;
    uint64_t expected = (uint64_t)ntohl(wire[4]) |
        ((uint64_t)ntohl(wire[5]) << 32);
    wire[4] = 0;
    wire[5] = 0;
    if (transport_mac((const uint8_t *)wire, sizeof(wire)) != expected) return -1;
    if (ntohl(wire[6]) != KOOKIE_TRANSPORT_MAGIC || ntohl(wire[7]) != 1) {
        return -1;
    }
    lobby.receive_sequence = sequence;
    return (int)ntohl(wire[8]);
}

static void service_lobby(AppState *app) {
    if (app->network_status != NETWORK_HOSTING &&
        app->network_status != NETWORK_JOINING &&
        app->network_status != NETWORK_CONNECTED) return;
    struct sockaddr_in sender;
    memset(&sender, 0, sizeof(sender));
    int operation = receive_lobby_message(&sender);
    if (operation < 0) {
        app->network_status = NETWORK_FAILED;
        close_lobby();
    } else if (operation == (int)KOOKIE_LOBBY_LEAVE) {
        app->network_status = NETWORK_OFFLINE;
        close_lobby();
    } else if (app->network_status == NETWORK_HOSTING &&
               operation == (int)KOOKIE_LOBBY_HELLO) {
        lobby.peer = sender;
        if (send_lobby_message(KOOKIE_LOBBY_ACCEPT, app->port)) {
            app->network_status = NETWORK_CONNECTED;
        } else {
            app->network_status = NETWORK_FAILED;
            close_lobby();
        }
    } else if (app->network_status == NETWORK_JOINING &&
               operation == (int)KOOKIE_LOBBY_ACCEPT) {
        app->network_status = NETWORK_CONNECTED;
    }
}

static bool apply_display(SDL_Window *window, const AppState *app) {
    static const int widths[] = {1280, 1600, 1920, 2560};
    static const int heights[] = {720, 900, 1080, 1440};
    int width = widths[app->resolution];
    int height = heights[app->resolution];
    if ((SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN) != 0 &&
        (!SDL_SetWindowFullscreen(window, false) ||
         !SDL_SyncWindow(window))) {
        return false;
    }
    if (app->display_mode == 0 || app->display_mode == 1) {
        if (!SDL_SetWindowBordered(window, app->display_mode == 0) ||
            !SDL_SetWindowResizable(window, app->display_mode == 0) ||
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
    if (display == 0) return false;
    SDL_DisplayMode mode;
    if (!SDL_GetClosestFullscreenDisplayMode(
            display, width, height, 0.0f, true, &mode) ||
        !SDL_SetWindowFullscreenMode(window, &mode) ||
        !SDL_SetWindowFullscreen(window, true) ||
        !SDL_SyncWindow(window)) {
        return false;
    }
    return (SDL_GetWindowFlags(window) & SDL_WINDOW_FULLSCREEN) != 0;
}

static void move_selection(AppState *app, int direction) {
    int count = app->screen == SCREEN_MAIN ? 5 :
        (app->screen == SCREEN_OPTIONS ? 7 :
        (app->screen == SCREEN_ACCESSIBILITY ? 4 : 6));
    app->selection = (app->selection + direction + count) % count;
}

static bool adjust_options(AppState *app, int direction, AudioState *audio) {
    if (app->selection == 0) {
        app->resolution = (app->resolution + direction + 4) % 4;
    } else if (app->selection == 1) {
        app->display_mode = (app->display_mode + direction + 3) % 3;
    } else if (app->selection == 2) {
        app->effects_volume += direction * 10;
        if (app->effects_volume < 0) app->effects_volume = 0;
        if (app->effects_volume > 100) app->effects_volume = 100;
        audio_set_volumes(audio, app->effects_volume, app->music_volume);
    } else if (app->selection == 3) {
        app->music_volume += direction * 10;
        if (app->music_volume < 0) app->music_volume = 0;
        if (app->music_volume > 100) app->music_volume = 100;
        audio_set_volumes(audio, app->effects_volume, app->music_volume);
    } else if (app->selection == 4) {
        app->text_size = (app->text_size + direction + 3) % 3;
    } else {
        return false;
    }
    app->display_result = 0;
    return true;
}

static bool adjust_accessibility(AppState *app, int direction) {
    if (app->selection == 0) {
        app->hud_scale = (app->hud_scale + direction + 3) % 3;
    } else if (app->selection == 1) {
        app->tactical_map = direction > 0;
    } else if (app->selection == 2) {
        app->high_contrast = direction > 0;
    } else {
        return false;
    }
    return true;
}

static void start_host(AppState *app) {
    if (app->network_status != NETWORK_OFFLINE &&
        app->network_status != NETWORK_FAILED) return;
    app->network_status = open_lobby_socket(
        app->port, true, app->address) ? NETWORK_HOSTING : NETWORK_FAILED;
}

static void start_join(AppState *app) {
    if (app->network_status != NETWORK_OFFLINE &&
        app->network_status != NETWORK_FAILED) return;
    if (open_lobby_socket(app->port, false, app->address) &&
        send_lobby_message(KOOKIE_LOBBY_HELLO, app->port)) {
        app->network_status = NETWORK_JOINING;
    } else {
        app->network_status = NETWORK_FAILED;
        close_lobby();
    }
}

static void leave_lobby(AppState *app) {
    if (app->network_status == NETWORK_CONNECTED) {
        send_lobby_message(KOOKIE_LOBBY_LEAVE, app->port);
    }
    close_lobby();
    app->network_status = NETWORK_OFFLINE;
}

static bool edit_network(AppState *app, SDL_Keycode key) {
    if (key == SDLK_RETURN || key == SDLK_SPACE || key == SDLK_ESCAPE) {
        app->network_editing = false;
        return true;
    }
    if (app->selection == 3) {
        if (key == SDLK_LEFT) {
            app->address_field = (app->address_field + 3) % 4;
            return true;
        }
        if (key == SDLK_RIGHT) {
            app->address_field = (app->address_field + 1) % 4;
            return true;
        }
        if (key == SDLK_UP || key == SDLK_DOWN) {
            int change = key == SDLK_UP ? 1 : -1;
            app->address[app->address_field] =
                (app->address[app->address_field] + change + 256) % 256;
            return true;
        }
    }
    if (app->selection == 4) {
        int change = 0;
        if (key == SDLK_LEFT) change = -100;
        if (key == SDLK_RIGHT) change = 100;
        if (key == SDLK_UP) change = 1;
        if (key == SDLK_DOWN) change = -1;
        if (change != 0) {
            app->port += change;
            if (app->port < 1024) app->port = 65535;
            if (app->port > 65535) app->port = 1024;
            return true;
        }
    }
    return false;
}

static bool activate(
    AppState *app, SDL_Window *window, AudioState *audio
) {
    if (app->screen == SCREEN_MAIN) {
        if (app->selection == 0) app->screen = SCREEN_GAME;
        else if (app->selection == 1) {
            app->screen = SCREEN_MULTIPLAYER;
            app->selection = 0;
        } else if (app->selection == 2) {
            app->screen = SCREEN_OPTIONS;
            app->selection = 0;
        } else if (app->selection == 3) {
            app->screen = SCREEN_ACCESSIBILITY;
            app->selection = 0;
        } else app->quit = true;
        return true;
    }
    if (app->screen == SCREEN_ACCESSIBILITY) {
        if (app->selection < 3) return adjust_accessibility(app, 1);
        app->screen = SCREEN_MAIN;
        app->selection = 3;
        return true;
    }
    if (app->screen == SCREEN_OPTIONS) {
        if (app->selection <= 4) return adjust_options(app, 1, audio);
        if (app->selection == 5) {
            app->display_result = apply_display(window, app) ? 1 : 2;
            return true;
        }
        app->screen = SCREEN_MAIN;
        app->selection = 0;
        return true;
    }
    if (app->screen == SCREEN_MULTIPLAYER) {
        if (app->selection == 0) start_host(app);
        else if (app->selection == 1) start_join(app);
        else if (app->selection == 2) leave_lobby(app);
        else if (app->selection == 3 || app->selection == 4) {
            app->network_editing = true;
        } else {
            app->screen = SCREEN_MAIN;
            app->selection = 1;
        }
        return true;
    }
    return false;
}

static bool handle_key(
    AppState *app, SDL_Window *window, AudioState *audio, SDL_Keycode key
) {
    if (app->screen == SCREEN_GAME) {
        if (key == SDLK_ESCAPE) {
            app->screen = SCREEN_MAIN;
            app->selection = 0;
            return true;
        }
        return false;
    }
    if (app->network_editing) return edit_network(app, key);
    if (key == SDLK_UP || key == SDLK_W) {
        move_selection(app, -1);
        return true;
    }
    if (key == SDLK_DOWN || key == SDLK_S) {
        move_selection(app, 1);
        return true;
    }
    if ((key == SDLK_LEFT || key == SDLK_A) && app->screen == SCREEN_OPTIONS) {
        return adjust_options(app, -1, audio);
    }
    if ((key == SDLK_RIGHT || key == SDLK_D) && app->screen == SCREEN_OPTIONS) {
        return adjust_options(app, 1, audio);
    }
    if ((key == SDLK_LEFT || key == SDLK_A) &&
        app->screen == SCREEN_ACCESSIBILITY) {
        return adjust_accessibility(app, -1);
    }
    if ((key == SDLK_RIGHT || key == SDLK_D) &&
        app->screen == SCREEN_ACCESSIBILITY) {
        return adjust_accessibility(app, 1);
    }
    if (key == SDLK_RETURN || key == SDLK_SPACE) {
        return activate(app, window, audio);
    }
    if (key == SDLK_ESCAPE) {
        if (app->screen == SCREEN_MAIN) app->quit = true;
        else {
            Screen previous = app->screen;
            app->screen = SCREEN_MAIN;
            app->selection = previous == SCREEN_ACCESSIBILITY ? 3 : 0;
        }
        return true;
    }
    return false;
}

static bool handle_click(
    AppState *app, SDL_Window *window, AudioState *audio, float x, float y
) {
    if (x < 100 || x > 1180 || app->screen == SCREEN_GAME) return false;
    if (app->screen == SCREEN_MAIN) {
        for (int index = 0; index < 5; index += 1) {
            int top = 202 + index * 76;
            if (y >= top && y <= top + 54) {
                app->selection = index;
                return activate(app, window, audio);
            }
        }
    } else if (app->screen == SCREEN_OPTIONS ||
               app->screen == SCREEN_ACCESSIBILITY) {
        int count = app->screen == SCREEN_OPTIONS ? 7 : 4;
        for (int index = 0; index < count; index += 1) {
            int top = 142 + index * 64;
            if (y >= top && y <= top + 54) {
                app->selection = index;
                return activate(app, window, audio);
            }
        }
    } else {
        const int tops[] = {178, 246, 314, 396, 464, 550};
        for (int index = 0; index < 6; index += 1) {
            if (y >= tops[index] && y <= tops[index] + 54) {
                app->selection = index;
                return activate(app, window, audio);
            }
        }
    }
    return false;
}
static int audio_clip_for_key(
    Screen before, const AppState *app, SDL_Keycode key, bool handled
) {
    if (before == SCREEN_GAME) {
        if (key == SDLK_ESCAPE && handled) {
            return KOOKIE_AUDIO_UI_POPUP_CLOSE_1;
        }
        if (key == SDLK_RETURN || key == SDLK_SPACE) {
            return KOOKIE_AUDIO_UI_SELECT_2;
        }
        return 0;
    }
    if (!handled) {
        if (key == SDLK_RETURN || key == SDLK_SPACE) {
            return KOOKIE_AUDIO_UI_ERROR_1;
        }
        return 0;
    }
    if (key == SDLK_UP || key == SDLK_W) {
        return KOOKIE_AUDIO_UI_CURSOR_1;
    }
    if (key == SDLK_DOWN || key == SDLK_S) {
        return KOOKIE_AUDIO_UI_CURSOR_2;
    }
    if (key == SDLK_LEFT || key == SDLK_A) {
        return KOOKIE_AUDIO_UI_SWIPE_1;
    }
    if (key == SDLK_RIGHT || key == SDLK_D) {
        return KOOKIE_AUDIO_UI_SWIPE_2;
    }
    if (key == SDLK_RETURN || key == SDLK_SPACE) {
        return before == app->screen
            ? KOOKIE_AUDIO_UI_SELECT_1
            : KOOKIE_AUDIO_UI_POPUP_OPEN_1;
    }
    if (key == SDLK_ESCAPE) {
        return before == SCREEN_MAIN
            ? KOOKIE_AUDIO_UI_CANCEL_1
            : KOOKIE_AUDIO_UI_POPUP_CLOSE_1;
    }
    return 0;
}

static int audio_clip_for_click(
    Screen before, const AppState *app, bool clicked
) {
    if (before == SCREEN_GAME) {
        return KOOKIE_AUDIO_UI_SELECT_2;
    }
    if (!clicked) return 0;
    return before == app->screen
        ? KOOKIE_AUDIO_UI_SELECT_1
        : KOOKIE_AUDIO_UI_POPUP_OPEN_1;
}

static Uint64 explicit_deadline(void) {

    const char *value = getenv("KOOKIE_VISUAL_TEST_MILLISECONDS");
    if (value == NULL || *value == '\0') return 0;
    char *end = NULL;
    unsigned long long milliseconds = strtoull(value, &end, 10);
    if (end == value || *end != '\0' || milliseconds == 0) return 0;
    return SDL_GetTicks() + (Uint64)milliseconds;
}

static bool save_screenshot(SDL_Renderer *renderer) {
    const char *path = getenv("KOOKIE_WINDOWS_SCREENSHOT_PATH");
    if (path == NULL || path[0] == '\0') return true;
    SDL_Surface *surface = SDL_RenderReadPixels(renderer, NULL);
    if (surface == NULL) return false;
    bool saved = SDL_SaveBMP(surface, path);
    SDL_DestroySurface(surface);
    return saved;
}

int main(int argc, char **argv) {
    const char *mode = argc > 1 ? argv[1] : "";
    bool package_smoke = strcmp(mode, "--package-smoke") == 0;
    bool visual_smoke = strcmp(mode, "--visual-smoke") == 0 ||
        strcmp(mode, "--visual-smoke-options") == 0 ||
        strcmp(mode, "--visual-smoke-accessibility") == 0 ||
        strcmp(mode, "--visual-smoke-multiplayer") == 0;
    int linked_sdl = SDL_GetVersion();
    int linked_mixer = MIX_Version();
    bool dependency_versions_match =
        linked_sdl == SDL_VERSION && linked_mixer == SDL_MIXER_VERSION;
    if (package_smoke) {
        if (!dependency_versions_match) {
            fprintf(stderr,
                "KOOKIE dependency mismatch SDL=%d SDL_mixer=%d\n",
                linked_sdl, linked_mixer);
            return 8;
        }
        printf(
            "KOOKIE Windows package smoke verified SDL=%d SDL_mixer=%d\n",
            linked_sdl, linked_mixer);
        return 0;
    }
    if (!dependency_versions_match) return 9;
    if (!SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_EVENTS)) return 10;
    WSADATA winsock_data;
    bool winsock_ready = WSAStartup(MAKEWORD(2, 2), &winsock_data) == 0;

    SDL_Window *window = SDL_CreateWindow(
        "GatoGanso", 1280, 720,
        SDL_WINDOW_RESIZABLE | SDL_WINDOW_HIGH_PIXEL_DENSITY);
    if (window == NULL) {
        if (winsock_ready) WSACleanup();
        SDL_Quit();
        return 11;
    }
    SDL_SetWindowMinimumSize(window, 640, 360);
    if (visual_smoke) {
        int resized_width = 0;
        int resized_height = 0;
        bool window_capabilities_ok =
            (SDL_GetWindowFlags(window) & SDL_WINDOW_RESIZABLE) != 0 &&
            SDL_SetWindowSize(window, 1024, 640) &&
            SDL_SyncWindow(window) &&
            SDL_GetWindowSize(window, &resized_width, &resized_height) &&
            resized_width == 1024 && resized_height == 640 &&
            SDL_MaximizeWindow(window) &&
            SDL_SyncWindow(window) &&
            (SDL_GetWindowFlags(window) & SDL_WINDOW_MAXIMIZED) != 0 &&
            SDL_RestoreWindow(window) &&
            SDL_SyncWindow(window);
        if (!window_capabilities_ok) {
            SDL_DestroyWindow(window);
            if (winsock_ready) WSACleanup();
            SDL_Quit();
            return 14;
        }
    }
    SDL_Renderer *renderer = SDL_CreateRenderer(window, NULL);
    if (renderer == NULL ||
        !SDL_SetRenderLogicalPresentation(
            renderer, KOOKIE_LOGICAL_WIDTH, KOOKIE_LOGICAL_HEIGHT,
            SDL_LOGICAL_PRESENTATION_LETTERBOX) ||
        !SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND)) {
        if (renderer != NULL) SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        if (winsock_ready) WSACleanup();
        SDL_Quit();
        return 12;
    }
    if (kookie_kof_gameplay_main() != 0) {
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        if (winsock_ready) WSACleanup();
        SDL_Quit();
        return 16;
    }
    printf("KOOKIE native Kof PE gameplay verified\n");
    SDL_SetRenderVSync(renderer, 1);

    AppState app = {
        .screen = SCREEN_MAIN,
        .text_size = 1,
        .effects_volume = 80,
        .music_volume = 60,
        .hud_scale = 1,
        .tactical_map = true,
        .high_contrast = false,
        .network_status = NETWORK_OFFLINE,
        .address = {127, 0, 0, 1},
        .port = KOOKIE_LOBBY_PORT
    };
    if (strcmp(mode, "--visual-smoke-options") == 0) {
        app.screen = SCREEN_OPTIONS;
    } else if (strcmp(mode, "--visual-smoke-accessibility") == 0) {
        app.screen = SCREEN_ACCESSIBILITY;
    } else if (strcmp(mode, "--visual-smoke-multiplayer") == 0) {
        app.screen = SCREEN_MULTIPLAYER;
    }
    const char *lobby_smoke_role = getenv("KOOKIE_LOBBY_SMOKE_ROLE");
    bool lobby_smoke_host = lobby_smoke_role != NULL &&
        strcmp(lobby_smoke_role, "host") == 0;
    bool lobby_smoke_join = lobby_smoke_role != NULL &&
        strcmp(lobby_smoke_role, "join") == 0;
    bool lobby_smoke = lobby_smoke_host || lobby_smoke_join;
    bool lobby_smoke_seen_connection = false;
    bool lobby_smoke_success = false;
    if (lobby_smoke) {
        app.screen = SCREEN_MULTIPLAYER;
        if (lobby_smoke_host) start_host(&app);
        else start_join(&app);
    }
    AudioState audio;
    bool audio_ready = audio_open(&audio);
    if (audio_ready) {
        audio_set_volumes(&audio, app.effects_volume, app.music_volume);
    }

    Uint64 deadline = explicit_deadline();
    int rendered_frames = 0;
    bool screenshot_saved = false;
    while (!app.quit) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT ||
                event.type == SDL_EVENT_WINDOW_CLOSE_REQUESTED) {
                app.quit = true;
            } else if (event.type == SDL_EVENT_KEY_DOWN && !event.key.repeat) {
                Screen before = app.screen;
                bool handled = handle_key(&app, window, &audio, event.key.key);
                if (audio_ready) {
                    int clip = audio_clip_for_key(
                        before, &app, event.key.key, handled);
                    if (clip > 0) {
                        (void)audio_play_ui_clip(&audio, clip);
                    }
                }
            } else if (event.type == SDL_EVENT_MOUSE_BUTTON_DOWN &&
                       event.button.button == SDL_BUTTON_LEFT) {
                SDL_ConvertEventToRenderCoordinates(renderer, &event);
                Screen before = app.screen;
                bool clicked = handle_click(
                    &app, window, &audio,
                    event.button.x, event.button.y);
                if (audio_ready) {
                    int clip = audio_clip_for_click(before, &app, clicked);
                    if (clip > 0) {
                        (void)audio_play_ui_clip(&audio, clip);
                    }
                }
            }
        }
        if (winsock_ready) service_lobby(&app);
        if (lobby_smoke_join && app.network_status == NETWORK_CONNECTED) {
            lobby_smoke_seen_connection = true;
            leave_lobby(&app);
            lobby_smoke_success = true;
            app.quit = true;
        } else if (lobby_smoke_host) {
            if (app.network_status == NETWORK_CONNECTED) {
                lobby_smoke_seen_connection = true;
            } else if (lobby_smoke_seen_connection &&
                       app.network_status == NETWORK_OFFLINE) {
                lobby_smoke_success = true;
                app.quit = true;
            }
        }
        render(renderer, &app);
        rendered_frames += 1;
        if (visual_smoke && rendered_frames >= 3 && !screenshot_saved) {
            screenshot_saved = save_screenshot(renderer);
            app.quit = true;
        }
        SDL_RenderPresent(renderer);
        if (deadline != 0 && SDL_GetTicks() >= deadline) app.quit = true;
        SDL_Delay(8);
    }

    close_lobby();
    if (audio_ready) audio_close(&audio);
    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    if (winsock_ready) WSACleanup();
    SDL_Quit();
    if (visual_smoke && !screenshot_saved) return 13;
    if (lobby_smoke && !lobby_smoke_success) return 15;
    if (lobby_smoke_success) {
        printf("KOOKIE Windows lobby host join leave smoke verified\n");
    }
    return 0;
}
