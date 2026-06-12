import SwiftUI
import AVFoundation
import Combine
import UIKit

// MARK: - Main Camera View

struct FoodCameraView: View {
    let onResult:  (FoodScanResult) -> Void
    let onDismiss: () -> Void

    @StateObject private var camera = CameraModel()
    @State private var scanResult:   FoodScanResult? = nil
    @State private var isScanning    = false
    @State private var errorMessage: String? = nil
    @State private var showResult    = false
    @State private var capturedImage: UIImage? = nil
    @State private var scanBoxScale: CGFloat = 1.0
    @State private var mealType: MealType = .lunch

    private let service: any FoodScanServiceProtocol = ScanServiceFactory.make()

    var body: some View {
        ZStack {
            // Live camera feed
            CameraPreview(camera: camera)
                .ignoresSafeArea()

            // Dark vignette edges
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        center: .center,
                        startRadius: 150,
                        endRadius: 350
                    )
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                // Top bar
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Scanner")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    // Flash toggle
                    Button {
                        camera.toggleFlash()
                    } label: {
                        Image(systemName: camera.flashOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial)
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

                Text(isScanning ? "Analyzing…" : "Point at your food")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 20)

                Spacer()

                // Bottom: shutter button
                if !isScanning {
                    Button {
                        capture()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.2))
                                .frame(width: 80, height: 80)
                            Circle()
                                .fill(.white)
                                .frame(width: 64, height: 64)
                        }
                    }
                    .padding(.bottom, 50)
                } else {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                        .padding(.bottom, 70)
                }
            }

            // Error toast
            if let error = errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.system(size: 14))
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
            if let result = scanResult, let img = capturedImage {
                ScanResultView(
                    image:    img,
                    result:   result,
                    onAdd:    { _ in
                        showResult = false
                        onResult(result)
                        onDismiss()
                    },
                    onRetake: { showResult = false },
                    onCancel: { showResult = false; onDismiss() }
                )
            }
        }
    }

    private func capture() {
        camera.capturePhoto { image in
            guard let image else { return }
            capturedImage = image
            isScanning    = true
            errorMessage  = nil

            Task {
                do {
                    let result = try await service.scan(image: image)
                    await MainActor.run {
                        scanResult = result
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
    }
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
            .stroke(.white, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
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
                    colors: [.clear, .white.opacity(0.6), .clear],
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

// MARK: - Result view

private struct ScanResultView: View {
    let image:    UIImage
    let result:   FoodScanResult
    let onAdd:    (FoodScanResult) -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var mealType: MealType = .lunch

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name).font(.system(size: 18, weight: .bold))
                                Text(result.servingSize).font(.system(size: 13)).foregroundStyle(MochiTheme.textSecondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(result.calories)").font(.system(size: 26, weight: .bold))
                                Text("kcal").font(.system(size: 12)).foregroundStyle(MochiTheme.textSecondary)
                            }
                        }
                        .padding(16)

                        Divider().padding(.horizontal)

                        HStack(spacing: 0) {
                            MacroCell(label: "Protein", value: result.protein, color: MochiTheme.success)
                            Divider().frame(height: 40)
                            MacroCell(label: "Carbs",   value: result.carbs,   color: MochiTheme.warning)
                            Divider().frame(height: 40)
                            MacroCell(label: "Fat",     value: result.fat,     color: MochiTheme.accent)
                        }
                        .padding(.vertical, 8)

                        Divider().padding(.horizontal)

                        HStack {
                            Image(systemName: result.confidence > 0.7 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(result.confidence > 0.7 ? MochiTheme.success : MochiTheme.warning)
                            Text(result.confidence > 0.7 ? "High confidence" : "Low confidence — verify")
                                .font(.system(size: 13)).foregroundStyle(MochiTheme.textSecondary)
                            Spacer()
                            Text("\(Int(result.confidence * 100))%")
                                .font(.system(size: 13, weight: .medium)).foregroundStyle(MochiTheme.textSecondary)
                        }
                        .padding(16)
                    }
                    .background(MochiTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    HStack {
                        Text("Meal").font(.system(size: 15, weight: .medium))
                        Spacer()
                        Picker("Meal", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(MochiTheme.surfaceAlt)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    VStack(spacing: 10) {
                        Button { onAdd(result) } label: {
                            Text("Add to \(mealType.rawValue)")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .frame(maxWidth: .infinity).padding(.vertical, 16)
                                .background(MochiTheme.primary)
                                .foregroundStyle(MochiTheme.surfaceAlt)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Button { onRetake() } label: {
                            Text("Retake")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .background(MochiTheme.surfaceAlt)
                                .foregroundStyle(MochiTheme.textPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal).padding(.bottom, 24)
                }
            }
            .background(MochiTheme.background)
            .navigationTitle("Scan Result").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { onCancel() } }
            }
        }
    }
}

private struct MacroCell: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1fg", value)).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
            Text(label).font(.system(size: 11)).foregroundStyle(MochiTheme.textSecondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
    }
}
