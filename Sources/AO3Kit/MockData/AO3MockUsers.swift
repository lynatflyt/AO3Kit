import Foundation

/// Sample users for testing and SwiftUI previews
@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
extension AO3MockData {
    /// A sample user profile
    public static let sampleUser1: AO3User = {
        let user = try! AO3MockDataFactory.createMockUser(
            username: "AuthorOne",
            pseud: "AuthorOne",
            imageURL: "https://via.placeholder.com/100",
            location: "Somewhere in the world",
            joinDate: "2020-05-15",
            fandoms: ["Original Work", "Fantasy", "Science Fiction"],
            recentWorks: [1000001, 1000004, 1000005]
        )
        return user
    }()

    /// Another sample user profile
    public static let sampleUser2: AO3User = {
        let user = try! AO3MockDataFactory.createMockUser(
            username: "WriterTwo",
            pseud: "WriterTwo",
            imageURL: "https://via.placeholder.com/100",
            location: "Coffee shop",
            joinDate: "2019-08-22",
            fandoms: ["Original Work", "Romance", "Slice of Life"],
            recentWorks: [1000002, 1000006]
        )
        return user
    }()

    /// Array of sample users
    public static let sampleUsers: [AO3User] = [
        sampleUser1,
        sampleUser2
    ]
}
