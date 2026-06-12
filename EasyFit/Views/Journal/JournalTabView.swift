import SwiftUI
import SwiftData

// MARK: - Main Journal Tab

struct JournalTabView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var showCamera     = false
    @State private var selectedEntry: JournalEntry? = nil
    @State private var selectedMonth  = Date.now

    private let cal     = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["S","M","T","W","T","F","S"]

    private var monthEntries: [JournalEntry] {
        entries.filter { cal.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
    }

    private var daysInMonth: [Date?] {
        let start        = cal.date(from: cal.dateComponents([.year, .month], from: selectedMonth))!
        let range        = cal.range(of: .day, in: .month, for: start)!
        let firstWeekday = cal.component(.weekday, from: start) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            days.append(cal.date(byAdding: .day, value: day - 1, to: start))
        }
        return days
    }

    func entriesForDate(_ date: Date) -> [JournalEntry] {
        entries.filter { cal.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Month navigator
                    HStack {
                        Button {
                            selectedMonth = cal.date(byAdding: .month, value: -1, to: selectedMonth)!
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(MochiTheme.surface)
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text(selectedMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.system(size: 17, weight: .semibold))
                        Spacer()
                        Button {
                            selectedMonth = cal.date(byAdding: .month, value: 1, to: selectedMonth)!
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 36, height: 36)
                                .background(MochiTheme.surface)
                                .clipShape(Circle())
                        }
                        .disabled(cal.isDate(selectedMonth, equalTo: .now, toGranularity: .month))
                        .opacity(cal.isDate(selectedMonth, equalTo: .now, toGranularity: .month) ? 0.3 : 1)
                    }
                    .padding(.horizontal)

                    // Calendar grid
                    VStack(spacing: 10) {
                        HStack(spacing: 0) {
                            ForEach(weekdaySymbols.indices, id: \.self) { i in
                                Text(weekdaySymbols[i])
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(MochiTheme.textSecondary)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(daysInMonth.indices, id: \.self) { i in
                                if let date = daysInMonth[i] {
                                    JournalDayCell(
                                        date:    date,
                                        entries: entriesForDate(date),
                                        isToday: cal.isDateInToday(date)
                                    )
                                    .onTapGesture {
                                        if let entry = entriesForDate(date).first {
                                            selectedEntry = entry
                                        }
                                    }
                                } else {
                                    Color.clear.frame(height: 50)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(MochiTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)

                    // Entry count
                    if !monthEntries.isEmpty {
                        HStack {
                            Text("\(monthEntries.count) entr\(monthEntries.count == 1 ? "y" : "ies") this month")
                                .font(.system(size: 13))
                                .foregroundStyle(MochiTheme.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }

                    // Photo grid
                    if !entries.isEmpty {
                        LazyVGrid(
                            columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                            spacing: 3
                        ) {
                            ForEach(entries) { entry in
                                JournalGridCell(entry: entry)
                                    .onTapGesture { selectedEntry = entry }
                            }
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(MochiTheme.textSecondary)
                            Text("No journal entries yet")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Tap the camera button to take a post-workout photo and track your visual progress.")
                                .font(.system(size: 14))
                                .foregroundStyle(MochiTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.vertical, 60)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCamera = true } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                JournalCameraView(
                    onSave: { image, note in
                        let entry = JournalEntry(
                            date:      .now,
                            note:      note,
                            imageData: image.jpegData(compressionQuality: 0.8)
                        )
                        context.insert(entry)
                    },
                    onDismiss: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            .sheet(item: $selectedEntry) { entry in
                NavigationStack { JournalDetailView(entry: entry) }
            }
        }
    }
}

// MARK: - Day Cell

struct JournalDayCell: View {
    let date:    Date
    let entries: [JournalEntry]
    let isToday: Bool

    var body: some View {
        let day = Calendar.current.component(.day, from: date)
        ZStack {
            if let img = entries.first?.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? MochiTheme.primary : Color.clear, lineWidth: 2)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Text("\(day)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 1)
                            .padding(3)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? MochiTheme.primary.opacity(0.08) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? MochiTheme.primary : Color.clear, lineWidth: 1.5)
                    )
                    .frame(height: 50)
                    .overlay {
                        VStack(spacing: 3) {
                            Text("\(day)")
                                .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                                .foregroundStyle(MochiTheme.textPrimary)
                            if !entries.isEmpty {
                                Circle().fill(MochiTheme.primary).frame(width: 4, height: 4)
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Grid Cell

struct JournalGridCell: View {
    let entry: JournalEntry

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottomLeading) {
                if let img = entry.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.width)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(MochiTheme.surface)
                        .overlay {
                            Image(systemName: "note.text")
                                .foregroundStyle(MochiTheme.textSecondary)
                                .font(.system(size: 24))
                        }
                }
                Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .padding(5)
            }
            .clipShape(Rectangle())
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Camera View

struct JournalCameraView: View {
    let onSave:    (UIImage, String) -> Void
    let onDismiss: () -> Void

    @State private var capturedImage: UIImage? = nil
    @State private var note          = ""
    @State private var showPicker    = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let img = capturedImage {
                VStack(spacing: 0) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.height * 0.58)
                        .clipped()
                        .ignoresSafeArea(edges: .top)

                    VStack(spacing: 16) {
                        TextField("Add a note… (optional)", text: $note, axis: .vertical)
                            .lineLimit(3)
                            .padding(12)
                            .background(MochiTheme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            Button {
                                capturedImage = nil
                                showPicker    = true
                            } label: {
                                Text("Retake")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(MochiTheme.surface)
                                    .foregroundStyle(MochiTheme.textPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            Button {
                                onSave(img, note)
                                onDismiss()
                            } label: {
                                Text("Save Entry")
                                    .font(.system(size: 15, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(MochiTheme.primary)
                                    .foregroundStyle(MochiTheme.surfaceAlt)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 20)
                    .background(MochiTheme.background)
                }
            } else {
                Color.black.ignoresSafeArea()
                    .onAppear { showPicker = true }
                VStack {
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 56)
                    Spacer()
                }
            }
        }
        .fullScreenCover(isPresented: $showPicker) {
            JournalCameraPicker(
                onImage:   { img in capturedImage = img },
                onDismiss: { showPicker = false; if capturedImage == nil { onDismiss() } }
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Camera Picker

struct JournalCameraPicker: UIViewControllerRepresentable {
    let onImage:   (UIImage) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker          = UIImagePickerController()
        picker.sourceType   = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.cameraDevice = .front
        picker.delegate     = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: JournalCameraPicker
        init(_ parent: JournalCameraPicker) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.onDismiss() }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.onDismiss()
        }
    }
}

// MARK: - Detail View

struct JournalDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let entry: JournalEntry
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let img = entry.image {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                }
                if !entry.note.isEmpty {
                    Text(entry.note)
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(MochiTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }
                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year().hour().minute()))
                    .font(.system(size: 13))
                    .foregroundStyle(MochiTheme.textSecondary)
            }
            .padding(.vertical)
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showDeleteAlert = true } label: {
                    Image(systemName: "trash").foregroundStyle(MochiTheme.danger)
                }
            }
        }
        .alert("Delete entry?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { context.delete(entry); dismiss() }
            Button("Cancel", role: .cancel) {}
        }
    }
}
