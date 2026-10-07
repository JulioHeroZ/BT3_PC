#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <filesystem>
#include <string>

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int)
{
    wchar_t module[32768]{};
    if (!GetModuleFileNameW(nullptr, module, 32768)) return 1;
    const auto root = std::filesystem::path(module).parent_path();
    auto runner = root / L"ps2EntryRunner.exe";
    if (!std::filesystem::exists(runner)) {
        wchar_t configured[32768]{};
        GetPrivateProfileStringW(L"Launcher", L"Runner", L"", configured, 32768,
                                 (root / L"launcher.ini").c_str());
        runner = configured;
    }
    auto elf = root / L"data" / L"SLUS_216.78";
    if (!std::filesystem::exists(elf)) elf = root / L"ELF" / L"slus_216.78";
    if (!std::filesystem::is_regular_file(runner) || !std::filesystem::is_regular_file(elf)) {
        MessageBoxW(nullptr, L"Executavel ou dados do jogo ausentes. Conclua a build e a instalacao dos dados.",
                    L"BT3 PC", MB_OK | MB_ICONERROR);
        return 1;
    }
    SetEnvironmentVariableW(L"PS2X_CD_IMAGE", nullptr);
    auto userRoot = root;
    if (std::filesystem::exists(root / L"installed.marker")) {
        wchar_t local[32768]{};
        if (!GetEnvironmentVariableW(L"LOCALAPPDATA", local, 32768)) return 1;
        userRoot = std::filesystem::path(local) / L"Dragon Ball Budokai Tenkaichi 3";
        std::error_code setupError;
        std::filesystem::create_directories(userRoot / L"savedata", setupError);
        for (const auto &file : {L"savedata/settings.toml", L"fps60_sites.txt"}) {
            if (!std::filesystem::exists(userRoot / file))
                std::filesystem::copy_file(root / file, userRoot / file, setupError);
        }
        SetEnvironmentVariableW(L"PS2X_SAVE_ROOT", (userRoot / L"savedata").c_str());
    } else {
        SetEnvironmentVariableW(L"PS2X_SAVE_ROOT", nullptr);
    }
    SetEnvironmentVariableW(L"PS2X_EXEDIR", userRoot.c_str());
    SetEnvironmentVariableW(L"PS2X_ASSETDIR", (root / L"assets").c_str());
    std::error_code ec;
    std::filesystem::create_directories(userRoot / L"logs", ec);
    SECURITY_ATTRIBUTES security{sizeof(security), nullptr, TRUE};
    HANDLE log = CreateFileW((userRoot / L"logs" / L"game-latest.log").c_str(), GENERIC_WRITE,
                            FILE_SHARE_READ, &security, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (log == INVALID_HANDLE_VALUE) {
        MessageBoxW(nullptr, L"Nao foi possivel criar o log na pasta do jogo.", L"BT3 PC", MB_OK | MB_ICONERROR);
        return 1;
    }
    HANDLE input = CreateFileW(L"NUL", GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE,
                               &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    STARTUPINFOW start{};
    start.cb = sizeof(start);
    start.dwFlags = STARTF_USESTDHANDLES;
    start.hStdOutput = log;
    start.hStdError = log;
    start.hStdInput = input;
    PROCESS_INFORMATION process{};
    std::wstring command = L"\"" + runner.wstring() + L"\" \"" + elf.wstring() + L"\"";
    const BOOL ok = CreateProcessW(runner.c_str(), command.data(), nullptr, nullptr, TRUE,
                                   CREATE_NO_WINDOW, nullptr, userRoot.c_str(), &start, &process);
    const DWORD error = ok ? 0 : GetLastError();
    CloseHandle(log);
    if (input != INVALID_HANDLE_VALUE) CloseHandle(input);
    if (!ok) {
        const auto message = L"Falha ao iniciar o jogo. Codigo Windows: " + std::to_wstring(error);
        MessageBoxW(nullptr, message.c_str(), L"BT3 PC", MB_OK | MB_ICONERROR);
        return 1;
    }
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
    return 0;
}
