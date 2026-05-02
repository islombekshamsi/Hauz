import SwiftUI

struct BorderContentView: View {
    @Binding var text: String
    var onDismiss: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 25) {
            TextField("What are you looking for?...", text: $text)
                .font(.custom("Outfit-Medium", size: 17))
                .focused($isFieldFocused)
                .textFieldStyle(.plain)
                .submitLabel(.search)
                .padding(.top, 8)

            HStack(spacing: 20) {
                Button {
                } label: {
                    Text("Name/Model Name")
                        .font(.caption)
                        .foregroundStyle(Color.primary.opacity(0.8))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 15)
                        .background(Color.primary.opacity(0.08), in: Capsule())
                }
                Spacer(minLength: 0)

                Group {
                    Button { } label: { Image(systemName: "plus") }
                    Button { } label: { Image(systemName: "cloud") }
                    Button { } label: { Image(systemName: "mic") }
                    Button(action: onDismiss) {
                        Image(systemName: "arrow.up")
                            .frame(width: 35, height: 35)
                            .background(Color.primary.opacity(0.08), in: Circle())
                    }
                }
                .foregroundStyle(Color.primary)
            }
        }
        .padding(15)
        .borderBeam(
            border: .primary,
            beam: [.green, .blue, .pink, .orange, .indigo],
            beamBlur: 15,
            cornerRadius: 20,
            isEnabled: true
        )
        .background(Color.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isFieldFocused = true
            }
        }
    }
}

#Preview {
    struct PreviewHolder: View {
        @State private var text = ""
        var body: some View {
            BorderContentView(text: $text, onDismiss: {})
                .padding()
        }
    }
    return PreviewHolder()
}
