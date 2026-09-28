#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <detours.h>
#include <stdio.h>

int WINAPI wWinMain(HINSTANCE, HINSTANCE, LPWSTR, int) {
    wchar_t launcher[MAX_PATH] = {}, command[MAX_PATH + 32] = {};
    GetEnvironmentVariableW(L"LOCALAPPDATA", launcher, MAX_PATH);
    wcscat_s(launcher, L"\\LINE\\bin\\LineLauncher.exe");
    swprintf_s(command, L"\"%s\" --booting", launcher);
    char hook[MAX_PATH] = {};
    GetModuleFileNameA(nullptr, hook, MAX_PATH);
    char* tail = strrchr(hook, '\\');
    if (!tail) return 1;
    strcpy_s(tail + 1, MAX_PATH - (tail + 1 - hook), "LineTrayHook32.dll");
    STARTUPINFOW si = { sizeof(si) };
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi = {};
    if (!DetourCreateProcessWithDllExW(launcher, command, nullptr, nullptr, FALSE,
        CREATE_DEFAULT_ERROR_MODE, nullptr, nullptr, &si, &pi, hook, nullptr)) {
        wchar_t message[256];
        swprintf_s(message, L"LINEの通知領域起動に失敗しました (Windows error %lu)。", GetLastError());
        MessageBoxW(nullptr, message, L"LINE Tray Startup", MB_OK | MB_ICONERROR);
        return 1;
    }
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    return 0;
}
