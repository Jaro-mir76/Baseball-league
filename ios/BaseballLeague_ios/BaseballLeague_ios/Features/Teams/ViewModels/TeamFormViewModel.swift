import Foundation
import Observation
import BaseballShared

@Observable
final class TeamFormViewModel {
    var name = ""
    var shortName = ""
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Non-nil when editing an existing team
    let editingTeam: TeamResponse?

    private let apiClient: APIClient

    init(apiClient: APIClient, team: TeamResponse? = nil) {
        self.apiClient = apiClient
        self.editingTeam = team
        if let team {
            self.name = team.name
            self.shortName = team.shortName ?? ""
        }
    }

    var isEditing: Bool { editingTeam != nil }

    func save() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedShort = shortName.trimmingCharacters(in: .whitespaces)
        let request = TeamRequest(
            name: trimmedName,
            shortName: trimmedShort.isEmpty ? nil : trimmedShort
        )

        do {
            if let team = editingTeam {
                let _: TeamResponse = try await apiClient.request(.updateTeam(team.id), body: request)
            } else {
                let _: TeamResponse = try await apiClient.request(.createTeam, body: request)
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
