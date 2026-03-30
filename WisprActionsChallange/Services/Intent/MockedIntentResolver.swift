//
//  MockedIntentResolver.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

final class MockedIntentResolver: IntentResolving {
    func resolveIntent(from speechText: String) async throws -> MapIntent {
        MapIntent(
            action: .goTo(destination: .nearest("coffee shop")),
            locomotionType: .walking
        )
    }
}
