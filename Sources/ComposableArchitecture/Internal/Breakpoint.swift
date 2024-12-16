import Darwin

/// Raises a debug breakpoint if a debugger is attached.
@inline(__always) func breakpoint(_ message: @autoclosure () -> String = "") {
}
