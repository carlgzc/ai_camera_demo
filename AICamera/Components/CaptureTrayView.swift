// FileName: CaptureTrayView.swift
import SwiftUI

struct CaptureTrayView: View {
    @Binding var tasks: [CaptureTask]
    let onSelectTask: (CaptureTask) -> Void
    
    var body: some View {
        if !tasks.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(tasks) { task in
                        Button(action: { onSelectTask(task) }) {
                            ZStack {
                                // ✅ 修改: 使用计算属性
                                if let image = task.originalImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 80)
                                        .cornerRadius(8)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(width: 60, height: 80)
                                        .cornerRadius(8)
                                }

                                // ✅ 修改: 使用文件名判断
                                if task.videoFileName == nil && task.inspirationText == nil {
                                    ProgressView().tint(.white)
                                }
                                else if task.inspirationText != nil {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .padding(4)
                                        .background(Circle().fill(Color.black.opacity(0.5)))
                                        .position(x: 50, y: 10)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 90)
            .padding(.bottom, 15)
        }
    }
}
