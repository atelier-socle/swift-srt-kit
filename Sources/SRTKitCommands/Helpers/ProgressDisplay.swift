// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Prints progress and status messages to stderr.
///
/// All output goes to stderr so it doesn't interfere with data output
/// (e.g., when piping received data to stdout).
public struct ProgressDisplay: Sendable {

    /// Print a connecting message.
    ///
    /// - Parameters:
    ///   - host: Remote host.
    ///   - port: Remote port.
    public static func connecting(host: String, port: Int) {
        printErr("Connecting to \(host):\(port)...")
    }

    /// Print a listening message.
    ///
    /// - Parameters:
    ///   - host: Bind host.
    ///   - port: Bind port.
    public static func listening(host: String, port: Int) {
        printErr("Listening on \(host):\(port)...")
    }

    /// Print a connected message.
    ///
    /// - Parameter peerAddress: The peer's address string.
    public static func connected(peerAddress: String) {
        printErr("Connected to \(peerAddress)")
    }

    /// Print an in-place transfer progress update.
    ///
    /// - Parameters:
    ///   - bytes: Total bytes transferred so far.
    ///   - packets: Total packets transferred so far.
    ///   - elapsed: Elapsed time in seconds.
    public static func transferProgress(
        bytes: UInt64,
        packets: UInt64,
        elapsed: Double
    ) {
        let byteStr = formatBytes(bytes)
        let rate = elapsed > 0 ? Double(bytes) * 8.0 / elapsed : 0
        let rateStr = formatBitrate(UInt64(rate))
        printErr(
            "\r\(byteStr) sent, \(packets) packets, \(rateStr)\u{1B}[K",
            newline: false
        )
    }

    /// Print a final summary.
    ///
    /// - Parameters:
    ///   - totalBytes: Total bytes transferred.
    ///   - totalPackets: Total packets transferred.
    ///   - duration: Total duration in seconds.
    public static func summary(
        totalBytes: UInt64,
        totalPackets: UInt64,
        duration: Double
    ) {
        let byteStr = formatBytes(totalBytes)
        let rate = duration > 0 ? Double(totalBytes) * 8.0 / duration : 0
        let rateStr = formatBitrate(UInt64(rate))
        let durStr = String(format: "%.1fs", duration)
        printErr("")  // newline after progress
        printErr(
            "Done: \(byteStr), \(totalPackets) packets in \(durStr) (\(rateStr))"
        )
    }

    /// Print an error message.
    ///
    /// - Parameter message: The error message.
    public static func error(_ message: String) {
        printErr("Error: \(message)")
    }

    // MARK: - Private

    /// Print to stderr.
    private static func printErr(_ message: String, newline: Bool = true) {
        var data = Data(message.utf8)
        if newline {
            data.append(contentsOf: [0x0A])  // \n
        }
        FileHandle.standardError.write(data)
    }

    /// Format byte count for display.
    static func formatBytes(_ bytes: UInt64) -> String {
        StatisticsFormatter.formatBytes(bytes)
    }

    /// Format bitrate for display.
    static func formatBitrate(_ bps: UInt64) -> String {
        StatisticsFormatter.formatBitrate(bps)
    }
}
