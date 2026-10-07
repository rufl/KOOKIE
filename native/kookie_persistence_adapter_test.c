#ifndef _WIN32
#define _POSIX_C_SOURCE 200809L
#endif
#include "kookie_persistence_adapter.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#else
#include <sys/stat.h>
#include <unistd.h>
#endif

static const char *const staging_path = "durable-save.dat.kookie-stage";
static const char *const target_path = "durable-save.dat";

static bool write_file(const char *path, const char *contents) {
    FILE *file = fopen(path, "wb");
    if (file == NULL) {
        return false;
    }
    size_t length = strlen(contents);
    bool ok = fwrite(contents, 1, length, file) == length;
    if (fclose(file) != 0) {
        ok = false;
    }
    return ok;
}

static bool read_matches(const char *path, const char *expected) {
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return false;
    }
    char contents[64];
    size_t length = fread(contents, 1, sizeof(contents) - 1, file);
    bool ok = ferror(file) == 0;
    if (fclose(file) != 0) {
        ok = false;
    }
    if (!ok) {
        return false;
    }
    contents[length] = '\0';
    return strcmp(contents, expected) == 0;
}

static bool absent(const char *path) {
    FILE *file = fopen(path, "rb");
    if (file != NULL) {
        fclose(file);
        return false;
    }
    return true;
}

static bool discard_stage(void) {
    if (absent(staging_path)) {
        return true;
    }
    return remove(staging_path) == 0 && absent(staging_path);
}

static bool publish_paths(
    const char *staging, const char *target) {
    return kookie_durable_publish(staging, target);
}

static bool publish(void) {
    return publish_paths(staging_path, target_path);
}

static bool make_directory_path(const char *path) {
#ifdef _WIN32
    return CreateDirectoryA(path, NULL) != 0;
#else
    return mkdir(path, 0700) == 0;
#endif
}

static bool remove_directory_path(const char *path) {
#ifdef _WIN32
    return RemoveDirectoryA(path) != 0;
#else
    return rmdir(path) == 0;
#endif
}

static bool create_hard_link_path(
    const char *existing, const char *link_path) {
#ifdef _WIN32
    return CreateHardLinkA(link_path, existing, NULL) != 0;
#else
    return link(existing, link_path) == 0;
#endif
}

static bool create_symbolic_link_path(
    const char *existing, const char *link_path) {
#ifdef _WIN32
    return CreateSymbolicLinkA(link_path, existing, 0) != 0;
#else
    return symlink(existing, link_path) == 0;
#endif
}

static bool verify_symlink_path(
    const char *symlink_path) {
#ifdef _WIN32
    if (!create_symbolic_link_path(target_path, symlink_path)) {
        return true;
    }
#else
    if (!create_symbolic_link_path(target_path, symlink_path)) {
        return false;
    }
#endif
    bool ok = !publish_paths(symlink_path, target_path) &&
        read_matches(target_path, "revision-1");
    if (remove(symlink_path) != 0) {
        ok = false;
    }
    return ok;
}

static bool verify_negative_paths(void) {
    const char *cross_directory = "durable-save-negative-dir";
    const char *cross_stage =
        "durable-save-negative-dir/stage";
    const char *hard_link = "durable-save.dat.hardlink";
    const char *symlink_path = "durable-save.dat.symlink";
    (void)remove(cross_stage);
    (void)remove(hard_link);
    (void)remove(symlink_path);
    (void)remove_directory_path(cross_directory);
    (void)remove_directory_path(staging_path);

    if (!make_directory_path(cross_directory) ||
        publish_paths(cross_stage, target_path) ||
        kookie_durable_trace() != 0 ||
        !read_matches(target_path, "revision-1") ||
        !remove_directory_path(cross_directory)) {
        return false;
    }
    if (!make_directory_path(staging_path) ||
        publish() ||
        !read_matches(target_path, "revision-1") ||
        !remove_directory_path(staging_path)) {
        return false;
    }
    if (!write_file(staging_path, "revision-2") ||
        !create_hard_link_path(staging_path, hard_link) ||
        publish_paths(hard_link, target_path) ||
        !read_matches(target_path, "revision-1") ||
        remove(hard_link) != 0 ||
        remove(staging_path) != 0) {
        return false;
    }
    return verify_symlink_path(symlink_path);
}

