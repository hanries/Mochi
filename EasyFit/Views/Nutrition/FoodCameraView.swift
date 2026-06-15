import SwiftUI
import AVFoundation
import Combine
import UIKit

// MARK: - Main Camera View

struct FoodCameraView: View {
    var suggestedMeal: MealType = .lunch
    let onSave:    ([FoodEntry]) -> Void
    let onDismiss: () -> Void

    @EnvironmentObject private var paywall: PaywallCoordinator
    @StateObject private var camera = CameraModel()
    @State private var scanItems:    [FoodScanItem]? = nil
    @State private var isScanning    = false
    @State private var errorMessage: String? = nil
    @State private var showResult    = false
    @State private var capturedImage: UIImage? = nil
    @State private var scanBoxScale: CGFloat = 1.0

    private let service: any FoodScanServiceProtocol = ScanServiceFactory.make()

    var body: some View {
        ZStack {
            // Live camera feed
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            // Warm legibility scrims — tinted to the app's brown, not black
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [MochiTheme.textPrimary.opacity(0.55), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 190)
                Spacer()
                LinearGradient(
                    colors: [.clear, MochiTheme.textPrimary.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 260)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack {
                // Top bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(MochiTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(MochiTheme.surfaceAlt)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Scan your meal")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(MochiTheme.surfaceAlt)
                        .shadow(color: MochiTheme.textPrimary.opacity(0.4), radius: 4, y: 1)
                    Spacer()
                    // Flash toggle
                    Button {
                        camera.toggleFlash()
                    } label: {
                        Image(systemName: camera.flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(camera.flashOn ? MochiTheme.primary : MochiTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(MochiTheme.surfaceAlt)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // Scanning frame
                ZStack {
                    ScanFrame()
                        .scaleEffect(scanBoxScale)
                        .animation(
                            isScanning
                                ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                : .default,
                            value: scanBoxScale
                        )

                    if isScanning {
                        // Scanning line animation
                        ScanLineView()
                    }
                }
                .frame(width: 260, height: 260)

                Text(isScanning ? "Mochi's taking a look…" : "Point at your food")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(MochiTheme.surfaceAlt)
                    .shadow(color: MochiTheme.textPrimary.opacity(0.4), radius: 4, y: 1)
                    .padding(.top, 20)

                Spacer()

                // Bottom: shutter button
                if !isScanning {
                    Button {
                        capture()
                    } label: {
                        ZStack {
                            Circle()
                                .strokeBorder(MochiTheme.surfaceAlt, lineWidth: 4)
                                .frame(width: 84, height: 84)
                            Circle()
                                .fill(MochiTheme.primary)
                                .frame(width: 68, height: 68)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(MochiTheme.surfaceAlt)
                        }
                    }
                    .padding(.bottom, 50)
                } else {
                    ProgressView()
                        .tint(MochiTheme.primary)
                        .scaleEffect(1.5)
                        .padding(.bottom, 70)
                }
            }

            // Error toast
            if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(MochiTheme.danger.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 32)
                        .padding(.bottom, 140)
                        .onTapGesture { errorMessage = nil }
                }
            }
        }
        .onAppear  { camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: isScanning) { _, scanning in
            scanBoxScale = scanning ? 1.05 : 1.0
        }
        .sheet(isPresented: $showResult) {
            if let items = scanItems, let img = capturedImage {
                ScanResultView(
                    image:        img,
                    initialItems: items,
                    suggestedMeal: suggestedMeal,
                    onSave:    { entries in
                        showResult = false
                        onSave(entries)
                        onDismiss()
                    },
                    onRetake: { showResult = false },
                    onCancel: { showResult = false; onDismiss() }
                )
            }
        }
    }

    private func capture() {
        #if targetEnvironment(simulator)
        // The simulator has no camera, so synthesize a placeholder and run
        // the scan service directly (mock data when no API key is set).
        beginScan(with: Self.placeholderImage())
        #else
        camera.capturePhoto { image in
            guard let image else { return }
            beginScan(with: image)
        }
        #endif
    }

    private func beginScan(with image: UIImage) {
        capturedImage = image
        isScanning    = true
        errorMessage  = nil
        // The only place an AI scan actually runs — count it here.
        paywall.recordScanUsed()

        Task {
            do {
                let items = try await service.scan(image: image)
                await MainActor.run {
                    scanItems  = items
                    isScanning = false
                    showResult = true
                }
            } catch {
                await MainActor.run {
                    isScanning    = false
                    errorMessage  = error.localizedDescription
                }
            }
        }
    }

    #if targetEnvironment(simulator)
    private static func placeholderImage() -> UIImage {
        let size = CGSize(width: 200, height: 200)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.85, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
    #endif
}

// MARK: - Scan frame (corner brackets)

private struct ScanFrame: View {
    var body: some View {
        ZStack {
            // Dimmed area outside frame — just the corner brackets
            ForEach(0..<4, id: \.self) { i in
                CornerBracket()
                    .rotationEffect(.degrees(Double(i) * 90))
            }
        }
    }
}

private struct CornerBracket: View {
    let length: CGFloat = 30
    let thickness: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { p in
                // Horizontal arm
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: length, y: 0))
                // Vertical arm
                p.move(to: CGPoint(x: 0, y: 0))
                p.addLine(to: CGPoint(x: 0, y: length))
            }
            .stroke(MochiTheme.primary, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Animated scan line

private struct ScanLineView: View {
    @State private var offset: CGFloat = -130

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, MochiTheme.primary.opacity(0.9), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 2)
            .offset(y: offset)
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: true)) {
                    offset = 130
                }
            }
    }
}

// MARK: - Camera model

@MainActor
class CameraModel: NSObject, ObservableObject {
    let session    = AVCaptureSession()
    @Published var flashOn = false
    private var photoOutput = AVCapturePhotoOutput()
    private var photoCompletion: ((UIImage?) -> Void)?
    private var device: AVCaptureDevice?

    func start() {
        Task.detached {
            await self.setupSession()
        }
    }

    func stop() {
        session.stopRunning()
    }

    private func setupSession() async {
        guard await AVCaptureDevice.requestAccess(for: .video) else { return }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input  = try? AVCaptureDeviceInput(device: device)
        else { return }

        self.device = device
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input)       { session.addInput(input) }
        if session.canAddOutput(photoOutput){ session.addOutput(photoOutput) }
        session.commitConfiguration()
        session.startRunning()
    }

    func toggleFlash() {
        flashOn.toggle()
    }

    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCompletion = completion
        var settings = AVCapturePhotoSettings()
        if let device, device.hasFlash, flashOn {
            settings = AVCapturePhotoSettings()
            settings.flashMode = .on
        }
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraModel: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput,
                      didFinishProcessingPhoto photo: AVCapturePhoto,
                      error: Error?) {
        guard let data  = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Task { @MainActor in self.photoCompletion?(nil) }
            return
        }
        Task { @MainActor in self.photoCompletion?(image) }
    }
}

// MARK: - Camera preview (UIKit bridge)

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var camera: CameraModel

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.session = camera.session
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

        var session: AVCaptureSession? {
            get { previewLayer.session }
            set {
                previewLayer.session    = newValue
                previewLayer.videoGravity = .resizeAspectFill
            }
        }
    }
}
