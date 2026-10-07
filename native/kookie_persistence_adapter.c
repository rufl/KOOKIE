#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <fcntl.h>
#include <io.h>
#else
#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#endif

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "kookie_persistence_adapter.h"

#ifndef _WIN32
#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif
#ifndef O_DIRECTORY
#define O_DIRECTORY 0
#endif
#ifndef O_NOFOLLOW
#define O_NOFOLLOW 0
#endif
#endif

static int kookie_durable_last_trace;

static size_t kookie_durable_length(const char *path, size_t capacity) {
    size_t length = 0;
    if (path == NULL) {
        return capacity;
    }
    while (length < capacity && path[length] != '\0') {
        length += 1;
    }
    return length;
}

static bool kookie_durable_parent(
    const char *path, char *parent, size_t capacity) {
    if (path == NULL || parent == NULL || capacity < 2) {
        return false;
    }
    size_t length = kookie_durable_length(path, capacity);
    if (length == 0 || length >= capacity) {
        return false;
    }
#ifdef _WIN32
    if (path[length - 1] == '/' || path[length - 1] == '\\') {
#else
    if (path[length - 1] == '/') {
#endif
        return false;
    }
#ifdef _WIN32
    if (length >= 2 && path[1] == ':' &&
        (length < 3 || (path[2] != '/' && path[2] != '\\'))) {
        return false;
    }
#endif
    const char *slash = strrchr(path, '/');
#ifdef _WIN32
    const char *backslash = strrchr(path, '\\');
    if (backslash != NULL && (slash == NULL || backslash > slash)) {
        slash = backslash;
    }
#endif
    if (slash == NULL) {
        parent[0] = '.';
        parent[1] = '\0';
        return true;
    }
    if (slash == path) {
        parent[0] = path[0];
        parent[1] = '\0';
        return true;
    }
    size_t parent_length = (size_t)(slash - path);
#ifdef _WIN32
    if (parent_length > 0 && path[parent_length - 1] == ':') {
        parent_length += 1;
    }
#endif
    if (parent_length + 1 > capacity) {
        return false;
    }
    memcpy(parent, path, parent_length);
    parent[parent_length] = '\0';
    return true;
}

static bool kookie_durable_same_parent(
    const char *first, const char *second) {
#ifdef _WIN32
    char first_full[4096];
    char second_full[4096];
    DWORD first_length = GetFullPathNameA(
        first, (DWORD)sizeof(first_full), first_full, NULL);
    DWORD second_length = GetFullPathNameA(
        second, (DWORD)sizeof(second_full), second_full, NULL);
    if (first_length == 0 || second_length == 0 ||
        first_length >= sizeof(first_full) ||
        second_length >= sizeof(second_full)) {
        return false;
    }
    return _stricmp(first_full, second_full) == 0;
#else
    return strcmp(first, second) == 0;
#endif
}

static bool kookie_durable_safe_parent(const char *parent) {
#ifdef _WIN32
    DWORD attributes = GetFileAttributesA(parent);
    return attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_DIRECTORY) != 0 &&
        (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0;
#else
    struct stat status;
    return lstat(parent, &status) == 0 &&
        S_ISDIR(status.st_mode) && !S_ISLNK(status.st_mode);
#endif
}

static int kookie_durable_fault(void) {
    const char *fault = getenv("KOOKIE_DURABLE_FAULT");
    if (fault == NULL) {
        return 0;
    }
    if (strcmp(fault, "before-file-sync") == 0) {
        return 5;
    }
    if (strcmp(fault, "before-rename") == 0 ||
        strcmp(fault, "after-file-sync") == 0) {
        return 1;
    }
    if (strcmp(fault, "after-rename") == 0) {
        return 2;
    }
    if (strcmp(fault, "recover") == 0) {
        return 3;
    }
    if (strcmp(fault, "recover-before-file-sync") == 0) {
        return 8;
    }
    if (strcmp(fault, "recover-after-file-sync") == 0) {
        return 9;
    }
    if (strcmp(fault, "recover-after-directory") == 0) {
        return 7;
    }
    if (strcmp(fault, "torn-stage") == 0) {
        return 4;
    }
    if (strcmp(fault, "after-directory-sync") == 0) {
        return 6;
    }
    return 0;
}

static void kookie_durable_terminate(unsigned int status) {
#ifdef _WIN32
    ExitProcess((UINT)status);
#else
    _exit((int)status);
#endif
}

bool kookie_durable_publish(
    const char *staging_path, const char *target_path) {
    char staging_parent[4096];
    char target_parent[4096];
    kookie_durable_last_trace = 0;
    if (staging_path == NULL || target_path == NULL ||
        strcmp(staging_path, target_path) == 0 ||
        !kookie_durable_parent(
            staging_path, staging_parent, sizeof(staging_parent)) ||
        !kookie_durable_parent(
            target_path, target_parent, sizeof(target_parent)) ||
        !kookie_durable_same_parent(staging_parent, target_parent) ||
        !kookie_durable_safe_parent(staging_parent) ||
        !kookie_durable_safe_parent(target_parent)) {
        return false;
    }

#ifdef _WIN32
    HANDLE staging = CreateFileA(
        staging_path,
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL,
        OPEN_EXISTING,
        FILE_FLAG_OPEN_REPARSE_POINT,
        NULL);
    if (staging == INVALID_HANDLE_VALUE) {
        return false;
    }
    kookie_durable_last_trace |= 1;
    BY_HANDLE_FILE_INFORMATION status;
    if (!GetFileInformationByHandle(staging, &status) ||
        (status.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0 ||
        (status.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ||
        status.nNumberOfLinks != 1) {
        CloseHandle(staging);
        return false;
    }
    if (kookie_durable_fault() == 5) {
        CloseHandle(staging);
        kookie_durable_terminate(84);
    }
    if (!FlushFileBuffers(staging)) {
        CloseHandle(staging);
        return false;
    }
    kookie_durable_last_trace |= 2;
    if (!CloseHandle(staging)) {
        return false;
    }
    if (kookie_durable_fault() == 1) {
        kookie_durable_terminate(85);
    }
    if (!MoveFileExA(
        staging_path, target_path,
        MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH)) {
        return false;
    }
    kookie_durable_last_trace |= 4;
    if (kookie_durable_fault() == 2) {
        kookie_durable_terminate(86);
    }

    HANDLE directory = CreateFileA(
        target_parent,
        GENERIC_READ | GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL,
        OPEN_EXISTING,
        FILE_FLAG_BACKUP_SEMANTICS,
        NULL);
    if (directory == INVALID_HANDLE_VALUE) {
        return false;
    }
    kookie_durable_last_trace |= 8;
    if (!FlushFileBuffers(directory)) {
        CloseHandle(directory);
        return false;
    }
    kookie_durable_last_trace |= 16;
    if (!CloseHandle(directory)) {
        return false;
    }
    if (kookie_durable_fault() == 6) {
        kookie_durable_terminate(87);
    }
    return true;
#else
    struct stat status;
    int staging = open(
        staging_path, O_RDWR | O_CLOEXEC | O_NOFOLLOW);
    if (staging < 0) {
        return false;
    }
    kookie_durable_last_trace |= 1;
    if (fstat(staging, &status) != 0 ||
        !S_ISREG(status.st_mode) || status.st_nlink != 1) {
        close(staging);
        return false;
    }
    if (kookie_durable_fault() == 5) {
        close(staging);
        kookie_durable_terminate(84);
    }
    if (fsync(staging) != 0) {
        close(staging);
        return false;
    }
    kookie_durable_last_trace |= 2;
    if (close(staging) != 0) {
        return false;
    }
    if (kookie_durable_fault() == 1) {
        kookie_durable_terminate(85);
    }
    if (rename(staging_path, target_path) != 0) {
        return false;
    }
    kookie_durable_last_trace |= 4;
    if (kookie_durable_fault() == 2) {
        kookie_durable_terminate(86);
    }

    int directory = open(
        target_parent, O_RDONLY | O_CLOEXEC | O_DIRECTORY);
    if (directory < 0) {
        return false;
    }
    kookie_durable_last_trace |= 8;
    if (fsync(directory) != 0) {
        close(directory);
        return false;
    }
    kookie_durable_last_trace |= 16;
    if (close(directory) != 0) {
        return false;
    }
    if (kookie_durable_fault() == 6) {
        kookie_durable_terminate(87);
    }
    return true;
#endif
}
bool kookie_durable_publish_default(void) {
    return kookie_durable_publish(
        "durable-save.dat.kookie-stage", "durable-save.dat");
}

int kookie_durable_trace(void) {
    return kookie_durable_last_trace;
}

int kookie_durable_mode(void) {
    return kookie_durable_fault();
}

#define KOOKIE_HOST_SECTION_CAPACITY 12
#define KOOKIE_HOST_PAYLOAD_CAPACITY 160
#define KOOKIE_HOST_WIRE_CAPACITY \
    (4 + KOOKIE_HOST_SECTION_CAPACITY * (3 + KOOKIE_HOST_PAYLOAD_CAPACITY))
#define KOOKIE_HOST_SLOT_CAPACITY (KOOKIE_HOST_WIRE_CAPACITY + 2)
#define KOOKIE_HOST_FILE_WORD_CAPACITY \
    (3 + KOOKIE_HOST_SLOT_CAPACITY * 2)
#define KOOKIE_HOST_DIGITS_PER_WORD 6
#define KOOKIE_HOST_FILE_BYTE_CAPACITY \
    (KOOKIE_HOST_FILE_WORD_CAPACITY * KOOKIE_HOST_DIGITS_PER_WORD)

static const char *const kookie_host_staging_path =
    "durable-save.dat.kookie-stage";
static const char *const kookie_host_target_path = "durable-save.dat";
static int kookie_host_stage_words[KOOKIE_HOST_WIRE_CAPACITY];
static int kookie_host_stage_length;
static bool kookie_host_stage_open;
static int kookie_host_loaded_words[KOOKIE_HOST_WIRE_CAPACITY];
static int kookie_host_loaded_length;
static int kookie_host_file_words[KOOKIE_HOST_FILE_WORD_CAPACITY];
static unsigned char kookie_host_input_bytes[
    KOOKIE_HOST_FILE_BYTE_CAPACITY + 1];
static unsigned char kookie_host_output_bytes[
    KOOKIE_HOST_FILE_BYTE_CAPACITY];

static bool kookie_host_regular_path(const char *path) {
    char parent[4096];
    if (!kookie_durable_parent(path, parent, sizeof(parent)) ||
        !kookie_durable_safe_parent(parent)) {
        return false;
    }
#ifdef _WIN32
    DWORD attributes = GetFileAttributesA(path);
    return attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_DIRECTORY) == 0 &&
        (attributes & FILE_ATTRIBUTE_REPARSE_POINT) == 0;
#else
    struct stat status;
    return lstat(path, &status) == 0 && S_ISREG(status.st_mode) &&
        status.st_nlink == 1;
#endif
}

static FILE *kookie_host_open_read(const char *path) {
    char parent[4096];
    if (!kookie_durable_parent(path, parent, sizeof(parent)) ||
        !kookie_durable_safe_parent(parent)) {
        return NULL;
    }
#ifdef _WIN32
    HANDLE handle = CreateFileA(
        path, GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        NULL, OPEN_EXISTING, FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        return NULL;
    }
    BY_HANDLE_FILE_INFORMATION status;
    if (!GetFileInformationByHandle(handle, &status) ||
        (status.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) != 0 ||
        (status.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) != 0 ||
        status.nNumberOfLinks != 1) {
        CloseHandle(handle);
        return NULL;
    }
    int descriptor = _open_osfhandle(
        (intptr_t)handle, _O_RDONLY | _O_BINARY);
    if (descriptor < 0) {
        CloseHandle(handle);
        return NULL;
    }
    FILE *file = _fdopen(descriptor, "rb");
    if (file == NULL) {
        _close(descriptor);
    }
    return file;
#else
    int descriptor = open(
        path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (descriptor < 0) {
        return NULL;
    }
    struct stat status;
    if (fstat(descriptor, &status) != 0 ||
        !S_ISREG(status.st_mode) || status.st_nlink != 1) {
        close(descriptor);
        return NULL;
    }
    FILE *file = fdopen(descriptor, "rb");
    if (file == NULL) {
        close(descriptor);
    }
    return file;
#endif
}

static FILE *kookie_host_open_create(const char *path) {
    char parent[4096];
    if (!kookie_durable_parent(path, parent, sizeof(parent)) ||
        !kookie_durable_safe_parent(parent)) {
        return NULL;
    }
#ifdef _WIN32
    HANDLE handle = CreateFileA(
        path, GENERIC_WRITE, 0, NULL, CREATE_NEW,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OPEN_REPARSE_POINT, NULL);
    if (handle == INVALID_HANDLE_VALUE) {
        return NULL;
    }
    int descriptor = _open_osfhandle(
        (intptr_t)handle, _O_WRONLY | _O_BINARY);
    if (descriptor < 0) {
        CloseHandle(handle);
        return NULL;
    }
    FILE *file = _fdopen(descriptor, "wb");
    if (file == NULL) {
        _close(descriptor);
    }
    return file;
#else
    int descriptor = open(
        path, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0600);
    if (descriptor < 0) {
        return NULL;
    }
    FILE *file = fdopen(descriptor, "wb");
    if (file == NULL) {
        close(descriptor);
    }
    return file;
#endif
}

static bool kookie_host_remove_file(const char *path) {
    if (!kookie_host_regular_path(path)) {
#ifdef _WIN32
        return GetFileAttributesA(path) == INVALID_FILE_ATTRIBUTES &&
            GetLastError() == ERROR_FILE_NOT_FOUND;
#else
        struct stat status;
        return lstat(path, &status) != 0 && errno == ENOENT;
#endif
    }
#ifdef _WIN32
    return DeleteFileA(path) != 0;
#else
    return unlink(path) == 0;
#endif
}

static int kookie_host_checksum(
    int schema_version, int revision, const int *payload, int length) {
    int bounded_revision = revision % 1000003;
    int checksum = (1 + schema_version * 31 + bounded_revision * 17) %
        1000003;
    for (int index = 0; index < length; index += 1) {
        checksum = (
            checksum + payload[index] + (index + 1) * 17) % 1000003;
    }
    return checksum;
}

static int kookie_host_current_version(int section_id) {
    if (section_id == 2 || section_id == 3) {
        return 2;
    }
    if (section_id >= 1 && section_id <= KOOKIE_HOST_SECTION_CAPACITY) {
        return 1;
    }
    return -1;
}

static bool kookie_host_accepts_source(int section_id, int version) {
    if (section_id == 2 || section_id == 3) {
        return version >= 0 && version <= 2;
    }
    return kookie_host_current_version(section_id) == version;
}

// 1 is accepted, 0 is corrupt, -1 is an unsupported schema.
static int kookie_host_validate_wire(const int *wire, int length) {
    if (wire == NULL || length < 4 ||
        length > KOOKIE_HOST_WIRE_CAPACITY ||
        wire[0] != 99112233 || wire[1] < 1 ||
        wire[1] > 1000000 || wire[2] < 0 ||
        wire[2] > 1000000 || wire[3] < 0 ||
        wire[3] > KOOKIE_HOST_SECTION_CAPACITY) {
        return 0;
    }
    int seen[KOOKIE_HOST_SECTION_CAPACITY];
    memset(seen, 0, sizeof(seen));
    int offset = 4;
    bool unsupported = wire[1] > 1;
    for (int section = 0; section < wire[3]; section += 1) {
        if (offset + 3 > length) {
            return 0;
        }
        int section_id = wire[offset];
        int version = wire[offset + 1];
        int payload_length = wire[offset + 2];
        if (section_id <= 0 || section_id > KOOKIE_HOST_SECTION_CAPACITY ||
            payload_length < 0 ||
            payload_length > KOOKIE_HOST_PAYLOAD_CAPACITY ||
            offset + 3 + payload_length > length) {
            return 0;
        }
        for (int previous = 0; previous < section; previous += 1) {
            if (seen[previous] == section_id) {
                return 0;
            }
        }
        seen[section] = section_id;
        if (!kookie_host_accepts_source(section_id, version)) {
            unsupported = true;
        }
        for (int value = 0; value < payload_length; value += 1) {
            int payload_value = wire[offset + 3 + value];
            if (payload_value < 0 || payload_value > 1000000) {
                return 0;
            }
        }
        offset += 3 + payload_length;
    }
    if (offset != length) {
        return 0;
    }
    return unsupported ? -1 : 1;
}

static bool kookie_host_encode_word(int value, unsigned char *output) {
    if (value < 0 || output == NULL) {
        return false;
    }
    for (int digit = 0; digit < KOOKIE_HOST_DIGITS_PER_WORD; digit += 1) {
        output[digit] = (unsigned char)(value % 64);
        value /= 64;
    }
    return output[KOOKIE_HOST_DIGITS_PER_WORD - 1] == 0;
}

static bool kookie_host_decode_word(
    const unsigned char *input, int *value) {
    if (input == NULL || value == NULL) {
        return false;
    }
    int decoded = 0;
    int multiplier = 1;
    for (int digit = 0; digit < KOOKIE_HOST_DIGITS_PER_WORD; digit += 1) {
        if (input[digit] >= 64 ||
            (digit == KOOKIE_HOST_DIGITS_PER_WORD - 1 &&
                input[digit] != 0)) {
            return false;
        }
        decoded += input[digit] * multiplier;
        if (digit < KOOKIE_HOST_DIGITS_PER_WORD - 1) {
            multiplier *= 64;
        }
    }
    *value = decoded;
    return true;
}

static int kookie_host_read_words(
    const char *path, int *words, int capacity) {
    FILE *file = kookie_host_open_read(path);
    if (file == NULL || words == NULL || capacity <= 0) {
        if (file != NULL) {
            fclose(file);
        }
        return 0;
    }
    size_t length = fread(
        kookie_host_input_bytes, 1,
        sizeof(kookie_host_input_bytes), file);
    bool ok = ferror(file) == 0 && fclose(file) == 0;
    if (!ok || length == 0 ||
        length > (size_t)KOOKIE_HOST_FILE_BYTE_CAPACITY ||
        length % KOOKIE_HOST_DIGITS_PER_WORD != 0) {
        return 0;
    }
    int word_count = (int)(length / KOOKIE_HOST_DIGITS_PER_WORD);
    if (word_count > capacity) {
        return 0;
    }
    for (int index = 0; index < word_count; index += 1) {
        if (!kookie_host_decode_word(
                &kookie_host_input_bytes[
                    index * KOOKIE_HOST_DIGITS_PER_WORD],
                &words[index])) {
            return 0;
        }
    }
    return word_count;
}

static int kookie_host_decode_slot(
    const int *words, int length, int length_index, int wire_start,
    int slot_limit, int *wire, int *wire_length) {
    if (words == NULL || wire == NULL || wire_length == NULL ||
        length_index < 0 || wire_start < 0 ||
        length_index >= length || wire_start + slot_limit > length ||
        wire_start < 2 || slot_limit < 4) {
        return 0;
    }
    int encoded_length = words[length_index];
    if (encoded_length < 4 || encoded_length > slot_limit ||
        encoded_length != slot_limit) {
        return 0;
    }
    for (int index = 0; index < encoded_length; index += 1) {
        if (words[wire_start + index] < 0) {
            return 0;
        }
        wire[index] = words[wire_start + index];
    }
    if (wire[0] != 99112233 ||
        words[wire_start - 2] != encoded_length ||
        words[wire_start - 1] != kookie_host_checksum(
            wire[1], wire[2], wire, encoded_length)) {
        return 0;
    }
    int status = kookie_host_validate_wire(wire, encoded_length);
    if (status == 0) {
        return 0;
    }
    *wire_length = encoded_length;
    return status;
}

static bool kookie_host_load_schema(const char *path) {
    int word_count = kookie_host_read_words(
        path, kookie_host_file_words, KOOKIE_HOST_FILE_WORD_CAPACITY);
    if (word_count < 3 ||
        kookie_host_file_words[0] != 11773399 ||
        kookie_host_file_words[1] != 2) {
        return false;
    }
    int slot_words = kookie_host_file_words[2];
    if (slot_words < 6 ||
        slot_words > KOOKIE_HOST_WIRE_CAPACITY + 2 ||
        word_count != 3 + slot_words * 2) {
        return false;
    }
    int first[KOOKIE_HOST_WIRE_CAPACITY];
    int second[KOOKIE_HOST_WIRE_CAPACITY];
    int first_length = 0;
    int second_length = 0;
    int first_status = kookie_host_decode_slot(
        kookie_host_file_words, word_count, 3, 5,
        slot_words - 2, first, &first_length);
    int second_status = kookie_host_decode_slot(
        kookie_host_file_words, word_count, 3 + slot_words,
        5 + slot_words, slot_words - 2, second, &second_length);
    if (first_status < 0 || second_status < 0 ||
        (first_status == 0 && second_status == 0)) {
        return false;
    }
    int *selected = second;
    int selected_length = second_length;
    if (first_status == 1 &&
        (second_status == 0 || second[2] <= first[2])) {
        selected = first;
        selected_length = first_length;
    }
    memcpy(
        kookie_host_loaded_words, selected,
        (size_t)selected_length * sizeof(selected[0]));
    kookie_host_loaded_length = selected_length;
    return true;
}

static bool kookie_host_write_schema(
    const char *path, const int *wire, int wire_length) {
    if (kookie_host_validate_wire(wire, wire_length) != 1) {
        return false;
    }
    int slot_words = wire_length + 2;
    int word_count = 3 + slot_words * 2;
    if (word_count > KOOKIE_HOST_FILE_WORD_CAPACITY) {
        return false;
    }
    kookie_host_file_words[0] = 11773399;
    kookie_host_file_words[1] = 2;
    kookie_host_file_words[2] = slot_words;
    int checksum = kookie_host_checksum(
        wire[1], wire[2], wire, wire_length);
    for (int copy = 0; copy < 2; copy += 1) {
        int start = 3 + copy * slot_words;
        kookie_host_file_words[start] = wire_length;
        kookie_host_file_words[start + 1] = checksum;
        memcpy(
            &kookie_host_file_words[start + 2], wire,
            (size_t)wire_length * sizeof(wire[0]));
    }
    for (int index = 0; index < word_count; index += 1) {
        if (!kookie_host_encode_word(
                kookie_host_file_words[index],
                &kookie_host_output_bytes[
                    index * KOOKIE_HOST_DIGITS_PER_WORD])) {
            return false;
        }
    }
    FILE *file = kookie_host_open_create(path);
    if (file == NULL) {
        return false;
    }
    size_t byte_count = (size_t)word_count * KOOKIE_HOST_DIGITS_PER_WORD;
    bool ok = fwrite(kookie_host_output_bytes, 1, byte_count, file) ==
        byte_count;
    if (fclose(file) != 0) {
        ok = false;
    }
    return ok;
}

bool kookie_durable_host_stage_begin(int wire_length) {
    if (kookie_host_stage_open || wire_length < 4 ||
        wire_length > KOOKIE_HOST_WIRE_CAPACITY) {
        return false;
    }
    kookie_host_stage_length = wire_length;
    kookie_host_stage_open = true;
    return true;
}

bool kookie_durable_host_stage_word(int index, int value) {
    if (!kookie_host_stage_open || index < 0 ||
        index >= kookie_host_stage_length || value < 0) {
        return false;
    }
    kookie_host_stage_words[index] = value;
    return true;
}

bool kookie_durable_host_stage_commit(void) {
    if (!kookie_host_stage_open) {
        return false;
    }
    bool ok = kookie_host_write_schema(
        kookie_host_staging_path, kookie_host_stage_words,
        kookie_host_stage_length);
    kookie_host_stage_open = false;
    kookie_host_stage_length = 0;
    return ok;
}

bool kookie_durable_host_stage_cancel(void) {
    kookie_host_stage_open = false;
    kookie_host_stage_length = 0;
    return true;
}

bool kookie_durable_host_staging_exists(void) {
    return kookie_host_regular_path(kookie_host_staging_path);
}

bool kookie_durable_host_discard_stage(void) {
    if (kookie_host_stage_open) {
        return false;
    }
    return kookie_host_remove_file(kookie_host_staging_path);
}

bool kookie_durable_host_target_exists(void) {
    return kookie_host_regular_path(kookie_host_target_path);
}

bool kookie_durable_host_load_begin(void) {
    kookie_host_loaded_length = 0;
    return kookie_host_load_schema(kookie_host_target_path);
}

int kookie_durable_host_load_length(void) {
    return kookie_host_loaded_length;
}

int kookie_durable_host_load_word(int index) {
    if (index < 0 || index >= kookie_host_loaded_length) {
        return -1;
    }
    return kookie_host_loaded_words[index];
}
