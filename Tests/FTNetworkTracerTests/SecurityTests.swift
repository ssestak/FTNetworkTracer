// swiftlint:disable force_unwrapping non_optional_string_data_conversion file_length type_body_length number_separator
@testable import FTNetworkTracer
import XCTest

/// Comprehensive security tests to ensure sensitive data is properly masked
class SecurityTests: XCTestCase {
    // MARK: - Default Configuration Security

    func testDefaultAnalyticsConfigurationIsSensitive() {
        let config = AnalyticsConfiguration.default

        // Default must be sensitive (most secure)
        XCTAssertEqual(config.privacy, .sensitive)
    }

    func testDefaultLogPrivacyIsAuto() {
        let defaultPrivacy = LogPrivacy.default

        // Default should be auto (safe balance)
        XCTAssertEqual(defaultPrivacy, .auto)
    }

    // MARK: - Common Sensitive Patterns

    func testCommonSensitiveHeadersAreMasked() {
        let config = AnalyticsConfiguration(privacy: .private)

        let sensitiveHeaders = [
            "Authorization": "Bearer secret_token_12345",
            "X-API-Key": "api_key_67890",
            "Cookie": "session=abcdef123456",
            "X-Auth-Token": "token_xyz",
            "X-CSRF-Token": "csrf_token_abc"
        ]

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: "https://api.example.com"),
            headers: sensitiveHeaders,
            configuration: config
        )

        // All sensitive headers should be masked
        for (key, _) in sensitiveHeaders {
            XCTAssertEqual(entry.headers?[key], "***", "Header \(key) should be masked")
        }
    }

    func testCommonSensitiveBodyFieldsAreMasked() {
        let config = AnalyticsConfiguration(privacy: .private)

        let sensitiveJSON = """
        {
            "password": "secret123",
            "token": "abc123xyz",
            "api_key": "key_12345",
            "secret": "my_secret",
            "creditCard": "4111111111111111",
            "ssn": "123-45-6789"
        }
        """.data(using: .utf8)!

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com"),
            body: sensitiveJSON,
            configuration: config
        )

        // All fields should be masked since none are in unmaskedBodyParams
        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(bodyJSON["password"], "***")
            XCTAssertEqual(bodyJSON["token"], "***")
            XCTAssertEqual(bodyJSON["api_key"], "***")
            XCTAssertEqual(bodyJSON["secret"], "***")
            XCTAssertEqual(bodyJSON["creditCard"], "***")
            XCTAssertEqual(bodyJSON["ssn"], "***")
        } else {
            XCTFail("Body should be parseable JSON")
        }
    }

    func testCommonSensitiveQueryParamsAreMasked() {
        let config = AnalyticsConfiguration(privacy: .private)

        let url = "https://api.example.com/data?api_key=secret123&token=xyz789&password=pass123&session_id=abc456"

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: url),
            configuration: config
        )

        // All query params should be masked
        XCTAssertTrue(entry.url.contains("api_key=***"))
        XCTAssertTrue(entry.url.contains("token=***"))
        XCTAssertTrue(entry.url.contains("password=***"))
        XCTAssertTrue(entry.url.contains("session_id=***"))

        // Original values should not appear
        XCTAssertFalse(entry.url.contains("secret123"))
        XCTAssertFalse(entry.url.contains("xyz789"))
        XCTAssertFalse(entry.url.contains("pass123"))
        XCTAssertFalse(entry.url.contains("abc456"))
    }

    // MARK: - Case Sensitivity

    func testUnmaskedParamsAreCaseInsensitive() {
        let config = AnalyticsConfiguration(
            privacy: .private,
            unmaskedHeaders: ["content-type"],
            unmaskedUrlQueries: ["publicparam"],
            unmaskedBodyParams: ["username"]
        )

        // Test headers with different casing
        let entry1 = AnalyticEntry(
            type: .request(method: "GET", url: "https://api.example.com"),
            headers: ["content-type": "application/json"],
            configuration: config
        )
        XCTAssertEqual(entry1.headers?["content-type"], "application/json")

        // Test URL query params with different casing
        let entry2 = AnalyticEntry(
            type: .request(method: "GET", url: "https://api.example.com?publicparam=value1&PublicParam=value2&PUBLICPARAM=value3"),
            configuration: config
        )
        XCTAssertTrue(entry2.url.contains("publicparam=value1"))
        XCTAssertTrue(entry2.url.contains("PublicParam=value2"))
        XCTAssertTrue(entry2.url.contains("PUBLICPARAM=value3"))

        // Test body params with different casing
        let json = """
        {"username": "john", "UserName": "jane", "USERNAME": "bob"}
        """.data(using: .utf8)!

        let entry3 = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com"),
            body: json,
            configuration: config
        )

        if let bodyData = entry3.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(bodyJSON["username"], "john")
            XCTAssertEqual(bodyJSON["UserName"], "jane")
            XCTAssertEqual(bodyJSON["USERNAME"], "bob")
        } else {
            XCTFail("Body should be parseable")
        }
    }

    // MARK: - Edge Cases and Attack Vectors

    func testMaskingVeryLongStrings() {
        let config = AnalyticsConfiguration(privacy: .private)

        let longValue = String(repeating: "A", count: 10000)
        let url = "https://api.example.com?secret=\(longValue)"

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: url),
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("secret=***"))
        XCTAssertFalse(entry.url.contains(longValue))
    }

    func testMaskingSpecialCharacters() {
        let config = AnalyticsConfiguration(privacy: .private)

        let specialChars = "<script>alert('XSS')</script>"
        let url = "https://api.example.com?param=\(specialChars.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: url),
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("param=***"))
        XCTAssertFalse(entry.url.contains("script"))
        XCTAssertFalse(entry.url.contains("XSS"))
    }

    func testMaskingUnicodeCharacters() {
        let config = AnalyticsConfiguration(privacy: .private)

        let unicodeValue = "🔑密碼🔐"
        let json = """
        {"secret": "\(unicodeValue)"}
        """.data(using: .utf8)!

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com"),
            body: json,
            configuration: config
        )

        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(bodyJSON["secret"], "***")
            XCTAssertFalse(bodyJSON["secret"]?.contains(unicodeValue) ?? false)
        } else {
            XCTFail("Body should be parseable")
        }
    }

    func testMaskingSQLInjectionAttempts() {
        let config = AnalyticsConfiguration(privacy: .private)

        let sqlInjection = "' OR '1'='1"
        let url = "https://api.example.com?id=\(sqlInjection.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: url),
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("id=***"))
        XCTAssertFalse(entry.url.contains(sqlInjection))
    }

    func testMaskingPathTraversalAttempts() {
        let config = AnalyticsConfiguration(privacy: .private)

        let pathTraversal = "../../../etc/passwd"
        let url = "https://api.example.com?file=\(pathTraversal.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: url),
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("file=***"))
        XCTAssertFalse(entry.url.contains("passwd"))
    }

    // MARK: - Masking Across All Entry Types

    func testRequestEntryMasking() {
        let config = AnalyticsConfiguration(privacy: .private)

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com?secret=abc123"),
            headers: ["Authorization": "Bearer token"],
            body: "{\"password\": \"secret\"}".data(using: .utf8),
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("secret=***"))
        XCTAssertEqual(entry.headers?["Authorization"], "***")

        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(bodyJSON["password"], "***")
        }
    }

    func testResponseEntryMasking() {
        let config = AnalyticsConfiguration(privacy: .private)

        let entry = AnalyticEntry(
            type: .response(method: "POST", url: "https://api.example.com?secret=abc123", statusCode: 200),
            headers: ["Set-Cookie": "session=xyz789"],
            body: "{\"token\": \"secret_token\"}".data(using: .utf8),
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("secret=***"))
        XCTAssertEqual(entry.headers?["Set-Cookie"], "***")

        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(bodyJSON["token"], "***")
        }
    }

    func testErrorEntryMasking() {
        let config = AnalyticsConfiguration(privacy: .private)

        let entry = AnalyticEntry(
            type: .error(method: "POST", url: "https://api.example.com?secret=abc123", error: "Authentication failed"),
            headers: ["Authorization": "Bearer token"],
            configuration: config
        )

        XCTAssertTrue(entry.url.contains("secret=***"))
        XCTAssertEqual(entry.headers?["Authorization"], "***")
    }

    // MARK: - GraphQL Variables Masking

    func testGraphQLVariablesMasking() {
        let config = AnalyticsConfiguration(
            privacy: .private,
            unmaskedBodyParams: ["userid"]
        )

        let variables: [String: any Sendable] = [
            "userId": "123",
            "password": "secret123",
            "token": "abc_xyz",
            "apiKey": "key_12345"
        ]

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "LoginUser",
            variables: variables,
            configuration: config
        )

        XCTAssertNotNil(entry.variables)
        let maskedVars = entry.variables!

        XCTAssertEqual(maskedVars["userId"] as? String, "123")
        XCTAssertEqual(maskedVars["password"] as? String, "***")
        XCTAssertEqual(maskedVars["token"] as? String, "***")
        XCTAssertEqual(maskedVars["apiKey"] as? String, "***")
    }

    func testGraphQLNestedVariablesMasking() {
        let config = AnalyticsConfiguration(
            privacy: .private,
            unmaskedBodyParams: ["email"]
        )

        let profile: [String: any Sendable] = [
            "name": "John",
            "apiKey": "key_xyz"
        ]

        let userInput: [String: any Sendable] = [
            "email": "user@example.com",
            "password": "secret123",
            "profile": profile
        ]

        let variables: [String: any Sendable] = [
            "input": userInput
        ]

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "CreateUser",
            variables: variables,
            configuration: config
        )

        XCTAssertNotNil(entry.variables)
        let maskedVars = entry.variables!
        let input = maskedVars["input"] as? [String: Any]

        XCTAssertEqual(input?["email"] as? String, "user@example.com")
        XCTAssertEqual(input?["password"] as? String, "***")

        let maskedProfile = input?["profile"] as? [String: Any]
        XCTAssertEqual(maskedProfile?["name"] as? String, "***")
        XCTAssertEqual(maskedProfile?["apiKey"] as? String, "***")
    }

    // MARK: - Masking Irreversibility

    func testMaskedDataCannotBeUnmasked() {
        let config = AnalyticsConfiguration(privacy: .private)

        let originalPassword = "MySecretPassword123!"
        let json = """
        {"password": "\(originalPassword)"}
        """.data(using: .utf8)!

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com"),
            body: json,
            configuration: config
        )

        // Verify masked body doesn't contain original
        if let bodyData = entry.body,
           let bodyString = String(data: bodyData, encoding: .utf8) {
            XCTAssertFalse(bodyString.contains(originalPassword))
            XCTAssertTrue(bodyString.contains("***"))
        }

        // Verify original password is not recoverable
        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            let maskedValue = bodyJSON["password"]
            XCTAssertNotEqual(maskedValue, originalPassword)
            XCTAssertEqual(maskedValue, "***")
        }
    }

    // MARK: - Sensitive Mode Comprehensive Test

    func testSensitiveModeBlocksAllUserData() {
        let config = AnalyticsConfiguration(
            privacy: .sensitive,
            unmaskedHeaders: ["content-type"],
            unmaskedUrlQueries: ["public"],
            unmaskedBodyParams: ["public_field"]
        )

        let url = "https://api.example.com/users/123/profile?public=yes&private=data"
        let headers = [
            "Content-Type": "application/json",
            "Authorization": "Bearer token"
        ]
        let body = """
        {"public_field": "value1", "private_field": "value2"}
        """.data(using: .utf8)!

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: url),
            headers: headers,
            body: body,
            configuration: config
        )

        // In sensitive mode, ALL query params are removed
        XCTAssertFalse(entry.url.contains("?"))
        XCTAssertFalse(entry.url.contains("public"))
        XCTAssertFalse(entry.url.contains("private"))

        // ALL headers are masked (unmaskedHeaders is ignored)
        XCTAssertEqual(entry.headers?["Content-Type"], "***")
        XCTAssertEqual(entry.headers?["Authorization"], "***")

        // Body is completely removed (unmaskedBodyParams is ignored)
        XCTAssertNil(entry.body)
    }

    // MARK: - Empty and Nil Values

    func testMaskingHandlesEmptyValues() {
        let config = AnalyticsConfiguration(privacy: .private)

        let json = """
        {"empty": "", "field": "value"}
        """.data(using: .utf8)!

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com"),
            body: json,
            configuration: config
        )

        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: String] {
            XCTAssertEqual(bodyJSON["empty"], "***")
            XCTAssertEqual(bodyJSON["field"], "***")
        }
    }

    func testMaskingHandlesNilValues() {
        let config = AnalyticsConfiguration(privacy: .private)

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: "https://api.example.com"),
            headers: nil,
            body: nil,
            configuration: config
        )

        XCTAssertNil(entry.headers)
        XCTAssertNil(entry.body)
    }

    // MARK: - Multiple Query Parameters

    func testMaskingMultipleQueryParametersWithSameKey() {
        let config = AnalyticsConfiguration(privacy: .private)

        let url = "https://api.example.com?id=1&id=2&id=3"

        let entry = AnalyticEntry(
            type: .request(method: "GET", url: url),
            configuration: config
        )

        // All instances should be masked
        let components = URLComponents(string: entry.url)
        let queryItems = components?.queryItems ?? []

        for item in queryItems where item.name == "id" {
            XCTAssertEqual(item.value, "***")
        }
    }

    // MARK: - JSON Arrays Masking

    func testMaskingArraysInJSON() {
        let config = AnalyticsConfiguration(
            privacy: .private,
            unmaskedBodyParams: ["public_ids"]
        )

        let json = """
        {
            "public_ids": ["1", "2", "3"],
            "secret_tokens": ["token1", "token2", "token3"]
        }
        """.data(using: .utf8)!

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com"),
            body: json,
            configuration: config
        )

        if let bodyData = entry.body,
           let bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] {
            // public_ids should not be masked
            let publicIds = bodyJSON["public_ids"] as? [String]
            XCTAssertEqual(publicIds, ["1", "2", "3"])

            // secret_tokens should be masked
            let secretTokens = bodyJSON["secret_tokens"] as? [String]
            XCTAssertEqual(secretTokens, ["***", "***", "***"])
        }
    }

    // MARK: - GraphQL Query Masking Security

    func testGraphQLQueryMaskingPreventsDataLeakage() {
        let config = AnalyticsConfiguration(privacy: .private)

        // Query with PII in literals
        let query = """
        query GetUser {
            user(email: "john.doe@example.com", ssn: "123-45-6789", creditCard: "4111111111111111") {
                name
                profile(phone: "+1-555-123-4567")
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "GetUser",
            query: query,
            configuration: config
        )

        XCTAssertNotNil(entry.query)
        let maskedQuery = entry.query!

        // Verify PII is masked
        XCTAssertFalse(maskedQuery.contains("john.doe@example.com"), "Email should be masked")
        XCTAssertFalse(maskedQuery.contains("123-45-6789"), "SSN should be masked")
        XCTAssertFalse(maskedQuery.contains("4111111111111111"), "Credit card should be masked")
        XCTAssertFalse(maskedQuery.contains("+1-555-123-4567"), "Phone should be masked")

        // Verify structure is preserved
        XCTAssertTrue(maskedQuery.contains("GetUser"))
        XCTAssertTrue(maskedQuery.contains("user"))
        XCTAssertTrue(maskedQuery.contains("profile"))

        // Verify masking is applied
        XCTAssertTrue(maskedQuery.contains("\"***\""))
    }

    func testGraphQLQueryMaskingSQLInjection() {
        let config = AnalyticsConfiguration(privacy: .private)

        let sqlInjection = "' OR '1'='1"
        let query = """
        query MaliciousQuery {
            user(id: "\(sqlInjection)") {
                name
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "MaliciousQuery",
            query: query,
            configuration: config
        )

        XCTAssertNotNil(entry.query)
        let maskedQuery = entry.query!

        // SQL injection attempt should be masked
        XCTAssertFalse(maskedQuery.contains(sqlInjection))
        XCTAssertTrue(maskedQuery.contains("id: \"***\""))

        // Structure preserved
        XCTAssertTrue(maskedQuery.contains("MaliciousQuery"))
        XCTAssertTrue(maskedQuery.contains("user"))
    }

    func testGraphQLQueryMaskingXSS() {
        let config = AnalyticsConfiguration(privacy: .private)

        let xssPayload = "<script>alert('XSS')</script>"
        let query = """
        query XSSAttempt {
            comment(text: "\(xssPayload)", author: "attacker") {
                id
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "XSSAttempt",
            query: query,
            configuration: config
        )

        XCTAssertNotNil(entry.query)
        let maskedQuery = entry.query!

        // XSS payload should be masked
        XCTAssertFalse(maskedQuery.contains(xssPayload))
        XCTAssertFalse(maskedQuery.contains("script"))
        XCTAssertFalse(maskedQuery.contains("alert"))

        // Both string literals should be masked
        XCTAssertTrue(maskedQuery.contains("text: \"***\""))
        XCTAssertTrue(maskedQuery.contains("author: \"***\""))

        // Structure preserved
        XCTAssertTrue(maskedQuery.contains("comment"))
    }

    func testMalformedGraphQLQueryWithUnclosedString() {
        let config = AnalyticsConfiguration(privacy: .private)

        // Malformed query with unclosed string literal (security vulnerability test)
        let malformedQuery = """
        query Test {
            user(id: $userId, secret: "password123
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "Test",
            query: malformedQuery,
            configuration: config
        )

        XCTAssertNotNil(entry.query)
        let maskedQuery = entry.query!

        // Critical: Unclosed string content must be masked, not leaked
        XCTAssertFalse(maskedQuery.contains("password123"), "Unclosed string content must be masked")

        // Should contain masked marker for safety
        XCTAssertTrue(maskedQuery.contains("\"***\""))

        // Variable reference should still be preserved
        XCTAssertTrue(maskedQuery.contains("$userId"))
    }

    func testGraphQLQueryNilInSensitiveMode() {
        let config = AnalyticsConfiguration(privacy: .sensitive)

        let query = """
        query GetUser {
            user(id: "123", role: "admin") {
                name
            }
        }
        """

        let entry = AnalyticEntry(
            type: .request(method: "POST", url: "https://api.example.com/graphql"),
            operationName: "GetUser",
            query: query,
            configuration: config
        )

        // In sensitive mode, query should be completely blocked
        XCTAssertNil(entry.query, "Query should be nil in sensitive privacy mode")
    }
}
