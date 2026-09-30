#define _POSIX_C_SOURCE 200809L

#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#ifndef O_CLOEXEC
#define O_CLOEXEC 0
#endif
#ifndef O_DIRECTORY
#define O_DIRECTORY 0
#endif
#ifndef O_NOFOLLOW
#define O_NOFOLLOW 0
#endif

static int kookie_durable_last_trace;

static bool kookie_durable_parent(const char *path, char *parent, size_t capacity) {
    if (path == NULL || parent == NULL || capacity < 2) {
        return false;
    }
    size_t length = strnlen(path, capacity);
    if (length == 0 || length >= capacity || path[length - 1] == '/') {
        return false;
    }
    const char *slash = strrchr(path, '/');
    if (slash == NULL) {
        parent[0] = '.';
        parent[1] = '\0';
        return true;
    }
    if (slash == path) {
        parent[0] = '/';
        parent[1] = '\0';
        return true;
    }
    size_t parent_length = (size_t)(slash - path);
    if (parent_length + 1 > capacity) {
        return false;
    }
    memcpy(parent, path, parent_length);
    parent[parent_length] = '\0';
    return true;
}

static int kookie_durable_fault(void) {
    const char *fault = getenv("KOOKIE_DURABLE_FAULT");
    if (fault == NULL) {
        return 0;
    }
    if (strcmp(fault, "before-rename") == 0) {
        return 1;
    }
    if (strcmp(fault, "after-rename") == 0) {
        return 2;
    }
    if (strcmp(fault, "recover") == 0) {
        return 3;
    }
    if (strcmp(fault, "torn-stage") == 0) {
        return 4;
    }
    return 0;
}

bool kookie_durable_publish(const char *staging_path, const char *target_path) {
    char staging_parent[4096];
    char target_parent[4096];
    struct stat status;
    kookie_durable_last_trace = 0;
    if (staging_path == NULL || target_path == NULL ||
        strcmp(staging_path, target_path) == 0 ||
        !kookie_durable_parent(staging_path, staging_parent, sizeof(staging_parent)) ||
        !kookie_durable_parent(target_path, target_parent, sizeof(target_parent)) ||
        strcmp(staging_parent, target_parent) != 0) {
        return false;
    }

    int staging = open(staging_path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (staging < 0) {
        return false;
    }
    kookie_durable_last_trace |= 1;
    if (fstat(staging, &status) != 0 || !S_ISREG(status.st_mode) || status.st_nlink != 1) {
        close(staging);
        return false;
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
        errno = EINTR;
        return false;
    }
    if (rename(staging_path, target_path) != 0) {
        return false;
    }
    kookie_durable_last_trace |= 4;
    if (kookie_durable_fault() == 2) {
        _exit(86);
    }

    int directory = open(target_parent, O_RDONLY | O_CLOEXEC | O_DIRECTORY);
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
    return true;
}

int kookie_durable_trace(void) {
    return kookie_durable_last_trace;
}

int kookie_durable_mode(void) {
    return kookie_durable_fault();
}
