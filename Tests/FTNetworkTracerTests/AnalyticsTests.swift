// swiftlint:disable force_unwrapping force_cast force_try non_optional_string_data_conversion
import Foundation
@testable import FTNetworkTracer
import XCTest

class AnalyticsTests: XCTestCase {
    func testSensitivePrivacy() {
        let config = AnalyticsConfiguration(
            privacy: .sensitive,
            unmaskedHeaders: ["public_header"],
            unmaskedUrlQueries: ["public_query"],
            unmaskedBodyParams: ["public_param"]
        )

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: "https://example.com/path?secret_query=1&public_query=2"),
            headers: ["secret_header": "foo", "public_header": "bar"],
            body: "{\"secret_param\": \"foo\", \"public_param\": \"bar\"}".data(using: .utf8),
            configuration: config
        )

        XCTAssertEqual(entry.url, "https://example.com/path")
        XCTAssertEqual(entry.headers?["secret_header"], "***")
        XCTAssertEqual(entry.headers?["public_header"], "***") // Ignored
        XCTAssertNil(entry.body)
    }

    func testPrivatePrivacy() {
        let config = AnalyticsConfiguration(
            privacy: .private,
            unmaskedHeaders: ["public_header"],
            unmaskedUrlQueries: ["public_query"],
            unmaskedBodyParams: ["public_param"]
        )

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: "https://example.com/path?secret_query=1&public_query=2"),
            headers: ["secret_header": "foo", "public_header": "bar"],
            body: "{\"secret_param\": \"foo\", \"public_param\": \"bar\"}".data(using: .utf8),
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("secret_query=***"))
        XCTAssertTrue(entry.url.contains("public_query=2"))
        XCTAssertEqual(entry.headers?["secret_header"], "***")
        XCTAssertEqual(entry.headers?["public_header"], "bar")

        let bodyString = entry.body.flatMap { String(data: $0, encoding: .utf8) }
        XCTAssertTrue(bodyString?.contains("\"secret_param\":\"***\"") ?? false)
        XCTAssertTrue(bodyString?.contains("\"public_param\":\"bar\"") ?? false)
    }

    func testNonePrivacy() {
        let config = AnalyticsConfiguration(
            privacy: .none
        )

        let url = "https://example.com/path?secret_query=1&public_query=2"
        let headers = ["secret_header": "foo", "public_header": "bar"]
        let body = "{\"secret_param\": \"foo\", \"public_param\": \"bar\"}".data(using: .utf8)

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: url),
            headers: headers,
            body: body,
            configuration: config
        )

        XCTAssertEqual(entry.url, url)
        XCTAssertEqual(entry.headers, headers)
        XCTAssertEqual(entry.body, body)
    }

    func testRecursiveBodyMasking() {
        let config = AnalyticsConfiguration(
            privacy: .private,
            unmaskedBodyParams: ["public_param", "public_nested_object"]
        )

        let json = """
        {
            \"secret_param\": \"foo\",
            \"public_param\": \"bar\",
            \"nested_object\": {
                \"secret_nested_param\": \"baz\",
                \"public_nested_object\": {
                    \"another_secret\": \"qux\"
                }
            },
            \"array_of_objects\": [
                { \"secret_in_array\": \"foo\" },
                { \"public_param\": \"visible\" }
            ]
        }
        """.data(using: .utf8)

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: "https://example.com"),
            body: json,
            configuration: config
        )

        let body = entry.body!
        let maskedJSON = try! JSONSerialization.jsonObject(with: body, options: []) as! [String: Any]

        XCTAssertEqual(maskedJSON["secret_param"] as? String, "***")
        XCTAssertEqual(maskedJSON["public_param"] as? String, "bar")

        let nestedObject = maskedJSON["nested_object"] as! [String: Any]
        XCTAssertEqual(nestedObject["secret_nested_param"] as? String, "***")
        XCTAssertNotNil(nestedObject["public_nested_object"])

        let publicNestedObject = nestedObject["public_nested_object"] as! [String: Any]
        XCTAssertEqual(publicNestedObject["another_secret"] as? String, "qux")

        let array = maskedJSON["array_of_objects"] as! [Any]
        let firstObjectInArray = array[0] as! [String: Any]
        XCTAssertEqual(firstObjectInArray["secret_in_array"] as? String, "***")
        let secondObjectInArray = array[1] as! [String: Any]
        XCTAssertEqual(secondObjectInArray["public_param"] as? String, "visible")
    }

    // MARK: - Query Masking Tests

    func testQueryLiteralMaskingEnabledByDefault() {
        let config = AnalyticsConfiguration(privacy: .private)
        let query = """
        query GetUser {
            user(id: "12345", age: 25, role: "admin") {
                name
                email
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "GetUser",
            query: query,
            configuration: config
        )

        // Literals should be masked by default
        XCTAssertNotNil(entry.query)
        XCTAssertFalse(entry.query?.contains("12345") ?? true)
        XCTAssertFalse(entry.query?.contains("\"admin\"") ?? true)
        XCTAssertTrue(entry.query?.contains("id: \"***\"") ?? false)
        XCTAssertTrue(entry.query?.contains("age: ***") ?? false)
        XCTAssertTrue(entry.query?.contains("user") ?? false) // Structure preserved
        XCTAssertTrue(entry.query?.contains("name") ?? false)
        XCTAssertTrue(entry.query?.contains("email") ?? false)
    }

    func testQueryIncludedWithoutMasking() {
        let config = AnalyticsConfiguration(privacy: .private, maskQueryLiterals: false)
        let query = """
        query GetUser($id: ID!) {
            user(id: $id, role: "admin") {
                name
                email
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "GetUser",
            query: query,
            configuration: config
        )

        // Query should be included as-is
        XCTAssertEqual(entry.query, query)
        XCTAssertTrue(entry.query?.contains("$id") ?? false)
        XCTAssertTrue(entry.query?.contains("\"admin\"") ?? false)
    }

    func testQueryPreservesVariableReferences() {
        let config = AnalyticsConfiguration(privacy: .private, maskQueryLiterals: true)
        let query = """
        query GetUser($userId: ID!, $includeEmail: Boolean!) {
            user(id: $userId) {
                name
                email @include(if: $includeEmail)
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "GetUser",
            variables: ["userId": "123", "includeEmail": true],
            query: query,
            configuration: config
        )

        // Variable references should be preserved
        XCTAssertTrue(entry.query?.contains("$userId") ?? false)
        XCTAssertTrue(entry.query?.contains("$includeEmail") ?? false)
    }

    func testQueryNilWithSensitivePrivacy() {
        let config = AnalyticsConfiguration(privacy: .sensitive)
        let query = "query GetUser { user { name } }"

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "GetUser",
            query: query,
            configuration: config
        )

        // Query should be nil with sensitive privacy
        XCTAssertNil(entry.query)
    }

    func testQueryNilWhenNotProvided() {
        let config = AnalyticsConfiguration(privacy: .private)

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: "https://api.example.com/users"),
            configuration: config
        )

        // Query should be nil for non-GraphQL requests
        XCTAssertNil(entry.query)
    }

    func testComplexQueryMasking() {
        let config = AnalyticsConfiguration(privacy: .private, maskQueryLiterals: true)
        let query = """
        query GetUserData($userId: ID!, $limit: Int!) {
            user(id: $userId) {
                name
                posts(limit: $limit, status: "published", minLikes: 10) {
                    title
                    content
                    tags(filter: "technology")
                }
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "GetUserData",
            query: query,
            configuration: config
        )

        let maskedQuery = entry.query!

        // Variable references preserved
        XCTAssertTrue(maskedQuery.contains("$userId"))
        XCTAssertTrue(maskedQuery.contains("$limit"))

        // String literals masked
        XCTAssertFalse(maskedQuery.contains("\"published\""))
        XCTAssertFalse(maskedQuery.contains("\"technology\""))
        XCTAssertTrue(maskedQuery.contains("status: \"***\""))
        XCTAssertTrue(maskedQuery.contains("filter: \"***\""))

        // Number literals masked
        XCTAssertFalse(maskedQuery.contains("10"))
        XCTAssertTrue(maskedQuery.contains("minLikes: ***"))

        // Structure preserved
        XCTAssertTrue(maskedQuery.contains("GetUserData"))
        XCTAssertTrue(maskedQuery.contains("user"))
        XCTAssertTrue(maskedQuery.contains("posts"))
        XCTAssertTrue(maskedQuery.contains("tags"))
    }

    func testQueryMasksStringLiteralsContainingSpecialCharacters() {
        let config = AnalyticsConfiguration(privacy: .private, maskQueryLiterals: true)
        let query = """
        query Test {
            user(id: "$123&45", email: "user@example.com", filter: "status:active") {
                name
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "Test",
            query: query,
            configuration: config
        )

        let maskedQuery = entry.query!

        // String literals should be masked even if they contain special characters
        XCTAssertFalse(maskedQuery.contains("\"$123&45\""))
        XCTAssertFalse(maskedQuery.contains("\"user@example.com\""))
        XCTAssertFalse(maskedQuery.contains("\"status:active\""))

        // All string values should be masked
        XCTAssertTrue(maskedQuery.contains("id: \"***\""))
        XCTAssertTrue(maskedQuery.contains("email: \"***\""))
        XCTAssertTrue(maskedQuery.contains("filter: \"***\""))

        // Structure preserved
        XCTAssertTrue(maskedQuery.contains("query Test"))
        XCTAssertTrue(maskedQuery.contains("user"))
        XCTAssertTrue(maskedQuery.contains("name"))
    }
}
