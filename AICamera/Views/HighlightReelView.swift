// FileName: AICamera/Views/HighlightReelView.swift
import SwiftUI

struct HighlightReelView: View {
    // ✅ 修复: 将 viewModel 的类型从 CameraViewModel 更改为 HighlightViewModel
    @ObservedObject var viewModel: HighlightViewModel
    @Environment(\.dismiss) var dismiss
    
    // ✅ 新增: 本地状态来控制分享成功后的提示
    @State private var showCopiedAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if viewModel.isGeneratingHighlightStory {
                    VStack {
                        ProgressView("正在为您编织高光故事...")
                            .padding()
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
                else if let story = viewModel.highlightStory {
                    Text(story.title)
                        .font(.largeTitle.bold())
                        .padding(.horizontal)
                    
                    Text(story.caption)
                        .font(.body)
                        .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(story.hashtags, id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.accentColor.opacity(0.2))
                                    .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Button(action: copyToClipboard) {
                        Label("复制分享文案", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                } else {
                    VStack {
                        Text("未能生成故事。")
                            .foregroundColor(.secondary)
                        Button("重试") {
                            // 调用 ViewModel 的重试逻辑（如果需要的话）
                        }
                        .padding(.top)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)

                }
            }
            .padding(.vertical)
        }
        .navigationTitle("高光卷轴")
        .navigationBarTitleDisplayMode(.inline)
        // ✅ 修复: 使用新的 alert 逻辑
        .alert("已复制", isPresented: $showCopiedAlert) {
            Button("好的", role: .cancel) { }
        } message: {
            Text("分享文案已复制到剪贴板。")
        }
    }
    
    private func copyToClipboard() {
        guard let story = viewModel.highlightStory else { return }
        
        let tags = story.hashtags.map { "#\($0)" }.joined(separator: " ")
        let fullText = """
        \(story.title)

        \(story.caption)

        \(tags)
        """
        UIPasteboard.general.string = fullText
        showCopiedAlert = true
    }
}
