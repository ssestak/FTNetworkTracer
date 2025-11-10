import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(os.log)
import os.log
#endif

public class FTNetworkTracer {
    private let logger: LoggerConfiguration?
    private let analytics: AnalyticsProtocol?

    public init(logger: LoggerConfiguration?, analytics: AnalyticsProtocol?) {
        self.logger = logger
        self.analytics = analytics
    }

    // MARK: - Public API

    public func logAndTrackRequest(
        request: URLRequest,
        requestId: String
    ) {
        logAndTrack(
            entryType: .request(method: request.httpMethod ?? "UNKNOWN", url: request.url?.absoluteString ?? "UNKNOWN"),
            request: request,
            requestId: requestId
        )
    }

    public func logAndTrackResponse(
        request: URLRequest,
        response: URLResponse?,
        data: Data?,
        requestId: String,
        startTime: Date
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            return
        }

        logAndTrack(
            entryType: .response(
                method: request.httpMethod ?? "UNKNOWN",
                url: request.url?.absoluteString ?? "UNKNOWN",
                statusCode: httpResponse.statusCode
            ),
            request: request,
            requestId: requestId,
            response: httpResponse,
            data: data,
            startTime: startTime
        )
    }

    public func logAndTrackError(
        request: URLRequest,
        error: Error,
        requestId: String
    ) {
        logAndTrack(
            entryType: .error(
                method: request.httpMethod ?? "UNKNOWN",
                url: request.url?.absoluteString ?? "UNKNOWN",
                error: error.localizedDescription
            ),
            request: request,
            requestId: requestId
        )
    }

    // MARK: - GraphQL API

    public func logAndTrackRequest(
        url: String?,
        operationName: String,
        query: String,
        variables: [String: any Sendable]?,
        headers: [String: String]?,
        requestId: String = UUID().uuidString
    ) {
        performLogAndTrack(
            entryType: .request(method: "POST", url: url ?? "UNKNOWN"),
            headers: headers,
            body: nil,
            duration: nil,
            requestId: requestId,
            operationName: operationName,
            query: query,
            variables: variables
        )
    }

    public func logAndTrackResponse(
        url: String?,
        operationName: String,
        statusCode: Int?,
        requestId: String,
        startTime: Date
    ) {
        performLogAndTrack(
            entryType: .response(method: "POST", url: url ?? "UNKNOWN", statusCode: statusCode),
            headers: nil,
            body: nil,
            duration: Date().timeIntervalSince(startTime),
            requestId: requestId,
            operationName: operationName
        )
    }

    public func logAndTrackError(
        url: String?,
        operationName: String,
        error: Error,
        requestId: String
    ) {
        performLogAndTrack(
            entryType: .error(method: "POST", url: url ?? "UNKNOWN", error: String(describing: error)),
            headers: nil,
            body: nil,
            duration: nil,
            requestId: requestId,
            operationName: operationName
        )
    }

    // MARK: - Private Helpers

    private func logAndTrack(
        entryType: EntryType,
        request: URLRequest,
        requestId: String,
        response: HTTPURLResponse? = nil,
        data: Data? = nil,
        startTime: Date? = nil
    ) {
        let headers = response?.allHeaderFields as? [String: String] ?? request.allHTTPHeaderFields
        let body = data ?? request.httpBody
        let duration = startTime.map { Date().timeIntervalSince($0) }

        performLogAndTrack(
            entryType: entryType,
            headers: headers,
            body: body,
            duration: duration,
            requestId: requestId
        )
    }

    private func performLogAndTrack(
        entryType: EntryType,
        headers: [String: String]?,
        body: Data?,
        duration: TimeInterval?,
        requestId: String,
        operationName: String? = nil,
        query: String? = nil,
        variables: [String: any Sendable]? = nil
    ) {
        let timestamp = Date()
        // Log if logger is available
        if let logger {
            let logEntry = LogEntry(
                type: entryType,
                headers: headers,
                body: body,
                timestamp: timestamp,
                duration: duration,
                requestId: requestId,
                operationName: operationName,
                query: query,
                variables: variables
            )

            #if canImport(os.log)
            // Only log if this entry meets the minimum log level threshold
            if logger.logLevel.shouldLog(logEntry.level) {
                let message = logEntry.buildMessage(configuration: logger)
                switch logger.privacy {
                case .none:
                    logger.logger.log(level: logEntry.level, "\(message, privacy: OSLogPrivacy.public)")
                case .auto:
                    logger.logger.log(level: logEntry.level, "\(message, privacy: OSLogPrivacy.auto)")
                case .private:
                    logger.logger.log(level: logEntry.level, "\(message, privacy: OSLogPrivacy.private)")
                case .sensitive:
                    logger.logger.log(level: logEntry.level, "\(message, privacy: OSLogPrivacy.sensitive)")
                }
            }
            #endif
        }

        // Track analytics if available
        if let analytics {
            let analyticEntry = AnalyticEntry(
                type: entryType,
                headers: headers,
                body: body,
                timestamp: timestamp,
                duration: duration,
                requestId: requestId,
                operationName: operationName,
                variables: variables,
                configuration: analytics.configuration
            )
            analytics.track(analyticEntry)
        }
    }
}
