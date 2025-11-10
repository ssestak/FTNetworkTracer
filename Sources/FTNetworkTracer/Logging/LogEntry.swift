import Foundation
#if canImport(os.log)
import os.log
#endif

/// Represents a log entry for logging network activity.
///
/// This struct contains all the data needed to log network requests, responses, and errors.
/// It uses ``EntryType`` with associated values to provide type-safe access to basic
/// network information without optionals.
///
/// - Note: For analytics tracking, use ``AnalyticEntry`` instead.
struct LogEntry: NetworkEntry {
    let type: EntryType
    let headers: [String: String]?
    let body: Data?
    let timestamp: Date
    let duration: TimeInterval?
    let requestId: String

    /// Additional context for GraphQL operations
    let operationName: String?
    let query: String?
    let variables: [String: any Sendable]?

    #if canImport(os.log)
    /// Determines the appropriate log level for this entry based on its type
    var level: OSLogType {
        switch type {
        case .error:
            return .error
        case let .response(_, _, statusCode):
            guard let statusCode else {
                return .info
            }
            return statusCode >= 400 ? .error : .info
        case .request:
            return .info
        }
    }
    #endif

    init(
        type: EntryType,
        headers: [String: String]? = nil,
        body: Data? = nil,
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        requestId: String = UUID().uuidString,
        operationName: String? = nil,
        query: String? = nil,
        variables: [String: any Sendable]? = nil
    ) {
        self.type = type
        self.headers = headers
        self.body = body
        self.timestamp = timestamp
        self.duration = duration
        self.requestId = requestId
        self.operationName = operationName
        self.query = query
        self.variables = variables
    }

    // MARK: - Message Building

    /// Builds a formatted log message from this LogEntry
    func buildMessage(configuration: LoggerConfiguration) -> String {
        let requestIdPrefix = String(requestId.prefix(8))
        let timestampString = formatTimestamp(timestamp)

        switch type {
        case let .request(method, url):
            var message = "[REQUEST] [\(requestIdPrefix)]"
            let titles = ["Method", "URL", "Timestamp"]
            let maxTitleLength = calculateMaxTitleLength(for: titles)

            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            // Mutual
            message += formatHeaders(maxTitleLength: maxTitleLength)

            // GraphQL-specific
            message += formatGraphQLInfo(maxTitleLength: maxTitleLength)

            // REST-specific
            message += RESTFormatter.formatBody(body, decoder: configuration.dataDecoder, type: type)

            return message

        case let .response(method, url, statusCode):
            var message = "[RESPONSE] [\(requestIdPrefix)]"
            var titles = ["Method", "URL", "Timestamp"]
            if statusCode != nil { titles.append("Status Code") }
            if duration != nil { titles.append("Duration") }

            let maxTitleLength = calculateMaxTitleLength(for: titles)
            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)

            if let statusCode {
                message += format(title: "Status Code", text: "\(statusCode)", maxTitleLength: maxTitleLength)
            }

            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            if let duration {
                message += format(title: "Duration", text: "\(String(format: "%.2f", duration * 1_000))ms", maxTitleLength: maxTitleLength)
            }

            message += formatHeaders(maxTitleLength: maxTitleLength)
            message += RESTFormatter.formatBody(body, decoder: configuration.dataDecoder, type: type)

            return message

        case let .error(method, url, error):
            var message = "[ERROR] [\(requestIdPrefix)]"
            let titles = ["Method", "URL", "ERROR", "Timestamp"]
            let maxTitleLength = calculateMaxTitleLength(for: titles)

            message += format(title: "Method", text: method, maxTitleLength: maxTitleLength)
            message += format(title: "URL", text: url, maxTitleLength: maxTitleLength)
            message += format(title: "ERROR", text: error, maxTitleLength: maxTitleLength)
            message += format(title: "Timestamp", text: timestampString, maxTitleLength: maxTitleLength)

            message += RESTFormatter.formatBody(body, decoder: configuration.dataDecoder, type: type)

            return message
        }
    }

    // MARK: - Formatting Helpers

    private func calculateMaxTitleLength(for titles: [String]) -> Int {
        var allTitles = titles
        if let headers, !headers.isEmpty {
            allTitles.append(contentsOf: headers.keys)
        }
        if operationName != nil {
            allTitles.append("Operation")
        }
        return allTitles.map { $0.count }.max() ?? 0
    }

    private func format(title: String, text: String, maxTitleLength: Int) -> String {
        let padding = String(repeating: " ", count: max(1, maxTitleLength - title.count))
        return "\n\t\(title)\(padding)\(text)"
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
    }

    private func formatHeaders(maxTitleLength: Int) -> String {
        guard let headers, !headers.isEmpty else {
            return ""
        }

        var message = "\nHeaders:"
        // Sort headers by key to ensure consistent ordering
        let sortedHeaders = headers.sorted { $0.key < $1.key }
        for (key, value) in sortedHeaders {
            message += format(title: key, text: value, maxTitleLength: maxTitleLength)
        }
        return message
    }

    // MARK: - GraphQL Formatting

    private func formatGraphQLInfo(maxTitleLength: Int) -> String {
        var message = ""
        if let operationName {
            message += format(title: "Operation", text: operationName, maxTitleLength: maxTitleLength)
        }

        if let query {
            message += "\nQuery:"
            message += GraphQLFormatter.formatQuery(query)
        }

        if let variables, !variables.isEmpty {
            message += "\nVariables:"
            message += GraphQLFormatter.formatVariables(variables)
        }
        return message
    }
}
