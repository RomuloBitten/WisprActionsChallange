//
//  WisprActionsChallangeApp.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import SwiftUI

@main
struct WisprActionsChallangeApp: App {
    private let builder = AppBuilder(environment: .prod)

    var body: some Scene {
        WindowGroup {
            builder.makeInitialView()
        }
    }
}
