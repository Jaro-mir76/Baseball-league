import SwiftUI

struct CommentEntryView: View {
    @State private var comment = ""
    var onSubmit: (String) async -> Void

    var body: some View {
        HStack {
            TextField("Add comment...", text: $comment)
                .textFieldStyle(.roundedBorder)

            Button {
                let text = comment
                comment = ""
                Task { await onSubmit(text) }
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .disabled(comment.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}
