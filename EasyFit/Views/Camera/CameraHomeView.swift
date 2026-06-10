import SwiftUI
import AVFoundation
import SwiftData
import Combine
import PhotosUI

// MARK: - AVFoundation session manager

final class CameraSessionManager: NSObject, ObservableObject {
    let session                        = AVCaptureSession()
    private let photoOutput            = AVCapturePhotoOutput()
    private var captureDevice:         AVCaptureDevice?

    @Published var capturedImage:      UIImage? = nil
    @Published var isReady             = false
    @Published var permissionDenied    = false
    @Published var flashMode:          AVCaptureDevice.FlashMode = .off
    var torchOn = false

    func setup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configure() : (self?.permissionDenied = true)
                }
            }
        default:
            DispatchQueue.main.async { self.permissionDenied = true }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else { session.commitConfiguration(); return }

        captureDevice = device
        session.addInput(input)
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isReady = true }
        }
    }

    func toggleTorch() {
        guard let device = captureDevice, device.hasTorch else { return }
        try? device.lockForConfiguration()
        torchOn.toggle()
        device.torchMode = torchOn ? .on : .off
        device.unlockForConfiguration()
    }

    func capture() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraSessionManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data  = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.capturedImage = image }
    }
}

// MARK: - Live preview

struct LiveCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    class VideoView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> VideoView {
        let v = VideoView()
        v.videoLayer.session      = session
        v.videoLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: VideoView, context: Context) {
        DispatchQueue.main.async { uiView.videoLayer.frame = uiView.bounds }
    }
}

// MARK: - Camera Home

