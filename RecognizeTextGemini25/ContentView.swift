//
//  ContentView.swift
//  RecognizeTextGemini25
//
//  Created by Tatiana Kornilova on 11.05.2025.
//

import SwiftUI
import PencilKit
import Vision // Don't forget to import Vision

// 1. SwiftUI View to host everything
struct ContentView: View {
    @State private var drawing = PKDrawing()
    @State private var recognizedText: String = "Draw something and text will appear here."
    // This will hold the tool picker instance
    @State private var toolPicker = PKToolPicker()

    var body: some View {
        NavigationView {
            VStack {
                Text("Recognized Text:")
                    .font(.headline)
                TextEditor(text: .constant(recognizedText)) // Use TextEditor for scrollable multi-line text
                    .frame(height: 100)
                    .border(Color.gray)
                    .padding()
               
                Button("Clear Drawing") {
                    drawing = PKDrawing() // Reset the drawing
                    recognizedText = "Drawing cleared."
                }
                .padding()
                Text("Canvas:")
                    .font(.headline)
                DrawingView(drawing: $drawing, recognizedText: $recognizedText, toolPicker: $toolPicker)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .border(Color.blue)
                    .padding()
            }
         //   .navigationTitle("Handwriting OCR")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}


// 2. UIViewRepresentable for PKCanvasView
struct DrawingView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var recognizedText: String
    @Binding var toolPicker: PKToolPicker // Pass the tool picker

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()
        canvasView.drawing = drawing
        canvasView.delegate = context.coordinator
        canvasView.drawingPolicy = .anyInput // Or .pencilOnly for Apple Pencil only
        canvasView.backgroundColor = .clear // Or any other color
        canvasView.isOpaque = false

        // Show the tool picker
        toolPicker.addObserver(canvasView) // Observe tool changes
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder() // Important to make the canvas active for the tool picker

        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Update the drawing if it's changed from outside (e.g., by the "Clear Drawing" button)
        if uiView.drawing != drawing {
             uiView.drawing = drawing
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self, recognizedText: $recognizedText)
    }

    // 3. Coordinator to handle PKCanvasViewDelegate methods
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingView
        @Binding var recognizedText: String
        private var recognitionTask: DispatchWorkItem? // To debounce recognition

        init(_ parent: DrawingView, recognizedText: Binding<String>) {
            self.parent = parent
            self._recognizedText = recognizedText
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Update the parent's drawing binding
            parent.drawing = canvasView.drawing

            // Debounce recognition: Cancel previous task and schedule a new one
            recognitionTask?.cancel()

            let task = DispatchWorkItem { [weak self] in
                self?.recognizeText(in: canvasView.drawing)
            }
            self.recognitionTask = task
            // Perform recognition after a short delay to avoid excessive processing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
        }

        private func recognizeText(in currentDrawing: PKDrawing) {
            // Ensure there's something to recognize
            guard !currentDrawing.bounds.isEmpty else {
                DispatchQueue.main.async {
                    self.recognizedText = "Canvas is empty."
                }
                return
            }
            //-------------------
            // 1. Get the current drawing from the canvas or state
            // Or currentDrawing
            // 2. Define the target "not so black" color
            let slightlyLighterBlack = UIColor(white: 0.15, alpha: 1.0) // A very dark gray

            // 3. Modify the drawing
            let modifiedDrawing = modifyBlackStrokes(in: currentDrawing,
                                                     to: slightlyLighterBlack,
                                                     blacknessTolerance: 0.1)
            //-------------PRINT-----
            let originalBlackStrokes = currentDrawing.strokes.filter { $0.ink.color.isEssentiallyBlack(tolerance: 0.1) }.count
            let newBlackStrokes = modifiedDrawing.strokes.filter { $0.ink.color.isEssentiallyBlack(tolerance: 0.1) }.count
            let newColorStrokes = modifiedDrawing.strokes.filter {
                $0.ink.color.isVisuallyEqual(to: slightlyLighterBlack)}.count
            
            print("Original drawing had \(originalBlackStrokes) black strokes.")
            print("Modified drawing has \(newBlackStrokes) black strokes (should be 0 if all were changed).")
            print("Modified drawing has \(newColorStrokes) strokes with the new color.")
            //------------

            // 1. Get an image from the PKDrawing
            // Use a slightly larger bounds for the image to ensure all strokes are captured,
            // especially if they go near the edges of the tight `drawing.bounds`.
            let imageRect = currentDrawing.bounds.insetBy(dx: -20, dy: -20) // Add some padding
       //     let image = currentDrawing.image(from: imageRect, scale: UIScreen.main.scale)
            let image = modifiedDrawing.image(from: imageRect, scale: UIScreen.main.scale)

            // 2. Create a Vision text recognition request
            let request = VNRecognizeTextRequest { (request, error) in
                if let error = error {
                    print("Error recognizing text: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.recognizedText = "Error: \(error.localizedDescription)"
                    }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    DispatchQueue.main.async {
                        self.recognizedText = "No text recognized."
                    }
                    return
                }

                let recognizedStrings = observations.compactMap { observation in
                    // Return the string with the highest confidence.
                    observation.topCandidates(1).first?.string
                }
                
                DispatchQueue.main.async {
                    self.recognizedText = recognizedStrings.joined(separator: "\n")
                    if self.recognizedText.isEmpty {
                         self.recognizedText = "No text confidently recognized."
                    }
                }
            }

            // Optional: Configure the request
            request.recognitionLevel = .accurate//.fast // .accurate or .fast
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"] // Specify languages if needed

            // Very important - set this to true for handwriting
            if #available(iOS 16.0, *) {
                request.automaticallyDetectsLanguage = false
                request.revision = VNRecognizeTextRequestRevision3
            }

            // 3. Create a request handler and perform the request
           guard let cgImage = image.cgImage else {
                print("Failed to get CGImage from drawing.")
                DispatchQueue.main.async {
                    self.recognizedText = "Error processing drawing."
                }
                return
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    print("Failed to perform recognition: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.recognizedText = "Recognition failed."
                    }
                }
            }
        }
        
        //------------------
        func modifyBlackStrokes(in drawing: PKDrawing,
                                to newColor: UIColor,
                                blacknessTolerance: CGFloat = 0.05) -> PKDrawing {
            var modifiedStrokes: [PKStroke] = []

            for originalStroke in drawing.strokes {
                // Check if the original stroke's ink color is essentially black
                if originalStroke.ink.color.isEssentiallyBlack(tolerance: blacknessTolerance) {
                    // Create a new ink with the new color, keeping other ink properties
                    let newInk = PKInk(originalStroke.ink.inkType, color: newColor)
                    
                    // Create a new stroke with the new ink but the same path and transform
                    let newStroke = PKStroke(ink: newInk, path: originalStroke.path, transform: originalStroke.transform, mask: originalStroke.mask)
                    modifiedStrokes.append(newStroke)
                } else {
                    // If the stroke is not black, keep it as is
                    modifiedStrokes.append(originalStroke)
                }
            }
            return PKDrawing(strokes: modifiedStrokes)
        }
        //------------------
    }
}


    extension UIColor {
        // Check if this color is essentially black
        func isEssentiallyBlack(tolerance: CGFloat = 0.05) -> Bool {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0

            // Convert to sRGB to get consistent components for black
            guard let srgbColor = self.convertToSRGB() else {
                // Fallback or handle error if conversion fails
                // For black, if conversion fails, it's unlikely to be black anyway
                return false
            }
            
            srgbColor.getRed(&r, green: &g, blue: &b, alpha: &a)

            return r <= tolerance && g <= tolerance && b <= tolerance /*&& a >= (1.0 - tolerance)*/
        }

        // Convert UIColor to sRGB color space
        func convertToSRGB() -> UIColor? {
            // If already sRGB, no need to convert (though converting again is safe)
            // Note: Comparing CGColor.colorSpace is more robust than string matching name
            if self.cgColor.colorSpace?.name == CGColorSpace.sRGB {
                return self
            }

            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            
            // GetRed can convert simple color spaces (like gray) to a compatible RGB
            // For more complex conversions, one might need Core Graphics context drawing.
            // However, for PencilKit colors (usually sRGB or Gray), this should often suffice.
            if self.getRed(&r, green: &g, blue: &b, alpha: &a) {
                return UIColor(red: r, green: g, blue: b, alpha: a) // This will be in sRGB by default
            } else {
                // More robust conversion using a graphics context (handles more color spaces)
                let newColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
                let cgColor = self.cgColor
                guard let convertedCGColor = cgColor.converted(to: newColorSpace, intent: .defaultIntent, options: nil) else {
                    print("Warning: Could not convert color \(self) to sRGB.")
                    return nil // Or return self if conversion fails, depending on desired behavior
                }
                return UIColor(cgColor: convertedCGColor)
            }
        }

        // Check if this color is visually equal to another color, considering color spaces
        func isVisuallyEqual(to otherColor: UIColor, tolerance: CGFloat = 0.001) -> Bool {
            guard let srgbSelf = self.convertToSRGB(),
                  let srgbOther = otherColor.convertToSRGB() else {
                // If conversion fails for either, consider them not equal for safety
                // or handle as a direct isEqual if one conversion failed but not the other.
                // Simplest is to return false if any conversion fails.
                if self.isEqual(otherColor) { return true } // Fallback for simple cases
                return false
            }

            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

            srgbSelf.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
            srgbOther.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

            return abs(r1 - r2) <= tolerance &&
                   abs(g1 - g2) <= tolerance &&
                   abs(b1 - b2) <= tolerance &&
                   abs(a1 - a2) <= tolerance
        }
    }
#Preview {
    ContentView()
}
