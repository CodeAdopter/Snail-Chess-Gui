/* What the fastchess extension needs of Windows past what the engine's headers declare: fastchess run
   in this console with its output piped back, files read and cut while fastchess appends to them,
   named events between snailfast and the app, and the person's PATH. Declared by hand as the
   engine's headers are, so no program includes windows.h. */
#pragma once
#include <stdlib.h>
#include "desktop_child.h"

__declspec(dllimport) void *__stdcall GetStdHandle(unsigned long which);
__declspec(dllimport) unsigned long __stdcall GetLastError(void);
__declspec(dllimport) unsigned short *__stdcall GetCommandLineW(void);
__declspec(dllimport) int __stdcall WideCharToMultiByte(unsigned int page, unsigned long flags, const unsigned short *wide, int chars, char *text, int bytes, const char *fallback, int *used);
__declspec(dllimport) int __stdcall SetConsoleCtrlHandler(int (__stdcall *handler)(unsigned long), int add);
__declspec(dllimport) int __stdcall GenerateConsoleCtrlEvent(unsigned long event, unsigned long group);
__declspec(dllimport) void *__stdcall CreateEventW(sn_security *security, int manual, int initial, const unsigned short *name);
__declspec(dllimport) void *__stdcall OpenEventW(unsigned long access, int inherit, const unsigned short *name);
__declspec(dllimport) int __stdcall SetEvent(void *event);
__declspec(dllimport) void *__stdcall CreateFileW(const unsigned short *name, unsigned long access, unsigned long share, void *security, unsigned long disposition, unsigned long flags, void *template_file);
__declspec(dllimport) int __stdcall GetFileSizeEx(void *file, long long *size);
__declspec(dllimport) int __stdcall SetFilePointerEx(void *file, long long to, long long *at, unsigned long method);
__declspec(dllimport) int __stdcall SetEndOfFile(void *file);
__declspec(dllimport) int __stdcall MoveFileExW(const unsigned short *from, const unsigned short *to, unsigned long flags);
__declspec(dllimport) int __stdcall DeleteFileW(const unsigned short *path);
__declspec(dllimport) int __stdcall CopyFileW(const unsigned short *from, const unsigned short *to, int fail_if_there);
__declspec(dllimport) unsigned long __stdcall GetModuleFileNameW(void *module, unsigned short *name, unsigned long size);
__declspec(dllimport) unsigned long __stdcall GetEnvironmentVariableW(const unsigned short *name, unsigned short *value, unsigned long size);
__declspec(dllimport) unsigned long __stdcall GetCurrentProcessId(void);
__declspec(dllimport) unsigned long __stdcall GetCurrentDirectoryW(unsigned long size, unsigned short *path);
__declspec(dllimport) int __stdcall CreateDirectoryW(const unsigned short *path, void *security);
__declspec(dllimport) void __stdcall GetSystemTimeAsFileTime(unsigned long long *time);
__declspec(dllimport) long __stdcall RegOpenKeyExW(void *key, const unsigned short *sub_key, unsigned long options, unsigned long access, void **result);
__declspec(dllimport) long __stdcall RegQueryValueExW(void *key, const unsigned short *name, unsigned long *reserved, unsigned long *type, unsigned char *data, unsigned long *size);
__declspec(dllimport) long __stdcall RegSetValueExW(void *key, const unsigned short *name, unsigned long reserved, unsigned long type, const unsigned char *data, unsigned long size);
__declspec(dllimport) long __stdcall RegCloseKey(void *key);
__declspec(dllimport) long long __stdcall SendMessageTimeoutW(void *window, unsigned int message, unsigned long long wparam, long long lparam, unsigned int flags, unsigned int timeout, unsigned long long *result);
#pragma comment(lib, "advapi32")
#pragma comment(lib, "user32")

#define SN_FC_PATH_CHARS 32768
#define SN_FC_SHARE_ALL 7u
#define SN_FC_GENERIC_READ 0x80000000u
#define SN_FC_GENERIC_WRITE 0x40000000u
#define SN_FC_OPEN_ALWAYS 4u
#define SN_FC_OPEN_EXISTING 3u
#define SN_FC_CREATE_ALWAYS 2u
#define SN_FC_EVENT_MODIFY 0x0002u
#define SN_FC_SYNCHRONIZE 0x00100000u

/* The app's event that snailfast sets when anything of a run changes, and so finds the app open. */
static const unsigned short sn_fc_app_event[] = L"Local\\SnailChessGuiFastchess";

