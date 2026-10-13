$arguments = @($args)
$timeoutSeconds = 240
$separator = -1
$index = 0
while ($index -lt $arguments.Count) {
    if ($arguments[$index] -eq '--timeout') {
        if ($index + 1 -ge $arguments.Count) {
            [Console]::Error.WriteLine('windows-isolated-display: --timeout requires a value')
            exit 2
        }
        $parsedTimeout = 0
        if (-not [int]::TryParse([string]$arguments[$index + 1], [ref]$parsedTimeout) -or $parsedTimeout -le 0) {
            [Console]::Error.WriteLine('windows-isolated-display: timeout must be a positive integer')
            exit 2
        }
        $timeoutSeconds = $parsedTimeout
        $index += 2
        continue
    }
    if ($arguments[$index] -eq '--') {
        $separator = $index
        break
    }
    [Console]::Error.WriteLine(('windows-isolated-display: unexpected argument: {0}' -f $arguments[$index]))
    exit 2
}
if ($separator -lt 0 -or $separator + 1 -ge $arguments.Count) {
    [Console]::Error.WriteLine('windows-isolated-display: expected -- followed by a command')
    exit 2
}
 $commandArguments = @($arguments[($separator + 1)..($arguments.Count - 1)])
 if ($commandArguments.Count -eq 0) {
     [Console]::Error.WriteLine('windows-isolated-display: command is required')
     exit 2
 }

