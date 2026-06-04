import SwiftUI
import SwiftData

// MARK: - Journal Camera Picker

struct JournalCameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.cameraDevice = .front
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: JournalCameraPicker
        init(_ parent: JournalCameraPicker) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onDismiss()
        }
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.onDismiss()
        }
    }
}

// MARK: - Add Journal Entry Sheet

struct AddJournalEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var note          = ""
    @State private var selectedImage: UIImage? = nil
    @State private var showCamera    = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Photo section
                    Button {
                        showCamera = true
                    } label: {
                        if let img = selectedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(uiColor: .secondarySystemBackground))
                                    .frame(height: 300)
                                VStack(spacing: 12) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.secondary)
                                    Text("Take a progress photo")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    if selectedImage != nil {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Retake photo", systemImage: "camera")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Note section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Note (optional)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal)

                        TextEditor(text: $note)
                            .frame(height: 100)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Progress Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEntry()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedImage == nil && note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                JournalCameraPicker(
                    onImage:   { img in selectedImage = img },
                    onDismiss: { showCamera = false }
                )
                .ignoresSafeArea()
            }
        }
    }

    private func saveEntry() {
        let imageData = selectedImage?
            .jpegData(compressionQuality: 0.8)

        let entry = JournalEntry(
            date:      .now,
            note:      note.trimmingCharacters(in: .whitespaces),
            imageData: imageData
        )
        context.insert(entry)
        dismiss()
    }
}

// MARK: - Journal Detail View

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
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                }

                Text(entry.date.formatted(.dateTime.weekday(.wide).month(.wide).day().year().hour().minute()))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(.bottom)
            }
            .padding(.top)
        }
        .navigationTitle("Journal Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .alert("Delete entry?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                context.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Journal Calendar View

struct JournalCalendarView: View {
    let journalEntries: [JournalEntry]
    let onAddEntry:     () -> Void

    @State private var selectedEntry: JournalEntry? = nil

    private let calendar = Calendar.current
    private let columns  = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdaySymbols = ["S","M","T","W","T","F","S"]

    private var currentMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
    }

    private var daysInMonth: [Date?] {
        let range        = calendar.range(of: .day, in: .month, for: currentMonth)!
        let firstWeekday = calendar.component(.weekday, from: currentMonth) - 1
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            days.append(calendar.date(byAdding: .day, value: day - 1, to: currentMonth))
        }
        return days
    }

    private var monthTitle: String {
        currentMonth.formatted(.dateTime.month(.wide).year())
    }

    func entriesForDate(_ date: Date) -> [JournalEntry] {
        journalEntries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(monthTitle).font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: onAddEntry) {
                    Label("Add entry", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.primary)
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .clipShape(Capsule())
                }
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInMonth.indices, id: \.self) { i in
                    if let date = daysInMonth[i] {
                        JournalDayCell(
                            date:    date,
                            entries: entriesForDate(date),
                            isToday: calendar.isDateInToday(date)
                        )
                        .onTapGesture {
                            if let entry = entriesForDate(date).first {
                                selectedEntry = entry
                            }
                        }
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }

            // Recent entries strip
            if !journalEntries.isEmpty {
                Divider()
                Text("Recent entries")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(journalEntries.prefix(10)) { entry in
                            JournalThumbnail(entry: entry)
                                .onTapGesture { selectedEntry = entry }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .sheet(item: $selectedEntry) { entry in
            NavigationStack {
                JournalDetailView(entry: entry)
            }
        }
    }
}

// MARK: - Day cell

private struct JournalDayCell: View {
    let date:    Date
    let entries: [JournalEntry]
    let isToday: Bool

    var hasPhoto: Bool { entries.contains { $0.imageData != nil } }
    var hasEntry: Bool { !entries.isEmpty }

    var body: some View {
        ZStack {
            // Thumbnail if photo exists
            if let img = entries.first?.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.primary : Color.clear, lineWidth: 2)
                    )
                    .overlay(alignment: .bottom) {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(.bottom, 2)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isToday ? Color.primary.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isToday ? Color.primary : Color.clear, lineWidth: 1.5)
                    )
                    .frame(height: 44)
                    .overlay {
                        VStack(spacing: 2) {
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 13, weight: isToday ? .semibold : .regular))
                                .foregroundStyle(.primary)
                            if hasEntry {
                                Circle()
                                    .fill(Color.primary)
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
            }
        }
    }
}

// MARK: - Thumbnail

private struct JournalThumbnail: View {
    let entry: JournalEntry

    var body: some View {
        VStack(spacing: 4) {
            if let img = entry.image {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .tertiarySystemBackground))
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: "note.text")
                            .foregroundStyle(.secondary)
                    }
            }
            Text(entry.date, format: .dateTime.month(.abbreviated).day())
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}
