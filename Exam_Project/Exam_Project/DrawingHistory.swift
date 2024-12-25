// New file to manage drawing history
import PencilKit

class DrawingHistory: ObservableObject {
    private var undoStack: [PKDrawing] = []
    private var redoStack: [PKDrawing] = []
    private let maxHistorySize = 20 // Limit stack size to prevent memory issues
    
    func pushDrawing(_ drawing: PKDrawing) {
        undoStack.append(drawing)
        // Clear redo stack when new drawing is added
        redoStack.removeAll()
        
        // Maintain stack size limit
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
    }
    
    func undo() -> PKDrawing? {
        guard let lastDrawing = undoStack.popLast() else { return nil }
        redoStack.append(lastDrawing)
        return undoStack.last
    }
    
    func redo() -> PKDrawing? {
        guard let nextDrawing = redoStack.popLast() else { return nil }
        undoStack.append(nextDrawing)
        return nextDrawing
    }
    
    func canUndo() -> Bool {
        return undoStack.count > 1 // Need at least 2 states to undo
    }
    
    func canRedo() -> Bool {
        return !redoStack.isEmpty
    }
    
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
} 