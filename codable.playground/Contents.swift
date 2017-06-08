
/*
 * @nixzhu (zhuhongxu@gmail.com)
 */

import Foundation

struct Place: Codable {
    let address: String
    let enabled: Bool
}

struct User: Codable {
    let id: Int
    let name: String
    let birthday: Date
    let home: Place
    struct Project: Codable {
        let name: String
    }
    let projects: [Project]
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case birthday
        case home = "old_place"
        case projects
    }
}

let json = """
{
    "id": 42,
    "name": "NIX",
    "birthday": "2017-10-04T21:00:49Z",
    "old_place": {
        "address": "CandyStar",
        "enabled": true
    },
    "projects": [
        {
            "name": "New Project"
        }
    ]
}
"""
print("\njson: \(json)")
let jsonData = json.data(using: .utf8)!

let decoder = JSONDecoder()
decoder.dateDecodingStrategy = .iso8601

let user = try decoder.decode(User.self, from: jsonData)
print("\nuser: \(user)")

let encoder = JSONEncoder()
let userData = try encoder.encode(user)
let userJSON = String(data: userData, encoding: .utf8)!

print("\nuserJSON: \(userJSON)")
