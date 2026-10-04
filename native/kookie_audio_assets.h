#ifndef KOOKIE_AUDIO_ASSETS_H
#define KOOKIE_AUDIO_ASSETS_H

#define KOOKIE_AUDIO_UI_CURSOR_1 1001
#define KOOKIE_AUDIO_UI_CURSOR_2 1002
#define KOOKIE_AUDIO_UI_CURSOR_3 1003
#define KOOKIE_AUDIO_UI_CURSOR_4 1004
#define KOOKIE_AUDIO_UI_CURSOR_5 1005
#define KOOKIE_AUDIO_UI_CANCEL_1 1010
#define KOOKIE_AUDIO_UI_CANCEL_2 1011
#define KOOKIE_AUDIO_UI_ERROR_1 1020
#define KOOKIE_AUDIO_UI_POPUP_CLOSE_1 1030
#define KOOKIE_AUDIO_UI_POPUP_OPEN_1 1031
#define KOOKIE_AUDIO_UI_SELECT_1 1040
#define KOOKIE_AUDIO_UI_SELECT_2 1041
#define KOOKIE_AUDIO_UI_SWIPE_1 1050
#define KOOKIE_AUDIO_UI_SWIPE_2 1051
#define KOOKIE_AUDIO_UI_ASSET_COUNT 14

static inline int kookie_audio_ui_clip_id_at(int index) {
    static const int clip_ids[KOOKIE_AUDIO_UI_ASSET_COUNT] = {
        KOOKIE_AUDIO_UI_CURSOR_1,
        KOOKIE_AUDIO_UI_CURSOR_2,
        KOOKIE_AUDIO_UI_CURSOR_3,
        KOOKIE_AUDIO_UI_CURSOR_4,
        KOOKIE_AUDIO_UI_CURSOR_5,
        KOOKIE_AUDIO_UI_CANCEL_1,
        KOOKIE_AUDIO_UI_CANCEL_2,
        KOOKIE_AUDIO_UI_ERROR_1,
        KOOKIE_AUDIO_UI_POPUP_CLOSE_1,
        KOOKIE_AUDIO_UI_POPUP_OPEN_1,
        KOOKIE_AUDIO_UI_SELECT_1,
        KOOKIE_AUDIO_UI_SELECT_2,
        KOOKIE_AUDIO_UI_SWIPE_1,
        KOOKIE_AUDIO_UI_SWIPE_2
    };
    if (index < 0 || index >= KOOKIE_AUDIO_UI_ASSET_COUNT) {
        return 0;
    }
    return clip_ids[index];
}

static inline int kookie_audio_ui_clip_index(int clip_id) {
    if (clip_id >= KOOKIE_AUDIO_UI_CURSOR_1 &&
        clip_id <= KOOKIE_AUDIO_UI_CURSOR_5) {
        return clip_id - KOOKIE_AUDIO_UI_CURSOR_1;
    }
    if (clip_id >= KOOKIE_AUDIO_UI_CANCEL_1 &&
        clip_id <= KOOKIE_AUDIO_UI_CANCEL_2) {
        return 5 + clip_id - KOOKIE_AUDIO_UI_CANCEL_1;
    }
    if (clip_id == KOOKIE_AUDIO_UI_ERROR_1) {
        return 7;
    }
    if (clip_id == KOOKIE_AUDIO_UI_POPUP_CLOSE_1) {
        return 8;
    }
    if (clip_id == KOOKIE_AUDIO_UI_POPUP_OPEN_1) {
        return 9;
    }
    if (clip_id >= KOOKIE_AUDIO_UI_SELECT_1 &&
        clip_id <= KOOKIE_AUDIO_UI_SELECT_2) {
        return 10 + clip_id - KOOKIE_AUDIO_UI_SELECT_1;
    }
    if (clip_id >= KOOKIE_AUDIO_UI_SWIPE_1 &&
        clip_id <= KOOKIE_AUDIO_UI_SWIPE_2) {
        return 12 + clip_id - KOOKIE_AUDIO_UI_SWIPE_1;
    }
    return -1;
}

static inline const char *kookie_audio_ui_clip_path(int clip_id) {
    switch (clip_id) {
        case KOOKIE_AUDIO_UI_CURSOR_1:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 1.ogg";
        case KOOKIE_AUDIO_UI_CURSOR_2:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 2.ogg";
        case KOOKIE_AUDIO_UI_CURSOR_3:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 3.ogg";
        case KOOKIE_AUDIO_UI_CURSOR_4:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 4.ogg";
        case KOOKIE_AUDIO_UI_CURSOR_5:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cursor - 5.ogg";
        case KOOKIE_AUDIO_UI_CANCEL_1:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cancel - 1.ogg";
        case KOOKIE_AUDIO_UI_CANCEL_2:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Cancel - 2.ogg";
        case KOOKIE_AUDIO_UI_ERROR_1:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Error - 1.ogg";
        case KOOKIE_AUDIO_UI_POPUP_CLOSE_1:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Popup Close - 1.ogg";
        case KOOKIE_AUDIO_UI_POPUP_OPEN_1:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Popup Open - 1.ogg";
        case KOOKIE_AUDIO_UI_SELECT_1:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Select - 1.ogg";
        case KOOKIE_AUDIO_UI_SELECT_2:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Select - 2.ogg";
        case KOOKIE_AUDIO_UI_SWIPE_1:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Swipe - 1.ogg";
        case KOOKIE_AUDIO_UI_SWIPE_2:
            return "assets/audio/ui/JDSherbert - Ultimate UI SFX Pack - Swipe - 2.ogg";
        default:
            return 0;
    }
}

#endif