struct CameraHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @StateObject private var camera    = CameraSessionManager()
    @StateObject private var vm        = NutritionViewModel()
    private let scanService            = ScanServiceFactory.make()

    @State private var isScanning        = false
    @State private var scanResult:       FoodScanResult? = nil
    @State private var showSearchPanel   = false
    @State private var showPhotoPicker   = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showManual        = false
    @State private var scanError:        String? = nil
    @State private var captureFlash      = false
    @State private var torchOn           = false

    var activeMeal: MealType {
        let h = Calendar.current.component(.hour, from: .now)
        if h < 11 { return .breakfast }
        if h < 15 { return .lunch }
        if h < 20 { return .dinner }
        return .snack
    }

    var body: some View {
        ZStack {

            // ── Camera layer ──────────────────────────────────────────────
            Group {
                if camera.permissionDenied {
                    permissionView
                } else {
                    Color.black
                    if camera.isReady {
                        LiveCameraPreview(session: camera.session)
                            .ignoresSafeArea()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
            }
            .ignoresSafeArea()

            // White capture flash
            Color.white.opacity(captureFlash ? 0.7 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .animation(.easeOut(duration: 0.2), value: captureFlash)

            // ── UI shell ──────────────────────────────────────────────────
            VStack(spacing: 0) {

                // Top bar
                HStack {
                    CircleIconButton(systemImage: "xmark") {
                        // no-op on home; could navigate elsewhere if needed
                    }
                    Spacer()
                    CircleIconButton(systemImage: "questionmark") {
                        showSearchPanel = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)

                Spacer()

                // Viewfinder brackets
                ViewfinderBrackets()
                    .frame(width: 210, height: 210)
                    .opacity(scanResult == nil ? 1 : 0)

                Spacer()

                // Bottom controls
                HStack(alignment: .center) {
                    // Flash toggle
                    Button {
                        torchOn.toggle()
                        camera.toggleTorch()
                    } label: {
                        Image(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(torchOn ? .yellow : .white)
                            .frame(width: 48, height: 48)
                    }

                    Spacer()

                    // Shutter
                    ShutterButton(isScanning: isScanning) { triggerCapture() }

                    Spacer()

                    // Album picker
                    Button { showPhotoPicker = true } label: {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 48, height: 48)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }

            // Scanning pill
            if isScanning {
                VStack {
                    Spacer()
                    HStack(spacing: 10) {
                        ProgressView().tint(.white).scaleEffect(0.85)
                        Text("Identifying food…")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 22).padding(.vertical, 13)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 180)
                }
                .allowsHitTesting(false)
            }

            // Result card
            if let result = scanResult {
                Color.black.opacity(0.45).ignoresSafeArea()
                    .onTapGesture { dismissResult() }

                VStack {
                    Spacer()
                    ScanResultCard(result: result) { didLog in
                        if didLog {
                            context.insert(FoodEntry(
                                name: result.name, calories: result.calories,
                                protein: result.protein, carbs: result.carbs, fat: result.fat,
                                servingSize: result.servingSize, mealType: activeMeal
                            ))
                        }
                        dismissResult()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        // Swipe up → search panel
        .gesture(
            DragGesture(minimumDistance: 60)
                .onEnded { v in
                    if v.translation.height < -60 && scanResult == nil && !isScanning {
                        showSearchPanel = true
                    }
                }
        )
        // Swipe-up → manual entry panel
        .sheet(isPresented: $showSearchPanel) {
            SearchLogPanel(activeMeal: activeMeal).preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showManual) {
            AddFoodView(mealType: activeMeal) { entry in context.insert(entry) }
                .preferredColorScheme(.dark)
        }
        // Album photo picker
        .photosPicker(isPresented: $showPhotoPicker,
                      selection: $selectedPhotoItem,
                      matching: .images)
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data  = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { camera.capturedImage = image }
                }
                await MainActor.run { selectedPhotoItem = nil }
            }
        }
        .alert("Scan failed", isPresented: .constant(scanError != nil)) {
            Button("OK") { scanError = nil }
        } message: { Text(scanError ?? "") }
        .onAppear { camera.setup() }
        .onChange(of: camera.capturedImage) { _, img in
            guard let img else { return }
            Task { await runScan(image: img) }
        }
    }

    // MARK: - Helpers

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.slash.fill")
                .font(.system(size: 52)).foregroundStyle(.white.opacity(0.5))
            Text("Camera access needed")
                .font(.system(size: 20, weight: .bold)).foregroundStyle(.white)
            Text("Allow camera access in Settings to scan food.")
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.black)
            .padding(.horizontal, 28).padding(.vertical, 14)
            .background(Theme.teal).clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func triggerCapture() {
        guard !isScanning, scanResult == nil else { return }
        captureFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { captureFlash = false }
        camera.capture()
    }

    private func runScan(image: UIImage) async {
        await MainActor.run { isScanning = true }
        do {
            let result = try await scanService.scan(image: image)
            await MainActor.run {
                isScanning = false
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { scanResult = result }
            }
        } catch {
            await MainActor.run { isScanning = false; scanError = error.localizedDescription }
        }
        await MainActor.run { camera.capturedImage = nil }
    }

    private func dismissResult() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { scanResult = nil }
    }
}

// MARK: - Viewfinder brackets

private struct ViewfinderBrackets: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let arm: CGFloat = 28
            let lw:  CGFloat = 2.5

            Path { p in
                // Top-left
                p.move(to: CGPoint(x: 0,     y: arm)); p.addLine(to: .init(x: 0, y: 0))
                p.addLine(to: CGPoint(x: arm, y: 0))
                // Top-right
                p.move(to: CGPoint(x: w - arm, y: 0)); p.addLine(to: .init(x: w, y: 0))
                p.addLine(to: CGPoint(x: w,    y: arm))
                // Bottom-right
                p.move(to: CGPoint(x: w,     y: h - arm)); p.addLine(to: .init(x: w, y: h))
                p.addLine(to: CGPoint(x: w - arm, y: h))
                // Bottom-left
                p.move(to: CGPoint(x: arm,   y: h)); p.addLine(to: .init(x: 0, y: h))
                p.addLine(to: CGPoint(x: 0,  y: h - arm))
            }
            .stroke(.white, style: StrokeStyle(lineWidth: lw, lineCap: .round, lineJoin: .round))
        }
    }
}

// MARK: - Circle icon button (X, ?)

private struct CircleIconButton: View {
    let systemImage: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.black.opacity(0.35))
                .clipShape(Circle())
        }
    }
}

// MARK: - Shutter button

