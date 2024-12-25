//
//  ContentView.swift
//  Exam_Project
//
//  Created by Sree J Akkina on 11/1/24.
//

import SwiftUI
import PDFKit
import PencilKit

// Add this function at the file level, outside any struct
func getDocumentId(for document: PDFDocument) -> String {
    return document.documentURL?.absoluteString ?? UUID().uuidString
}

struct ContentView: View {
    @StateObject private var documentManager = DocumentManager()
    @StateObject private var documentStateManager = DocumentStateManager()
    @State private var selectedPDF: PDFDocument?
    @State private var canvasView = PKCanvasView(frame: .zero)
    @State private var isShowingFilePicker = false
    @State private var toolPicker = PKToolPicker()
    @State private var drawingIsEnabled = true
    @State private var currentDocumentId: String?
    
    var body: some View {
        NavigationView {
            DocumentLibraryView(
                documents: documentManager.savedDocuments,
                selectedPDF: $selectedPDF,
                documentStateManager: documentStateManager,
                documentManager: documentManager
            )
            
            if let pdfDocument = selectedPDF {
                let documentId = getDocumentId(for: pdfDocument)
                let documentState = documentStateManager.getState(for: documentId)
                
                ZStack {
                    PDFKitView(document: pdfDocument)
                    PencilKitView(
                        canvasView: $canvasView,
                        toolPicker: $toolPicker,
                        drawingIsEnabled: $drawingIsEnabled,
                        documentState: documentState,
                        documentId: documentId,
                        documentStateManager: documentStateManager
                    )
                }
                .toolbar {
                    // Add Leading toolbar group for back button
                    ToolbarItemGroup(placement: .navigationBarLeading) {
                        Button(action: {
                            // Save current document before going back
                            saveDocument(documentId: documentId)
                            // Clear the selected PDF to return to home
                            selectedPDF = nil
                            // Reset canvas
                            canvasView = PKCanvasView(frame: .zero)
                        }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                        
                        // Add delete button to toolbar
                        Button(role: .destructive) {
                            if let url = pdfDocument.documentURL {
                                documentManager.deleteDocument(at: url)
                                selectedPDF = nil
                                canvasView = PKCanvasView(frame: .zero)
                            }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Existing trailing toolbar items
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        // Drawing toggle
                        Toggle(isOn: $drawingIsEnabled) {
                            Image(systemName: drawingIsEnabled ? "pencil.circle.fill" : "pencil.circle")
                        }
                        
                        // Updated Undo button
                        Button(action: {
                            if let previousDrawing = documentState.drawingHistory.undo() {
                                canvasView.drawing = previousDrawing
                                documentState.drawing = previousDrawing
                            }
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                        }
                        .disabled(!documentState.drawingHistory.canUndo())
                        
                        // Updated Redo button
                        Button(action: {
                            if let nextDrawing = documentState.drawingHistory.redo() {
                                canvasView.drawing = nextDrawing
                                documentState.drawing = nextDrawing
                            }
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                        }
                        .disabled(!documentState.drawingHistory.canRedo())
                        
                        // Save button
                        Button(action: { saveDocument(documentId: documentId) }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                }
                .onDisappear {
                    saveDocument(documentId: documentId)
                }
            } else {
                WelcomeView(isShowingFilePicker: $isShowingFilePicker, selectedPDF: $selectedPDF)
            }
        }
        .sheet(isPresented: $isShowingFilePicker) {
            DocumentPicker(pdfDocument: $selectedPDF)
        }
    }
    
    private func saveDocument(documentId: String) {
        guard let pdfDocument = selectedPDF else { return }
        let documentState = documentStateManager.getState(for: documentId)
        
        if let pdfData = pdfDocument.dataRepresentation() {
            let fileName = pdfDocument.documentURL?.lastPathComponent ?? "Untitled.pdf"
            
            do {
                let (savedPDFURL, savedDrawingURL) = try documentManager.saveDocument(
                    pdfData: pdfData,
                    fileName: fileName,
                    drawing: documentState.drawing
                )
                print("Document saved at: \(savedPDFURL)")
                print("Drawing saved at: \(savedDrawingURL)")
            } catch {
                print("Error saving document: \(error)")
            }
        }
    }
}

// Document Library View
struct DocumentLibraryView: View {
    let documents: [DocumentManager.SavedDocument]
    @Binding var selectedPDF: PDFDocument?
    @ObservedObject var documentStateManager: DocumentStateManager
    @ObservedObject var documentManager: DocumentManager
    
    var body: some View {
        List {
            ForEach(documents) { document in
                HStack {
                    DocumentRow(document: document)
                        .onTapGesture {
                            loadDocument(document)
                        }
                    
                    Spacer()
                    
                    Button(action: {
                        documentManager.deleteDocument(at: document.fileURL)
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(SidebarListStyle())
        .frame(minWidth: 250)
    }
    
    private func loadDocument(_ document: DocumentManager.SavedDocument) {
        // Load PDF first
        guard let pdfDoc = PDFDocument(url: document.fileURL) else { return }
        
        // Load drawing if it exists
        if let drawing = documentManager.loadDrawing(from: document.drawingURL) {
            // Update state manager first
            let docId = getDocumentId(for: pdfDoc)
            DispatchQueue.main.async {
                documentStateManager.updateState(for: docId, with: drawing)
                selectedPDF = pdfDoc // Update selected PDF last
            }
        } else {
            // If no drawing exists, just update the PDF
            DispatchQueue.main.async {
                selectedPDF = pdfDoc
            }
        }
    }
}

// Document Row View
struct DocumentRow: View {
    let document: DocumentManager.SavedDocument
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(document.fileName)
                .font(.headline)
            Text("Modified: \(document.lastModified?.formatted() ?? "Never")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// Welcome View
struct WelcomeView: View {
    @Binding var isShowingFilePicker: Bool
    @Binding var selectedPDF: PDFDocument?
    @State private var showingMenu = false
    
    var body: some View {
        VStack {
            Text("Exam Project")
                .font(.largeTitle)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        isShowingFilePicker = true
                    }) {
                        Label("Select PDF", systemImage: "doc.badge.plus")
                    }
                    
                    Button(action: createBlankDocument) {
                        Label("New Blank Document", systemImage: "square.and.pencil")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title2)
                }
            }
        }
    }
    
    private func createBlankDocument() {
        let blankPDF = PDFDocument()
        
        // Create a blank page with standard US Letter size
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let blankPage = PDFPage()  // Create empty page first
        blankPage.setBounds(pageRect, for: .mediaBox)  // Then set its bounds
        
        // Add the blank page to the document
        blankPDF.insert(blankPage, at: 0)
        
        // Create a temporary URL for the blank document
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Untitled-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        
        // Save the blank PDF to get a valid URL
        do {
            try blankPDF.dataRepresentation()?.write(to: tempURL)
            
            // Load it back with the URL
            if let newDoc = PDFDocument(url: tempURL) {
                selectedPDF = newDoc
            }
        } catch {
            print("Error creating blank document: \(error)")
        }
    }
}

// Enhanced PencilKit View with latest practices
struct PencilKitView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var toolPicker: PKToolPicker
    @Binding var drawingIsEnabled: Bool
    let documentState: DocumentState
    let documentId: String
    let documentStateManager: DocumentStateManager
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitView
        private var lastUpdateTime: TimeInterval = 0
        private let updateThreshold: TimeInterval = 0.1 // 100ms threshold
        
        init(_ parent: PencilKitView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let currentTime = CACurrentMediaTime()
            if currentTime - lastUpdateTime >= updateThreshold {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.parent.documentState.drawing = canvasView.drawing
                    self.parent.documentStateManager.updateState(
                        for: self.parent.documentId,
                        with: canvasView.drawing
                    )
                    self.lastUpdateTime = currentTime
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .pencilOnly
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        
        // Set initial drawing
        DispatchQueue.main.async {
            canvas.drawing = documentState.drawing
            
            // Configure tool picker
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
        }
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Only update if necessary and not during active drawing
        if !uiView.isFirstResponder && uiView.drawing != documentState.drawing {
            DispatchQueue.main.async {
                uiView.drawing = documentState.drawing
            }
        }
        
        uiView.isUserInteractionEnabled = drawingIsEnabled
    }
}

// Update PDFKitView with better page management and scrolling
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    
    class Coordinator: NSObject {
        var parent: PDFKitView
        var pdfView: PDFView?
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        @objc func handlePageChange(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            
            // Check if we're on the last page
            if currentPage == document.page(at: document.pageCount - 1) {
                DispatchQueue.main.async {
                    // Create and add new blank page
                    let newPage = PDFPage()
                    document.insert(newPage, at: document.pageCount)
                    print("Added new page at index: \(document.pageCount - 1)")
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        context.coordinator.pdfView = pdfView
        
        // Configure PDF view
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = 0.25
        pdfView.isUserInteractionEnabled = true
        
        // Enable better scrolling
        pdfView.usePageViewController(true, withViewOptions: [
            UIPageViewController.OptionsKey.interPageSpacing: 20
        ])
        
        // Configure gesture recognizers
        pdfView.displayMode = .singlePage
        pdfView.displaysPageBreaks = true
        
        // Add page change observer
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.handlePageChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document !== document {
            uiView.document = document
        }
    }
}

// Document Picker for selecting PDFs
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var pdfDocument: PDFDocument?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        // Allow access to all document types
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                // Create a copy of the file in the app's document directory
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileName = url.lastPathComponent
                let destinationURL = documentsDirectory.appendingPathComponent(fileName)
                
                // Remove any existing file
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Copy the file
                try FileManager.default.copyItem(at: url, to: destinationURL)
                
                // Create PDFDocument from the copied file
                if let document = PDFDocument(url: destinationURL) {
                    DispatchQueue.main.async {
                        self.parent.pdfDocument = document
                    }
                } else {
                    print("Error: Could not create PDF document from file")
                }
            } catch {
                print("Error handling document: \(error.localizedDescription)")
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("Document picker was cancelled")
        }
    }
}

#Preview {
    ContentView()
}