/* UTF-16 to UTF-8 into text, which holds bytes; the length, 0 when it does not fit. */
static int sn_fc_narrow(const unsigned short *wide, int chars, unsigned char *text, int bytes)
{
    int n = chars != 0 ? WideCharToMultiByte(65001, 0, wide, chars, (char *)text, bytes, 0, 0) : 0;
    return n < 0 ? 0 : n;
}

/* UTF-8 path to UTF-16 in a buffer of SN_FC_PATH_CHARS made here, freed by the caller. */
static unsigned short *sn_fc_wide(const unsigned char *text, int bytes)
{
    unsigned short *wide = (unsigned short *)malloc(SN_FC_PATH_CHARS * 2);
    if (!wide) return 0;
    if (!sn_child_wide(text, bytes, wide, SN_FC_PATH_CHARS)) { free(wide); return 0; }
    return wide;
}

/* The command line this program was given past its own name, as it was typed, in UTF-8. */
static int sn_fc_command_tail(unsigned char *out, int size)
{
    const unsigned short *c = GetCommandLineW();
    int quoted = 0;
    while (*c && (quoted || (*c != ' ' && *c != '\t'))) { if (*c == '"') quoted = !quoted; c++; }
    while (*c == ' ' || *c == '\t') c++;
    int chars = 0;
    while (c[chars]) chars++;
    return sn_fc_narrow(c, chars, out, size);
}

/* This program's own path in UTF-8. */
static int sn_fc_own_path(unsigned char *out, int size)
{
    unsigned short wide[1024];
    unsigned long n = GetModuleFileNameW(0, wide, 1024);
    return n > 0 && n < 1024 ? sn_fc_narrow(wide, (int)n, out, size) : 0;
}

/* An environment variable in UTF-8, 0 when it is not set. */
static int sn_fc_env(const unsigned char *name, int name_len, unsigned char *out, int size)
{
    unsigned short wide_name[128];
    unsigned short value[2048];
    if (!sn_child_wide(name, name_len, wide_name, 128)) return 0;
    unsigned long n = GetEnvironmentVariableW(wide_name, value, 2048);
    return n > 0 && n < 2048 ? sn_fc_narrow(value, (int)n, out, size) : 0;
}

static unsigned long sn_fc_child_group;
static unsigned long sn_fc_start_error;
static volatile long sn_fc_breaks;
static void *sn_fc_child_process;
static void *sn_fc_child_job;
static void *sn_fc_stop_event;

/* Ctrl+C and Ctrl+Break reach snailfast, which hands fastchess a Ctrl+Break of its own, as fastchess
   sits in a group of its own where Ctrl+C is off. fastchess then stops its games and saves. A match
   hands it to its stop thread instead, which ends fastchess should it not stop. */
static int __stdcall sn_fc_on_break(unsigned long kind)
{
    if (kind > 1) return 0;
    sn_fc_breaks++;
    if (sn_fc_stop_event) SetEvent(sn_fc_stop_event);
    else if (sn_fc_child_group) GenerateConsoleCtrlEvent(1, sn_fc_child_group);
    return 1;
}

/* The event a match's stop thread waits on, which Ctrl+C then sets. */
static void sn_fc_stop_with(void *event)
{
    sn_fc_stop_event = event;
}

/* Waits up to ms for fastchess to end once asked to stop, then ends it and its engines with its job.
   Gives 1 when it had to. fastchess can hang as it stops: with many games at once an engine whose
   output it no longer reads stops reading what it is told, and fastchess waits to tell it to quit. */
static int sn_fc_end_child(int ms)
{
    if (!sn_fc_child_process) return 0;
    if (WaitForSingleObject(sn_fc_child_process, (unsigned long)ms) != 0x102 /* WAIT_TIMEOUT */) return 0;
    if (sn_fc_child_job) TerminateJobObject(sn_fc_child_job, 1);
    return 1;
}

/* Closes fastchess's process and its job once nothing waits on them, ending any engine left. */
static void sn_fc_drop_child(void)
{
    if (sn_fc_child_process) CloseHandle(sn_fc_child_process);
    if (sn_fc_child_job) CloseHandle(sn_fc_child_job);
    sn_fc_child_process = 0;
    sn_fc_child_job = 0;
}

/* Runs command with this console, nothing for its input and its output and errors into one pipe
   whose end comes back in from_child, in a job that ends it should this program end. Gives its
   process id, 0 when it could not start. */