private struct ShutterButton: View {
    let isScanning: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.85), lineWidth: 3.5)
                    .frame(width: 76, height: 76)
                if isScanning {
                    ProgressView().tint(.white).scaleEffect(1.3)
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .disabled(isScanning)
        .scaleEffect(isScanning ? 0.92 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isScanning)
    }
}

// MARK: - Scan Result Card

struct ScanResultCard: View {
    let result:   FoodScanResult
    let onAction: (Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 14)

            VStack(spacing: 20) {
                // Name + confidence
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.name.uppercased())
                            .font(.system(size: 22, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text(result.servingSize)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%% match", result.confidence * 100))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.teal)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Theme.tealDim)
                        .clipShape(Capsule())
                }

                // Nutrition grid
                HStack(spacing: 8) {
                    ResultMacroBox(label: "CAL",     value: "\(result.calories)",                  unit: "kcal", color: Theme.teal)
                    ResultMacroBox(label: "PROTEIN", value: String(format: "%.0f", result.protein), unit: "g",    color: Color(red: 0.3, green: 0.71, blue: 0.67))
                    ResultMacroBox(label: "CARBS",   value: String(format: "%.0f", result.carbs),   unit: "g",    color: Color(red: 1.0, green: 0.72, blue: 0.3))
                    ResultMacroBox(label: "FAT",     value: String(format: "%.0f", result.fat),     unit: "g",    color: Color(red: 0.9, green: 0.35, blue: 0.35))
                }

                VStack(spacing: 10) {
                    Button { onAction(true) } label: {
                        Text("LOG IT")
                            .font(.system(size: 17, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.teal)
                            .foregroundStyle(.black)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    Button { onAction(false) } label: {
                        Text("Dismiss")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 6)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Theme.cardAlt)
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct ResultMacroBox: View {
    let label: String; let value: String; let unit: String; let color: Color
    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 9, weight: .bold)).foregroundStyle(color).tracking(0.5)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(Theme.textPrimary)
            Text(unit).font(.system(size: 10)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Search / Log Panel

struct SearchLogPanel: View {
    let activeMeal: MealType
    @Environment(\.dismiss)      private var dismiss
    @Environment(\.modelContext) private var context
    @EnvironmentObject           private var mochi: MochiViewModel
    @State private var showSearch = false
    @State private var showManual = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ADD FOOD")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundStyle(Theme.textPrimary)
                        Text("Logging to \(activeMeal.rawValue.lowercased())")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 20).padding(.top, 28).padding(.bottom, 28)

                    VStack(spacing: 12) {
                        SearchPanelRow(icon: "magnifyingglass", label: "Search food database",
                                       sublabel: "Millions of foods", color: Theme.teal) { showSearch = true }
                        SearchPanelRow(icon: "square.and.pencil", label: "Enter manually",
                                       sublabel: "Quick custom entry", color: .orange) { showManual = true }
                        SearchPanelRow(icon: "book.closed.fill", label: "Create a recipe",
                                       sublabel: "Build & save your own meal",
                                       color: Color(red: 0.55, green: 0.42, blue: 0.95)) { showManual = true }
                    }
                    .padding(.horizontal, 20)
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showSearch) {
            FoodSearchView(mealType: activeMeal) { entry in
                context.insert(entry)
                mochi.mealLogged()
                dismiss()
            }
            .preferredColorScheme(.dark)
        }
        .sheet(isPresented: $showManual) {
            AddFoodView(mealType: activeMeal) { entry in
                context.insert(entry)
                mochi.mealLogged()
                dismiss()
            }
            .preferredColorScheme(.dark)
        }
    }
}

private struct SearchPanelRow: View {
    let icon: String; let label: String; let sublabel: String
    let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.15)).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 20, weight: .medium)).foregroundStyle(color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label).font(.system(size: 16, weight: .semibold)).foregroundStyle(Theme.textPrimary)
                    Text(sublabel).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
            }
            .padding(16).darkCard()
        }
    }
}

#Preview {
    CameraHomeView()
        .modelContainer(for: FoodEntry.self, inMemory: true)
        .preferredColorScheme(.dark)
}
