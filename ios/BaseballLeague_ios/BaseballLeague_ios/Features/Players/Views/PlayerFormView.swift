import SwiftUI
import BaseballShared

struct PlayerFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PlayerFormViewModel

    var onSaved: (() -> Void)?

    init(apiClient: APIClient, teamId: UUID, player: PlayerSummary? = nil, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: PlayerFormViewModel(apiClient: apiClient, teamId: teamId, player: player))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                TextField("First Name", text: $viewModel.firstName)
                    .textContentType(.givenName)
                    .autocorrectionDisabled()

                TextField("Last Name", text: $viewModel.lastName)
                    .textContentType(.familyName)
                    .autocorrectionDisabled()
            }

            Section {
                TextField("Jersey Number (optional)", text: $viewModel.jerseyNumber)
                    .keyboardType(.numberPad)

                TextField("Position (optional)", text: $viewModel.position)
                    .autocorrectionDisabled()
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit Player" : "New Player")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await viewModel.save() }
                }
                .disabled(!viewModel.isValid || viewModel.isSaving)
            }
        }
        .disabled(viewModel.isSaving)
        .onChange(of: viewModel.didSave) {
            if viewModel.didSave {
                onSaved?()
                dismiss()
            }
        }
    }
}
