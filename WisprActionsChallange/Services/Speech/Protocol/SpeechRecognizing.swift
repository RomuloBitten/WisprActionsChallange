//
//  SpeechRecognizing.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import CoreGraphics

protocol SpeechRecognizing {
    func requestAuthorization() async -> SpeechRecognitionConsent
    func prepareOnDevice() throws
    func startRecognition() -> AsyncStream<Result<String, AppleSpeechRecognizerError>>
    func soundLevelStream(barCount: Int) -> AsyncStream<[CGFloat]>
    func stop()
}
