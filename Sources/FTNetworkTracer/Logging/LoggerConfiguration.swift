import Foundation
#if canImport(os.log)
import os.log
#endif

#if canImport(os.log)
/// Minimum log level threshold for filtering logs.
///
/// Only logs at or above this level will be logged. This follows `OSLogType` priority:
/// - `.debug` (lowest priority) - shows all logs
/// - `.info` - shows info, error, and fault
/// - `.error` - shows error and fault only
/// - `.fault` (highest priority) - shows only fault logs
public enum LogLevel: Sendable {
    /// Show all logs (debug and above)
    case debug

    /// Show info, error, and fault logs
    case info

    /// Show error and fault logs only
    case error

    /// Show only fault logs
    case fault

    /// The corresponding OSLogType
    var osLogType: OSLogType {
        switch self {
        case .debug:
            return .debug
        case .info:
            return .info
        case .error:
            return .error
        case .fault:
            return .fault
        }
    }

    /// Check if a given log level should be logged based on this threshold
    func shouldLog(_ level: OSLogType) -> Bool {
        // OSLogType priority order: debug < info < error < fault
        // We need to check if the given level meets or exceeds our threshold
        let priorityOrder: [OSLogType] = [.debug, .info, .error, .fault]

        guard let thresholdIndex = priorityOrder.firstIndex(of: osLogType),
              let levelIndex = priorityOrder.firstIndex(of: level) else {
            return false
        }

        // Log if the message level is at or above the threshold
        return levelIndex >= thresholdIndex
    }
}
#endif

/// Configuration for the network logger.
///
/// This struct defines the configuration for the network logger, including the
/// subsystem and category for `OSLog`, the privacy level for logging, the minimum
/// log level threshold, and a custom data decoder for formatting body data.
public struct LoggerConfiguration: Sendable {
    let subsystem: String
    let category: String
    let privacy: LogPrivacy
    let dataDecoder: @Sendable (Data) -> String?

    #if canImport(os.log)
    let logger: os.Logger
    let logLevel: LogLevel
    #endif

    #if canImport(os.log)
    /// Initializes a new logger configuration.
    ///
    /// - Parameters:
    ///   - subsystem: The subsystem for `OSLog`.
    ///   - category: The category for `OSLog`.
    ///   - privacy: The privacy level for logging.
    ///   - logLevel: The minimum log level threshold. Only logs at or above this level will be logged. Defaults to `.debug` (logs everything).
    ///   - dataDecoder: A closure that decodes `Data` into a `String` for logging.
    public init(
        subsystem: String,
        category: String,
        privacy: LogPrivacy = .default,
        logLevel: LogLevel = .debug,
        dataDecoder: @escaping @Sendable (Data) -> String? = LoggerConfiguration.defaultDataDecoder
    ) {
        self.subsystem = subsystem
        self.category = category
        self.privacy = privacy
        self.dataDecoder = dataDecoder
        self.logger = os.Logger(subsystem: subsystem, category: category)
        self.logLevel = logLevel
    }
    #else
    /// Initializes a new logger configuration.
    ///
    /// - Parameters:
    ///   - subsystem: The subsystem for `OSLog`.
    ///   - category: The category for `OSLog`.
    ///   - privacy: The privacy level for logging.
    ///   - dataDecoder: A closure that decodes `Data` into a `String` for logging.
    ///
    /// - Note: On platforms without `os.log`, this initializer does not include log level configuration.
    public init(
        subsystem: String,
        category: String,
        privacy: LogPrivacy = .default,
        dataDecoder: @escaping @Sendable (Data) -> String? = LoggerConfiguration.defaultDataDecoder
    ) {
        self.subsystem = subsystem
        self.category = category
        self.privacy = privacy
        self.dataDecoder = dataDecoder
    }
    #endif

    /// Default data decoder that tries to format as pretty JSON with UTF8 fallback
    public static func defaultDataDecoder(_ data: Data) -> String? {
        // Try to decode as JSON and pretty print it
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted]),
           let prettyJSON = String(data: prettyData, encoding: .utf8) {
            return prettyJSON
        }

        // Fallback to UTF8 string
        return String(data: data, encoding: .utf8)
    }

    /// Simple UTF8 decoder (no JSON formatting)
    public static func utf8DataDecoder(_ data: Data) -> String? {
        String(data: data, encoding: .utf8)
    }

    /// Custom decoder that only shows data size
    public static func sizeOnlyDataDecoder(_ data: Data) -> String? {
        "<\(data.count) bytes>"
    }
}
