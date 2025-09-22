import Foundation

struct UserNameGenerator {
    private static let firstNames = [
        "Alex", "Jordan", "Taylor", "Casey", "Morgan", "Jamie", "Quinn", "Avery",
        "Riley", "Cameron", "Peyton", "Hayden", "Reese", "Emerson", "Rowan",
        "Sage", "Parker", "Dakota", "Charlie", "River", "Skyler", "Phoenix",
        "Finley", "Logan", "Bailey", "Kennedy", "Blake", "Sydney", "Jesse",
        "Drew", "Kai", "Eden", "Reagan", "Ari", "Lane", "Elliot", "Jules"
    ]

    private static let lastNames = [
        "Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller",
        "Davis", "Rodriguez", "Martinez", "Hernandez", "Lopez", "Gonzalez",
        "Wilson", "Anderson", "Thomas", "Taylor", "Moore", "Jackson", "Martin",
        "Lee", "Perez", "Thompson", "White", "Harris", "Sanchez", "Clark",
        "Ramirez", "Lewis", "Robinson", "Walker", "Young", "Allen", "King",
        "Wright", "Scott", "Torres", "Nguyen", "Hill", "Flores", "Green",
        "Adams", "Nelson", "Baker", "Hall", "Rivera", "Campbell", "Mitchell",
        "Carter", "Roberts", "Gomez", "Phillips", "Evans", "Turner", "Diaz",
        "Parker", "Cruz", "Edwards", "Collins", "Reyes", "Stewart", "Morris",
        "Morales", "Murphy", "Cook", "Rogers", "Gutierrez", "Ortiz", "Morgan",
        "Cooper", "Peterson", "Bailey", "Reed", "Kelly", "Howard", "Ramos",
        "Kim", "Cox", "Ward", "Richardson", "Watson", "Brooks", "Chavez",
        "Wood", "James", "Bennet", "Gray", "Mendoza", "Ruiz", "Hughes",
        "Price", "Alvarez", "Castillo", "Sanders", "Patel", "Myers", "Long",
        "Ross", "Foster", "Jimenez"
    ]

    static func generateDisplayName() -> String {
        let firstName = firstNames.randomElement() ?? "User"
        let lastName = lastNames.randomElement() ?? "Name"
        return "\(firstName) \(lastName)"
    }

    static func generateDisplayName(for phoneNumber: String) -> String {
        // Use phone number to generate consistent names
        let hash = abs(phoneNumber.hashValue)
        let firstNameIndex = hash % firstNames.count
        let lastNameIndex = (hash / firstNames.count) % lastNames.count

        let firstName = firstNames[firstNameIndex]
        let lastName = lastNames[lastNameIndex]
        return "\(firstName) \(lastName)"
    }
}