static unsigned long sn_fc_start(const unsigned char *command, int command_len, void **process, void **from_child, void **job)
{
    sn_security inherit = { sizeof(sn_security), 0, 1 };
    void *child_out = 0, *out_read = 0;
    sn_startup startup = { 0 };
    sn_process_info info = { 0 };
    unsigned short *wide = sn_fc_wide(command, command_len);
    if (!wide) return 0;
    if (!CreatePipe(&out_read, &child_out, &inherit, 65536)) { free(wide); return 0; }
    SetHandleInformation(out_read, 1, 0);
    startup.cb = sizeof(sn_startup);
    startup.flags = 0x100;
    startup.std_input = 0;
    startup.std_output = child_out;
    startup.std_error = child_out;
    /* CREATE_NEW_PROCESS_GROUP and CREATE_SUSPENDED, so it joins the job before it runs */
    int ok = CreateProcessW(0, wide, 0, 0, 1, 0x200 | 0x4, 0, 0, &startup, &info);
    free(wide);
    CloseHandle(child_out);
    if (!ok) { sn_fc_start_error = GetLastError(); CloseHandle(out_read); return 0; }
    void *j = CreateJobObjectW(0, 0);
    if (j)
    {
        sn_job_limits limits = { 0 };
        limits.basic.flags = 0x2000; /* JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE */
        SetInformationJobObject(j, 9, &limits, sizeof(limits));
        AssignProcessToJobObject(j, info.process);
    }
    sn_fc_child_group = info.process_id;
    sn_fc_child_process = info.process;
    sn_fc_child_job = j;
    SetConsoleCtrlHandler(sn_fc_on_break, 1);
    ResumeThread(info.thread);
    CloseHandle(info.thread);
    *process = info.process;
    *from_child = out_read;
    *job = j;
    return info.process_id;
}

/* Why the last start failed, as Windows numbers it. */
static unsigned long sn_fc_why(void)
{
    return sn_fc_start_error;
}

/* Waits for the process to end and gives its exit code. */
static int sn_fc_finish(void *process)
{
    unsigned long code = 1;
    WaitForSingleObject(process, 0xFFFFFFFFu);
    GetExitCodeProcess(process, &code);
    return (int)code;
}

/* Asks fastchess to stop as Ctrl+C would. */
static void sn_fc_break_child(void)
{
    if (sn_fc_child_group) GenerateConsoleCtrlEvent(1, sn_fc_child_group);
}

/* Reads what a pipe or file holds, waiting for some; 0 at its end or on failure. */
static int sn_fc_read(void *handle, unsigned char *buffer, int size)
{
    unsigned long n = 0;
    if (!ReadFile(handle, buffer, (unsigned long)size, &n, 0)) return 0;
    return (int)n;
}

/* Writes to this program's own output, as the console or a pipe takes it. */
static void sn_fc_print(const unsigned char *text, int len)
{
    unsigned long n = 0;
    void *out = GetStdHandle((unsigned long)-11);
    if (out && out != (void *)(long long)-1 && len > 0) WriteFile(out, text, (unsigned long)len, &n, 0);
}

/* A file opened to add to, made when it is not there and readable by others meanwhile. */
static void *sn_fc_open_add(const unsigned char *path, int len)
{
    unsigned short *wide = sn_fc_wide(path, len);
    if (!wide) return 0;
    void *h = CreateFileW(wide, 4u /* FILE_APPEND_DATA */, SN_FC_SHARE_ALL, 0, SN_FC_OPEN_ALWAYS, 0x80, 0);
    free(wide);
    return h == (void *)(long long)-1 ? 0 : h;
}

/* A file opened to read and cut while another program appends to it, made when it is not there. */
static void *sn_fc_open_shared(const unsigned char *path, int len)
{
    unsigned short *wide = sn_fc_wide(path, len);
    if (!wide) return 0;
    void *h = CreateFileW(wide, SN_FC_GENERIC_READ | SN_FC_GENERIC_WRITE, SN_FC_SHARE_ALL, 0, SN_FC_OPEN_ALWAYS, 0x80, 0);
    free(wide);
    return h == (void *)(long long)-1 ? 0 : h;
}

/* A file opened to read while another program writes it; 0 when it is not there. */
static void *sn_fc_open_read(const unsigned char *path, int len)
{
    unsigned short *wide = sn_fc_wide(path, len);
    if (!wide) return 0;
    void *h = CreateFileW(wide, SN_FC_GENERIC_READ, SN_FC_SHARE_ALL, 0, SN_FC_OPEN_EXISTING, 0x80, 0);
    free(wide);
    return h == (void *)(long long)-1 ? 0 : h;
}

/* A file only this program may open until it closes, made empty; 0 when another holds it. */
static void *sn_fc_hold(const unsigned char *path, int len)
{
    unsigned short *wide = sn_fc_wide(path, len);
    if (!wide) return 0;
    void *h = CreateFileW(wide, SN_FC_GENERIC_WRITE, 0, 0, SN_FC_CREATE_ALWAYS, 0x80, 0);
    free(wide);
    return h == (void *)(long long)-1 ? 0 : h;
}

