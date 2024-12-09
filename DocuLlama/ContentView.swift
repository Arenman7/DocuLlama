import SwiftUI
import AppKit

struct ContentView: View {
    
    @EnvironmentObject var appModel: DataInterface
    @State private var localMonitor: Any?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            DisclosureGroup("Settings") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Ollama URL")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        TextField("Ollama URL", text: $appModel.baseURL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        if appModel.availableModels.isEmpty {
                            Text("Loading models...")
                                .foregroundColor(.secondary)
                        } else {
                            Text("Selected Model")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $appModel.selectedModel) {
                                ForEach(appModel.availableModels, id: \.self) { model in
                                    Text(model.name).tag(Optional(model))
                                }
                            }
                            .pickerStyle(.menu)
                            Button(action: appModel.fetchModels) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("Custom System Prompt")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $appModel.customPrompt)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.bottom, 8)
            
            Text("Input")
                .font(.caption2)
                .foregroundStyle(.secondary)
            TextEditor(text: $appModel.prompt)
                .padding()
                .font(.system(.body, design: .monospaced))
                .frame(height: 150)  
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
                .disabled(appModel.isStreaming)  
                .opacity(appModel.isStreaming ? 0.6 : 1)  
            
            Divider()
                .padding()
            
            Text("Response")
                .font(.caption2)
                .foregroundStyle(.secondary)
            
            ScrollView {
                Text(appModel.response != "" ? appModel.response : "Send a message to get started...") 
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)  
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(8)
            }
            .scrollBounceBehavior(.always)
            
            
            HStack {
                if appModel.isStreaming {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        Text("Generating...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading)
                    }
                } else {
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if appModel.isStreaming {
                        Button("Stop", role: .destructive) {
                            appModel.cancelStream()
                        }
                        .keyboardShortcut(.escape)
                    } else {
                        Button("Send") {
                            appModel.sendPrompt()
                        }
                        .keyboardShortcut(.return)
                    }
                    
                    Button("Clear") {
                        appModel.prompt = ""
                        appModel.response = ""
                    }
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(appModel.response, forType: .string)
                    }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .help("Copy response")
                    .keyboardShortcut("c", modifiers: .command)
                    
                    
                    Button(action: {
                        if let clipboardContent = NSPasteboard.general.string(forType: .string) {
                            appModel.prompt = clipboardContent
                        }
                    }) {
                        Label("Paste", systemImage: "doc.on.clipboard")
                    }
                    .help("Paste into input")
                    .keyboardShortcut("v", modifiers: .command)
                }
            }
            .frame(height: 24)  
            .padding(.top, 4)
        }
        .frame(width: 400, height: 600)
        .padding()
        .onAppear {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                if event.keyCode == 36 { 
                    if !appModel.isStreaming && NSApp.keyWindow?.firstResponder is NSTextView {
                        if event.modifierFlags.contains(.shift) {
                            return event
                        }
                        appModel.sendPrompt()
                        return nil
                    }
                }
                return event
            }
        }
        .onDisappear {
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
