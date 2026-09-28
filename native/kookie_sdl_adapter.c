#include <SDL3/SDL.h>

#include <SDL3/SDL_gpu.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <errno.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#define KOOKIE_MAX_WINDOWS 8
#define KOOKIE_TRANSPORT_MAX_SLOTS 4
#define KOOKIE_TRANSPORT_MAX_WORDS 300
#define KOOKIE_GPU_SCENE_MAX_VERTICES 256
#define KOOKIE_GPU_PALETTE_WIDTH 4
#define KOOKIE_GPU_PALETTE_COLORS 16
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
    int socket_fd;
    int receive_socket_fd;
    struct sockaddr_in peer;
    struct sockaddr_in last_sender;
    bool last_sender_valid;
    uint64_t key0;
    uint64_t key1;
    bool key_configured;
    int send_count;
    uint32_t send_sequence;
    uint32_t send_words[KOOKIE_TRANSPORT_MAX_WORDS];
    int last_send_bytes;
    bool last_send_valid;
    uint32_t last_send_wire[
        KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_TRANSPORT_MAX_WORDS];
    int receive_count;
    uint32_t receive_sequence;
    int last_status;
    int receive_words[KOOKIE_TRANSPORT_MAX_WORDS];
} KookieTransport;
static KookieTransport transport_slots[KOOKIE_TRANSPORT_MAX_SLOTS] = {
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    },
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    },
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    },
    {
        .socket_fd = -1,
        .receive_socket_fd = -1
    }
};
static KookieTransport *active_transport = &transport_slots[0];
#define transport (*active_transport)
static int gpu_recovery_state = KOOKIE_GPU_RECOVERY_UNAVAILABLE;

static KookieGpuResources gpu_resources;
static KookieGpuScene gpu_scene;
static int last_gpu_fence_wait_microseconds;

