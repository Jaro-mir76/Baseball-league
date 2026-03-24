import Foundation
import Observation
import BaseballShared

@Observable
final class PlayerFormViewModel {
    var firstName = ""
    var lastName = ""
    var jerseyNumber = ""
    var position = ""
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    let editingPlayer: PlayerSummary?
    private let teamId: UUID
    private let apiClient: APIClient

    init(apiClient: APIClient, teamId: UUID, player: PlayerSummary? = nil) {
        self.apiClient = apiClient
        self.teamId = teamId
        self.editingPlayer = player
        if let player {
            self.firstName = player.firstName
            self.lastName = player.lastName
            self.jerseyNumber = player.jerseyNumber.map(String.init) ?? ""
            self.position = player.position ?? ""
        }
    }

    var isEditing: Bool { editingPlayer != nil }

    func save() async {
        guard isValid else { return }
        isSaving = true
        errorMessage = nil

        let trimmedFirst = firstName.trimmingCharacters(in: .whitespaces)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespaces)
        let jersey = Int(jerseyNumber.trimmingCharacters(in: .whitespaces))
        let pos = position.trimmingCharacters(in: .whitespaces)

        do {
            if let player = editingPlayer {
                let request = PlayerUpdateRequest(
                    firstName: trimmedFirst,
                    lastName: trimmedLast,
                    jerseyNumber: jersey,
                    position: pos.isEmpty ? nil : pos
                )
                let _: PlayerResponse = try await apiClient.request(.updatePlayer(player.id), body: request)
            } else {
                let request = PlayerRequest(
                    firstName: trimmedFirst,
                    lastName: trimmedLast,
                    jerseyNumber: jersey,
                    position: pos.isEmpty ? nil : pos,
                    teamId: teamId
                )
                let _: PlayerResponse = try await apiClient.request(.createPlayer, body: request)
            }
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }

        isSaving = false
    }
}
