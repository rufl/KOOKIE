#include <SDL3/SDL.h>

#include <SDL3/SDL_gpu.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>
#define KOOKIE_MAX_WINDOWS 8
#define KOOKIE_TRANSPORT_MAX_WORDS 78
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
    SDL_AudioStream *stream;
    SDL_AudioSpec spec;
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
    SDL_GPUTexture *texture;
    SDL_GPUBuffer *vertex_buffer;
    SDL_GPUBuffer *index_buffer;
    SDL_GPUSampler *sampler;
    bool ready;
} KookieGpuResources;

typedef struct {
    int socket_fd;
    int receive_socket_fd;
    struct sockaddr_in peer;
    uint64_t key0;
    uint64_t key1;
    bool key_configured;
    int send_count;
    uint32_t send_sequence;
    uint32_t send_words[KOOKIE_TRANSPORT_MAX_WORDS];
    int receive_count;
    uint32_t receive_sequence;
    int last_status;
    int receive_words[KOOKIE_TRANSPORT_MAX_WORDS];
} KookieTransport;
static KookieTransport transport = {
    .socket_fd = -1,
    .receive_socket_fd = -1
};
static int gpu_recovery_state = KOOKIE_GPU_RECOVERY_UNAVAILABLE;

static KookieGpuResources gpu_resources;
static int last_gpu_fence_wait_microseconds;

static KookieWindowSlot window_slots[KOOKIE_MAX_WINDOWS];
static KookieAudioSlot audio_slot;
static void kookie_gpu_release_resources(SDL_GPUDevice *device) {
    if (device == NULL || !gpu_resources.ready) {
        memset(&gpu_resources, 0, sizeof(gpu_resources));
        return;
    }
    SDL_WaitForGPUIdle(device);
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
    if (gpu_resources.pipeline != NULL) {
        SDL_ReleaseGPUGraphicsPipeline(device, gpu_resources.pipeline);
    }
    if (gpu_resources.fragment_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.fragment_shader);
    }
    if (gpu_resources.vertex_shader != NULL) {
        SDL_ReleaseGPUShader(device, gpu_resources.vertex_shader);
    }
    memset(&gpu_resources, 0, sizeof(gpu_resources));
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
static uint64_t kookie_rotate_left(uint64_t value, unsigned int shift) {
    return (value << shift) | (value >> (64u - shift));
}

static uint64_t kookie_load_u64_le(const Uint8 *bytes) {
    uint64_t value = 0;
    for (unsigned int index = 0; index < 8; index += 1) {
        value |= ((uint64_t)bytes[index]) << (index * 8u);
    }
    return value;
}

static void kookie_sip_round(
    uint64_t *v0, uint64_t *v1, uint64_t *v2, uint64_t *v3
) {
    *v0 += *v1;
    *v1 = kookie_rotate_left(*v1, 13);
    *v1 ^= *v0;
    *v0 = kookie_rotate_left(*v0, 32);
    *v2 += *v3;
    *v3 = kookie_rotate_left(*v3, 16);
    *v3 ^= *v2;
    *v0 += *v3;
    *v3 = kookie_rotate_left(*v3, 21);
    *v3 ^= *v0;
    *v2 += *v1;
    *v1 = kookie_rotate_left(*v1, 17);
    *v1 ^= *v2;
    *v2 = kookie_rotate_left(*v2, 32);
}

static uint64_t kookie_transport_mac(const Uint8 *bytes, size_t length) {
    const uint64_t key0 = transport.key0;
    const uint64_t key1 = transport.key1;
    uint64_t v0 = UINT64_C(0x736f6d6570736575) ^ key0;
    uint64_t v1 = UINT64_C(0x646f72616e646f6d) ^ key1;
    uint64_t v2 = UINT64_C(0x6c7967656e657261) ^ key0;
    uint64_t v3 = UINT64_C(0x7465646279746573) ^ key1;
    size_t offset = 0;
    while (offset + 8 <= length) {
        uint64_t message = kookie_load_u64_le(bytes + offset);
        v3 ^= message;
        kookie_sip_round(&v0, &v1, &v2, &v3);
        kookie_sip_round(&v0, &v1, &v2, &v3);
        v0 ^= message;
        offset += 8;
    }
    uint64_t final_message = ((uint64_t)length) << 56;
    for (size_t index = 0; offset + index < length; index += 1) {
        final_message |= ((uint64_t)bytes[offset + index]) << (index * 8);
    }
    v3 ^= final_message;
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    v0 ^= final_message;
    v2 ^= UINT64_C(0xff);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    kookie_sip_round(&v0, &v1, &v2, &v3);
    return v0 ^ v1 ^ v2 ^ v3;
}
static bool kookie_transport_bind_socket(
    int *socket_fd,
    struct sockaddr_in *address
) {
    int next_socket = socket(AF_INET, SOCK_DGRAM, 0);
    if (next_socket < 0) {
        return false;
    }
    memset(address, 0, sizeof(*address));
    address->sin_family = AF_INET;
    address->sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address->sin_port = htons(0);
    if (bind(next_socket, (struct sockaddr *)address, sizeof(*address)) != 0) {
        close(next_socket);
        return false;
    }
    socklen_t address_length = sizeof(*address);
    if (getsockname(
            next_socket, (struct sockaddr *)address, &address_length) != 0) {
        close(next_socket);
        return false;
    }
    struct timeval receive_timeout = {
        .tv_sec = KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS / 1000,
        .tv_usec = (KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS % 1000) * 1000
    };
    if (setsockopt(
            next_socket, SOL_SOCKET, SO_RCVTIMEO,
            &receive_timeout, sizeof(receive_timeout)) != 0) {
        close(next_socket);
        return false;
    }
    *socket_fd = next_socket;
    return true;
}

