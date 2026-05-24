import AVFoundation
import Speech
import Combine

@MainActor
class VoiceService: NSObject, ObservableObject {
    static let shared = VoiceService()

    @Published var isSpeaking = false
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var speechError: String?
    @Published var availableVoices: [VoiceOption] = []
    @Published var selectedVoiceID: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: .current)

    private override init() {
        super.init()
        synthesizer.delegate = self
        loadVoices()
        selectedVoiceID = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.selectedVoice)
            ?? preferredDefaultVoiceID
    }

    // MARK: - TTS
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        stop()
        configureAudioSession(forPlayback: true)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = selectedVoice
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.05
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0.1

        synthesizer.speak(utterance)
        isSpeaking = true
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func resume() {
        synthesizer.continueSpeaking()
    }

    // MARK: - STT
    func startListening() async {
        guard await requestSpeechPermission() else {
            speechError = "Speech recognition permission denied."
            return
        }
        guard await requestMicPermission() else {
            speechError = "Microphone permission denied."
            return
        }

        recognizedText = ""
        isListening = true
        configureAudioSession(forRecording: true)

        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest?.shouldReportPartialResults = true
        recognitionRequest?.requiresOnDeviceRecognition = false

        guard let audioEngine, let recognitionRequest else { return }

        let node = audioEngine.inputNode
        let format = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                Task { @MainActor in
                    self.recognizedText = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            stopListening()
            speechError = "Failed to start audio: \(error.localizedDescription)"
        }
    }

    func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        configureAudioSession(forPlayback: true)
    }

    // MARK: - Voices
    func loadVoices() {
        let premium = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("en") &&
            (voice.quality == .enhanced || voice.quality == .premium || voice.name.contains("Siri"))
        }
        let fallback = AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.language.hasPrefix("en-US")
        }
        let voices = (premium.isEmpty ? fallback : premium)
            .sorted { $0.quality.rawValue > $1.quality.rawValue }
            .map { VoiceOption(id: $0.identifier, name: friendlyName($0), quality: $0.quality) }

        availableVoices = voices
    }

    private var preferredDefaultVoiceID: String {
        // Prefer enhanced/premium Siri or Samantha voices
        if let siri = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.name.contains("Samantha") && $0.quality == .premium
        }) { return siri.identifier }
        if let enhanced = AVSpeechSynthesisVoice.speechVoices().first(where: {
            $0.language.hasPrefix("en") && $0.quality == .enhanced
        }) { return enhanced.identifier }
        return AVSpeechSynthesisVoice(language: "en-US")?.identifier ?? ""
    }

    private var selectedVoice: AVSpeechSynthesisVoice? {
        if !selectedVoiceID.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: selectedVoiceID) {
            return voice
        }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    func selectVoice(id: String) {
        selectedVoiceID = id
        UserDefaults.standard.set(id, forKey: Constants.UserDefaultsKeys.selectedVoice)
    }

    private func friendlyName(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium:  quality = " · Premium"
        case .enhanced: quality = " · Enhanced"
        default:        quality = ""
        }
        return "\(voice.name)\(quality)"
    }

    // MARK: - Audio Session
    private func configureAudioSession(forPlayback: Bool = false, forRecording: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        do {
            if forRecording {
                try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            } else {
                try session.setCategory(.playback, mode: .default, options: [.allowBluetooth])
            }
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch { }
    }

    // MARK: - Permissions
    private func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicPermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
            }
        }
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Only clear isSpeaking if no other utterance started immediately after
        Task { @MainActor in
            if !synthesizer.isSpeaking { self.isSpeaking = false }
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Guard against the race where speak() stops an old utterance then starts a new
        // one before the didCancel fires — without this, the callback would clear
        // isSpeaking even though the new utterance is already playing.
        Task { @MainActor in
            if !synthesizer.isSpeaking { self.isSpeaking = false }
        }
    }
}

struct VoiceOption: Identifiable, Equatable {
    let id: String
    let name: String
    let quality: AVSpeechSynthesisVoiceQuality
}
