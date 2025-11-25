# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

FTNetworkTracer is a Swift Package Manager library for logging and tracking network requests. It provides dual functionality:
1. **Logging** - Formatted console output via `os.log` with privacy controls
2. **Analytics** - Privacy-masked network data tracking via a protocol-based system

The library supports both REST and GraphQL requests with specialized formatting for each.

## Common Commands

### Building
```bash
swift build
```

### Running Tests
```bash
# Run all tests
swift test

# Run a specific test
swift test --filter LoggingTests
swift test --filter AnalyticsTests
```

### Cleaning Build Artifacts
```bash
swift package clean
```

## Architecture

### Core Components

**FTNetworkTracer** (`FTNetworkTracer.swift:6`) - Main entry point
- Dual-mode design: Can be initialized with a logger, analytics tracker, or both
- Provides separate APIs for REST (via `URLRequest`) and GraphQL (via operation parameters)
- All requests flow through `performLogAndTrack()` which dispatches to both systems

**Entry System** - Type-safe network data representation
- `EntryType` (enum): Type-safe representation of request/response/error with associated values (method, URL, status code, error message)
- `NetworkEntry` (protocol): Common interface for accessing network data
- `LogEntry` (struct): Internal logging data with message formatting
- `AnalyticEntry` (struct): Public analytics data with automatic privacy masking

### Logging System

Located in `Sources/FTNetworkTracer/Logging/`

**LoggerConfiguration** - Configures `os.log` behavior
- Subsystem and category for log organization
- Privacy levels (none/auto/private/sensitive)
- Pluggable data decoders (default JSON pretty-printer, UTF8, size-only)

**Formatters** - Specialized message formatting
- `GraphQLFormatter`: Formats GraphQL queries with custom indentation rules and pretty-prints variables as JSON
- `RESTFormatter`: Formats REST request/response bodies using the configured data decoder

**LogEntry** - Message building
- Builds formatted log messages with aligned titles
- Routes to appropriate formatter based on presence of GraphQL data (operationName/query/variables)
- Automatically sets log level (error vs info) based on status codes and entry type

### Analytics System

Located in `Sources/FTNetworkTracer/Analytics/`

**AnalyticsProtocol** - Consumer interface
- Implement this protocol to receive network events
- Receive privacy-masked `AnalyticEntry` instances

**AnalyticsConfiguration** - Privacy controls
- Define sensitive query parameters, headers, and JSON body keys
- URL masking automatically strips sensitive query parameters and masks path segments
- Header/body/variables masking replaces sensitive values with `***`
- GraphQL query literal masking enabled by default (`maskQueryLiterals: true`)
  - Masks string literals (`"admin"` → `"***"`) and number literals (`123` → `***`)
  - Preserves query structure, field selections, and variable references (`$userId`)
  - Can be disabled with `maskQueryLiterals: false` for teams confident queries contain no sensitive data

**AnalyticEntry** - Masked data
- All masking happens at initialization time based on configuration
- Variables are deep-masked (handles nested dictionaries and arrays)
- GraphQL queries include `query` property with literal masking applied
  - `.none`/`.private` privacy: Query included with optional literal masking
  - `.sensitive` privacy: Query set to `nil` (most restrictive)

### Data Flow

1. Network adapter calls `logAndTrackRequest()`, `logAndTrackResponse()`, or `logAndTrackError()`
2. Request flows to `performLogAndTrack()` with standardized parameters
3. If logger configured: Creates `LogEntry` → Builds formatted message → Logs via `os.log`
4. If analytics configured: Creates `AnalyticEntry` (with privacy masking) → Calls `track()`

### Key Design Patterns

**Associated Values for Type Safety**
- `EntryType` uses associated values instead of optionals
- Eliminates impossible states (e.g., request can't have status code)
- Access via computed properties on `NetworkEntry` protocol

**Dual-Mode Formatters**
- GraphQL detected by presence of `operationName`, `query`, or `variables`
- REST formatting used otherwise
- Both systems share same entry types but use different formatters

**Privacy by Design**
- Logging: Privacy controlled via `OSLogPrivacy` levels
- Analytics: Privacy via automatic masking in `AnalyticEntry` initializer
- Masking is irreversible - once masked data is created, original data is gone
- GraphQL query masking: Secure by default with `maskQueryLiterals: true`
  - Removes literal values from queries while preserving structure for complexity analysis
  - Consistent with variable masking behavior

## Platform Support

- iOS 14+
- macOS 11+
- tvOS 14+
- watchOS 7+
- Swift 6.1.2+

## Code Conventions

- Use `@Sendable` for closures that cross concurrency boundaries
- All public types conform to `Sendable` for Swift 6 strict concurrency
- Privacy-sensitive data uses consistent `***MASKED***` replacement string
- GraphQL query formatting removes `__typename` as noise in logs
