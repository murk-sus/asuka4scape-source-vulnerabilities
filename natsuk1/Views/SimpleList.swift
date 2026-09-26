import SwiftUI
import UIKit

struct SimpleList<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(UIColor.systemGroupedBackground))
    }
}

struct SimpleSection<Content: View>: View {
    let title: String?
    let systemImage: String?
    let content: Content

    init(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    init(@ViewBuilder content: () -> Content) {
        self.title = nil
        self.systemImage = nil
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = title {
                HStack(spacing: 4) {
                    if let img = systemImage {
                        Image(systemName: img)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text(title.uppercased())
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.secondary)
                .padding(.leading, 12)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(UIColor.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
