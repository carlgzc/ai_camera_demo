// FileName: InspirationView.swift
import SwiftUI

struct InspirationView: View {
    @Binding var state: InspirationState
    let reasoningText: String
    let inspirationText: String
    let latency: Int?
    let onDismiss: () -> Void
    
    private let scrollAnchorID = "bottomAnchor"

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .center, spacing: 8) {
                        contentView
                        EmptyView().id(scrollAnchorID)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 150)
                .task(id: reasoningText + inspirationText) {
                    do {
                        try await Task.sleep(for: .milliseconds(100))
                        withAnimation(.easeInOut(duration: 0.5)) {
                            scrollViewProxy.scrollTo(scrollAnchorID, anchor: .bottom)
                        }
                    } catch {}
                }
            }

            if state != .idle {
                 Button(action: onDismiss) {
                     Image(systemName: "xmark.circle.fill")
                         .foregroundColor(.white.opacity(0.7))
                         .font(.title3)
                 }
                 .padding(.top, 8)
                 .padding(.trailing, 4)
            }
        }
        .padding(.leading, 12)
        .background(Color.black.opacity(0.65))
        .cornerRadius(15)
        .padding(.horizontal, 30)
    }
    
    @ViewBuilder
    private var contentView: some View {
        switch state {
        case .thinking:
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("灵感正在酝酿...")
            }
            .frame(minHeight: 44)

        case .reasoning:
            Text("🤔 " + (reasoningText.isEmpty ? "深入场景的肌理..." : reasoningText))
                .foregroundColor(.gray)
            
        // ✅ FIX: 强制将字符串变量作为 Markdown 解析
        case .streaming, .finished:
            Text(.init(inspirationText))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
        
        case .error(let message):
            Text(message).foregroundColor(.red)
        
        default:
            EmptyView()
        }

        if let latency = latency, case .finished = state {
            Text("心流耗时: \(latency) ms")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
                .padding(.top, 4)
        }
    }
}
