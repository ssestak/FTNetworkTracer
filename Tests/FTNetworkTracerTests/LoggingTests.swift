// swiftlint:disable force_unwrapping non_optional_string_data_conversion
@testable import FTNetworkTracer
import XCTest

class LoggingTests: XCTestCase {
    func testLoggerConfigurationInitialization() {
        let configuration = LoggerConfiguration(
            subsystem: "com.test",
            category: "test"
        )
        XCTAssertNotNil(configuration)
        XCTAssertEqual(configuration.subsystem, "com.test")
        XCTAssertEqual(configuration.category, "test")
    }

    func testLoggerConfigurationDataDecoder() {
        let jsonData = """
        {"name": "test", "value": 123}
        """.data(using: .utf8)!

        let prettyJSON = LoggerConfiguration.defaultDataDecoder(jsonData)
        XCTAssertNotNil(prettyJSON)
        XCTAssertTrue(prettyJSON!.contains("\n")) // Should be pretty printed

        let utf8Data = "simple text".data(using: .utf8)!
        let utf8Result = LoggerConfiguration.utf8DataDecoder(utf8Data)
        XCTAssertEqual(utf8Result, "simple text")

        let sizeResult = LoggerConfiguration.sizeOnlyDataDecoder(utf8Data)
        XCTAssertEqual(sizeResult, "<11 bytes>")
    }

    func testLogEntryBuildMessage() {
        let configuration = LoggerConfiguration(
            subsystem: "com.test",
            category: "test"
        )

        // Test request message
        let requestEntry = LogEntry(
            type: .request(method: "POST", url: "https://api.example.com/users"),
            headers: ["Content-Type": "application/json"],
            body: "{\"username\": \"test\"}".data(using: .utf8)!,
            requestId: "abc12345"
        )

        let requestMessage = requestEntry.buildMessage(configuration: configuration)
        XCTAssertTrue(requestMessage.contains("[REQUEST]"))
        XCTAssertTrue(requestMessage.contains("POST"))
        XCTAssertTrue(requestMessage.contains("https://api.example.com/users"))
        XCTAssertTrue(requestMessage.contains("Headers:"))
        XCTAssertTrue(requestMessage.contains("Body:"))

        // Test response message
        let responseEntry = LogEntry(
            type: .response(method: "POST", url: "https://api.example.com/users", statusCode: 201),
            headers: ["Content-Type": "application/json"],
            body: "{\"id\": 123}".data(using: .utf8)!,
            duration: 0.5,
            requestId: "abc12345"
        )

        let responseMessage = responseEntry.buildMessage(configuration: configuration)
        XCTAssertTrue(responseMessage.contains("[RESPONSE]"))
        XCTAssertTrue(responseMessage.contains("201"))
        XCTAssertTrue(responseMessage.contains("500.00ms"))

        // Test error message
        let errorEntry = LogEntry(
            type: .error(method: "POST", url: "https://api.example.com/users", error: "Network error"),
            body: "{\"error\": \"Connection failed\"}".data(using: .utf8)!,
            requestId: "abc12345"
        )

        let errorMessage = errorEntry.buildMessage(configuration: configuration)
        XCTAssertTrue(errorMessage.contains("[ERROR]"))
        XCTAssertTrue(errorMessage.contains("ERROR"))
        XCTAssertTrue(errorMessage.contains("Network error"))
        XCTAssertTrue(errorMessage.contains("Data:"))
    }

    func testGraphQLLogEntry() {
        let configuration = LoggerConfiguration(
            subsystem: "com.test",
            category: "test"
        )

        let query = """
        query GetUser($id: ID!) {
            user(id: $id) {
                name
                email
            }
        }
        """

        let variables: [String: any Sendable] = ["id": "123"]

        let entry = LogEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            requestId: "test-id",
            operationName: "GetUser",
            query: query,
            variables: variables
        )

        let message = entry.buildMessage(configuration: configuration)
        XCTAssertTrue(message.contains("[REQUEST]"))
        XCTAssertTrue(message.contains("Operation"))
        XCTAssertTrue(message.contains("GetUser"))
        XCTAssertTrue(message.contains("Query:"))
        XCTAssertTrue(message.contains("Variables:"))
    }

    #if canImport(os.log)
    func testLogLevelFiltering() {
        // Test that log levels correctly determine what gets logged
        let debugConfig = LoggerConfiguration(
            subsystem: "com.test",
            category: "test",
            logLevel: .debug
        )

        let infoConfig = LoggerConfiguration(
            subsystem: "com.test",
            category: "test",
            logLevel: .info
        )

        let errorConfig = LoggerConfiguration(
            subsystem: "com.test",
            category: "test",
            logLevel: .error
        )

        let faultConfig = LoggerConfiguration(
            subsystem: "com.test",
            category: "test",
            logLevel: .fault
        )

        // Test shouldLog logic - debug level (logs everything)
        XCTAssertTrue(debugConfig.logLevel.shouldLog(.debug))
        XCTAssertTrue(debugConfig.logLevel.shouldLog(.info))
        XCTAssertTrue(debugConfig.logLevel.shouldLog(.error))
        XCTAssertTrue(debugConfig.logLevel.shouldLog(.fault))

        // Test info level (logs info, error, fault)
        XCTAssertFalse(infoConfig.logLevel.shouldLog(.debug))
        XCTAssertTrue(infoConfig.logLevel.shouldLog(.info))
        XCTAssertTrue(infoConfig.logLevel.shouldLog(.error))
        XCTAssertTrue(infoConfig.logLevel.shouldLog(.fault))

        // Test error level (logs only error and fault)
        XCTAssertFalse(errorConfig.logLevel.shouldLog(.debug))
        XCTAssertFalse(errorConfig.logLevel.shouldLog(.info))
        XCTAssertTrue(errorConfig.logLevel.shouldLog(.error))
        XCTAssertTrue(errorConfig.logLevel.shouldLog(.fault))

        // Test fault level (logs only fault)
        XCTAssertFalse(faultConfig.logLevel.shouldLog(.debug))
        XCTAssertFalse(faultConfig.logLevel.shouldLog(.info))
        XCTAssertFalse(faultConfig.logLevel.shouldLog(.error))
        XCTAssertTrue(faultConfig.logLevel.shouldLog(.fault))
    }

    func testLogEntryLevels() {
        // Test that log entries have correct levels
        let requestEntry = LogEntry(
            type: .request(method: "GET", url: "https://api.example.com/users"),
            requestId: "test-123"
        )
        XCTAssertEqual(requestEntry.level, .info)

        let successResponseEntry = LogEntry(
            type: .response(method: "GET", url: "https://api.example.com/users", statusCode: 200),
            requestId: "test-123"
        )
        XCTAssertEqual(successResponseEntry.level, .info)

        let errorResponseEntry = LogEntry(
            type: .response(method: "GET", url: "https://api.example.com/users", statusCode: 404),
            requestId: "test-123"
        )
        XCTAssertEqual(errorResponseEntry.level, .error)

        let errorEntry = LogEntry(
            type: .error(method: "GET", url: "https://api.example.com/users", error: "Network error"),
            requestId: "test-123"
        )
        XCTAssertEqual(errorEntry.level, .error)
    }
    #endif
}