static void kookie_transport_reset_counters(void) {
    transport.send_count = 0;
    transport.send_sequence = 0;
    transport.receive_count = 0;
    transport.receive_sequence = 0;
    transport.last_status = 0;
}



bool kookie_transport_set_key(
    int key0_low, int key0_high, int key1_low, int key1_high
) {
    if (transport.socket_fd >= 0) {
        return false;
    }
    uint64_t next_key0 =
        (uint64_t)(uint32_t)key0_low |
        ((uint64_t)(uint32_t)key0_high << 32);
    uint64_t next_key1 =
        (uint64_t)(uint32_t)key1_low |
        ((uint64_t)(uint32_t)key1_high << 32);
    if (next_key0 == 0 && next_key1 == 0) {
        return false;
    }
    transport.key0 = next_key0;
    transport.key1 = next_key1;
    transport.key_configured = true;
    return true;
}

bool kookie_transport_open(void) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in peer;
    if (!kookie_transport_bind_socket(&socket_fd, &peer)) {
        return false;
    }
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = peer;
    kookie_transport_reset_counters();
    return true;
}

bool kookie_transport_open_pair(void) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    int receive_socket_fd = -1;
    struct sockaddr_in peer;
    struct sockaddr_in receive_address;
    if (!kookie_transport_bind_socket(&socket_fd, &peer) ||
        !kookie_transport_bind_socket(&receive_socket_fd, &receive_address)) {
        if (socket_fd >= 0) {
            close(socket_fd);
        }
        if (receive_socket_fd >= 0) {
            close(receive_socket_fd);
        }
        return false;
    }
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = receive_socket_fd;
    transport.peer = receive_address;
    kookie_transport_reset_counters();
    return true;
}
bool kookie_transport_set_peer_ipv4(
    int first_octet, int second_octet, int third_octet,
    int fourth_octet, int port
) {
    if (transport.socket_fd < 0 ||
        first_octet < 0 || first_octet > 255 ||
        second_octet < 0 || second_octet > 255 ||
        third_octet < 0 || third_octet > 255 ||
        fourth_octet < 0 || fourth_octet > 255 ||
        port <= 0 || port > 65535) {
        return false;
    }
    uint32_t address =
        ((uint32_t)first_octet << 24) |
        ((uint32_t)second_octet << 16) |
        ((uint32_t)third_octet << 8) |
        (uint32_t)fourth_octet;
    transport.peer.sin_family = AF_INET;
    transport.peer.sin_addr.s_addr = htonl(address);
    transport.peer.sin_port = htons((uint16_t)port);
    return true;
}

int kookie_transport_peer_port(void) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    return (int)ntohs(transport.peer.sin_port);
}


bool kookie_transport_send_begin(int word_count) {
    if (transport.socket_fd < 0 ||
        word_count <= 0 ||
        word_count > KOOKIE_TRANSPORT_MAX_WORDS) {
        return false;
    }
    transport.send_count = word_count;
    return true;
}

bool kookie_transport_send_word(int index, int word) {
    if (transport.socket_fd < 0 ||
        index < 0 ||
        index >= transport.send_count) {
        return false;
    }
    transport.send_words[index] = (uint32_t)word;
    return true;
}

