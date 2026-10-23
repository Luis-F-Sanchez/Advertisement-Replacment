import SwiftUI
import Roboflow

struct ContentView: View {
    @State private var myModel: RFModel?
    @State private var isModelLoaded = false

    var body: some View {
        ZStack {
            // If the model is loaded, show the live camera feed
            if isModelLoaded {
                CameraView(model: myModel)
                    .edgesIgnoringSafeArea(.all)
            } else {
                // Show a loading screen while the model downloads/initializes
                VStack {
                    ProgressView()
                        .scaleEffect(2.0)
                    Text("Loading Ad Tracking Model...")
                        .padding(.top, 20)
                }
            }
        }
        .onAppear {
            loadModel()
        }
    }
    
    func loadModel() {
        let rf = RoboflowMobile(apiKey: "XWPumbdd6MNd57sJirAw")
        
        rf.load(model: "advertisement-xm7zx-76map", modelVersion: 2) { model, error, modelName, modelType in
            if let error = error {
                print("Error loading model: \(error.localizedDescription)")
                return
            }
            
            model?.configure(threshold: 0.5, overlap: 0.5, maxObjects: 20)
            self.myModel = model
            
            // Tell the UI the model is ready, which will trigger the CameraView to appear
            DispatchQueue.main.async {
                self.isModelLoaded = true
            }
            print("Model loaded successfully!")
        }
    }
}
