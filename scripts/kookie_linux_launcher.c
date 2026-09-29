#define _GNU_SOURCE
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int join_path(char *out, size_t capacity, const char *root, const char *name) {
    int written = snprintf(out, capacity, "%s/%s", root, name);
    return written > 0 && (size_t)written < capacity;
}


#ifndef KOOKIE_PRESENTATION_PACKAGE
#define KOOKIE_PRESENTATION_PACKAGE 0
#endif
int main(int argc, char **argv) {
    if (argc < 1 || argv[0] == NULL) return 127;
    char module[PATH_MAX];
    if (realpath(argv[0], module) == NULL) {
        if (strlen(argv[0]) >= sizeof(module)) return 127;
        strcpy(module, argv[0]);
    }
    char *slash = strrchr(module, '/');
    if (slash == NULL) return 127;
    *slash = '\0';
    if (chdir(module) != 0) return 127;

    const char *binary_name = "kookie.bin";
    int first_child_argument = 1;
    if (KOOKIE_PRESENTATION_PACKAGE && argc == 2 &&
        strcmp(argv[1], "--package-smoke") == 0) {
        binary_name = "kookie-smoke.bin";
        first_child_argument = 2;
    }

    char loader[PATH_MAX];
    char library_path[PATH_MAX];
    char binary[PATH_MAX];
    if (!join_path(loader, sizeof(loader), module, "lib/ld-linux-x86-64.so.2") ||
        !join_path(library_path, sizeof(library_path), module, "lib") ||
        !join_path(binary, sizeof(binary), module, binary_name)) {
        return 127;
    }

    char **child_argv = calloc((size_t)argc + 4, sizeof(*child_argv));
    if (child_argv == NULL) return 127;
    child_argv[0] = loader;
    child_argv[1] = "--library-path";
    child_argv[2] = library_path;
    child_argv[3] = binary;
    int child_index = 4;
    for (int index = first_child_argument; index < argc; index += 1) {
        child_argv[child_index] = argv[index];
        child_index += 1;
    }
    execv(loader, child_argv);
    free(child_argv);
    return 127;
}
