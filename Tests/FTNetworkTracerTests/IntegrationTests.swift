// swiftlint:disable force_unwrapping non_optional_string_data_conversion type_body_length
@testable import FTNetworkTracer
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

class IntegrationTests: XCTestCase {
    // MARK: - Mock Analytics

    private class MockAnalytics: AnalyticsProtocol {
        var configuration: AnalyticsConfiguration
        var trackedEntries: [AnalyticEntry] = []

        init(configuration: AnalyticsConfiguration = .default) {
            self.configuration = configuration
        }

        func track(_ entry: AnalyticEntry) {
            trackedEntries.append(entry)
        }
    }

    // MARK: - REST Integration Tests

    func testRESTRequestTracking() {
        let analytics = MockAnalytics(configuration: AnalyticsConfiguration(privacy: .none))
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/users")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{\"name\": \"John\"}".data(using: .utf8)
        request.allHTTPHeaderFields = ["Content-Type": "application/json"]

        tracer.logAndTrackRequest(request: request, requestId: "test-123")

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        XCTAssertEqual(entry.method, "POST")
        XCTAssertEqual(entry.url, "https://api.example.com/users")
        XCTAssertNotNil(entry.headers)
        XCTAssertNotNil(entry.body)
    }

    func testRESTResponseTracking() {
        let analytics = MockAnalytics(configuration: AnalyticsConfiguration(privacy: .none))
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/users")!
        let request = URLRequest(url: url)
        let response = HTTPURLResponse(
            url: url,
            statusCode: 201,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        let responseData = "{\"id\": 123}".data(using: .utf8)
        let startTime = Date().addingTimeInterval(-1.0)

        tracer.logAndTrackResponse(
            request: request,
            response: response,
            data: responseData,
            requestId: "test-123",
            startTime: startTime
        )

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        XCTAssertEqual(entry.statusCode, 201)
        XCTAssertNotNil(entry.duration)
        XCTAssertTrue(entry.duration! > 0)
    }

    func testRESTErrorTracking() {
        let analytics = MockAnalytics(configuration: AnalyticsConfiguration(privacy: .none))
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/users")!
        let request = URLRequest(url: url)
        let error = NSError(domain: "TestError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Network timeout"])

        tracer.logAndTrackError(request: request, error: error, requestId: "test-123")

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        XCTAssertNotNil(entry.error)
        XCTAssertTrue(entry.error!.contains("Network timeout"))
    }

    // MARK: - GraphQL Integration Tests

    func testGraphQLRequestTracking() {
        let analytics = MockAnalytics(configuration: AnalyticsConfiguration(privacy: .none))
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let query = """
        query GetUser($id: ID!) {
            user(id: $id) {
                name
                email
            }
        }
        """
        let variables: [String: any Sendable] = ["id": "123"]

        tracer.logAndTrackRequest(
            url: "https://api.example.com/graphql",
            operationName: "GetUser",
            query: query,
            variables: variables,
            headers: ["Authorization": "Bearer token"],
            requestId: "graphql-123"
        )

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        XCTAssertEqual(entry.method, "POST")
        XCTAssertEqual(entry.operationName, "GetUser")
        XCTAssertNotNil(entry.variables)
    }

    func testGraphQLResponseTracking() {
        let analytics = MockAnalytics(configuration: AnalyticsConfiguration(privacy: .none))
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let startTime = Date().addingTimeInterval(-0.5)

        tracer.logAndTrackResponse(
            url: "https://api.example.com/graphql",
            operationName: "GetUser",
            statusCode: 200,
            requestId: "graphql-123",
            startTime: startTime
        )

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        XCTAssertEqual(entry.operationName, "GetUser")
        XCTAssertNotNil(entry.duration)
    }

    func testGraphQLErrorTracking() {
        let analytics = MockAnalytics(configuration: AnalyticsConfiguration(privacy: .none))
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let error = NSError(domain: "GraphQLError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Query failed"])

