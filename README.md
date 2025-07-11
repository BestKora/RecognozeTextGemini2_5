## SwiftUI iOS Apps “Recognize text, drawing with Apple Pencil” in Tandem with AI Gemini 2.5 Pro Experimental
 <img src="https://github.com/BestKora/RecognozeTextGemini2_5/blob/f2ca301028415accdee0bc9d7ce2a0321a288309/RecognizeTextGemini2_5.gif" width="350">

 I teamed up with Google's brilliant AI, Gemini 2.5 Pro Experimental, to create this app.
Apple Pencil has transformed the iPad into a powerful tool for note-taking and creative expression. But what about turning handwritten scribbles into usable digital text? For SwiftUI developers, Apple’s Vision framework offers a robust on-device solution for optical character recognition (OCR) that integrates seamlessly with PencilKit to bring handwriting recognition to life.

So PencilKit is for handwriting input, Vision is for recognition, and SwiftUI is for the UI.

The magic happens thanks to the collaboration of two of Apple’s core frameworks:

* PencilKit (PKCanvasView): This framework provides a drawing board. It allows users to write and sketch naturally with Apple Pencil or their finger, capturing that data as PKDrawing data — a vector representation of Strokes.
* Vision (VNRecognizeTextRequest): Once the handwriting is captured, Vision takes over. VNRecognizeTextRequest is specifically designed for image analysis and text content identification, including complex handwritten text.

 
### Ask Gemini 2.5 Pro Experimental (part 1)

<img src="https://github.com/BestKora/SearchableMapGemini2_5/blob/a93cd4590f488d9a35a3d54927f822fa3e0045b6/Stage1.png" width="750">

### Ask Gemini 2.5 Pro Experimental (part 2)

<img src="https://github.com/BestKora/SearchableMapGemini2_5/blob/8db96860e93df8536f389adbd27a043f7433258c/Stage2.png" width="750">

The task has been solved: we have a flawlessly working iOS application “Map with Search”.
