import SwiftUI
import BaseballShared

struct TeamFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: TeamFormViewModel

    var onSaved: (() -> Void)?

    init(apiClient: APIClient, team: TeamResponse? = nil, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: TeamFormViewModel(apiClient: apiClient, team: team))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                TextField("Team Name", text: $viewModel.name)
                    .textContentType(.organizationName)
                    .autocorrectionDisabled()

                TextField("Short Name (optional)", text: $viewModel.shortName)
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
        .navigationTitle(viewModel.isEditing ? "Edit Team" : "New Team")
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
