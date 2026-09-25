#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <stdio.h>
#include <string.h>

static int append(char *dst, size_t cap, size_t *used, const char *src) {
    size_t n = strlen(src);
    if (*used + n + 1 > cap) return 0;
    memcpy(dst + *used, src, n);
    *used += n;
    dst[*used] = '\0';
    return 1;
}

int main(void) {
    char module[MAX_PATH];
    DWORD length = GetModuleFileNameA(NULL, module, sizeof(module));
    if (length == 0 || length >= sizeof(module)) return 127;
    char *slash = strrchr(module, '\\');
    if (!slash) return 127;
    slash[1] = '\0';

    char command[32768];
    size_t used = 0;
    if (!append(command, sizeof(command), &used, "\"")) return 127;
    if (!append(command, sizeof(command), &used, module)) return 127;
    if (!append(command, sizeof(command), &used, "jdk\\bin\\java.exe\" -jar \"")) return 127;
    if (!append(command, sizeof(command), &used, module)) return 127;
    if (!append(command, sizeof(command), &used, "kookie.jar\"")) return 127;

    const char *full = GetCommandLineA();
    int quoted = 0;
    while (*full) {
        if (*full == '"') quoted = !quoted;
        else if (!quoted && (*full == ' ' || *full == '\t')) break;
        full++;
    }
    while (*full == ' ' || *full == '\t') full++;
    if (*full) {
        if (!append(command, sizeof(command), &used, " ")) return 127;
        if (!append(command, sizeof(command), &used, full)) return 127;
    }

    STARTUPINFOA startup;
    PROCESS_INFORMATION process;
    ZeroMemory(&startup, sizeof(startup));
    ZeroMemory(&process, sizeof(process));
    startup.cb = sizeof(startup);
    if (!CreateProcessA(NULL, command, NULL, NULL, FALSE, 0, NULL, module, &startup, &process)) {
        return 127;
    }
    WaitForSingleObject(process.hProcess, INFINITE);
    DWORD exit_code = 127;
    GetExitCodeProcess(process.hProcess, &exit_code);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return (int)exit_code;
}
