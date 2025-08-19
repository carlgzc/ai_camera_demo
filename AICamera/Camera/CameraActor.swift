// FileName: Camera/CameraActor.swift
import AVFoundation
import UIKit

actor CameraActor {
    nonisolated let session = AVCaptureSession()
    
    private let photoOutput = AVCapturePhotoOutput()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let videoOutput = AVCaptureVideoDataOutput() // For live frame analysis
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back

    private weak var recordingDelegate: AVCaptureFileOutputRecordingDelegate?

    init() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("Error: Could not create back camera input.")
            return
        }
        session.addInput(input)
        videoDeviceInput = input
        
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        if session.canAddOutput(movieOutput) {
            session.addOutput(movieOutput)
        }
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
    }
    
    // ✅ FIX: This is the root cause of the build error. The signature is now correct.
    func configureDelegates(photoDelegate: AVCapturePhotoCaptureDelegate, recordingDelegate: AVCaptureFileOutputRecordingDelegate, videoSampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        self.recordingDelegate = recordingDelegate
        
        let videoDataOutputQueue = DispatchQueue(label: "video_queue", qos: .userInitiated)
        videoOutput.setSampleBufferDelegate(videoSampleBufferDelegate, queue: videoDataOutputQueue)
    }

    func start() {
        if !session.isRunning {
            session.startRunning()
        }
    }
    
    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    func focus(at point: CGPoint) {
        guard let device = videoDeviceInput?.device else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("Error locking camera for configuration: \(error)")
        }
    }

    func capturePhoto(delegate: AVCapturePhotoCaptureDelegate) {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    func startRecording() {
        guard !movieOutput.isRecording, let delegate = recordingDelegate else { return }
        let outputPath = NSTemporaryDirectory() + UUID().uuidString + ".mov"
        let outputURL = URL(fileURLWithPath: outputPath)
        movieOutput.startRecording(to: outputURL, recordingDelegate: delegate)
    }

    func stopRecording() {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
    }
    
    func switchCamera() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        guard let currentInput = videoDeviceInput else { return }
        
        let newPosition: AVCaptureDevice.Position = (currentCameraPosition == .back) ? .front : .back
        guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newDevice)
            session.removeInput(currentInput)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoDeviceInput = newInput
                currentCameraPosition = newPosition
            } else {
                session.addInput(currentInput)
            }
        } catch {
            print("Error switching camera: \(error)")
            if !session.inputs.contains(currentInput) {
                session.addInput(currentInput)
            }
        }
    }
    
    func getCurrentCameraPosition() -> AVCaptureDevice.Position {
        return currentCameraPosition
    }
}
