#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <stdio.h>
#ifndef TEST_LAUNCHER
static int closes = 0;
static LRESULT CALLBACK Proc(HWND h, UINT m, WPARAM w, LPARAM l) {
    if (m == WM_CLOSE) { ++closes; ShowWindow(h, SW_HIDE); return 0; }
    return DefWindowProcW(h, m, w, l);
}
#endif
int WINAPI wWinMain(HINSTANCE instance, HINSTANCE, LPWSTR, int) {
#ifdef TEST_LAUNCHER
    (void)instance;
    wchar_t file[MAX_PATH];
    GetModuleFileNameW(nullptr, file, MAX_PATH);
    wcscpy_s(wcsrchr(file, L'\\') + 1, 32, L"current\\LINE.exe");
    SHELLEXECUTEINFOW info = {sizeof(info)};
    info.fMask = SEE_MASK_NOCLOSEPROCESS;
    info.lpFile = file;
    info.lpParameters = L"run --booting";
    info.nShow = SW_SHOWNORMAL;
    if (!ShellExecuteExW(&info)) return 20;
    WaitForSingleObject(info.hProcess, 15000);
    DWORD code = 21; GetExitCodeProcess(info.hProcess, &code);
    CloseHandle(info.hProcess);
    return static_cast<int>(code);
#else
    WNDCLASSW cls = {};
    cls.hInstance = instance; cls.lpfnWndProc = Proc; cls.lpszClassName = L"Qt663QWindowIcon";
    RegisterClassW(&cls);
    HWND splash = CreateWindowExW(WS_EX_TOOLWINDOW, cls.lpszClassName, L"", WS_POPUP | WS_VISIBLE,
        0, 0, 200, 100, nullptr, nullptr, instance, nullptr);
    ShowWindow(splash, SW_SHOWNORMAL);
    SetWindowPos(splash, nullptr, 0, 0, 200, 100, SWP_SHOWWINDOW | SWP_NOZORDER);
    bool splashHidden = !IsWindowVisible(splash);
    HWND window = CreateWindowExW(0, cls.lpszClassName, L"LINE", WS_OVERLAPPEDWINDOW,
        0, 0, 400, 300, nullptr, nullptr, instance, nullptr);
    ShowWindow(window, SW_SHOWNORMAL);
    bool initiallyHidden = !IsWindowVisible(window);
    MSG message;
    // Drain the fixture's queued WM_CLOSE. The production helper has no message loop.
    while (PeekMessageW(&message, nullptr, 0, 0, PM_REMOVE)) DispatchMessageW(&message);
    bool closeHidden = !IsWindowVisible(window) && closes == 1;
    ShowWindow(window, SW_SHOWNORMAL);
    bool reopened = IsWindowVisible(window);
    ShowWindow(window, SW_HIDE);
    wchar_t file[MAX_PATH]; GetEnvironmentVariableW(L"LOCALAPPDATA", file, MAX_PATH);
    wcscat_s(file, L"\\fixture-result.txt");
    FILE* result = nullptr; _wfopen_s(&result, file, L"w");
    if (result) { fprintf(result, "splashHidden=%d initiallyHidden=%d closeHidden=%d reopened=%d\n", splashHidden, initiallyHidden, closeHidden, reopened); fclose(result); }
    DestroyWindow(splash);
    DestroyWindow(window);
    return splashHidden && initiallyHidden && closeHidden && reopened ? 0 : 22;
#endif
}
