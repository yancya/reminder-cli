import Foundation

/// Captures everything written to stdout during `block`.
///
/// Not safe under `swift test --parallel`: `dup2` swaps out the
/// process-wide `STDOUT_FILENO`, so concurrent test methods would race on
/// the same file descriptor. This project runs tests serially (the default),
/// so that's acceptable here.
///
/// The write pipe is drained on a background queue while `block` runs, so
/// output larger than the pipe's kernel buffer (~64KB on macOS) can't
/// deadlock the writer.
func captureStdout(_ block: () throws -> Void) rethrows -> String {
    let pipe = Pipe()
    let originalStdout = dup(STDOUT_FILENO)
    fflush(stdout)
    dup2(pipe.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)

    var capturedData = Data()
    let readingDone = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        capturedData = pipe.fileHandleForReading.readDataToEndOfFile()
        readingDone.signal()
    }

    func restore() {
        fflush(stdout)
        dup2(originalStdout, STDOUT_FILENO)
        close(originalStdout)
        try? pipe.fileHandleForWriting.close()
        readingDone.wait()
        try? pipe.fileHandleForReading.close()
    }

    do {
        try block()
    } catch {
        restore()
        throw error
    }

    restore()
    return String(data: capturedData, encoding: .utf8) ?? ""
}