/* Whether another program holds the file as sn_fc_hold does. */
static int sn_fc_held(const unsigned char *path, int len)
{
    unsigned short *wide = sn_fc_wide(path, len);
    if (!wide) return 0;
    void *h = CreateFileW(wide, SN_FC_GENERIC_READ, SN_FC_SHARE_ALL, 0, SN_FC_OPEN_EXISTING, 0x80, 0);
    unsigned long why = h == (void *)(long long)-1 ? GetLastError() : 0;
    free(wide);
    if (h != (void *)(long long)-1) { CloseHandle(h); return 0; }
    return why == 32 /* ERROR_SHARING_VIOLATION */;
}

static long long sn_fc_size(void *file)
{
    long long size = 0;
    return GetFileSizeEx(file, &size) ? size : -1;
}

/* Reads from offset at, up to size bytes. */
static int sn_fc_read_at(void *file, long long at, unsigned char *buffer, int size)
{
    if (!SetFilePointerEx(file, at, 0, 0)) return 0;
    return sn_fc_read(file, buffer, size);
}

static int sn_fc_write(void *file, const unsigned char *text, int len)
{
    unsigned long n = 0;
    return len <= 0 || (WriteFile(file, text, (unsigned long)len, &n, 0) && n == (unsigned long)len);
}

/* Cuts a file to nothing. A program that appends to it goes on at its new end. */
static int sn_fc_cut(void *file)
{
    return SetFilePointerEx(file, 0, 0, 0) && SetEndOfFile(file);
}

static void sn_fc_close(void *handle)
{
    if (handle) CloseHandle(handle);
}

/* Deletes a file, the path in UTF-8. */
static int sn_fc_remove(const unsigned char *path, int len)
{
    unsigned short *wide = sn_fc_wide(path, len);
    int ok = wide && DeleteFileW(wide);
    free(wide);
    return ok;
}

/* Moves a file over another, or copies one, the paths in UTF-8. */
static int sn_fc_move(const unsigned char *from, int from_len, const unsigned char *to, int to_len)
{
    unsigned short *a = sn_fc_wide(from, from_len);
    unsigned short *b = sn_fc_wide(to, to_len);
    int ok = a && b && MoveFileExW(a, b, 1u | 8u); /* REPLACE_EXISTING, WRITE_THROUGH */
    free(a);
    free(b);
    return ok;
}

static int sn_fc_copy(const unsigned char *from, int from_len, const unsigned char *to, int to_len)
{
    unsigned short *a = sn_fc_wide(from, from_len);
    unsigned short *b = sn_fc_wide(to, to_len);
    int ok = a && b && CopyFileW(a, b, 0);
    free(a);
    free(b);
    return ok;
}

/* The app's event, made by the app; 0 when another copy of the app made it first. */
static void *sn_fc_listen(void)
{
    void *e = CreateEventW(0, 0, 0, sn_fc_app_event);
    if (e && GetLastError() == 183 /* ERROR_ALREADY_EXISTS */) { CloseHandle(e); return 0; }
    return e;
}

/* Waits up to ms for the event; 1 when it was set. */
static int sn_fc_wait(void *event, int ms)
{
    return WaitForSingleObject(event, ms < 0 ? 0xFFFFFFFFu : (unsigned long)ms) == 0;
}

/* Sets a named event, here the app's when name is empty; 0 when nothing made it. */
static int sn_fc_signal(const unsigned char *name, int len)
{
    unsigned short wide[260];
    if (len > 0 && !sn_child_wide(name, len, wide, 260)) return 0;
    void *e = OpenEventW(SN_FC_EVENT_MODIFY, 0, len > 0 ? wide : sn_fc_app_event);
    if (!e) return 0;
    SetEvent(e);
    CloseHandle(e);
    return 1;
}

/* A named event this program waits on, such as a run's stop, or one of its own with no name. */
static void *sn_fc_event(const unsigned char *name, int len)
{
    unsigned short wide[260];
    if (len > 0 && !sn_child_wide(name, len, wide, 260)) return 0;
    return CreateEventW(0, 0, 0, len > 0 ? wide : 0);
}

static int sn_fc_set(void *event)
{
    return event && SetEvent(event);
}

/* Starts a program with no ties to this one, leaving any job this one is in when it may, in folder
   when it is not empty. A console program gets a console of its own with no window when hidden is
   set, which snailfast needs to stop fastchess as Ctrl+C would, and none otherwise. */
