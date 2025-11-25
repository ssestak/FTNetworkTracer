import Foundation

/// Masks literal values in GraphQL queries while preserving structure
struct QueryLiteralMasker {
    /// The masked query with literals replaced by "***"
    let maskedQuery: String

    /// Initializes a masker and processes the query
    /// - Parameter query: The GraphQL query string to mask
    init(query: String) {
        var processor = Processor()
        self.maskedQuery = processor.process(query)
    }

    // MARK: - Internal Processor

    private struct Processor {
        private var result = ""
        private var insideString = false
        private var insideParentheses = false
        private var currentToken = ""
        private var escapeNext = false

        mutating func process(_ query: String) -> String {
            for char in query {
                if escapeNext {
                    handleEscapedCharacter(char)
                    continue
                }

                if char == "\\" {
                    handleBackslash(char)
                    continue
                }

                processCharacter(char)
            }

            finalize()
            return result
        }

        // MARK: - Character Handlers

        private mutating func handleEscapedCharacter(_ char: Character) {
            if insideString {
                currentToken.append(char)
            } else {
                result.append(char)
            }
            escapeNext = false
        }

        private mutating func handleBackslash(_ char: Character) {
            escapeNext = true
            if insideString {
                currentToken.append(char)
            } else {
                result.append(char)
            }
        }

        private mutating func processCharacter(_ char: Character) {
            switch char {
            case "\"":
                handleQuote()
            case "(":
                handleOpenParenthesis(char)
            case ")":
                handleCloseParenthesis(char)
            case " ", "\n", "\t", ",", ":":
                handleDelimiter(char)
            default:
                handleDefaultCharacter(char)
            }
        }

        private mutating func handleQuote() {
            if insideParentheses && !insideString {
                insideString = true
                currentToken = "\""
            } else if insideString {
                insideString = false
                result.append("\"***\"")
                currentToken = ""
            } else {
                result.append("\"")
            }
        }

        private mutating func handleOpenParenthesis(_ char: Character) {
            if insideString {
                // Inside string literal - treat as regular character
                currentToken.append(char)
            } else {
                result.append(currentToken)
                result.append(char)
                currentToken = ""
                insideParentheses = true
            }
        }

        private mutating func handleCloseParenthesis(_ char: Character) {
            if insideString {
                // Inside string literal - treat as regular character
                currentToken.append(char)
            } else {
                flushToken()
                result.append(char)
                currentToken = ""
                insideParentheses = false
            }
        }

        private mutating func handleDelimiter(_ char: Character) {
            if insideString {
                currentToken.append(char)
            } else {
                flushToken()
                result.append(char)
            }
        }

        private mutating func handleDefaultCharacter(_ char: Character) {
            if insideString || insideParentheses {
                currentToken.append(char)
            } else {
                result.append(char)
            }
        }

        private mutating func flushToken() {
            guard insideParentheses && !currentToken.isEmpty else {
                return
            }

            if isNumericLiteral(currentToken) {
                result.append("***")
            } else {
                result.append(currentToken)
            }
            currentToken = ""
        }

        private mutating func finalize() {
            // Handle any remaining token
            if insideString {
                // Unclosed string - mask it for safety
                result.append("\"***\"")
            } else if !currentToken.isEmpty {
                result.append(currentToken)
            }
        }

        private func isNumericLiteral(_ token: String) -> Bool {
            let trimmed = token.trimmingCharacters(in: .whitespaces)
            // Check if it's a number (int or float) but not a variable reference
            guard !trimmed.isEmpty && !trimmed.hasPrefix("$") else {
                return false
            }
            return Double(trimmed) != nil
        }
    }
}
