import Foundation

/// The exception this API throws.
public enum AO3Exception: Error, LocalizedError {
    case invalidStatusCode(Int, String?)
    case noBodyReturned
    case parsingError(String, Error?)
    case workNotFound(Int)
    case userNotFound(String)
    case chapterNotFound(Int)
    case tooManyRedirects
    case registeredUsersOnly
    case generic(String)

    public var errorDescription: String? {
        switch self {
        case .invalidStatusCode(let code, let message):
            if let message = message {
                return "Invalid status code from AO3: \(message)"
            }
            return "Invalid status code from AO3: \(code)"
        case .noBodyReturned:
            return "No body returned from AO3"
        case .parsingError(let context, let error):
            if let error = error {
                return "\(context): \(error.localizedDescription)"
            }
            return context
        case .workNotFound(let id):
            return "Cannot find work with ID: \(id)"
        case .userNotFound(let username):
            return "Cannot find user: \(username)"
        case .chapterNotFound(let id):
            return "Chapter not found! Either the ID is invalid or doesn't exist in the current work object: \(id)"
        case .tooManyRedirects:
            return "Too many redirects in adult work confirmation!"
        case .registeredUsersOnly:
            return "This work is only available to registered users!"
        case .generic(let message):
            return message
        }
    }
}