static int sn_fc_launch(const unsigned char *command, int len, const unsigned char *folder, int folder_len, int hidden)
{
    sn_startup startup = { 0 };
    sn_process_info info = { 0 };
    unsigned short *wide = sn_fc_wide(command, len);
    unsigned short *place = folder_len > 0 ? sn_fc_wide(folder, folder_len) : 0;
    if (!wide) { free(place); return 0; }
    startup.cb = sizeof(sn_startup);
    /* CREATE_NO_WINDOW or DETACHED_PROCESS, with CREATE_BREAKAWAY_FROM_JOB when the job allows it */
    unsigned long flags = hidden ? 0x08000000u : 0x8u;
    int ok = CreateProcessW(0, wide, 0, 0, 0, flags | 0x01000000u, 0, place, &startup, &info);
    if (!ok) ok = CreateProcessW(0, wide, 0, 0, 0, flags, 0, place, &startup, &info);
    free(place);
    free(wide);
    if (!ok) return 0;
    CloseHandle(info.thread);
    CloseHandle(info.process);
    return 1;
}

static unsigned long sn_fc_pid(void)
{
    return GetCurrentProcessId();
}

/* The time now in milliseconds since 1970, as the app's own clock reads it. */
static long long sn_fc_now_ms(void)
{
    unsigned long long t = 0;
    GetSystemTimeAsFileTime(&t);
    return (long long)(t / 10000ull) - 11644473600000ll;
}

/* The folder this program was started in, in UTF-8. */
static int sn_fc_folder(unsigned char *out, int size)
{
    unsigned short wide[1024];
    unsigned long n = GetCurrentDirectoryW(1024, wide);
    return n > 0 && n < 1024 ? sn_fc_narrow(wide, (int)n, out, size) : 0;
}

/* Makes a folder, giving 1 when it is there after. */
static int sn_fc_make_folder(const unsigned char *path, int len)
{
    unsigned short *wide = sn_fc_wide(path, len);
    if (!wide) return 0;
    int ok = CreateDirectoryW(wide, 0) || GetLastError() == 183 /* ERROR_ALREADY_EXISTS */;
    free(wide);
    return ok;
}

/* The person's own PATH, from HKEY_CURRENT_USER\Environment, in UTF-8; -1 when it cannot be read
   and 0 when it is empty or not there. */
static int sn_fc_user_path(unsigned char *out, int size, unsigned int *kind)
{
    void *key = 0;
    unsigned long t = 2; /* REG_EXPAND_SZ */
    unsigned long *type = &t;
    if (RegOpenKeyExW((void *)(long long)(int)0x80000001, L"Environment", 0, 0x20019u /* KEY_READ */, &key) != 0) return -1;
    unsigned long bytes = 0;
    long r = RegQueryValueExW(key, L"Path", 0, type, 0, &bytes);
    if (r == 2 /* ERROR_FILE_NOT_FOUND */) { RegCloseKey(key); return 0; }
    if (r != 0 || bytes > 65536) { RegCloseKey(key); return -1; }
    unsigned short *wide = (unsigned short *)malloc(bytes + 2);
    if (!wide) { RegCloseKey(key); return -1; }
    r = RegQueryValueExW(key, L"Path", 0, type, (unsigned char *)wide, &bytes);
    RegCloseKey(key);
    if (r != 0) { free(wide); return -1; }
    int chars = (int)(bytes / 2);
    while (chars > 0 && wide[chars - 1] == 0) chars--;
    int n = chars > 0 ? sn_fc_narrow(wide, chars, out, size) : 0;
    free(wide);
    *kind = (unsigned int)t;
    return chars > 0 && n == 0 ? -1 : n;
}

/* Saves the person's own PATH and tells open programs, so new terminals see it. */
static int sn_fc_set_user_path(const unsigned char *text, int len, unsigned int type)
{
    void *key = 0;
    unsigned short *wide = sn_fc_wide(text, len);
    if (!wide) return 0;
    int chars = 0;
    while (wide[chars]) chars++;
    if (RegOpenKeyExW((void *)(long long)(int)0x80000001, L"Environment", 0, 0x20006u /* KEY_WRITE */, &key) != 0) { free(wide); return 0; }
    long r = RegSetValueExW(key, L"Path", 0, type == 1 ? 1 : 2, (const unsigned char *)wide, (unsigned long)(chars + 1) * 2);
    RegCloseKey(key);
    free(wide);
    if (r != 0) return 0;
    unsigned long long result = 0;
    SendMessageTimeoutW((void *)(long long)0xffff, 0x1A, 0, (long long)L"Environment", 2, 2000, &result);
    return 1;
}
