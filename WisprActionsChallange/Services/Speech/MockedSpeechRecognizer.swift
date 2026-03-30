//
//  MockedSpeechRecognizer.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import Foundation
import CoreGraphics

final class MockedSpeechRecognizer: SpeechRecognizing {
    func requestAuthorization() async -> SpeechRecognitionConsent {
        .granted
    }

    func prepareOnDevice() throws {}

    func startRecognition() -> AsyncStream<Result<String, AppleSpeechRecognizerError>> {
        AsyncStream { continuation in
            continuation.yield(.success("Turn on the kitchen lights and start navigation home."))
            continuation.finish()
        }
    }

    func soundLevelStream(barCount: Int) -> AsyncStream<[CGFloat]> {
        AsyncStream { continuation in
            let baseHeight: CGFloat = 6
            continuation.yield(Array(repeating: baseHeight, count: barCount))
        }
    }

    func stop() {}
}
