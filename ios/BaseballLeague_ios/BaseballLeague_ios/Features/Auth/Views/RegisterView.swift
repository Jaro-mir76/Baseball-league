import SwiftUI

struct RegisterView: View {
    @State private var viewModel: RegisterViewModel

    init(appState: AppState) {
        _viewModel = State(initialValue: RegisterViewModel(appState: appState))
    }

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $viewModel.name)
                    .textContentType(.name)
                    .autocorrectionDisabled()

                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
            }

            Section {
                SecureField("Password (8+ characters)", text: $viewModel.password)
                    .textContentType(.newPassword)

                SecureField("Confirm Password", text: $viewModel.confirmPassword)
                    .textContentType(.newPassword)
            }

            if !viewModel.password.isEmpty && !viewModel.confirmPassword.isEmpty
                && viewModel.password != viewModel.confirmPassword {
                Section {
                    Text("Passwords do not match")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            if let error = viewModel.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }

            Section {
                Button {
                    Task { await viewModel.register() }
                } label: {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!viewModel.isValid || viewModel.isLoading)
            }
        }
        .navigationTitle("Create Account")
    }
}
