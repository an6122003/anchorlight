import Foundation

/// Reads and writes the system-wide `SleepDisabled` power setting
/// (the one `sudo pmset -a disablesleep 0|1` controls).
enum PowerSleep {

    enum Failure: LocalizedError {
        case cancelled
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Authorization was cancelled."
            case .failed(let message): return message
            }
        }
    }

    /// `true` when the Mac is set to stay awake with the lid closed.
    /// `nil` if the setting could not be read.
    static func isSleepDisabled() -> Bool? {
        guard let output = run("/usr/bin/pmset", ["-g"]).output else { return nil }
        for line in output.split(separator: "\n") {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("SleepDisabled") else { continue }
            return line.hasSuffix("1")
        }
        return nil
    }

    /// Applies the setting, asking for an administrator password only when needed.
    ///
    /// Tries passwordless sudo first (see scripts/install-sudoers.sh); falls back
    /// to the standard macOS authorization prompt.
    static func setSleepDisabled(_ disabled: Bool) throws {
        let value = disabled ? "1" : "0"

        let sudo = run("/usr/bin/sudo", ["-n", "/usr/bin/pmset", "-a", "disablesleep", value])
        if sudo.status == 0 { return }

        let script = "do shell script \"/usr/bin/pmset -a disablesleep \(value)\" with administrator privileges"
        let osascript = run("/usr/bin/osascript", ["-e", script])
        if osascript.status == 0 { return }

        let message = (osascript.output ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if message.contains("-128") || message.localizedCaseInsensitiveContains("cancel") {
            throw Failure.cancelled
        }
        throw Failure.failed(message.isEmpty ? "pmset exited with status \(osascript.status)." : message)
    }

    private static func run(_ path: String, _ arguments: [String]) -> (status: Int32, output: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return (-1, error.localizedDescription)
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(data: data, encoding: .utf8))
    }
}
