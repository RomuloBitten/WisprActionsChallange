//
//  IntentResolving.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import Foundation

enum MapLocomotionType: String, CaseIterable, Codable, Equatable {
    case walking
    case running
    case bicycle
    case car
    case motorbike
}

enum MapDestination: Equatable, Codable {
    case address(String)
    case nearest(String)
}

enum MapIntentAction: Equatable, Codable {
    case goTo(destination: MapDestination)
    case getTravelTime(destination: MapDestination)
    case showDirections(destination: MapDestination)
    case showInMaps(destination: MapDestination)
}

struct MapIntent: Equatable, Codable {
    let action: MapIntentAction
    let locomotionType: MapLocomotionType
}

extension MapIntent: CustomStringConvertible {
    var description: String {
        """
        Action: \(action.debugName)
        MapDestination: \(destination.debugName)
        MapDestination.value: \(destination.value)
        LocomotionType: \(locomotionType.rawValue)
        """
    }
}

extension MapDestination: CustomStringConvertible {
    var description: String {
        switch self {
        case .address(let address):
            return address
        case .nearest(let place):
            return "nearest \(place)"
        }
    }
}

private extension MapIntent {
    var destination: MapDestination {
        switch action {
        case .goTo(let destination),
                .getTravelTime(let destination),
                .showDirections(let destination),
                .showInMaps(let destination):
            return destination
        }
    }
}

private extension MapIntentAction {
    var debugName: String {
        switch self {
        case .goTo:
            return "goTo"
        case .getTravelTime:
            return "getTravelTime"
        case .showDirections:
            return "showDirections"
        case .showInMaps:
            return "showInMaps"
        }
    }
}

private extension MapDestination {
    var debugName: String {
        switch self {
        case .address:
            return "address"
        case .nearest:
            return "nearest"
        }
    }

    var value: String {
        switch self {
        case .address(let address):
            return address
        case .nearest(let place):
            return place
        }
    }
}

enum IntentResolverError: Error, Equatable {
    case modelUnavailable
    case unsupportedLanguage
    case failedToResolve
}

protocol IntentResolving {
    func resolveIntent(from speechText: String) async throws -> MapIntent
}
