#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
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
        !kookie_durable_same_parent(staging_parent, target_parent)) {
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
