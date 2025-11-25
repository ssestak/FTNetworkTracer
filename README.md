# FTNetworkTracer

A Swift package for comprehensive network request logging and analytics tracking with privacy-first design.

[![Swift](https://img.shields.io/badge/Swift-6.1.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS-lightgrey.svg)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager)

## Features

- 🔍 **Dual-mode operation**: Simultaneous logging and analytics tracking
- 🔒 **Privacy-first design**: Configurable data masking with three privacy levels
- 🌐 **REST & GraphQL support**: Specialized formatting for both API types
- 🔐 **GraphQL query masking**: Automatic literal masking for privacy-safe analytics
- 📊 **Structured logging**: Uses `os.log` for performance and privacy
- 🎚️ **Log level filtering**: Configurable minimum threshold (debug, info, error, fault)
- 🐧 **Linux support**: Full cross-platform compatibility with CI/CD
- 🎯 **Type-safe**: Associated values eliminate impossible states
- ⚡ **Zero dependencies**: Pure Swift implementation
- 🧪 **Fully tested**: 75 tests including comprehensive security and privacy tests
- 🔄 **Swift 6 ready**: Strict concurrency compliant with `Sendable` support

## Requirements

- iOS 14.0+ / macOS 11.0+ / tvOS 14.0+ / watchOS 7.0+
- Swift 6.1.0+
- Xcode 15.0+

## Installation

### Swift Package Manager

```swift
    .package(url: "https://github.com/futuredapp/FTNetworkTracer.git", from: "0.2.0")
```

## Quick Start

### Basic Setup

```swift
import FTNetworkTracer

// Create logger configuration
let logger = LoggerConfiguration(
    subsystem: "com.yourapp",
    category: "network"
)

// Create analytics tracker
class MyAnalytics: AnalyticsProtocol {
    let configuration = AnalyticsConfiguration(privacy: .private)

    func track(_ entry: AnalyticEntry) {
        // Send to your analytics service
        print("Tracking: \(entry.method) \(entry.url)")

        // Access GraphQL query for complexity analysis
        if let query = entry.query {
            analyzeQueryComplexity(query)
        }
    }

    func analyzeQueryComplexity(_ query: String) {
        // Analyze query structure without seeing sensitive literals
        let fieldCount = query.components(separatedBy: "\n").count
        print("Query complexity: \(fieldCount) lines")
    }
}

// Initialize tracer
let tracer = FTNetworkTracer(
    logger: logger,
    analytics: MyAnalytics()
)
```

### REST API Usage

```swift
// Track request
let request = URLRequest(url: URL(string: "https://api.example.com/users")!)
tracer.logAndTrackRequest(
    request: request,
    requestId: UUID().uuidString
)

// Track response
let response = HTTPURLResponse(...)
tracer.logAndTrackResponse(
    request: request,
    response: response,
    data: responseData,
    requestId: requestId,
    startTime: startTime
)

// Track error
tracer.logAndTrackError(
    request: request,
    error: error,
    requestId: requestId
)
```

### GraphQL Usage

```swift
let query = """
query GetUser($id: ID!) {
    user(id: $id) {
        name
        email
    }
}
"""

let variables: [String: any Sendable] = ["id": "123"]

// Track GraphQL request
tracer.logAndTrackRequest(
    url: "https://api.example.com/graphql",
    operationName: "GetUser",
    query: query,
    variables: variables,
    headers: ["Authorization": "Bearer token"],
    requestId: requestId
)

// Track GraphQL response
tracer.logAndTrackResponse(
    url: "https://api.example.com/graphql",
    operationName: "GetUser",
    statusCode: 200,
    requestId: requestId,
    startTime: startTime
)
```

## Configuration

### Logger Configuration

```swift
// Default configuration with pretty-printed JSON
let logger = LoggerConfiguration(
    subsystem: "com.yourapp",
    category: "network",
    privacy: .auto // .none, .auto, .private, .sensitive
)

// With log level filtering (only show errors and faults)
let logger = LoggerConfiguration(
    subsystem: "com.yourapp",
    category: "network",
    logLevel: .error // .debug, .info, .error, .fault
)

// Custom data decoder (e.g., show only size)
let logger = LoggerConfiguration(
    subsystem: "com.yourapp",
    category: "network",
    dataDecoder: LoggerConfiguration.sizeOnlyDataDecoder
)

// UTF8-only decoder (no JSON formatting)
let logger = LoggerConfiguration(
    subsystem: "com.yourapp",
    category: "network",
    dataDecoder: LoggerConfiguration.utf8DataDecoder
)
```

### Analytics Configuration

```swift
// Sensitive mode (most secure, default)
let config = AnalyticsConfiguration(privacy: .sensitive)

// Private mode with exceptions
let config = AnalyticsConfiguration(
    privacy: .private,
    unmaskedHeaders: ["content-type", "accept"],
    unmaskedUrlQueries: ["page", "limit"],
    unmaskedBodyParams: ["username", "email"]
)

// Private mode with GraphQL query literal masking disabled
let config = AnalyticsConfiguration(
    privacy: .private,
    maskQueryLiterals: false  // Disable query literal masking (default: true)
)

// No privacy (development only)
let config = AnalyticsConfiguration(privacy: .none)
```

### Privacy Levels

| Level | Headers | URL Queries | Body | GraphQL Queries | Use Case |
|-------|---------|-------------|------|----------------|----------|
| **`.none`** | ✅ Preserved | ✅ Preserved | ✅ Preserved | ⚠️ Literals masked* | Development only |
| **`.private`** | ⚠️ Masked (with exceptions) | ⚠️ Masked (with exceptions) | ⚠️ Masked (with exceptions) | ⚠️ Literals masked* | Production with selective tracking |
| **`.sensitive`** | 🔒 All masked | 🔒 All removed | 🔒 Removed | 🔒 Removed (nil) | Production with maximum privacy |

\* GraphQL query literal masking is **enabled by default** (`maskQueryLiterals: true`) to prevent accidental data leakage. Can be disabled if needed.

## Privacy & Security

### What Gets Masked

FTNetworkTracer automatically masks sensitive data in analytics:

- **Headers**: `Authorization`, `Cookie`, `X-API-Key`, etc.
- **URL Parameters**: All query parameters (in `.sensitive` mode)
- **Body Fields**: `password`, `token`, `secret`, `creditCard`, `ssn`, etc.
- **GraphQL Variables**: All variables unless explicitly unmasked
- **GraphQL Query Literals**: String and number literals in queries (enabled by default)
  - `"admin"` → `"***"`
  - `123` → `***`
  - Variable references like `$userId` are preserved
  - Query structure is preserved for complexity analysis

### Masking is Irreversible

Once data is masked with `***`, the original value **cannot be recovered**. This ensures sensitive data never leaves your application.

### Case-Insensitive Matching

Unmasked parameter lists use case-insensitive matching to prevent bypasses:

```swift
// These are all treated as the same key:
unmaskedHeaders: ["content-type"]
// Matches: "Content-Type", "CONTENT-TYPE", "content-type"
```

### Attack Vector Protection

FTNetworkTracer has been tested against common attack vectors:
- ✅ XSS attempts (`<script>alert('XSS')</script>`)
- ✅ SQL injection (`' OR '1'='1`)
- ✅ Path traversal (`../../../etc/passwd`)
- ✅ Very long strings (10,000+ characters)
- ✅ Unicode and special characters

## Log Output Examples

### REST Request Log
```
[REQUEST] [abc12345]
	Method       POST
	URL          https://api.example.com/users
	Timestamp    2025-11-04 15:42:30.123
Headers:
	Content-Type application/json
	Body:
	{
	  "username": "john",
	  "email": "john@example.com"
	}
```

### GraphQL Request Log
```
[REQUEST] [xyz67890]
	Method       POST
	URL          https://api.example.com/graphql
	Timestamp    2025-11-04 15:42:31.456
	Operation    GetUser
Headers:
	Authorization Bearer ***
Query:
	query GetUser($id: ID!) {
	  user(id: $id) {
	    name
	    email
	  }
	}
Variables:
	{
	  "id": "123"
	}
```

### GraphQL Query Masking (Analytics)

When tracking analytics, GraphQL queries are automatically masked for privacy:

**Original Query:**
```graphql
query GetUser($userId: ID!) {
  user(id: $userId, role: "admin", minAge: 18) {
    name
    email
  }
}
```

**Masked Query in AnalyticEntry (default behavior):**
```graphql
query GetUser($userId: ID!) {
  user(id: $userId, role: "***", minAge: ***) {
    name
    email
  }
}
```

✅ **Preserved**: Query structure, field selections, variable references (`$userId`)
🔒 **Masked**: String literals (`"admin"`), number literals (`18`)

This allows you to analyze query complexity and patterns without exposing sensitive data.

## Architecture

FTNetworkTracer uses a **dual-mode architecture**:

```
┌─────────────────┐
│ FTNetworkTracer │
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼───┐ ┌──▼────────┐
│Logging│ │ Analytics │
└───────┘ └───────────┘
```

### Key Components

- **`FTNetworkTracer`**: Main coordinator for logging and analytics
- **`EntryType`**: Type-safe enum with associated values (request/response/error)
- **`LogEntry`**: Internal logging data with formatted messages
- **`AnalyticEntry`**: Public analytics data with automatic privacy masking
- **`GraphQLFormatter`**: Specialized GraphQL query formatting
- **`RESTFormatter`**: REST body formatting with pluggable decoders

### Design Principles

- **Privacy by Design**: Masking happens at initialization, not at usage
- **Type Safety**: Associated values eliminate optional-heavy code
- **Separation of Concerns**: Logging and analytics are independent
- **Protocol-Based**: Easy to extend and test

## Test Coverage

- **AnalyticsTests** (11 tests): Privacy masking for all levels + GraphQL query masking
- **GraphQLFormatterTests** (11 tests): Query and variable formatting
- **IntegrationTests** (16 tests): End-to-end flows including query analytics
- **LoggingTests** (6 tests): Log message building and level filtering
- **RESTFormatterTests** (9 tests): Body formatting
- **SecurityTests** (22 tests): Comprehensive security validation

**Total: 75 tests** with full coverage of privacy, security, and GraphQL query masking

## Example Projects

### URLSession Integration

```swift
class NetworkClient {
    let tracer: FTNetworkTracer

    func fetch(url: URL) async throws -> Data {
        let requestId = UUID().uuidString
        let request = URLRequest(url: url)
        let startTime = Date()

        // Log request
        tracer.logAndTrackRequest(request: request, requestId: requestId)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            // Log response
            tracer.logAndTrackResponse(
                request: request,
                response: response,
                data: data,
                requestId: requestId,
                startTime: startTime
            )

            return data
        } catch {
            // Log error
            tracer.logAndTrackError(
                request: request,
                error: error,
                requestId: requestId
            )
            throw error
        }
    }
}
```

### Apollo GraphQL Integration

```swift
class ApolloNetworkInterceptor: ApolloInterceptor {
    let tracer: FTNetworkTracer

    func interceptAsync<Operation: GraphQLOperation>(
        chain: RequestChain,
        request: HTTPRequest<Operation>,
        response: HTTPResponse<Operation>?,
        completion: @escaping (Result<GraphQLResult<Operation.Data>, Error>) -> Void
    ) {
        let requestId = UUID().uuidString

        if let operation = request.operation as? GraphQLQuery {
            tracer.logAndTrackRequest(
                url: request.graphQLEndpoint.absoluteString,
                operationName: operation.operationName,
                query: operation.queryDocument,
                variables: operation.variables,
                headers: request.additionalHeaders,
                requestId: requestId
            )
        }

        chain.proceedAsync(
            request: request,
            response: response,
            completion: completion
        )
    }
}
```

## Best Practices

### 1. Use Appropriate Privacy Levels

- **Development**: `.none` or `.private`
- **Staging**: `.private` with specific unmasked fields
- **Production**: `.sensitive` (default)

### 2. Generate Unique Request IDs

```swift
let requestId = UUID().uuidString
// Use the same requestId for request, response, and error
```

### 3. Track Response Times

```swift
let startTime = Date()
// Make request...
tracer.logAndTrackResponse(..., startTime: startTime)
```

### 4. Don't Log Sensitive Data

Even with masking, avoid logging:
- Payment card details
- Social security numbers
- Biometric data
- Health information

### 5. Test Your Configuration

Always test your privacy configuration to ensure sensitive data is masked:

```swift
let config = AnalyticsConfiguration(privacy: .private, ...)
let entry = AnalyticEntry(type: .request(...), body: testData, configuration: config)
// Verify entry.body doesn't contain sensitive data
```
## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Review the [CLAUDE.md](CLAUDE.md) for architecture details

---

**Made with ❤️ by Futured**