static KookieWindowSlot window_slots[KOOKIE_MAX_WINDOWS];
static KookieAudioSlot audio_slot;
static void kookie_gpu_release_resources(SDL_GPUDevice *device) {
    if (device == NULL || !gpu_resources.ready) {
        memset(&gpu_resources, 0, sizeof(gpu_resources));
        return;
    }
    SDL_WaitForGPUIdle(device);
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
static void kookie_gpu_retire_resources(
    SDL_GPUDevice *device, bool device_lost
) {
    if (device_lost) {
        memset(&gpu_resources, 0, sizeof(gpu_resources));
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
static int kookie_transport_receive_timeout_milliseconds(void) {
    const char *encoded = getenv("KOOKIE_EXTERNAL_LAN_TIMEOUT_MILLISECONDS");
    if (encoded == NULL || encoded[0] == '\0') {
        return KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS;
    }
    char *end = NULL;
    long value = strtol(encoded, &end, 10);
    if (end == encoded || *end != '\0' || value < 1 || value > 60000) {
        return KOOKIE_TRANSPORT_TIMEOUT_MILLISECONDS;
    }
    return (int)value;
}

static bool kookie_transport_bind_socket_configured(
    int *socket_fd,
    uint32_t bind_address,
    int port,
    struct sockaddr_in *address
) {
    if (port < 0 || port > 65535) {
        return false;
    }
    int next_socket = socket(AF_INET, SOCK_DGRAM, 0);
    if (next_socket < 0) {
        return false;
    }
    memset(address, 0, sizeof(*address));
    address->sin_family = AF_INET;
    address->sin_addr.s_addr = htonl(bind_address);
    address->sin_port = htons((uint16_t)port);
    if (bind(
            next_socket,
            (struct sockaddr *)address,
            sizeof(*address)) != 0) {
        close(next_socket);
        return false;
    }
    socklen_t address_length = sizeof(*address);
    if (getsockname(
            next_socket, (struct sockaddr *)address, &address_length) != 0) {
        close(next_socket);
        return false;
    }
    int timeout_milliseconds =
        kookie_transport_receive_timeout_milliseconds();
    struct timeval receive_timeout = {
        .tv_sec = timeout_milliseconds / 1000,
        .tv_usec = (timeout_milliseconds % 1000) * 1000
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
static bool kookie_transport_bind_socket(
    int *socket_fd,
    struct sockaddr_in *address
) {
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_LOOPBACK, 0, address);
}
static bool kookie_transport_bind_socket_any(
    int *socket_fd,
    struct sockaddr_in *address
) {
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_ANY, 0, address);
}
static bool kookie_transport_bind_socket_at(
    int *socket_fd,
    int port,
    struct sockaddr_in *address
) {
    if (port <= 0 || port > 65535) {
        return false;
    }
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_LOOPBACK, port, address);
}
static bool kookie_transport_bind_socket_any_at(
    int *socket_fd,
    int port,
    struct sockaddr_in *address
) {
    if (port <= 0 || port > 65535) {
        return false;
    }
    return kookie_transport_bind_socket_configured(
        socket_fd, INADDR_ANY, port, address);
}


bool kookie_transport_select_slot(int slot) {
    if (slot < 0 || slot >= KOOKIE_TRANSPORT_MAX_SLOTS) {
        return false;
    }
    active_transport = &transport_slots[slot];
    return true;
}

static void kookie_transport_reset_counters(void) {
    transport.send_count = 0;
    transport.send_sequence = 0;
    transport.receive_count = 0;
    transport.receive_sequence = 0;
    transport.last_status = 0;
    transport.last_sender_valid = false;
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
static bool kookie_transport_parse_hex_word(
    const char *text,
    uint32_t *value
) {
    uint32_t parsed = 0;
    for (int index = 0; index < 8; index += 1) {
        char digit = text[index];
        uint32_t nibble;
        if (digit >= '0' && digit <= '9') {
            nibble = (uint32_t)(digit - '0');
        } else if (digit >= 'a' && digit <= 'f') {
            nibble = (uint32_t)(digit - 'a') + 10;
        } else if (digit >= 'A' && digit <= 'F') {
            nibble = (uint32_t)(digit - 'A') + 10;
        } else {
            return false;
        }
        parsed = (parsed << 4) | nibble;
    }
    *value = parsed;
    return true;
}
static bool kookie_transport_set_key_from_encoded(const char *encoded) {
    if (encoded == NULL || strlen(encoded) != 32) {
        return false;
    }
    uint32_t words[4];
    for (int index = 0; index < 4; index += 1) {
        if (!kookie_transport_parse_hex_word(
                encoded + index * 8, &words[index])) {
            return false;
        }
    }
    return kookie_transport_set_key(
        (int)words[0], (int)words[1],
        (int)words[2], (int)words[3]);
}

bool kookie_transport_set_key_from_environment(void) {
    if (transport.socket_fd >= 0) {
        return false;
    }
    return kookie_transport_set_key_from_encoded(
        getenv("KOOKIE_TRANSPORT_KEY_HEX"));
}

bool kookie_transport_set_key_from_file(void) {
    if (transport.socket_fd >= 0) {
        return false;
    }
    const char *path = getenv("KOOKIE_TRANSPORT_KEY_FILE");
    if (path == NULL || path[0] == '\0') {
        return false;
    }
    struct stat info;
    if (stat(path, &info) != 0 || !S_ISREG(info.st_mode) ||
        (info.st_mode & 0077) != 0) {
        return false;
    }
    int file_descriptor = open(path, O_RDONLY);
    if (file_descriptor < 0) {
        return false;
    }
    char encoded[33];
    ssize_t length = read(file_descriptor, encoded, sizeof(encoded));
    close(file_descriptor);
    if (length != 32) {
        return false;
    }
    encoded[32] = '\0';
    return kookie_transport_set_key_from_encoded(encoded);
}

bool kookie_transport_rotate_key_from_file(void) {
    return kookie_transport_set_key_from_file();
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
    peer.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
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
    receive_address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = receive_socket_fd;
    transport.peer = receive_address;
    kookie_transport_reset_counters();
    return true;
}
bool kookie_transport_open_remote_ipv4(
    int first_octet, int second_octet, int third_octet,
    int fourth_octet, int port
) {
    if (transport.socket_fd >= 0 || !transport.key_configured ||
        first_octet < 0 || first_octet > 255 ||
        second_octet < 0 || second_octet > 255 ||
        third_octet < 0 || third_octet > 255 ||
        fourth_octet < 0 || fourth_octet > 255 ||
        port <= 0 || port > 65535) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in local;
    if (!kookie_transport_bind_socket_any(&socket_fd, &local)) {
        return false;
    }
    uint32_t address =
        ((uint32_t)first_octet << 24) |
        ((uint32_t)second_octet << 16) |
        ((uint32_t)third_octet << 8) |
        (uint32_t)fourth_octet;
    local.sin_addr.s_addr = htonl(address);
    local.sin_port = htons((uint16_t)port);
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = local;
    kookie_transport_reset_counters();
    return true;
}
static bool kookie_transport_external_host_address(
    struct in_addr *address
) {
    const char *encoded = getenv("KOOKIE_EXTERNAL_LAN_HOST_IPV4");
    if (encoded == NULL || encoded[0] == '\0') {
        encoded = "127.0.0.1";
    }
    return inet_pton(AF_INET, encoded, address) == 1;
}

bool kookie_transport_open_remote_environment(int port) {
    struct in_addr address;
    if (!kookie_transport_external_host_address(&address)) {
        return false;
    }
    uint32_t host_order = ntohl(address.s_addr);
    return kookie_transport_open_remote_ipv4(
        (int)((host_order >> 24) & 0xffU),
        (int)((host_order >> 16) & 0xffU),
        (int)((host_order >> 8) & 0xffU),
        (int)(host_order & 0xffU),
        port);
}

int kookie_transport_external_host_octet(int index) {
    if (index < 0 || index > 3) {
        return -1;
    }
    struct in_addr address;
    if (!kookie_transport_external_host_address(&address)) {
        return -1;
    }
    uint32_t host_order = ntohl(address.s_addr);
    return (int)((host_order >> ((3 - index) * 8)) & 0xffU);
}

static int kookie_transport_external_role(void) {
    const char *role = getenv("KOOKIE_EXTERNAL_LAN_ROLE");
    if (role == NULL) {
        return 0;
    }
    if (strcmp(role, "host") == 0) {
        return 1;
    }
    if (strcmp(role, "client-a") == 0) {
        return 2;
    }
    if (strcmp(role, "client-b") == 0) {
        return 3;
    }
    return 0;
}
bool kookie_transport_external_is_host(void) {
    return kookie_transport_external_role() == 1;
}

bool kookie_transport_external_is_client_a(void) {
    return kookie_transport_external_role() == 2;
}

bool kookie_transport_external_is_client_b(void) {
    return kookie_transport_external_role() == 3;
}
bool kookie_transport_open_local_ipv4(int port) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in local;
    if (!kookie_transport_bind_socket_at(&socket_fd, port, &local)) {
        return false;
    }
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = local;
    kookie_transport_reset_counters();
    return true;
}
bool kookie_transport_open_listen_ipv4(int port) {
    if (transport.socket_fd >= 0 || !transport.key_configured) {
        return false;
    }
    int socket_fd = -1;
    struct sockaddr_in local;
    if (!kookie_transport_bind_socket_any_at(&socket_fd, port, &local)) {
        return false;
    }
    transport.socket_fd = socket_fd;
    transport.receive_socket_fd = socket_fd;
    transport.peer = local;
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
bool kookie_transport_set_peer_last_sender(void) {
    if (transport.socket_fd < 0 || !transport.last_sender_valid) {
        return false;
    }
    transport.peer = transport.last_sender;
    return true;
}

bool kookie_transport_received_sequence_at_least(int minimum) {
    return minimum >= 0 &&
        transport.receive_sequence >= (uint32_t)minimum;
}


int kookie_transport_peer_port(void) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    return (int)ntohs(transport.peer.sin_port);
}

int kookie_transport_local_port(void) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    struct sockaddr_in local;
    socklen_t address_length = sizeof(local);
    if (getsockname(
            transport.socket_fd,
            (struct sockaddr *)&local,
            &address_length) != 0) {
        return 0;
    }
    return (int)ntohs(local.sin_port);
}

int kookie_transport_max_words(void) {
    return KOOKIE_TRANSPORT_MAX_WORDS;
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
    memcpy(transport.last_send_wire, wire, bytes);
    transport.last_send_bytes = (int)bytes;
    transport.last_send_valid = true;
    transport.send_sequence += 1;
    return true;
}
bool kookie_transport_replay_last_datagram(void) {
    if (transport.socket_fd < 0 ||
        !transport.last_send_valid ||
        transport.last_send_bytes <= 0) {
        return false;
    }
    ssize_t sent = sendto(
        transport.socket_fd,
        transport.last_send_wire,
        (size_t)transport.last_send_bytes,
        0,
        (struct sockaddr *)&transport.peer,
        sizeof(transport.peer));
    return sent == (ssize_t)transport.last_send_bytes;
}

int kookie_transport_receive(void) {
    if (transport.socket_fd < 0) {
        return 0;
    }
    uint32_t wire[
        KOOKIE_TRANSPORT_HEADER_WORDS + KOOKIE_TRANSPORT_MAX_WORDS];
    struct sockaddr_in sender;
    memset(&sender, 0, sizeof(sender));
    socklen_t sender_length = sizeof(sender);
    ssize_t bytes = recvfrom(
        transport.receive_socket_fd,
        wire,
        sizeof(wire),
        0,
        (struct sockaddr *)&sender,
        &sender_length);
    if (bytes < 0) {
        transport.receive_count = 0;
        transport.last_sender_valid = false;
        transport.last_status =
            errno == EAGAIN || errno == EWOULDBLOCK ? 2 : 3;
        return 0;
    }
    transport.last_sender = sender;
    transport.last_sender_valid = true;
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
    return kookie_transport_receive_timeout_milliseconds();
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
    memset(&gpu_scene, 0, sizeof(gpu_scene));
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
    memset(&gpu_scene, 0, sizeof(gpu_scene));
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
    texture_info.width = KOOKIE_GPU_PALETTE_WIDTH;
    texture_info.height = KOOKIE_GPU_PALETTE_WIDTH;
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
    transfer_info.size = 172;
    transfer = SDL_CreateGPUTransferBuffer(device, &transfer_info);
    if (transfer == NULL) {
        goto cleanup;
    }
    Uint8 *pixels = (Uint8 *)SDL_MapGPUTransferBuffer(device, transfer, false);
    if (pixels == NULL) {
        goto cleanup;
    }
    const Uint8 palette[64] = {
         71,  85, 105, 255,  37,  99, 235, 255,
         15, 118, 110, 255, 124,  58, 237, 255,
        180,  83,   9, 255, 220,  38,  38, 255,
          8, 145, 178, 255, 101, 163,  13, 255,
        100, 116, 139, 255,  15,  23,  42, 255,
         30,  41,  59, 255, 239,  68,  68, 255,
        245, 158,  11, 255,  56, 189, 248, 255,
         34, 197,  94, 255, 248, 250, 252, 255
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
    memcpy(pixels, palette, sizeof(palette));
    memcpy(pixels + 64, vertices, sizeof(vertices));
    memcpy(pixels + 160, indices, sizeof(indices));
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
    destination.w = KOOKIE_GPU_PALETTE_WIDTH;
    destination.h = KOOKIE_GPU_PALETTE_WIDTH;
    destination.d = 1;
    SDL_UploadToGPUTexture(copy_pass, &source, &destination, false);
    SDL_GPUTransferBufferLocation vertex_source = {0};
    vertex_source.transfer_buffer = transfer;
    vertex_source.offset = 64;
    SDL_GPUBufferRegion vertex_destination = {0};
    vertex_destination.buffer = gpu_resources.vertex_buffer;
    vertex_destination.size = 96;
    SDL_UploadToGPUBuffer(copy_pass, &vertex_source, &vertex_destination, false);
    SDL_GPUTransferBufferLocation index_source = {0};
    index_source.transfer_buffer = transfer;
    index_source.offset = 160;
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

int kookie_gpu_scene_capacity(void) {
    return KOOKIE_GPU_SCENE_MAX_VERTICES;
}

int kookie_gpu_scene_count(void) {
    return gpu_scene.committed ? gpu_scene.count : 0;
}

bool kookie_gpu_scene_begin(int vertex_count) {
    if (vertex_count <= 0 ||
        vertex_count > KOOKIE_GPU_SCENE_MAX_VERTICES ||
        vertex_count % 3 != 0 || gpu_scene.open) {
        return false;
    }
    gpu_scene.expected = vertex_count;
    gpu_scene.count = 0;
    gpu_scene.open = true;
    gpu_scene.committed = false;
    gpu_scene.active = false;
    return true;
}

bool kookie_gpu_scene_push_vertex(
    int resource, int x, int y, int u, int v
) {
    if (!gpu_scene.open || gpu_scene.count >= gpu_scene.expected ||
        resource <= 0 || x < -100 || x > 100 || y < -100 || y > 100 ||
        u < 0 || u > 100 || v < 0 || v > 100) {
        return false;
    }
    int palette = (resource - 1) % KOOKIE_GPU_PALETTE_COLORS;
    int palette_x = palette % KOOKIE_GPU_PALETTE_WIDTH;
    int palette_y = palette / KOOKIE_GPU_PALETTE_WIDTH;
    size_t offset = (size_t)gpu_scene.count * 4u;
    gpu_scene.vertices[offset] = (float)x / 100.0f;
    gpu_scene.vertices[offset + 1u] = (float)y / 100.0f;
    gpu_scene.vertices[offset + 2u] =
        ((float)palette_x + 0.5f) / (float)KOOKIE_GPU_PALETTE_WIDTH;
    gpu_scene.vertices[offset + 3u] =
        ((float)palette_y + 0.5f) / (float)KOOKIE_GPU_PALETTE_WIDTH;
    gpu_scene.count += 1;
    return true;
}

bool kookie_gpu_scene_commit(void) {
    if (!gpu_scene.open || gpu_scene.count != gpu_scene.expected) {
        return false;
    }
    gpu_scene.open = false;
    gpu_scene.committed = true;
    return true;
}

static bool kookie_gpu_upload_scene(SDL_GPUDevice *device) {
    if (device == NULL || !gpu_scene.committed ||
        gpu_resources.scene_vertex_buffer == NULL ||
        gpu_resources.scene_transfer == NULL) {
        return false;
    }
    float *vertices = (float *)SDL_MapGPUTransferBuffer(
        device, gpu_resources.scene_transfer, true);
    if (vertices == NULL) {
        return false;
    }
    size_t byte_count = (size_t)gpu_scene.count * 4u * sizeof(float);
    memcpy(vertices, gpu_scene.vertices, byte_count);
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
    return kookie_gpu_submit_and_wait_fence(device, command_buffer);
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
    SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.pipeline);
    SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
    SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
    if (scene_draw) {
        SDL_DrawGPUPrimitives(
            render_pass, (Uint32)gpu_scene.count, 1, 0, 0);
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
    return kookie_gpu_draw_test_internal(
        window_slots[gpu_slot.window_slot].window, NULL, NULL);
}

bool kookie_gpu_draw_scene(void) {
    if (!gpu_scene.committed || gpu_slot.device == NULL ||
        gpu_slot.window_slot < 0 ||
        gpu_slot.window_slot >= KOOKIE_MAX_WINDOWS ||
        window_slots[gpu_slot.window_slot].window == NULL) {
        return false;
    }
    SDL_Window *window = window_slots[gpu_slot.window_slot].window;
    SDL_GPUTextureFormat target_format =
        SDL_GetGPUSwapchainTextureFormat(gpu_slot.device, window);
    if (target_format == SDL_GPU_TEXTUREFORMAT_INVALID ||
        !kookie_gpu_prepare_resources(gpu_slot.device, target_format) ||
        !kookie_gpu_upload_scene(gpu_slot.device)) {
        return false;
    }
    gpu_scene.active = true;
    if (!kookie_gpu_draw_test_internal(window, NULL, NULL)) {
        gpu_scene.active = false;
        return false;
    }
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
    SDL_BindGPUGraphicsPipeline(render_pass, gpu_resources.pipeline);
    SDL_BindGPUVertexBuffers(render_pass, 0, &vertex_binding, 1);
    SDL_BindGPUFragmentSamplers(render_pass, 0, &binding, 1);
    if (scene_draw) {
        SDL_DrawGPUPrimitives(
            render_pass, (Uint32)gpu_scene.count, 1, 0, 0);
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
    SDL_GPUDevice *device = gpu_slot.device;
    SDL_GPUTextureFormat format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
    if (!kookie_gpu_prepare_resources(device, format) ||
        !kookie_gpu_upload_scene(device)) {
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
        return 0;
    }
    gpu_scene.active = true;
    if (!kookie_gpu_draw_test_internal(NULL, target, NULL)) {
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
    static float clips[4][480 * 2];
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
    if (audio_slot.stream == NULL || frames <= 0 || frames > 480) {
        return false;
    }
    if (!initialized[variant]) {
        for (int frame = 0; frame < 480; frame += 1) {
            int phase = frame % 24;
            float sample = ((float)phase / 23.0f) * (0.25f + variant * 0.05f) - 0.125f;
            clips[variant][frame * 2] = sample;
            clips[variant][frame * 2 + 1] = sample;
        }
        initialized[variant] = true;
    }
    return SDL_PutAudioStreamData(
        audio_slot.stream,
        clips[variant],
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
