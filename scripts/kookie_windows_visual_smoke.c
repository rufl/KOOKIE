#define WIN32_LEAN_AND_MEAN
#include <SDL3/SDL.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

static Uint64 smoke_deadline(void) {
    const char *value = getenv("KOOKIE_VISUAL_TEST_MILLISECONDS");
    if (value == NULL || *value == '\0') return 0;
    char *end = NULL;
    unsigned long long milliseconds = strtoull(value, &end, 10);
    if (end == value || *end != '\0' || milliseconds == 0) return 0;
    return SDL_GetTicks() + (Uint64)milliseconds;
}

int main(int argc, char **argv) {
    bool smoke = argc > 1 && strcmp(argv[1], "--package-smoke") == 0;
    if (!SDL_Init(SDL_INIT_VIDEO)) return 10;

    SDL_Window *window = SDL_CreateWindow(
        "KOOKIE Visual Test",
        1280,
        720,
        SDL_WINDOW_RESIZABLE
    );
    if (window == NULL) {
        SDL_Quit();
        return 11;
    }
    SDL_Renderer *renderer = SDL_CreateRenderer(window, NULL);
    if (renderer == NULL) {
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 12;
    }

    Uint64 deadline = smoke ? SDL_GetTicks() + 250 : smoke_deadline();
    bool running = true;
    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            if (event.type == SDL_EVENT_QUIT) running = false;
        }
        if (deadline != 0 && SDL_GetTicks() >= deadline) running = false;

        Uint64 tick = SDL_GetTicks();
        float phase = (float)(tick % 2000) / 2000.0f;
        SDL_SetRenderDrawColor(renderer, 8, 12, 24, 255);
        SDL_RenderClear(renderer);

        SDL_FRect panel = {80.0f, 80.0f, 1120.0f, 560.0f};
        SDL_SetRenderDrawColor(renderer, 20, 32, 64, 255);
        SDL_RenderFillRect(renderer, &panel);

        SDL_FRect bar = {140.0f + phase * 900.0f, 330.0f, 180.0f, 60.0f};
        SDL_SetRenderDrawColor(renderer, 80, 210, 180, 255);
        SDL_RenderFillRect(renderer, &bar);

        SDL_FRect marker = {140.0f + (1.0f - phase) * 900.0f, 430.0f, 100.0f, 20.0f};
        SDL_SetRenderDrawColor(renderer, 240, 180, 80, 255);
        SDL_RenderFillRect(renderer, &marker);
        SDL_RenderPresent(renderer);
        SDL_Delay(16);
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
