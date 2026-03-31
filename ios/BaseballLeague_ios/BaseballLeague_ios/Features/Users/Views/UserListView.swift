import SwiftUI
import BaseballShared

extension UserResponse: @retroactive Identifiable {}

struct UserListView: View {
    @State private var viewModel: UserListViewModel
    @State private var showingNewUser = false
    @State private var editingUser: UserResponse?

    private let apiClient: APIClient

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        _viewModel = State(initialValue: UserListViewModel(apiClient: apiClient))
    }

    var body: some View {
        List {
            ForEach(viewModel.users, id: \.id) { user in
                Button {
                    editingUser = user
                } label: {
                    UserRow(user: user)
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                Task {
                    for index in offsets {
                        await viewModel.deleteUser(viewModel.users[index].id)
                    }
                }
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.users.isEmpty {
                ProgressView()
            } else if let error = viewModel.errorMessage, viewModel.users.isEmpty {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if viewModel.users.isEmpty && !viewModel.isLoading {
                ContentUnavailableView("No Users", systemImage: "person.2", description: Text("No users have been created yet."))
            }
        }
        .navigationTitle("Users")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewUser = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewUser) {
            NavigationStack {
                UserFormView(apiClient: apiClient) {
                    Task { await viewModel.loadUsers() }
                }
            }
        }
        .sheet(item: $editingUser) { user in
            NavigationStack {
                UserFormView(apiClient: apiClient, user: user) {
                    Task { await viewModel.loadUsers() }
                }
            }
        }
        .task {
            await viewModel.loadUsers()
        }
        .refreshable {
            await viewModel.loadUsers()
        }
    }
}

// MARK: - User Row

private struct UserRow: View {
    let user: UserResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(user.name)
                    .font(.headline)
                Spacer()
                RoleBadge(role: user.role)
            }
            Text(user.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Role Badge

private struct RoleBadge: View {
    let role: UserRole

    var body: some View {
        Text(role.rawValue.capitalized)
            .font(.caption.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch role {
        case .admin:  .red.opacity(0.15)
        case .scorer: .orange.opacity(0.15)
        case .viewer: .secondary.opacity(0.15)
        }
    }

    private var foregroundColor: Color {
        switch role {
        case .admin:  .red
        case .scorer: .orange
        case .viewer: .secondary
        }
    }
}