if (-not [Type]::GetType('KookieWindowsIsolatedDesktop', $false)) {
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text;

public static class KookieWindowsIsolatedDesktop
{
    private const uint CreateSuspended = 0x00000004;
    private const uint CreateUnicodeEnvironment = 0x00000400;
    private const uint StartfUseStdHandles = 0x00000100;
    private const uint GenericRead = 0x80000000;
    private const uint GenericWrite = 0x40000000;
    private const uint FileShareRead = 0x00000001;
    private const uint FileShareWrite = 0x00000002;
    private const uint OpenExisting = 3;
    private const uint FileAttributeNormal = 0x00000080;
    private const uint DesktopAllAccess = 0x000F01FF;
    private const uint JobObjectExtendedLimitInformation = 9;
    private const uint JobObjectLimitKillOnJobClose = 0x00002000;
    private const uint WaitObject0 = 0x00000000;
    private const uint WaitTimeout = 0x00000102;
    private const uint Infinite = 0xFFFFFFFF;
    private const uint StillActive = 259;
    private static readonly IntPtr InvalidHandleValue = new IntPtr(-1);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct StartupInfo
    {
        public int cb;
        public string lpReserved;
        public string lpDesktop;
        public string lpTitle;
        public int dwX;
        public int dwY;
        public int dwXSize;
        public int dwYSize;
        public int dwXCountChars;
        public int dwYCountChars;
        public int dwFillAttribute;
        public uint dwFlags;
        public short wShowWindow;
        public short cbReserved2;
        public IntPtr lpReserved2;
        public IntPtr hStdInput;
        public IntPtr hStdOutput;
        public IntPtr hStdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct SecurityAttributes
    {
        public int nLength;
        public IntPtr lpSecurityDescriptor;
        public int bInheritHandle;
    }
    private struct ProcessInformation
    {
        public IntPtr hProcess;
        public IntPtr hThread;
        public uint processId;
        public uint threadId;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct BasicLimitInformation
    {
        public long perProcessUserTimeLimit;
        public long perJobUserTimeLimit;
        public uint limitFlags;
        public UIntPtr minimumWorkingSetSize;
        public UIntPtr maximumWorkingSetSize;
        public uint activeProcessLimit;
        public UIntPtr affinity;
        public uint priorityClass;
        public uint schedulingClass;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct IoCounters
    {
        public ulong readOperationCount;
        public ulong writeOperationCount;
        public ulong otherOperationCount;
        public ulong readTransferCount;
        public ulong writeTransferCount;
        public ulong otherTransferCount;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ExtendedLimitInformation
    {
        public BasicLimitInformation basicLimitInformation;
        public IoCounters ioCounters;
        public UIntPtr processMemoryLimit;
        public UIntPtr jobMemoryLimit;
        public UIntPtr peakProcessMemoryUsed;
        public UIntPtr peakJobMemoryUsed;
    }

    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateDesktop(
        string desktopName,
        IntPtr device,
        IntPtr devMode,
        uint flags,
        uint desiredAccess,
        IntPtr securityAttributes);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool CloseDesktop(IntPtr desktop);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateJobObject(IntPtr securityAttributes, string name);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetInformationJobObject(
        IntPtr job,
        uint informationClass,
        ref ExtendedLimitInformation information,
        uint informationLength);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool AssignProcessToJobObject(IntPtr job, IntPtr process);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateJobObject(IntPtr job, uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr process, uint exitCode);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint ResumeThread(IntPtr thread);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GetExitCodeProcess(IntPtr process, out uint exitCode);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CreateFile(
        string name,
        uint desiredAccess,
        uint shareMode,
        ref SecurityAttributes securityAttributes,
        uint creationDisposition,
        uint flagsAndAttributes,
        IntPtr templateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CreateProcess(
        string applicationName,
        StringBuilder commandLine,
        IntPtr processAttributes,
        IntPtr threadAttributes,
        bool inheritHandles,
        uint creationFlags,
        IntPtr environment,
        string currentDirectory,
        ref StartupInfo startupInfo,
        out ProcessInformation processInformation);

    private static string QuoteArgument(string value)
    {
        if (value == null)
            return "\"\"";

        var result = new StringBuilder(value.Length + 2);
        result.Append('"');
        var backslashes = 0;
        foreach (var character in value)
        {
            if (character == '\\')
            {
                backslashes++;
                continue;
            }
            if (character == '"')
            {
                result.Append('\\', backslashes * 2 + 1);
                result.Append('"');
                backslashes = 0;
                continue;
            }
            result.Append('\\', backslashes);
            result.Append(character);
            backslashes = 0;
        }
        result.Append('\\', backslashes * 2);
        result.Append('"');
        return result.ToString();
    }

    private static string BuildCommandLine(string executable, string[] arguments)
    {
        var commandLine = new StringBuilder(QuoteArgument(executable));
        foreach (var argument in arguments)
        {
            commandLine.Append(' ');
            commandLine.Append(QuoteArgument(argument));
        }
        return commandLine.ToString();
    }

    private static void ThrowLastError(string operation)
    {
        throw new Win32Exception(Marshal.GetLastWin32Error(), operation);
    }

    private static IntPtr OpenNullHandle(uint access, string streamName)
    {
        var securityAttributes = new SecurityAttributes();
        securityAttributes.nLength = Marshal.SizeOf(typeof(SecurityAttributes));
        securityAttributes.bInheritHandle = 1;
        var handle = CreateFile(
            "NUL",
            access,
            FileShareRead | FileShareWrite,
            ref securityAttributes,
            OpenExisting,
            FileAttributeNormal,
            IntPtr.Zero);
        if (handle == InvalidHandleValue)
            ThrowLastError("CreateFile NUL " + streamName + " failed");
        return handle;
    }

    public static int Run(string executable, string[] arguments, int timeoutSeconds)
    {
        if (String.IsNullOrWhiteSpace(executable))
            throw new ArgumentException("an executable is required", "executable");
        if (arguments == null || arguments.Length == 0)
            throw new ArgumentException("a command is required", "arguments");
        if (timeoutSeconds <= 0)
            throw new ArgumentOutOfRangeException("timeoutSeconds");

        var desktopName = "kookie-isolated-" + Guid.NewGuid().ToString("N");
        var desktop = CreateDesktop(desktopName, IntPtr.Zero, IntPtr.Zero, 0, DesktopAllAccess, IntPtr.Zero);
        if (desktop == IntPtr.Zero)
            ThrowLastError("CreateDesktop failed");

        var job = IntPtr.Zero;
        var process = IntPtr.Zero;
        var thread = IntPtr.Zero;
        var standardInput = IntPtr.Zero;
        var standardOutput = IntPtr.Zero;
        var standardError = IntPtr.Zero;
        var completed = false;
        try
            {
                job = CreateJobObject(IntPtr.Zero, null);
                if (job == IntPtr.Zero)
                    ThrowLastError("CreateJobObject failed");
                var limits = new ExtendedLimitInformation();
                limits.basicLimitInformation.limitFlags = JobObjectLimitKillOnJobClose;
                var limitsSize = (uint)Marshal.SizeOf(typeof(ExtendedLimitInformation));
                if (!SetInformationJobObject(job, JobObjectExtendedLimitInformation, ref limits, limitsSize))
                    ThrowLastError("SetInformationJobObject failed");

                standardInput = OpenNullHandle(GenericRead, "stdin");
                standardOutput = OpenNullHandle(GenericWrite, "stdout");
                standardError = OpenNullHandle(GenericWrite, "stderr");
                var startup = new StartupInfo();
                startup.cb = Marshal.SizeOf(typeof(StartupInfo));
                startup.lpDesktop = desktopName;
                startup.dwFlags = StartfUseStdHandles;
                startup.hStdInput = standardInput;
                startup.hStdOutput = standardOutput;
                startup.hStdError = standardError;
                var commandLine = new StringBuilder(BuildCommandLine(executable, arguments));
                ProcessInformation processInformation;
                if (!CreateProcess(
                        executable,
                        commandLine,
                        IntPtr.Zero,
                        IntPtr.Zero,
                        true,
                        CreateSuspended | CreateUnicodeEnvironment,
                        IntPtr.Zero,
                        null,
                        ref startup,
                        out processInformation))
                    ThrowLastError("CreateProcess failed");

                process = processInformation.hProcess;
                thread = processInformation.hThread;
                if (!AssignProcessToJobObject(job, process))
                    ThrowLastError("AssignProcessToJobObject failed");
                if (ResumeThread(thread) == 0xFFFFFFFF)
                    ThrowLastError("ResumeThread failed");

                var timeoutMilliseconds = checked((uint)timeoutSeconds * 1000U);
                var waitResult = WaitForSingleObject(process, timeoutMilliseconds);
                if (waitResult == WaitTimeout)
                {
                    if (!TerminateJobObject(job, 124))
                        ThrowLastError("TerminateJobObject failed");
                    WaitForSingleObject(process, Infinite);
                    completed = true;
                    return 124;
                }
                if (waitResult != WaitObject0)
                    ThrowLastError("WaitForSingleObject failed");

                uint exitCode;
                if (!GetExitCodeProcess(process, out exitCode))
                    ThrowLastError("GetExitCodeProcess failed");
                completed = true;
                return exitCode == StillActive ? 1 : (int)exitCode;
            }
        finally
        {
            if (!completed)
            {
                if (process != IntPtr.Zero)
                    TerminateProcess(process, 2);
                if (job != IntPtr.Zero)
                    TerminateJobObject(job, 2);
            }
            if (standardError != IntPtr.Zero)
                CloseHandle(standardError);
            if (standardOutput != IntPtr.Zero)
                CloseHandle(standardOutput);
            if (standardInput != IntPtr.Zero)
                CloseHandle(standardInput);
            if (thread != IntPtr.Zero)
                CloseHandle(thread);
            if (process != IntPtr.Zero)
                CloseHandle(process);
            if (job != IntPtr.Zero)
                CloseHandle(job);
            CloseDesktop(desktop);
        }
    }
}
'@
}

try {
    $commandPath = $env:KOOKIE_WINDOWS_COMMAND
    if ([string]::IsNullOrWhiteSpace($commandPath) -or -not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        $commandPath = Join-Path $env:ProgramFiles 'Git\usr\bin\bash.exe'
        if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
            $commandPath = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
        }
    }
    if (-not (Test-Path -LiteralPath $commandPath -PathType Leaf)) {
        throw 'Windows command executable not found; set KOOKIE_WINDOWS_COMMAND'
    }
    $childArguments = @($commandArguments)
    if ([System.IO.Path]::GetFileName($commandPath) -ieq 'bash.exe') {
        $childArguments = @('--noprofile', '--norc') + $childArguments
    }
    $exitCode = [KookieWindowsIsolatedDesktop]::Run($commandPath, [string[]]$childArguments, $timeoutSeconds)
}
catch {
    [Console]::Error.WriteLine(('windows-isolated-display: {0}' -f $_.Exception.Message))
    exit 2
}
