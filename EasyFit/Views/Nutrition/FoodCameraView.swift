import SwiftUI
import UIKit

struct FoodCameraView: View {
    @Environment(\.dismiss) private var dismiss
    let onResult: (FoodScanResult) -> Void

    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var scanResult: FoodScanResult?
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var mealType: MealType = .lunch

    // Replace with your actual API key or load from config
    private let service: any FoodScanServiceProtocol = ScanServiceFactory.make()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Image preview / placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .frame(height: 260)

                    if let img = selectedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Take a photo of your food")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if isScanning {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.4))
                            .frame(height: 260)
                        ProgressView("Analyzing…")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal)

                // Scan result
                if let result = scanResult {
                    ScanResultCard(result: result, mealType: $mealType)
                        .padding(.horizontal)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button {
                        showImagePicker = true
                    } label: {
                        Label(selectedImage == nil ? "Open Camera" : "Retake", systemImage: "camera.fill")
                            .font(.system(size: 15, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.primary)
                            .foregroundStyle(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if scanResult != nil {
                        Button {
                            if let result = scanResult {
                                onResult(result)
                                dismiss()
                            }
                        } label: {
                            Text("Add to log")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green.opacity(0.15))
                                .foregroundStyle(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Scan Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onChange(of: selectedImage) { _, image in
                guard let image else { return }
                Task { await scanImage(image) }
            }
        }
    }

    private func scanImage(_ image: UIImage) async {
        isScanning   = true
        errorMessage = nil
        scanResult   = nil
        do {
            scanResult = try await service.scan(image: image)
        } catch {
            errorMessage = error.localizedDescription
        }
        isScanning = false
    }
}

private struct ScanResultCard: View {
    let result: FoodScanResult
    @Binding var mealType: MealType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name).font(.system(size: 16, weight: .semibold))
                    Text(result.servingSize).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(result.calories) kcal")
                    .font(.system(size: 20, weight: .bold))
            }

            HStack(spacing: 0) {
                MacroChip(label: "P", value: result.protein, color: Color(red: 0.3, green: 0.71, blue: 0.67))
                MacroChip(label: "C", value: result.carbs,   color: Color(red: 1.0,  green: 0.72, blue: 0.3))
                MacroChip(label: "F", value: result.fat,     color: Color(red: 0.9,  green: 0.35, blue: 0.35))
            }

            Picker("Meal", selection: $mealType) {
                ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct MacroChip: View {
    let label: String
    let value: Double
    let color: Color
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(color)
            Text(String(format: "%.0fg", value)).font(.system(size: 12))
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .padding(.trailing, 6)
    }
}

// MARK: - UIKit image picker wrapper

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.image = info[.originalImage] as? UIImage
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
