import Foundation

struct Response: Codable {
    let model: String
    let response: String
}

struct ModelList: Codable {
    let models: [ModelInfo]
}

struct ModelInfo: Codable, Hashable {
    let name: String
    let model: String
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
    
    static func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        return lhs.name == rhs.name
    }
}

class DataInterface: ObservableObject {
    @Published var prompt: String = ""
    @Published var response: String = ""
    @Published var isStreaming: Bool = false
    @Published var baseURL: String = "http://127.0.0.1:11434"
    @Published var availableModels: [ModelInfo] = []
    @Published var selectedModel: ModelInfo?
    @Published var customPrompt: String = """
    Your task is to add **DocC documentation comments** to the provided Swift code.  
    
    ### **Rules**  
    1. **Never modify the original code.** Do not add, remove, or change any part of the Swift code itself.  
    2. **Use this DocC format exactly:**  
    /// [Brief summary (3-4 words)] 
    /// 
    /// - Parameters: 
    /// - [parameter name]: [description] 
    /// - Returns: [description of the return value]
    
    3. **Do not include `swift` or any syntax highlighting indicators.** Only add the DocC documentation as plain comments.  
    4. Ensure that the **summary is short (3-4 words)** and concise.  
    5. Each parameter must have a clear, descriptive explanation.  
    
    ---
    
    ### **Example Input and Output**
    #### Input:
    func add(_ a: Int, _ b: Int) -> Int { 
        return a + b 
    }
    
    #### Output:
    /// Adds two integers 
    /// 
    /// - Parameters: 
    /// - a: First number to add 
    /// - b: Second number to add 
    /// - Returns: Sum of the two numbers
    func add(_ a: Int, _ b: Int) -> Int { 
        return a + b 
    }
    
    
    ---
    ### DO NOT INCLUDE `swift` or ```swift```
    ### **Now, Document This Swift Code**  
    {swift_code}
    """
    
    private var urlSession: URLSession?
    
    private var dataTask: URLSessionDataTask?
    
    init() {
        setupURLSession()
        fetchModels()
    }
    
    private func setupURLSession() {
        let config = URLSessionConfiguration.default
        let delegate = StreamDelegate(dataInterface: self)
        urlSession = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }
    
    func fetchModels() {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error { return }
            guard let data = data else { return }
            
            do {
                let modelList = try JSONDecoder().decode(ModelList.self, from: data)
                DispatchQueue.main.async {
                    self.availableModels = modelList.models
                    self.selectedModel = modelList.models.first
                }
            } catch { }
        }.resume()
    }
    
    func cancelStream() {
        dataTask?.cancel()
        dataTask = nil
        DispatchQueue.main.async {
            self.isStreaming = false
        }
    }
    
    func sendPrompt() {
        guard !prompt.isEmpty else { return }
        guard !isStreaming else { return }
        guard let selectedModel = selectedModel else { return }
        
        DispatchQueue.main.async {
            self.response = ""
            self.isStreaming = true
        }
        
        let urlString = "\(baseURL)/api/generate"
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": selectedModel.name,
            "prompt": customPrompt + prompt,
            "stream": true
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            DispatchQueue.main.async {
                self.isStreaming = false
                self.response = "Error: Failed to prepare request"
            }
            return
        }
        
        dataTask = urlSession?.dataTask(with: request)
        dataTask?.resume()
    }
}

class StreamDelegate: NSObject, URLSessionDataDelegate {
    private let dataInterface: DataInterface
    private let decoder = JSONDecoder()
    private var buffer = Data()
    
    init(dataInterface: DataInterface) {
        self.dataInterface = dataInterface
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        buffer.append(data)
        
        while let newlineIndex = buffer.firstIndex(of: 10) {
            let lineData = buffer[..<newlineIndex]
            buffer.removeSubrange(...newlineIndex)
            
            do {
                if let jsonLine = try? decoder.decode(Response.self, from: lineData) {
                    DispatchQueue.main.async {
                        self.dataInterface.response += jsonLine.response
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async {
            self.dataInterface.isStreaming = false
        }
        
        if let error = error {
            DispatchQueue.main.async {
                self.dataInterface.response += "\nError: \(error.localizedDescription)"
            }
        }
    }
}