        tracer.logAndTrackError(
            url: "https://api.example.com/graphql",
            operationName: "GetUser",
            error: error,
            requestId: "graphql-123"
        )

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        XCTAssertNotNil(entry.error)
        XCTAssertTrue(entry.error!.contains("Query failed"))
    }

    // MARK: - Privacy Integration Tests

    func testPrivacyMaskingInAnalytics() {
        let config = AnalyticsConfiguration(
            privacy: .private,
            unmaskedHeaders: ["content-type"],
            unmaskedUrlQueries: ["public_param"],
            unmaskedBodyParams: ["username"]
        )
        let analytics = MockAnalytics(configuration: config)
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/users?secret=abc&public_param=xyz")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{\"username\": \"john\", \"password\": \"secret123\"}".data(using: .utf8)
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Authorization": "Bearer token123"
        ]

        tracer.logAndTrackRequest(request: request, requestId: "privacy-test")

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]

        // URL should have secret param masked
        XCTAssertTrue(entry.url.contains("secret=***"))
        XCTAssertTrue(entry.url.contains("public_param=xyz"))

        // Headers: content-type unmasked, Authorization masked
        XCTAssertEqual(entry.headers?["Content-Type"], "application/json")
        XCTAssertEqual(entry.headers?["Authorization"], "***")

        // Body: username unmasked, password masked
        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(bodyJSON["username"], "john")
            XCTAssertEqual(bodyJSON["password"], "***")
        } else {
            XCTFail("Body should be parseable JSON")
        }
    }

    func testSensitivePrivacyMasksEverything() {
        let config = AnalyticsConfiguration(
            privacy: .sensitive,
            unmaskedHeaders: ["content-type"], // Should be ignored in sensitive mode
            unmaskedUrlQueries: ["public_param"],
            unmaskedBodyParams: ["username"]
        )
        let analytics = MockAnalytics(configuration: config)
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/users?secret=abc&public_param=xyz")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = "{\"username\": \"john\"}".data(using: .utf8)
        request.allHTTPHeaderFields = ["Content-Type": "application/json"]

        tracer.logAndTrackRequest(request: request, requestId: "sensitive-test")

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]

        // URL should have all query params removed
        XCTAssertFalse(entry.url.contains("?"))
        XCTAssertFalse(entry.url.contains("secret"))
        XCTAssertFalse(entry.url.contains("public_param"))

        // All headers should be masked
        XCTAssertEqual(entry.headers?["Content-Type"], "***")

        // Body should be nil
        XCTAssertNil(entry.body)
    }

    // MARK: - Dual Mode Tests

    func testTracerWithBothLoggingAndAnalytics() {
        let config = LoggerConfiguration(
            subsystem: "com.test",
            category: "integration"
        )
        let analytics = MockAnalytics()
        let tracer = FTNetworkTracer(logger: config, analytics: analytics)

        let url = URL(string: "https://api.example.com/test")!
        let request = URLRequest(url: url)

        // Should not crash with both logger and analytics
        tracer.logAndTrackRequest(request: request, requestId: "dual-mode-test")

        // Analytics should receive the entry
        XCTAssertEqual(analytics.trackedEntries.count, 1)
    }

    func testTracerWithOnlyLogging() {
        let config = LoggerConfiguration(
            subsystem: "com.test",
            category: "integration"
        )
        let tracer = FTNetworkTracer(logger: config, analytics: nil)

        let url = URL(string: "https://api.example.com/test")!
        let request = URLRequest(url: url)

        // Should not crash with only logger
        tracer.logAndTrackRequest(request: request, requestId: "logging-only-test")
    }

    func testTracerWithOnlyAnalytics() {
        let analytics = MockAnalytics()
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/test")!
        let request = URLRequest(url: url)

        // Should not crash with only analytics
        tracer.logAndTrackRequest(request: request, requestId: "analytics-only-test")

        XCTAssertEqual(analytics.trackedEntries.count, 1)
    }

    func testTracerWithNeitherLoggingNorAnalytics() {
        let tracer = FTNetworkTracer(logger: nil, analytics: nil)

        let url = URL(string: "https://api.example.com/test")!
        let request = URLRequest(url: url)

        // Should not crash with neither logger nor analytics
        tracer.logAndTrackRequest(request: request, requestId: "no-output-test")
    }

    // MARK: - Error Cases

    func testHandlesInvalidURLResponse() {
        let analytics = MockAnalytics()
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/test")!
        let request = URLRequest(url: url)
        // Create URLResponse using the cross-platform compatible initializer
        let invalidResponse = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil
        )

        tracer.logAndTrackResponse(
            request: request,
            response: invalidResponse,
            data: nil,
            requestId: "invalid-response-test",
            startTime: Date()
        )

        // Should not track analytics for non-HTTP response
        XCTAssertEqual(analytics.trackedEntries.count, 0)
    }

    func testHandlesMissingHTTPMethod() {
        let analytics = MockAnalytics()
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        let url = URL(string: "https://api.example.com/test")!
        var request = URLRequest(url: url)
        request.httpMethod = nil // No method set explicitly

        tracer.logAndTrackRequest(request: request, requestId: "no-method-test")

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        // URLRequest defaults to GET when no method is set
        XCTAssertTrue(entry.method == "GET" || entry.method == "UNKNOWN")
    }

    func testHandlesMissingURL() {
        let analytics = MockAnalytics()
        let tracer = FTNetworkTracer(logger: nil, analytics: analytics)

        var request = URLRequest(url: URL(string: "https://temp.com")!)
        request.url = nil

        tracer.logAndTrackRequest(request: request, requestId: "no-url-test")

        XCTAssertEqual(analytics.trackedEntries.count, 1)
        let entry = analytics.trackedEntries[0]
        XCTAssertEqual(entry.url, "UNKNOWN")
    }
}
