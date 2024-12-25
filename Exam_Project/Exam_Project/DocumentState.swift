// New file to manage individual document states
import PencilKit
import PDFKit

class DocumentState: ObservableObject {
    var drawing: PKDrawing
    var drawingHistory: DrawingHistory
    
    init(drawing: PKDrawing = PKDrawing()) {
        self.drawing = drawing
        self.drawingHistory = DrawingHistory()
        self.drawingHistory.pushDrawing(drawing)
    }
}

class DocumentStateManager: ObservableObject {
    @Published private var documentStates: [String: DocumentState] = [:]
    
    func getState(for documentId: String) -> DocumentState {
        if let state = documentStates[documentId] {
            return state
        }
        let newState = DocumentState()
        documentStates[documentId] = newState
        return newState
    }
    
    func updateState(for documentId: String, with drawing: PKDrawing) {
        let state = getState(for: documentId)
        state.drawing = drawing
        state.drawingHistory.pushDrawing(drawing)
    }
    
    func clearState(for documentId: String) {
        documentStates.removeValue(forKey: documentId)
    }
} 