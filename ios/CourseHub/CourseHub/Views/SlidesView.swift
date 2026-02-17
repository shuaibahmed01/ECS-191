import SwiftUI

struct SlidesView: View {
    @State private var viewModel: SlidesViewModel
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var slideTitle = ""
    @State private var showTitlePrompt = false
    @State private var pendingFileData: Data?
    @State private var pendingImage: UIImage?
    @State private var selectedSlide: SlideEntry?
    @Environment(\.dismiss) private var dismiss

    let classCode: String

    init(classId: String, classCode: String) {
        self._viewModel = State(initialValue: SlidesViewModel(classId: classId))
        self.classCode = classCode
    }

    var body: some View {
        Group {
            if viewModel.isUploading {
                uploadingView
            } else if viewModel.slides.isEmpty && !viewModel.isLoading {
                emptyView
            } else {
                slideListView
            }
        }
        .navigationTitle("Lecture Slides")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Upload PDF", systemImage: "doc.fill")
                    }
                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera.fill")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker { data in
                showDocumentPicker = false
                pendingFileData = data
                pendingImage = nil
                slideTitle = ""
                showTitlePrompt = true
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                pendingImage = image
                pendingFileData = nil
                slideTitle = ""
                showTitlePrompt = true
            }
            .ignoresSafeArea()
        }
        .alert("Name These Slides", isPresented: $showTitlePrompt) {
            TextField("e.g. Week 3 - Sorting", text: $slideTitle)
            Button("Upload") {
                let title = slideTitle.isEmpty ? "Untitled Slides" : slideTitle
                Task {
                    if let data = pendingFileData {
                        await viewModel.uploadPDF(data: data, title: title)
                    } else if let image = pendingImage {
                        await viewModel.uploadImage(image, title: title)
                    }
                    pendingFileData = nil
                    pendingImage = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingFileData = nil
                pendingImage = nil
            }
        } message: {
            Text("Give these slides a title so they're easy to find later.")
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .task {
            await viewModel.loadSlides()
        }
    }

    private var uploadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Analyzing slides...")
                .font(.headline)
            Text("Extracting key topics and concepts")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var emptyView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "rectangle.stack.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue)

            Text("No Slides Yet")
                .font(.title2.bold())

            Text("Upload lecture slides as PDF or take a photo. We'll extract key topics and concepts for the course agent to reference.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button {
                    showDocumentPicker = true
                } label: {
                    Label("Choose PDF", systemImage: "doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    showCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var slideListView: some View {
        List {
            ForEach(viewModel.slides) { slide in
                Button {
                    selectedSlide = slide
                } label: {
                    slideRow(slide)
                }
                .tint(.primary)
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let slide = viewModel.slides[index]
                    Task { await viewModel.deleteSlide(id: slide.id) }
                }
            }
        }
        .sheet(item: $selectedSlide) { slide in
            NavigationStack {
                ScrollView {
                    Text(slide.summary)
                        .padding()
                }
                .navigationTitle(slide.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { selectedSlide = nil }
                    }
                }
            }
        }
    }

    private func slideRow(_ slide: SlideEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.stack.fill")
                    .foregroundStyle(.blue)
                Text(slide.title)
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            if !slide.summary.isEmpty {
                Text(slide.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(.vertical, 4)
    }
}
