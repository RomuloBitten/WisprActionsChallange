//
//  SpeechRecognitionViewModel.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import Foundation
import Observation
import CoreGraphics

enum SpeechRecognitionScreenError: Equatable {
    case microphoneConsentDenied
    case audioProcessingConsentDenied
    case bothConsentsDenied
    case onDeviceRecognitionUnavailable

    var message: String {
        switch self {
        case .microphoneConsentDenied:
            return "Microphone consent was denied. Please update it in Settings."
        case .audioProcessingConsentDenied:
            return "Speech recognition consent was denied. Please update it in Settings."
        case .bothConsentsDenied:
            return "Microphone and speech recognition consents were denied. Please update them in Settings."
        case .onDeviceRecognitionUnavailable:
            return "Speech recognition is not available for this location."
        }
    }

    var settingsButtonTitle: String? {
        switch self {
        case .microphoneConsentDenied, .audioProcessingConsentDenied, .bothConsentsDenied:
            return "Open Settings"
        case .onDeviceRecognitionUnavailable:
            return nil
        }
    }
}

protocol SpeechRecognitionViewModeling: Observable, AnyObject {
    var recognizedText: String { get }
    var resolvedIntentDebugText: String? { get }
    var intentErrorMessage: String? { get }
    var screenError: SpeechRecognitionScreenError? { get }
    var isRecognizing: Bool { get }
    var isMicrophoneButtonEnabled: Bool { get }
    var soundHeights: [CGFloat] { get }
    func viewDidAppear()
    func didTapMicrophoneButton()
}

@Observable
final class SpeechRecognitionViewModel: SpeechRecognitionViewModeling {
    private enum Constants {
        static let soundBarCount = 22
        static let baseSoundHeight: CGFloat = 6
    }

    private let speechRecognizer: SpeechRecognizing
    private let intentResolver: IntentResolving

    private(set) var recognizedText = ""
    private(set) var resolvedIntent: MapIntent?
    private(set) var intentErrorMessage: String?
    private(set) var screenError: SpeechRecognitionScreenError?
    private(set) var soundHeights: [CGFloat]
    private var authorizationTask: Task<Void, Never>?
    private var recognitionTask: Task<Void, Never>?
    private var soundLevelsTask: Task<Void, Never>?
    private(set) var isRecognizing = false

    var resolvedIntentDebugText: String? {
        resolvedIntent?.description
    }

    var isMicrophoneButtonEnabled: Bool {
        screenError == nil
    }

    init(
        speechRecognizer: SpeechRecognizing,
        intentResolver: IntentResolving
    ) {
        self.speechRecognizer = speechRecognizer
        self.intentResolver = intentResolver
        self.soundHeights = Array(repeating: Constants.baseSoundHeight, count: Constants.soundBarCount)
    }

    func viewDidAppear() {
        resetScreenState()

        authorizationTask?.cancel()
        authorizationTask = Task { [weak self] in
            guard let self else { return }

            let consent = await speechRecognizer.requestAuthorization()
            guard !Task.isCancelled else { return }

            guard consent == .granted else {
                screenError = screenError(from: consent)
                return
            }

            do {
                try speechRecognizer.prepareOnDevice()
            } catch AppleSpeechRecognizerError.onDeviceRecognitionUnavailable {
                screenError = .onDeviceRecognitionUnavailable
            } catch {
                screenError = .onDeviceRecognitionUnavailable
            }
        }
    }

    func didTapMicrophoneButton() {
        guard screenError == nil else { return }

        if isRecognizing {
            stopRecognition()
            return
        }

        soundLevelsTask?.cancel()
        recognitionTask?.cancel()
        isRecognizing = true
        resolvedIntent = nil
        intentErrorMessage = nil

        soundLevelsTask = Task { [weak self] in
            guard let self else { return }

            for await soundHeights in speechRecognizer.soundLevelStream(barCount: Constants.soundBarCount) {
                guard !Task.isCancelled else { return }
                self.soundHeights = soundHeights
            }
        }

        recognitionTask = Task { [weak self] in
            guard let self else { return }

            defer {
                Task { @MainActor [weak self] in
                    self?.recognitionTask = nil
                    self?.soundLevelsTask?.cancel()
                    self?.soundLevelsTask = nil
                    self?.isRecognizing = false
                    self?.soundHeights = Array(
                        repeating: Constants.baseSoundHeight,
                        count: Constants.soundBarCount
                    )
                }
            }

            for await result in speechRecognizer.startRecognition() {
                guard !Task.isCancelled else { return }

                switch result {
                case .success(let text):
                    recognizedText = text
                case .failure:
                    screenError = .onDeviceRecognitionUnavailable
                    intentErrorMessage = nil
                    return
                }
            }

            guard !recognizedText.isEmpty else {
                intentErrorMessage = "I could not understand your instructions, please try again"
                return
            }

            do {
                resolvedIntent = try await intentResolver.resolveIntent(from: recognizedText)
                intentErrorMessage = nil
            } catch {
                resolvedIntent = nil
                intentErrorMessage = "I could not understand your instructions, please try again"
            }
        }
    }

    deinit {
        authorizationTask?.cancel()
        soundLevelsTask?.cancel()
        recognitionTask?.cancel()
    }

    private func stopRecognition() {
        soundLevelsTask?.cancel()
        soundLevelsTask = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecognizing = false
        soundHeights = Array(repeating: Constants.baseSoundHeight, count: Constants.soundBarCount)
        speechRecognizer.stop()
    }

    private func resetScreenState() {
        authorizationTask?.cancel()
        stopRecognition()
        recognizedText = ""
        resolvedIntent = nil
        intentErrorMessage = nil
        screenError = nil
    }

    private func screenError(from consent: SpeechRecognitionConsent) -> SpeechRecognitionScreenError? {
        switch consent {
        case .granted:
            return nil
        case .denied(let consentType):
            switch consentType {
            case .microphone:
                return .microphoneConsentDenied
            case .audioProcessing:
                return .audioProcessingConsentDenied
            case .both:
                return .bothConsentsDenied
            }
        }
    }
}