static bool verify_absolute_paths(void) {
#ifdef _WIN32
    char absolute_staging[4096];
    char absolute_target[4096];
    DWORD staging_length = GetFullPathNameA(
        staging_path, (DWORD)sizeof(absolute_staging),
        absolute_staging, NULL);
    DWORD target_length = GetFullPathNameA(
        target_path, (DWORD)sizeof(absolute_target),
        absolute_target, NULL);
    if (staging_length == 0 || target_length == 0 ||
        staging_length >= sizeof(absolute_staging) ||
        target_length >= sizeof(absolute_target)) {
        return false;
    }
    if (!write_file(absolute_staging, "revision-2") ||
        !publish_paths(absolute_staging, absolute_target) ||
        kookie_durable_trace() != 31 ||
        !read_matches(absolute_target, "revision-2") ||
        !absent(absolute_staging)) {
        return false;
    }
    if (!write_file(staging_path, "revision-1") ||
        !publish() || kookie_durable_trace() != 31 ||
        !read_matches(target_path, "revision-1") ||
        !absent(staging_path)) {
        return false;
    }
#endif
    return true;
}


int main(void) {
    int mode = kookie_durable_mode();
    if (mode == 0) {
        if (!discard_stage() ||
            (!absent(target_path) && remove(target_path) != 0)) {
            return 1;
        }
        if (!write_file(staging_path, "revision-1") ||
            !publish() || kookie_durable_trace() != 31 ||
            !read_matches(target_path, "revision-1") ||
            !absent(staging_path) ||
            !verify_negative_paths() ||
            !verify_absolute_paths()) {
            return 1;
        }
        puts("durable-baseline-ok");
        return 0;
    }
    if (mode == 5) {
        if (!write_file(staging_path, "revision-2") || publish()) {
            return 1;
        }
        return 1;
    }
    if (mode == 8) {
        if (!read_matches(staging_path, "revision-2") ||
            !read_matches(target_path, "revision-1") ||
            !discard_stage() || !absent(staging_path) ||
            !read_matches(target_path, "revision-1")) {
            return 1;
        }
        puts("durable-before-file-sync-recovered");
        return 0;
    }
    if (mode == 1) {
        if (!write_file(staging_path, "revision-2") || publish()) {
            return 1;
        }
        return 1;
    }
    if (mode == 9) {
        if (!read_matches(staging_path, "revision-2") ||
            !read_matches(target_path, "revision-1") ||
            !discard_stage() || !absent(staging_path) ||
            !read_matches(target_path, "revision-1")) {
            return 1;
        }
        puts("durable-after-file-sync-recovered");
        return 0;
    }
    if (mode == 2) {
        if (!write_file(staging_path, "revision-2") || !publish()) {
            return 1;
        }
        return 1;
    }
    if (mode == 3) {
        if (!absent(staging_path) || !read_matches(target_path, "revision-2") ||
            !write_file(staging_path, "revision-3") || !publish() ||
            kookie_durable_trace() != 31 ||
            !read_matches(target_path, "revision-3") ||
            !absent(staging_path)) {
            return 1;
        }
        puts("durable-after-rename-recovered");
        return 0;
    }
    if (mode == 6) {
        if (!write_file(staging_path, "revision-4") || !publish()) {
            return 1;
        }
        return 1;
    }
    if (mode == 7) {
        if (!absent(staging_path) || !read_matches(target_path, "revision-4")) {
            return 1;
        }
        puts("durable-after-directory-sync-recovered");
        return 0;
    }
    if (mode == 4) {
        if (!read_matches(target_path, "revision-4") ||
            !discard_stage() || !absent(staging_path) ||
            !read_matches(target_path, "revision-4")) {
            return 1;
        }
        puts("durable-torn-stage-discarded");
        return 0;
    }
    return 1;
}
