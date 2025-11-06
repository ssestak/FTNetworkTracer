import Foundation
#if canImport(os.log)
import os.log
#endif

/// Privacy level for logging sensitive data using `OSLogPrivacy`.
///
/// This enum defines the different levels of privacy for logging data.
/// Each level corresponds to a specific `OSLogPrivacy` level.
public enum LogPrivacy: String, CaseIterable, Sendable {
    /// Logs all data without any masking (not recommended for production).
    /// Corresponds to `OSLogPrivacy.public`.
    case none = "none"

    /// Uses `OSLogPrivacy.auto` for automatic privacy detection.
    case auto = "auto"

    /// Uses `OSLogPrivacy.private` for sensitive data.
    case `private` = "private"

    /// Uses `OSLogPrivacy.sensitive` for highly sensitive data.
    case sensitive = "sensitive"

    /// Default privacy level that respects user privacy.
    /// The default value is `.auto`.
    public static let `default`: LogPrivacy = .auto

    #if canImport(os.log)
    var level: OSLogPrivacy {
        switch self {
        case .none:
            OSLogPrivacy.public
        case .auto:
            OSLogPrivacy.auto
        case .private:
            OSLogPrivacy.private
        case .sensitive:
            OSLogPrivacy.sensitive
        }
    }
    #endif
}
