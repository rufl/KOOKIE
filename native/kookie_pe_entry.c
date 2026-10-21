#include <stdio.h>
#include <string.h>
#include <windows.h>

int kookie_kof_gameplay_main(void);

static int packaged_glb_valid(const char *root, const char *relative_path) {
    char path[MAX_PATH * 2];
    int path_length = snprintf(path, sizeof(path), "%s\\%s", root, relative_path);
    if (path_length < 0 || (size_t)path_length >= sizeof(path)) {
        return 0;
    }
    FILE *file = fopen(path, "rb");
    if (file == NULL) {
        return 0;
    }
    unsigned char header[12];
    int valid = fread(header, 1, sizeof(header), file) == sizeof(header) &&
        fseek(file, 0, SEEK_END) == 0;
    long size = valid ? ftell(file) : -1;
    fclose(file);
    if (!valid || size < 20 || size > 1048576) {
        return 0;
    }
    unsigned int declared_size = (unsigned int)header[8] |
        ((unsigned int)header[9] << 8) |
        ((unsigned int)header[10] << 16) |
        ((unsigned int)header[11] << 24);
    return header[0] == 'g' && header[1] == 'l' &&
        header[2] == 'T' && header[3] == 'F' &&
        header[4] == 2 && header[5] == 0 &&
        header[6] == 0 && header[7] == 0 && declared_size == (unsigned int)size;
}

static int package_smoke(void) {
#ifdef KOOKIE_PACKAGE_PROTOTYPE_CONTENT
    char executable[MAX_PATH];
    DWORD length = GetModuleFileNameA(NULL, executable, sizeof(executable));
    if (length == 0 || length >= sizeof(executable)) {
        fputs("KOOKIE package smoke: cannot resolve executable directory\n", stderr);
        return 1;
    }
    char *separator = strrchr(executable, '\\');
    if (separator == NULL) {
        separator = strrchr(executable, '/');
    }
    if (separator == NULL) {
        fputs("KOOKIE package smoke: executable has no directory\n", stderr);
        return 1;
    }
    *separator = '\0';
    if (!packaged_glb_valid(executable, "content/prototype/models/goose/goose.glb") ||
        !packaged_glb_valid(executable, "content/prototype/models/cat/cat.glb")) {
        fputs("KOOKIE package smoke: required prototype GLB is missing or invalid\n", stderr);
        return 1;
    }
    puts("KOOKIE Windows PE smoke verified packaged prototype GLBs");
#else
    puts("KOOKIE Windows PE entrypoint smoke verified");
#endif
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--package-smoke") == 0) {
        return package_smoke();
    }
    return kookie_kof_gameplay_main();
}
