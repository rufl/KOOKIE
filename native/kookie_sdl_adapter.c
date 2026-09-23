#include <SDL3/SDL.h>

#include <SDL3/SDL_gpu.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
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
int kookie_gpu_open_headless(void) {
    if (gpu_slot.device != NULL) {
        return 0;
    }

    SDL_GPUDevice *device = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, NULL);
    if (device == NULL) {
        return 0;
    }
    if (gpu_slot.generation == 0) {
        gpu_slot.generation = 1;
    }
    gpu_slot.device = device;
    gpu_slot.window_slot = -1;
    int token = make_token(0, gpu_slot.generation, KOOKIE_GPU_KIND);
    return token;
}
bool kookie_gpu_open_headless_ready(void) {
    return kookie_gpu_open_headless() > 0;
}

bool kookie_gpu_close_headless(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1) {
        return false;
    }
    SDL_DestroyGPUDevice(gpu_slot.device);
    gpu_slot.device = NULL;
    gpu_slot.window_slot = -1;
    gpu_slot.generation += 1;
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
    SDL_DestroyGPUDevice(gpu_slot.device);
    gpu_slot.device = NULL;
    gpu_slot.window_slot = -1;
    gpu_slot.generation += 1;
    return true;
}

static bool read_shader_binary(const char *name, Uint8 **bytes, size_t *size) {
    const char *directory = getenv("KOOKIE_SHADER_DIR");
    char path[512];
    if (directory == NULL) {
        directory = "build";
    }
    if (snprintf(path, sizeof(path), "%s/%s.spv", directory, name) < 0) {
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
    if (data == NULL || fread(data, 1, (size_t)length, file) != (size_t)length) {
        free(data);
        fclose(file);
        return false;
    }
    fclose(file);
    *bytes = data;
    *size = (size_t)length;
    return true;
}

static bool kookie_gpu_draw_test_internal(
    SDL_Window *window,
    SDL_GPUTexture *offscreen_target
) {
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

    Uint8 *vertex_code = NULL;
    Uint8 *fragment_code = NULL;
    size_t vertex_size = 0;
    size_t fragment_size = 0;
    SDL_GPUShader *vertex_shader = NULL;
    SDL_GPUShader *fragment_shader = NULL;
    SDL_GPUGraphicsPipeline *pipeline = NULL;
    SDL_GPUTexture *texture = NULL;
    SDL_GPUSampler *sampler = NULL;
    SDL_GPUTransferBuffer *transfer = NULL;
    SDL_GPUCommandBuffer *command_buffer = NULL;
    bool success = false;

    if (!read_shader_binary("g0_triangle.vert", &vertex_code, &vertex_size) ||
        !read_shader_binary("g0_triangle.frag", &fragment_code, &fragment_size)) {
        goto cleanup;
    }

    SDL_GPUShaderCreateInfo vertex_info = {0};
    vertex_info.code_size = vertex_size;
    vertex_info.code = vertex_code;
    vertex_info.entrypoint = "main";
    vertex_info.format = SDL_GPU_SHADERFORMAT_SPIRV;
    vertex_info.stage = SDL_GPU_SHADERSTAGE_VERTEX;
    vertex_shader = SDL_CreateGPUShader(device, &vertex_info);
    if (vertex_shader == NULL) {
        goto cleanup;
    }

    SDL_GPUShaderCreateInfo fragment_info = {0};
    fragment_info.code_size = fragment_size;
    fragment_info.code = fragment_code;
    fragment_info.entrypoint = "main";
    fragment_info.format = SDL_GPU_SHADERFORMAT_SPIRV;
    fragment_info.stage = SDL_GPU_SHADERSTAGE_FRAGMENT;
    fragment_info.num_samplers = 1;
    fragment_shader = SDL_CreateGPUShader(device, &fragment_info);
    if (fragment_shader == NULL) {
        goto cleanup;
    }

    SDL_GPUTextureCreateInfo texture_info = {0};
    texture_info.type = SDL_GPU_TEXTURETYPE_2D;
    texture_info.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    texture_info.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;
    texture_info.width = 2;
    texture_info.height = 2;
    texture_info.layer_count_or_depth = 1;
    texture_info.num_levels = 1;
    texture_info.sample_count = SDL_GPU_SAMPLECOUNT_1;
    texture = SDL_CreateGPUTexture(device, &texture_info);
    if (texture == NULL) {
        goto cleanup;
    }

    SDL_GPUTransferBufferCreateInfo transfer_info = {0};
    transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    transfer_info.size = 16;
    transfer = SDL_CreateGPUTransferBuffer(device, &transfer_info);
    if (transfer == NULL) {
        goto cleanup;
    }
    Uint8 *pixels = (Uint8 *)SDL_MapGPUTransferBuffer(device, transfer, false);
    if (pixels == NULL) {
        goto cleanup;
    }
    const Uint8 checker[16] = {
        255, 64, 64, 255, 64, 255, 64, 255,
        64, 64, 255, 255, 255, 255, 64, 255
    };
    memcpy(pixels, checker, sizeof(checker));
    SDL_UnmapGPUTransferBuffer(device, transfer);

    SDL_GPUSamplerCreateInfo sampler_info = {0};
    sampler_info.min_filter = SDL_GPU_FILTER_NEAREST;
    sampler_info.mag_filter = SDL_GPU_FILTER_NEAREST;
    sampler_info.mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
    sampler_info.address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    sampler_info.address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    sampler_info.address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
    sampler_info.max_lod = 1.0f;
    sampler = SDL_CreateGPUSampler(device, &sampler_info);
    if (sampler == NULL) {
        goto cleanup;
    }

    SDL_GPUColorTargetDescription color_target = {0};
    color_target.format = target_format;
    SDL_GPUGraphicsPipelineCreateInfo pipeline_info = {0};
    pipeline_info.vertex_shader = vertex_shader;
    pipeline_info.fragment_shader = fragment_shader;
    pipeline_info.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
    pipeline_info.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
    pipeline_info.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
    pipeline_info.rasterizer_state.front_face = SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE;
    pipeline_info.rasterizer_state.enable_depth_clip = true;
    pipeline_info.multisample_state.sample_count = SDL_GPU_SAMPLECOUNT_1;
    pipeline_info.target_info.color_target_descriptions = &color_target;
    pipeline_info.target_info.num_color_targets = 1;
    pipeline = SDL_CreateGPUGraphicsPipeline(device, &pipeline_info);
    if (pipeline == NULL) {
        goto cleanup;
    }

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
    destination.texture = texture;
    destination.w = 2;
    destination.h = 2;
    destination.d = 1;
    SDL_UploadToGPUTexture(copy_pass, &source, &destination, false);
    SDL_EndGPUCopyPass(copy_pass);

    SDL_GPUTexture *render_target = offscreen_target;
    Uint32 target_width = 320;
    Uint32 target_height = 240;
    if (window != NULL) {
        Uint32 swapchain_width = 0;
        Uint32 swapchain_height = 0;
        if (!SDL_WaitAndAcquireGPUSwapchainTexture(
                command_buffer, window, &render_target,
                &swapchain_width, &swapchain_height) ||
            render_target == NULL || swapchain_width == 0 || swapchain_height == 0) {
            goto cleanup;
        }
        target_width = swapchain_width;
        target_height = swapchain_height;
    }
    if (target_width == 0 || target_height == 0) {
        goto cleanup;
    }

    SDL_GPUColorTargetInfo target = {0};
    target.texture = render_target;
    target.clear_color.r = 0.05f;
    target.clear_color.g = 0.05f;
    target.clear_color.b = 0.05f;
    target.clear_color.a = 1.0f;
    target.load_op = SDL_GPU_LOADOP_CLEAR;
    target.store_op = SDL_GPU_STOREOP_STORE;
    SDL_GPURenderPass *render_pass = SDL_BeginGPURenderPass(command_buffer, &target, 1, NULL);
    if (render_pass == NULL) {
        goto cleanup;
    }
    SDL_GPUTextureSamplerBinding binding = {0};
    binding.texture = texture;
    binding.sampler = sampler;
    SDL_BindGPUGraphicsPipeline(render_pass, pipeline);
    SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
    SDL_DrawGPUPrimitives(render_pass, 6, 1, 0, 0);
    SDL_EndGPURenderPass(render_pass);
    if (!SDL_SubmitGPUCommandBuffer(command_buffer)) {
        goto cleanup;
    }
    command_buffer = NULL;
    success = SDL_WaitForGPUIdle(device);

cleanup:
    if (command_buffer != NULL) {
        SDL_CancelGPUCommandBuffer(command_buffer);
    }
    if (transfer != NULL) {
        SDL_ReleaseGPUTransferBuffer(device, transfer);
    }
    if (texture != NULL) {
        SDL_ReleaseGPUTexture(device, texture);
    }
    if (sampler != NULL) {
        SDL_ReleaseGPUSampler(device, sampler);
    }
    if (pipeline != NULL) {
        SDL_ReleaseGPUGraphicsPipeline(device, pipeline);
    }
    if (fragment_shader != NULL) {
        SDL_ReleaseGPUShader(device, fragment_shader);
    }
    if (vertex_shader != NULL) {
        SDL_ReleaseGPUShader(device, vertex_shader);
    }
    free(fragment_code);
    free(vertex_code);
    return success;
}

bool kookie_gpu_draw_test(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot < 0 ||
        gpu_slot.window_slot >= KOOKIE_MAX_WINDOWS ||
        window_slots[gpu_slot.window_slot].window == NULL) {
        return false;
    }
    return kookie_gpu_draw_test_internal(
        window_slots[gpu_slot.window_slot].window, NULL);
}

bool kookie_gpu_draw_headless_test(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1) {
        return false;
    }

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
    bool success = kookie_gpu_draw_test_internal(NULL, target);
    SDL_ReleaseGPUTexture(gpu_slot.device, target);
    return success;
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
    fprintf(stderr, "KOOKIE gpu-headless-draw-us=%d budget-us=%d\n",
        microseconds, budget_microseconds);
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

int kookie_poll_event(void) {
    SDL_Event event;
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
            default:
                break;
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

bool kookie_audio_queue_clip(int clip_id, int frames) {
    static float clip[480 * 2];
    static bool initialized;
    if (audio_slot.stream == NULL || clip_id != 1 || frames <= 0 || frames > 480) {
        return false;
    }
    if (!initialized) {
        for (int frame = 0; frame < 480; frame += 1) {
            int phase = frame % 24;
            float sample = ((float)phase / 23.0f) * 0.4f - 0.2f;
            clip[frame * 2] = sample;
            clip[frame * 2 + 1] = sample;
        }
        initialized = true;
    }
    return SDL_PutAudioStreamData(
        audio_slot.stream,
        clip,
        frames * audio_slot.spec.channels * (int)sizeof(float));
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
