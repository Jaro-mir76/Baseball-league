import Foundation
import BaseballShared

enum APIError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case validationFailed(String)
    case serverError
    case networkError(Error)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Your session has expired. Please log in again."
        case .forbidden:
            "You don't have permission to perform this action."
        case .notFound:
            "The requested resource was not found."
        case .conflict(let reason):
            reason
        case .validationFailed(let reason):
            reason
        case .serverError:
            "A server error occurred. Please try again later."
        case .networkError(let error):
            error.localizedDescription
        case .decodingError:
            "Failed to process the server response."
        }
    }

    static func fromHTTPStatus(_ statusCode: Int, data: Data) -> APIError {
        let reason = (try? JSONDecoder().decode(ErrorResponse.self, from: data))?.reason

        switch statusCode {
        case 401:
            return .unauthorized
        case 403:
            return .forbidden
        case 404:
            return .notFound
        case 409:
            return .conflict(reason ?? "A conflict occurred.")
        case 400, 422:
            return .validationFailed(reason ?? "Validation failed.")
        default:
            return .serverError
        }
    }
}
