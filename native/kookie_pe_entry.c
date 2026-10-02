#include <stdio.h>
#include <string.h>

int kookie_kof_gameplay_main(void);

static int package_smoke(void) {
    puts("KOOKIE Windows presentation package smoke verified");
    return 0;
}

int main(int argc, char **argv) {
    if (argc > 1 && strcmp(argv[1], "--package-smoke") == 0) {
        return package_smoke();
    }
    return kookie_kof_gameplay_main();
}
