import Vapor
import BaseballShared

extension RegisterRequest: @retroactive Validatable {
    public static func validations(_ validations: inout Validations) {
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
        validations.add("name", as: String.self, is: !.empty && .count(...100))
    }
}
