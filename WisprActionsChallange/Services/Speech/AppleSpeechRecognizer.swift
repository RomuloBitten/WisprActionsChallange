import Speech
import AVFoundation
import CoreGraphics

//
//  AppleSpeechRecognizer.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

enum AppleSpeechRecognizerError: Error, Equatable {
    case onDeviceRecognitionUnavailable
}
enum SpeechRecognitionConsent: Equatable {
    case granted
    case denied(consentType: SpeechConsentType)
}
enum SpeechConsentType: Equatable {
    case microphone
    case audioProcessing
    case both
}


final class AppleSpeechRecognizer: SpeechRecognizing {
    private final class RecognitionSessionState: @unchecked Sendable {
        var silenceTask: Task<Void, Never>?
        var didFinish = false
    }

    private let inactivityTimeoutNanoseconds: UInt64 = 1_500_000_000
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var soundLevelContinuation: AsyncStream<[CGFloat]>.Continuation?
    private var currentBarCount = 0
    private var wavePhase: CGFloat = 0
    private var isPrepared = false
    
    func requestAuthorization() async -> SpeechRecognitionConsent {
        let micGranted = await requestMicrophoneAuthorization()
        let speechGranted = await requestSpeechRecognitionAuthorization()

        switch (micGranted, speechGranted) {
        case (true, true):
            return .granted
        case (false, true):
            return .denied(consentType: .microphone)
        case (true, false):
            return .denied(consentType: .audioProcessing)
        case (false, false):
            return .denied(consentType: .both)
        }
    }

    /// Requests microphone recording permission and returns whether it was granted.
    private func requestMicrophoneAuthorization() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            return await AVAudioApplication.requestRecordPermission()
        case .denied:
            return false
        case .granted:
            return true
        @unknown default:
            return false
        }
    }

    /// Requests speech recognition authorization and returns whether it was granted.
    private func requestSpeechRecognitionAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                switch status {
                case .authorized:
                    continuation.resume(returning: true)
                case .denied, .restricted, .notDetermined:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Prepares on-device recognition by configuring the audio session, recognition request, and input tap.
    /// Call this during screen loading so recognition can start immediately when requested.
    /// Throws `.onDeviceRecognitionUnavailable` if on-device recognition isn't available or setup fails.
    func prepareOnDevice() throws {
        guard !isPrepared else { return }

        // Ensure recognizer is available and supports on-device recognition
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else { throw AppleSpeechRecognizerError.onDeviceRecognitionUnavailable }
        if !speechRecognizer.supportsOnDeviceRecognition { throw AppleSpeechRecognizerError.onDeviceRecognitionUnavailable }

        // Configure audio session (do not start engine yet)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers, .allowBluetoothHFP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw AppleSpeechRecognizerError.onDeviceRecognitionUnavailable
        }

        // Prepare recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        recognitionRequest = request

        // Install tap on input node (but do not start engine yet)
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            self?.yieldSoundLevel(from: buffer)
        }

        audioEngine.prepare()
        isPrepared = true
    }

    func soundLevelStream(barCount: Int) -> AsyncStream<[CGFloat]> {
        currentBarCount = barCount

        return AsyncStream { [weak self] continuation in
            guard let self else {
                continuation.finish()
                return
            }

            soundLevelContinuation?.finish()
            soundLevelContinuation = continuation
            continuation.yield(Array(repeating: 6, count: barCount))
        }
    }

    /// Starts recognition and returns an AsyncStream of results (success with text or failure with error).
    /// Ensure `prepareOnDevice()` has succeeded before calling this.
    func startRecognition() -> AsyncStream<Result<String, AppleSpeechRecognizerError>> {
        // Attempt to prepare on device, yield failure if error occurs
        do {
            try prepareOnDevice()
        } catch AppleSpeechRecognizerError.onDeviceRecognitionUnavailable {
            return AsyncStream { continuation in
                continuation.yield(.failure(.onDeviceRecognitionUnavailable))
                continuation.finish()
            }
        } catch {
            return AsyncStream { continuation in
                continuation.yield(.failure(.onDeviceRecognitionUnavailable))
                continuation.finish()
            }
        }

        // Start audio engine if not running
        if !audioEngine.isRunning {
            do { try audioEngine.start() } catch {
                return AsyncStream { continuation in
                    continuation.yield(.failure(.onDeviceRecognitionUnavailable))
                    continuation.finish()
                }
            }
        }

        return AsyncStream<Result<String, AppleSpeechRecognizerError>> { continuation in
            let sessionState = RecognitionSessionState()
            let inactivityTimeoutNanoseconds = self.inactivityTimeoutNanoseconds

            let finishRecognition: () -> Void = { [weak self] in
                guard !sessionState.didFinish else { return }
                sessionState.didFinish = true
                sessionState.silenceTask?.cancel()
                sessionState.silenceTask = nil
                self?.stop()
                continuation.finish()
            }

            let scheduleSilenceTimeout: () -> Void = {
                sessionState.silenceTask?.cancel()
                sessionState.silenceTask = nil
                sessionState.silenceTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: inactivityTimeoutNanoseconds)
                    } catch {
                        return
                    }

                    guard !Task.isCancelled else { return }
                    finishRecognition()
                }
            }

            // Start recognition task
            if let request = recognitionRequest, let recognizer = speechRecognizer {
                recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                    if let text = result?.bestTranscription.formattedString {
                        scheduleSilenceTimeout()
                        continuation.yield(.success(text))
                    }
                    if let result = result, result.isFinal {
                        finishRecognition()
                    }
                    if let error = error as NSError? {
                        // SFSpeechRecognizerErrorDomain and unsupportedLocale error code = 203
                        if error.domain == "SFSpeechRecognizerErrorDomain" && error.code == 203 {
                            continuation.yield(.failure(.onDeviceRecognitionUnavailable))
                        }
                        finishRecognition()
                    }
                }
            } else {
                finishRecognition()
            }
        }
    }

    /// Stops the recognition session and tears down audio.
    func stop() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        soundLevelContinuation?.yield(Array(repeating: 6, count: currentBarCount))
        soundLevelContinuation?.finish()
        soundLevelContinuation = nil
        currentBarCount = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        isPrepared = false
    }

    private func yieldSoundLevel(from buffer: AVAudioPCMBuffer) {
        guard currentBarCount > 0 else { return }
        guard let channelData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        guard frameCount > 0 else { return }

        let samples = UnsafeBufferPointer(start: channelData, count: frameCount)
        let meanSquare = samples.reduce(Float.zero) { partialResult, sample in
            partialResult + (sample * sample)
        } / Float(frameCount)
        let normalizedLevel = min(max(CGFloat(sqrt(meanSquare)) * 14, 0), 1)

        soundLevelContinuation?.yield(
            makeBarHeights(normalizedLevel: normalizedLevel, barCount: currentBarCount)
        )
    }

    private func makeBarHeights(normalizedLevel: CGFloat, barCount: Int) -> [CGFloat] {
        let minHeight: CGFloat = 6
        let maxHeight: CGFloat = 32
        wavePhase += 0.35

        return (0..<barCount).map { index in
            let progress = CGFloat(index) / CGFloat(max(barCount - 1, 1))
            let sine = (sin((progress * .pi * 3) + wavePhase) + 1) / 2
            let mixedLevel = (normalizedLevel * 0.75) + (sine * normalizedLevel * 0.25)
            return minHeight + ((maxHeight - minHeight) * mixedLevel)
        }
    }
}
