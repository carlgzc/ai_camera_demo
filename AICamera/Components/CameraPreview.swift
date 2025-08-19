// FileName: AICamera/Components/CameraPreview.swift
import SwiftUI
import AVFoundation

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let cameraPosition: AVCaptureDevice.Position
    var onTap: (CGPoint) -> Void

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView(session: session)
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        context.coordinator.previewView = view
        
        context.coordinator.updateVideoOrientation()
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        context.coordinator.updateVideoOrientation()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: CameraPreview
        weak var previewView: PreviewUIView?

        init(_ parent: CameraPreview) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(updateVideoOrientation), name: UIDevice.orientationDidChangeNotification, object: nil)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let view = previewView else { return }
            let tapPoint = gesture.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: tapPoint)
            parent.onTap(devicePoint)
            
            showFocusIndicator(at: tapPoint, in: view)
        }
        
        private func showFocusIndicator(at point: CGPoint, in view: UIView) {
            let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
            indicator.center = point
            indicator.layer.borderColor = UIColor.yellow.cgColor
            indicator.layer.borderWidth = 2
            indicator.layer.cornerRadius = 40
            indicator.alpha = 0
            
            view.addSubview(indicator)
            
            UIView.animate(withDuration: 0.3, animations: {
                indicator.alpha = 1.0
            }) { _ in
                UIView.animate(withDuration: 0.2, delay: 0.5, options: .curveEaseOut, animations: {
                    indicator.alpha = 0
                }) { _ in
                    indicator.removeFromSuperview()
                }
            }
        }
        
        @objc func updateVideoOrientation() {
            guard let connection = previewView?.previewLayer.connection else { return }
            
            // ✅ 修复: 直接设置该属性为 false，移除不存在的 '...Supported' 检查。
            connection.automaticallyAdjustsVideoMirroring = false
            
            let currentOrientation = UIDevice.current.orientation
            
            // 1. 始终为前置摄像头设置镜像
            connection.isVideoMirrored = (parent.cameraPosition == .front)
            
            // 2. 根据设备朝向和摄像头位置，计算正确的旋转角度
            switch currentOrientation {
            case .portrait:
                connection.videoRotationAngle = 90
                
            case .landscapeLeft: // 设备向左旋转，Home键/条在右侧
                connection.videoRotationAngle = (parent.cameraPosition == .front) ? 180 : 0
                
            case .landscapeRight: // 设备向右旋转，Home键/条在左侧
                connection.videoRotationAngle = (parent.cameraPosition == .front) ? 0 : 180
                
            case .portraitUpsideDown:
                connection.videoRotationAngle = 270
                
            default:
                // 对于未知或 faceUp/faceDown，可以保持上一次的状态或默认为竖屏
                connection.videoRotationAngle = 90
            }
        }
    }
}

class PreviewUIView: UIView {
    let previewLayer: AVCaptureVideoPreviewLayer
    
    init(session: AVCaptureSession) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        super.init(frame: .zero)
        self.backgroundColor = .black
        self.previewLayer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(previewLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = self.bounds
    }
}