bool kookie_transport_send_commit(void) {
    if (transport.socket_fd < 0 ||
        transport.send_count <= 0 ||
        transport.send_sequence == UINT32_MAX) {
        return false;
    }
    uint32_t wire[
        KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_TRANSPORT_MAX_WORDS];
    int frame_words = KOOKIE_TRANSPORT_HEADER_WORDS + transport.send_count;
    wire[0] = htonl(KOOKIE_TRANSPORT_MAGIC);
    wire[1] = htonl(KOOKIE_TRANSPORT_VERSION);
    wire[2] = htonl((uint32_t)transport.send_count);
    wire[3] = htonl(transport.send_sequence + 1);
    wire[4] = 0;
    wire[5] = 0;
    for (int index = 0; index < transport.send_count; index += 1) {
        wire[KOOKIE_TRANSPORT_HEADER_WORDS + index] =
            htonl(transport.send_words[index]);
    }
    size_t bytes = (size_t)frame_words * sizeof(uint32_t);
    uint64_t mac = kookie_transport_mac((const Uint8 *)wire, bytes);
    wire[4] = htonl((uint32_t)mac);
    wire[5] = htonl((uint32_t)(mac >> 32));
    ssize_t sent = sendto(
        transport.socket_fd,
        wire,
        bytes,
        0,
        (struct sockaddr *)&transport.peer,
        sizeof(transport.peer));
    transport.send_count = 0;
    if (sent != (ssize_t)bytes) {
        return false;
    }
    transport.send_sequence += 1;
    return true;
}

int kookie_transport_receive(void) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    uint32_t wire[
        KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_TRANSPORT_MAX_WORDS];
    ssize_t bytes = recvfrom(
        transport.receive_socket_fd,
        wire,
        sizeof(wire),
        0,
        NULL,
        NULL);
    if (bytes < 0) {
        transport.receive_count = 0;
        transport.last_status =
            errno == EAGAIN || errno == EWOULDBLOCK ? 2 : 3;
        return 0;
    }
    if (bytes <= 0 ||
        bytes % (ssize_t)sizeof(uint32_t) != 0 ||
        bytes > (ssize_t)sizeof(wire)) {
        transport.receive_count = 0;
        transport.last_status = 3;
        return 0;
    }
    int frame_words = (int)(bytes / (ssize_t)sizeof(uint32_t));
    uint32_t payload_count = ntohl(wire[2]);
    uint32_t sequence = ntohl(wire[3]);
    if (ntohl(wire[0]) != KOOKIE_TRANSPORT_MAGIC ||
        ntohl(wire[1]) != KOOKIE_TRANSPORT_VERSION ||
        payload_count == 0 ||
        payload_count > KOOKIE_TRANSPORT_MAX_WORDS ||
        frame_words != KOOKIE_TRANSPORT_HEADER_WORDS + (int)payload_count ||
        sequence == 0 ||
        sequence <= transport.receive_sequence) {
        transport.receive_count = 0;
        transport.last_status = 3;
        return 0;
    }
    uint64_t expected_mac =
        (uint64_t)ntohl(wire[4]) |
        ((uint64_t)ntohl(wire[5]) << 32);
    uint32_t received_mac_low = wire[4];
    uint32_t received_mac_high = wire[5];
    wire[4] = 0;
    wire[5] = 0;
    uint64_t actual_mac = kookie_transport_mac(
        (const Uint8 *)wire, bytes);
    wire[4] = received_mac_low;
    wire[5] = received_mac_high;
    if (actual_mac != expected_mac) {
        transport.receive_count = 0;
        transport.last_status = 3;
        return 0;
    }
    transport.receive_count = (int)payload_count;
    transport.receive_sequence = sequence;
    for (int index = 0; index < transport.receive_count; index += 1) {
        transport.receive_words[index] =
            (int)ntohl(wire[KOOKIE_TRANSPORT_HEADER_WORDS + index]);
    }
    transport.last_status = 1;
    return transport.receive_count;
}

int kookie_transport_receive_word(int index) {
    if (index < 0 || index >= transport.receive_count) {
        return 0;
    }
    return transport.receive_words[index];
}

int kookie_transport_receive_sum(void) {
    int sum = 0;
    for (int index = 0; index < transport.receive_count; index += 1) {
        sum += transport.receive_words[index];
    }
    return sum;
}

int kookie_transport_last_status(void) {
    return transport.last_status;
}

int kookie_transport_timeout_milliseconds(void) {
    return KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS;
}

bool kookie_transport_close(void) {
    if (transport.socket_fd < 0) {
        return false;
    }
    close(transport.socket_fd);
    if (transport.receive_socket_fd >= 0 &&
        transport.receive_socket_fd != transport.socket_fd) {
        close(transport.receive_socket_fd);
    }
    memset(&transport, 0, sizeof(transport));
    transport.socket_fd = -1;
    transport.receive_socket_fd = -1;
    transport.key0 = 0;
    transport.key1 = 0;
    transport.key_configured = false;
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
    if (audio_slot.stream != NULL) {
        SDL_DestroyAudioStream(audio_slot.stream);
        audio_slot.stream = NULL;
        audio_slot.generation += 1;
    }
    if (transport.socket_fd >= 0) {
        kookie_transport_close();
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
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_READY;
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

    SDL_GPUDevice *device = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, NULL);
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

bool kookie_gpu_mark_headless_device_lost(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1 ||
        gpu_recovery_state != KOOKIE_GPU_RECOVERY_READY) {
        return false;
    }
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_LOST;
    return true;
}

