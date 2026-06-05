import SwiftUI

/// A brief overlay toast notification that appears at the center of its parent.
struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.75))
            .cornerRadius(8)
    }
}

/// A view modifier that overlays a toast when `isShowing` is true.
struct ToastModifier: ViewModifier {
    let message: String
    let isShowing: Bool

    func body(content: Content) -> some View {
        ZStack {
            content

            if isShowing {
                VStack {
                    Spacer()
                    ToastView(message: message)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    Spacer()
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.2), value: isShowing)
            }
        }
    }
}

extension View {
    func toast(message: String, isShowing: Bool) -> some View {
        modifier(ToastModifier(message: message, isShowing: isShowing))
    }
}
