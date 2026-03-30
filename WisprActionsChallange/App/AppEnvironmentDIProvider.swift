//
//  AppEnvironmentDIProvider.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

struct AppEnvironmentDIProvider {
    let speechRecognizing: SpeechRecognizing
    let intentResolver: IntentResolving
}

extension AppEnvironmentDIProvider {
    static let prod = AppEnvironmentDIProvider(
        speechRecognizing: AppleSpeechRecognizer(),
        intentResolver: AppleFoundationIntentResolver()
    )

    static let mocked = AppEnvironmentDIProvider(
        speechRecognizing: MockedSpeechRecognizer(),
        intentResolver: MockedIntentResolver()
    )
}
