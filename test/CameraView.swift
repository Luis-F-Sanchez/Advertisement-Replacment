import SwiftUI
import AVFoundation
import Roboflow

// This struct allows us to use a standard UIKit view inside SwiftUI
struct CameraView: UIViewControllerRepresentable {
    var model: RFModel?
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.model = self.model
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// This is the controller that actually manages the camera hardware
class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var model: RFModel?
    var frameCounter = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .vga640x480 // Keep resolution low for faster AI inference
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch { return }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else { return }
        
        // Setup the preview layer so you can see what the camera sees
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Setup the output to intercept the video frames
        let videoOutput = AVCaptureVideoDataOutput()
        
        // Force standard color format so the iPad processes the buffer correctly
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }
        
        // Start the camera in the background
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }
    
    // This function runs every time the camera captures a new frame (30+ times a second)
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCounter += 1
        
        // Scan exactly once per second (assuming 30fps) to clear up bottlenecks
        if frameCounter % 30 == 0 {
            guard let model = model else { return }
            
            // 1. Grab the raw pixel buffer directly from the camera
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("Failed to get pixel buffer")
                return
            }
            
            print("Running AI on Frame \(self.frameCounter)...")
            
            // 2. RUN DETECTION IMMEDIATELY on the background thread
            model.detect(pixelBuffer: pixelBuffer) { predictions, error in
                
                // 3. Only jump to the main thread to update the UI or print results
                DispatchQueue.main.async {
                    if let error = error {
                        print("AI Error: \(error.localizedDescription)")
                    } else if let preds = predictions, !preds.isEmpty {
                        print("Detected Ad Coordinates: \(preds)")
                    } else {
                        print("AI scanned the image... no ads detected.")
                    }
                }
            }
        }
    }
}
