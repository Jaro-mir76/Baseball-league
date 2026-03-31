import SwiftUI
import BaseballShared

struct UserFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: UserFormViewModel

    var onSaved: (() -> Void)?

    init(apiClient: APIClient, user: UserResponse? = nil, onSaved: (() -> Void)? = nil) {
        _viewModel = State(initialValue: UserFormViewModel(apiClient: apiClient, user: user))
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $viewModel.name)
                    .textContentType(.name)
                    .autocorrectionDisabled()

                if viewModel.isEditing {
                    LabeledContent("Email", value: viewModel.email)
                } else {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)

                    SecureField("Password (8+ characters)", text: $viewModel.password)
                        .textContentType(.newPassword)
                }
            }

            Section {
                Picker("Role", selection: $viewModel.selectedRole) {
                    Text("Viewer").tag(UserRole.viewer)
                    Text("Scorer").tag(UserRole.scorer)
                    Text("Admin").tag(UserRole.admin)
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .navigationTitle(viewModel.isEditing ? "Edit User" : "New User")
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
