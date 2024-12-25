import Foundation
import PDFKit
import PencilKit

class DocumentManager: ObservableObject {
    @Published var savedDocuments: [SavedDocument] = []
    private let fileManager = FileManager.default
    
    struct SavedDocument: Identifiable, Codable {
        let id: UUID
        let fileName: String
        let dateCreated: Date
        let fileURL: URL
        let drawingURL: URL
        var lastModified: Date?
    }
    
    init() {
        loadSavedDocuments()
    }
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func loadSavedDocuments() {
        do {
            let files = try fileManager.contentsOfDirectory(at: documentsDirectory, 
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey])
            
            savedDocuments = files.filter { $0.pathExtension == "pdf" }.map { url in
                let drawingURL = url.deletingPathExtension().appendingPathExtension("drawing")
                return SavedDocument(
                    id: UUID(),
                    fileName: url.lastPathComponent,
                    dateCreated: (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date(),
                    fileURL: url,
                    drawingURL: drawingURL,
                    lastModified: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                )
            }
        } catch {
            print("Error loading documents: \(error)")
        }
    }
    
    func loadDrawing(from url: URL) -> PKDrawing? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let drawingData = try Data(contentsOf: url)
            return try PKDrawing(data: drawingData)
        } catch {
            print("Error loading drawing: \(error)")
            return nil
        }
    }
    
    func saveDocument(pdfData: Data, fileName: String, drawing: PKDrawing) throws -> (pdfURL: URL, drawingURL: URL) {
        let pdfURL = documentsDirectory.appendingPathComponent(fileName)
        let drawingURL = pdfURL.deletingPathExtension().appendingPathExtension("drawing")
        
        // Save PDF
        try pdfData.write(to: pdfURL)
        
        // Save drawing
        let drawingData = drawing.dataRepresentation()
        try drawingData.write(to: drawingURL)
        
        loadSavedDocuments()
        return (pdfURL, drawingURL)
    }
    
    func deleteDocument(at url: URL) {
        // Delete both PDF and its associated drawing
        try? fileManager.removeItem(at: url)
        let drawingURL = url.deletingPathExtension().appendingPathExtension("drawing")
        try? fileManager.removeItem(at: drawingURL)
        loadSavedDocuments()
    }
} 