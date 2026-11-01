#include <stdlib.h>
#include <string.h>

int kookie_native_adapter_mode(void) {
    const char *mode = getenv("KOOKIE_NATIVE_ADAPTER_MODE");
    if (mode != NULL && strcmp(mode, "transport") == 0) {
        return 1;
    }
    if (mode != NULL && strcmp(mode, "graphics") == 0) {
        return 2;
    }
    return 0;
}
