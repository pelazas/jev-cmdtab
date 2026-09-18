import Foundation

enum JevClient {
    struct Result {
        let shouldSwitch: Double
        let destination: String
        let confidence: Double
    }

    static func ask(
        apiKey: String,
        clipboard: String,
        frontmostName: String,
        frontmostID: String,
        apps: [(id: String, name: String)]
    ) async -> Result? {
        var criteria: [String: String] = [:]
        for app in apps {
            if criteria[app.id] == nil {
                criteria[app.id] = app.name
            }
        }
        guard criteria.count >= 2 else { return nil }
        let body: [String: Any] = [
            "model": "jev-latest",
            "state": [
                "frontmost": frontmostName,
                "frontmost_id": frontmostID,
                "clipboard": clipboard,
            ],
            "questions": [
                "should_switch": [
                    "type": "noul",
                    "instructions": "Does the clipboard give a reason to switch to a different app than the frontmost one?",
                    "criteria": [
                        "true": "The clipboard names, addresses, or belongs to another app in the list",
                        "false": "The clipboard is unrelated or the user is already in the right app",
                    ],
                ],
                "destination": [
                    "type": "choice",
                    "instructions": "Which app should the user switch to next given the clipboard and the current app?",
                    "criteria": criteria,
                ],
            ],
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        var request = URLRequest(url: URL(string: "https://api.typesafe.ai/v1/systemone")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 8
        request.httpBody = payload
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> Result? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = obj["answers"] as? [String: Any],
              let switchQ = answers["should_switch"] as? [String: Any],
              let destQ = answers["destination"] as? [String: Any],
              let destination = destQ["choice"] as? String
        else { return nil }
        return Result(
            shouldSwitch: number(switchQ["noul"]) ?? 0,
            destination: destination,
            confidence: number(destQ["confidence"]) ?? 0
        )
    }

    static func runSelfCheck() {
        let json = """
        {"model":"jev-latest","answers":{"should_switch":{"type":"noul","noul":0.91},"destination":{"type":"choice","choice":"com.apple.mail","confidence":0.82,"probabilities":{"com.apple.mail":0.82,"com.apple.Safari":0.18}}}}
        """
        guard let result = parse(Data(json.utf8)),
              result.destination == "com.apple.mail",
              result.shouldSwitch > 0.9,
              result.confidence > 0.8
        else {
            fputs("jev parse self-check failed\n", stderr)
            exit(1)
        }
        print("ok")
    }

    private static func number(_ raw: Any?) -> Double? {
        (raw as? NSNumber)?.doubleValue
    }
}
