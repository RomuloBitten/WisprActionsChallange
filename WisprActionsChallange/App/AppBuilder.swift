//
//  AppBuilder.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import SwiftUI

struct AppBuilder {
    private let environment: AppEnvironmentDIProvider

    init(environment: AppEnvironmentDIProvider) {
        self.environment = environment
    }

    @ViewBuilder
    func makeInitialView() -> some View {
        SpeechRecognitionView(
            viewModel: SpeechRecognitionViewModel(
                speechRecognizer: environment.speechRecognizing,
                intentResolver: environment.intentResolver
            )
        )
    }
}
