import SwiftUI
import UIKit

struct FoodCameraView: UIViewControllerRepresentable {
    let onResult: (FoodScanResult) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: FoodCameraView
        private let service: any FoodScanServiceProtocol = ScanServiceFactory.make()

        init(_ parent: FoodCameraView) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onDismiss()
                return
            }

            // Show scanning overlay on top of picker
            let overlay = ScanningOverlayViewController()
            picker.present(overlay, animated: false)

            Task {
                do {
                    let result = try await service.scan(image: image)
                    await MainActor.run {
                        overlay.dismiss(animated: false) {
                            // Show result sheet on top of picker
                            let resultVC = UIHostingController(
                                rootView: ScanResultView(
                                    image:  image,
                                    result: result,
                                    onAdd: { entry in
                                        picker.dismiss(animated: true)
                                        self.parent.onResult(result)
                                        self.parent.onDismiss()
                                    },
                                    onRetake: {
                                        overlay.dismiss(animated: true)
                                    },
                                    onCancel: {
                                        picker.dismiss(animated: true)
                                        self.parent.onDismiss()
                                    }
                                )
                            )
                            resultVC.modalPresentationStyle = .pageSheet
                            picker.present(resultVC, animated: true)
                        }
                    }
                } catch {
                    await MainActor.run {
                        overlay.dismiss(animated: false) {
                            let alert = UIAlertController(
                                title: "Scan Failed",
                                message: error.localizedDescription,
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "Retake", style: .default))
                            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                                picker.dismiss(animated: true)
                                self.parent.onDismiss()
                            })
                            picker.present(alert, animated: true)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Scanning overlay (shown while AI processes)

class ScanningOverlayViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()

        let label = UILabel()
        label.text = "Analyzing your food…"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)

        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(label)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
}

// MARK: - Result view shown after scan

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
                    // Photo preview
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Result card
                    VStack(spacing: 0) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(result.name)
                                    .font(.system(size: 18, weight: .bold))
                                Text(result.servingSize)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(result.calories)")
                                    .font(.system(size: 26, weight: .bold))
                                Text("kcal")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(16)

                        Divider().padding(.horizontal)

                        HStack(spacing: 0) {
                            MacroCell(label: "Protein", value: result.protein, color: Color(red: 0.3, green: 0.71, blue: 0.67))
                            Divider().frame(height: 40)
                            MacroCell(label: "Carbs",   value: result.carbs,   color: Color(red: 1.0, green: 0.72, blue: 0.3))
                            Divider().frame(height: 40)
                            MacroCell(label: "Fat",     value: result.fat,     color: Color(red: 0.9, green: 0.35, blue: 0.35))
                        }
                        .padding(.vertical, 8)

                        Divider().padding(.horizontal)

                        // Confidence indicator
                        HStack {
                            Image(systemName: result.confidence > 0.7 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(result.confidence > 0.7 ? .green : .orange)
                                .font(.system(size: 14))
                            Text(result.confidence > 0.7 ? "High confidence" : "Low confidence — please verify")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(Int(result.confidence * 100))%")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                    }
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Meal picker
                    HStack {
                        Text("Meal").font(.system(size: 15, weight: .medium))
                        Spacer()
                        Picker("Meal", selection: $mealType) {
                            ForEach(MealType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 4)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Buttons
                    VStack(spacing: 10) {
                        Button { onAdd(result) } label: {
                            Text("Add to \(mealType.rawValue)")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.primary)
                                .foregroundStyle(Color(uiColor: .systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        Button { onRetake() } label: {
                            Text("Retake")
                                .font(.system(size: 15, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Scan Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel() }
                }
            }
        }
    }
}

private struct MacroCell: View {
    let label: String; let value: Double; let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Text(String(format: "%.1fg", value))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
