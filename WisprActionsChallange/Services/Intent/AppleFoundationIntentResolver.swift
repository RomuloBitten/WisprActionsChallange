//
//  AppleFoundationIntentResolver.swift
//  WisprActionsChallange
//
//  Created by Romulo on 30/03/26.
//

import Foundation
import FoundationModels

@Generable(description: "A normalized map action parsed from a spoken request.")
private struct ResolvedMapIntentPayload {
    @Guide(description: "The requested map action.", .anyOf(["goToAddress", "goToNearest", "travelTimeToAddress", "travelTimeToNearest", "showDirectionsToAddress", "showDirectionsToNearest", "showInMapsAddress", "showInMapsNearest"]))
    var action: String

    @Guide(description: "Transportation mode requested by the user.", .anyOf(["walking", "running", "bicycle", "car", "motorbike"]))
    var locomotionType: String

    @Guide(description: "The concrete address or place name to navigate to. Use an empty string if the request is about the nearest place.")
    var addressQuery: String

    @Guide(description: "The place category for nearest-place requests, such as gas station, hospital, or cafe. Use an empty string otherwise.")
    var nearestQuery: String
}

final class AppleFoundationIntentResolver: IntentResolving {
    private let model: SystemLanguageModel
    private let session: LanguageModelSession

    init(model: SystemLanguageModel = .default) {
        self.model = model
        self.session = LanguageModelSession(
            model: model,
            instructions: """
            Convert spoken mapping requests into one normalized map action.
            Allowed actions are: go to address, go to nearest place, get travel time to address, get travel time to nearest place, show directions to address, show directions to nearest place, show in Maps for an address, show in Maps for the nearest place.
            Always choose one locomotion type from walking, running, bicycle, car, or motorbike.
            For nearest place requests, fill nearestQuery and leave addressQuery empty.
            For concrete destinations, fill addressQuery and leave nearestQuery empty.
            Do not add commentary.
            """
        )
    }

    func resolveIntent(from speechText: String) async throws -> MapIntent {
        guard model.availability == .available else {
            return try fallbackResolveIntent(from: speechText)
        }

        guard model.supportsLocale(Locale.current) else {
            return try fallbackResolveIntent(from: speechText)
        }

        do {
            let response = try await session.respond(
                to: speechText,
                generating: ResolvedMapIntentPayload.self
            )

            return try mapIntent(from: response.content)
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .unsupportedLanguageOrLocale:
                return try fallbackResolveIntent(from: speechText)
            default:
                return try fallbackResolveIntent(from: speechText)
            }
        } catch {
            return try fallbackResolveIntent(from: speechText)
        }
    }

    private func mapIntent(from payload: ResolvedMapIntentPayload) throws -> MapIntent {
        guard let locomotionType = MapLocomotionType(rawValue: payload.locomotionType) else {
            throw IntentResolverError.failedToResolve
        }

        switch payload.action {
        case "goToAddress":
            guard !payload.addressQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .goTo(destination: .address(payload.addressQuery)),
                locomotionType: locomotionType
            )
        case "goToNearest":
            guard !payload.nearestQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .goTo(destination: .nearest(payload.nearestQuery)),
                locomotionType: locomotionType
            )
        case "travelTimeToAddress":
            guard !payload.addressQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .getTravelTime(destination: .address(payload.addressQuery)),
                locomotionType: locomotionType
            )
        case "travelTimeToNearest":
            guard !payload.nearestQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .getTravelTime(destination: .nearest(payload.nearestQuery)),
                locomotionType: locomotionType
            )
        case "showDirectionsToAddress":
            guard !payload.addressQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .showDirections(destination: .address(payload.addressQuery)),
                locomotionType: locomotionType
            )
        case "showDirectionsToNearest":
            guard !payload.nearestQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .showDirections(destination: .nearest(payload.nearestQuery)),
                locomotionType: locomotionType
            )
        case "showInMapsAddress":
            guard !payload.addressQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .showInMaps(destination: .address(payload.addressQuery)),
                locomotionType: locomotionType
            )
        case "showInMapsNearest":
            guard !payload.nearestQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return MapIntent(
                action: .showInMaps(destination: .nearest(payload.nearestQuery)),
                locomotionType: locomotionType
            )
        default:
            throw IntentResolverError.failedToResolve
        }
    }

    private func fallbackResolveIntent(from speechText: String) throws -> MapIntent {
        let normalizedText = normalizedText(from: speechText)
        let locomotionType = inferredLocomotionType(from: normalizedText)
        let action = inferredAction(from: normalizedText)
        let destination = try inferredDestination(from: normalizedText)

        return MapIntent(
            action: action(destination),
            locomotionType: locomotionType
        )
    }

    private func normalizedText(from speechText: String) -> String {
        speechText
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9\\s]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func inferredLocomotionType(from text: String) -> MapLocomotionType {
        if text.contains("walk") {
            return .walking
        }
        if text.contains("run") {
            return .running
        }
        if text.contains("bike") || text.contains("bicycle") {
            return .bicycle
        }
        if text.contains("motorbike") || text.contains("motorcycle") {
            return .motorbike
        }
        return .car
    }

    private func inferredAction(
        from text: String
    ) -> (MapDestination) -> MapIntentAction {
        if text.contains("show in maps") || text.contains("open in maps") {
            return { .showInMaps(destination: $0) }
        }
        if text.contains("direction") {
            return { .showDirections(destination: $0) }
        }
        if text.contains("travel time") || text.contains("eta") || text.contains("how long") {
            return { .getTravelTime(destination: $0) }
        }
        return { .goTo(destination: $0) }
    }

    private func inferredDestination(from text: String) throws -> MapDestination {
        if let nearestRange = text.range(of: "nearest ") {
            let nearestQuery = String(text[nearestRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            guard !nearestQuery.isEmpty else { throw IntentResolverError.failedToResolve }
            return .nearest(nearestQuery)
        }

        let addressPrefixes = [
            "to ",
            "for ",
            "at "
        ]

        for prefix in addressPrefixes {
            if let range = text.range(of: prefix, options: .backwards) {
                let candidate = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty {
                    return .address(candidate)
                }
            }
        }

        throw IntentResolverError.failedToResolve
    }
}
