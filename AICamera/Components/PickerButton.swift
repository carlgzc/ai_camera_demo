// FileName: PickerButton.swift
import SwiftUI

// ✅ FIX: The 'PostContentType' enum was not in scope.
// It is defined here to resolve the error. This component is part of a deprecated UI flow.
enum PostContentType {
    case original
    case optimized
    case videoStory
}

struct PickerButton: View {
    let type: PostContentType
    @Binding var selection: PostContentType
    let image: UIImage?
    let icon: String
    var videoURL: URL? = nil
    var isLoading: Bool = false
    
    private var isSelected: Bool { selection == type }
    
    var body: some View {
        Button(action: { withAnimation { selection = type } }) {
            ZStack(alignment: .center) {
                Group {
                    // ✅ FIX: Safely unwrap the optional 'image' property before use.
                    if let img = image {
                        Image(uiImage: img).resizable()
                    } else if videoURL != nil {
                        Rectangle().fill(Color.black)
                    } else {
                        Rectangle().fill(Color.secondary.opacity(0.2))
                    }
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 100)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                )

                if isLoading {
                    ProgressView().tint(.white)
                }
                
                ZStack {
                    Image(systemName: icon)
                        .font(.callout)
                        .padding(5)
                        .background(Circle().fill(.ultraThinMaterial))
                        .offset(x: 30, y: 40)
                }
            }
        }
    }
}