bool kookie_gpu_recover_headless(void) {
    if (gpu_slot.device == NULL || gpu_slot.window_slot != -1 ||
        gpu_recovery_state != KOOKIE_GPU_RECOVERY_LOST) {
        return false;
    }
    gpu_recovery_state = KOOKIE_GPU_RECOVERY_FAILED;
    kookie_gpu_release_resources(gpu_slot.device);
    SDL_DestroyGPUDevice(gpu_slot.device);
    gpu_slot.device = NULL;
    gpu_slot.generation += 1;
    return kookie_gpu_open_headless() > 0;
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
    size_t vertex_size = 0;
    size_t fragment_size = 0;
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
    gpu_resources.vertex_shader = SDL_CreateGPUShader(device, &vertex_info);
    if (gpu_resources.vertex_shader == NULL) {
        goto cleanup;
    }

    SDL_GPUShaderCreateInfo fragment_info = {0};
    fragment_info.code_size = fragment_size;
    fragment_info.code = fragment_code;
    fragment_info.entrypoint = "main";
    fragment_info.format = SDL_GPU_SHADERFORMAT_SPIRV;
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
    texture_info.width = 2;
    texture_info.height = 2;
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

    SDL_GPUBufferCreateInfo mesh_index_info = {0};
    mesh_index_info.usage = SDL_GPU_BUFFERUSAGE_INDEX;
    mesh_index_info.size = 12;
    gpu_resources.index_buffer = SDL_CreateGPUBuffer(device, &mesh_index_info);
    if (gpu_resources.index_buffer == NULL) {
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

    SDL_GPUTransferBufferCreateInfo transfer_info = {0};
    transfer_info.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
    transfer_info.size = 128;
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
    const float vertices[24] = {
        -0.8f, -0.8f, 0.0f, 1.0f,
         0.8f, -0.8f, 1.0f, 1.0f,
         0.8f,  0.8f, 1.0f, 0.0f,
        -0.8f, -0.8f, 0.0f, 1.0f,
         0.8f,  0.8f, 1.0f, 0.0f,
        -0.8f,  0.8f, 0.0f, 0.0f
    };
    const Uint16 indices[6] = {0, 1, 2, 3, 4, 5};
    memcpy(pixels, checker, sizeof(checker));
    memcpy(pixels + 16, vertices, sizeof(vertices));
    memcpy(pixels + 112, indices, sizeof(indices));
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
    destination.w = 2;
    destination.h = 2;
    destination.d = 1;
    SDL_UploadToGPUTexture(copy_pass, &source, &destination, false);
    SDL_GPUTransferBufferLocation vertex_source = {0};
    vertex_source.transfer_buffer = transfer;
    vertex_source.offset = 16;
    SDL_GPUBufferRegion vertex_destination = {0};
    vertex_destination.buffer = gpu_resources.vertex_buffer;
    vertex_destination.size = 96;
    SDL_UploadToGPUBuffer(copy_pass, &vertex_source, &vertex_destination, false);
    SDL_GPUTransferBufferLocation index_source = {0};
    index_source.transfer_buffer = transfer;
    index_source.offset = 112;
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
    free(vertex_code);
    if (!success) {
        kookie_gpu_release_resources(device);
    }
    return success;
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
    SDL_GPUBufferBinding vertex_binding = {0};
    vertex_binding.buffer = gpu_resources.vertex_buffer;
    SDL_GPUBufferBinding index_binding = {0};
    index_binding.buffer = gpu_resources.index_buffer;
    SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.pipeline);
    SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
    SDL_BindGPUIndexBuffer(render_pass, &index_binding, SDL_GPU_INDEXELEMENTSIZE_16BIT);
    SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
    SDL_DrawGPUIndexedPrimitives(render_pass, 6, 1, 0, 0, 0);
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
    return kookie_gpu_draw_test_internal(
        window_slots[gpu_slot.window_slot].window, NULL, NULL);
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
    bool success = kookie_gpu_draw_test_internal(NULL, target, NULL);
    SDL_ReleaseGPUTexture(gpu_slot.device, target);
    return success;
}
int kookie_gpu_measure_headless_overlap(int frames, int slots) {
    if (frames <= 0 || frames > 8 || slots <= 0 || slots > 2 ||
        gpu_slot.device == NULL || gpu_slot.window_slot != -1) {
        return 0;
    }
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
