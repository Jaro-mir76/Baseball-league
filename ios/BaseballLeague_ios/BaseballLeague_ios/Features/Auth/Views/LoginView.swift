import SwiftUI

struct LoginView: View {
    @State private var viewModel: LoginViewModel
    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        _viewModel = State(initialValue: LoginViewModel(appState: appState))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.emailAddress)

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await viewModel.login()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Log In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!viewModel.isValid || viewModel.isLoading)
                }

                Section {
                    NavigationLink("Create Account") {
                        RegisterView(appState: appState)
                    }
                }
            }
            .navigationTitle("Baseball League")
        }
    }
}
