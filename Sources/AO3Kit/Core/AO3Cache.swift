import Foundation

// MARK: - Cache Protocol

/// Protocol for implementing custom AO3 caches
public protocol AO3CacheProtocol: Sendable {
    /// Retrieve a work from cache
    func getWork(_ id: Int) async -> AO3Work?

    /// Store a work in cache
    func setWork(_ work: AO3Work) async

    /// Retrieve a chapter from cache
    func getChapter(workID: Int, chapterID: Int) async -> AO3Chapter?

    /// Store a chapter in cache
    func setChapter(_ chapter: AO3Chapter) async

    /// Retrieve a user from cache
    func getUser(username: String, pseud: String) async -> AO3User?

    /// Store a user in cache
    func setUser(_ user: AO3User) async

    /// Clear all cached data
    func clear() async
}

// MARK: - In-Memory Cache

/// A thread-safe in-memory cache with size limits
public actor AO3MemoryCache: AO3CacheProtocol {
    private var works: [Int: CacheEntry<AO3Work>] = [:]
    private var chapters: [String: CacheEntry<AO3Chapter>] = [:]
    private var users: [String: CacheEntry<AO3User>] = [:]

    private let maxWorks: Int
    private let maxChapters: Int
    private let maxUsers: Int
    private let ttl: TimeInterval  // Time to live in seconds

    private struct CacheEntry<T> {
        let value: T
        let timestamp: Date

        func isExpired(ttl: TimeInterval) -> Bool {
            return Date().timeIntervalSince(timestamp) > ttl
        }
    }

    /// Initialize a memory cache
    /// - Parameters:
    ///   - maxWorks: Maximum number of works to cache (default: 100)
    ///   - maxChapters: Maximum number of chapters to cache (default: 500)
    ///   - maxUsers: Maximum number of users to cache (default: 100)
    ///   - ttl: Time to live in seconds (default: 3600 = 1 hour)
    public init(maxWorks: Int = 100, maxChapters: Int = 500, maxUsers: Int = 100, ttl: TimeInterval = 3600) {
        self.maxWorks = maxWorks
        self.maxChapters = maxChapters
        self.maxUsers = maxUsers
        self.ttl = ttl
    }

    public func getWork(_ id: Int) async -> AO3Work? {
        guard let entry = works[id], !entry.isExpired(ttl: ttl) else {
            works.removeValue(forKey: id)
            return nil
        }
        return entry.value
    }

    public func setWork(_ work: AO3Work) async {
        // Evict oldest if at capacity
        if works.count >= maxWorks, works[work.id] == nil {
            if let oldestKey = works.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                works.removeValue(forKey: oldestKey)
            }
        }
        works[work.id] = CacheEntry(value: work, timestamp: Date())
    }

    public func getChapter(workID: Int, chapterID: Int) async -> AO3Chapter? {
        let key = "\(workID):\(chapterID)"
        guard let entry = chapters[key], !entry.isExpired(ttl: ttl) else {
            chapters.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    public func setChapter(_ chapter: AO3Chapter) async {
        let key = "\(chapter.workID):\(chapter.id)"

        // Evict oldest if at capacity
        if chapters.count >= maxChapters, chapters[key] == nil {
            if let oldestKey = chapters.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                chapters.removeValue(forKey: oldestKey)
            }
        }
        chapters[key] = CacheEntry(value: chapter, timestamp: Date())
    }

    public func getUser(username: String, pseud: String) async -> AO3User? {
        let key = "\(username):\(pseud)"
        guard let entry = users[key], !entry.isExpired(ttl: ttl) else {
            users.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    public func setUser(_ user: AO3User) async {
        let key = "\(user.username):\(user.pseud)"

        // Evict oldest if at capacity
        if users.count >= maxUsers, users[key] == nil {
            if let oldestKey = users.min(by: { $0.value.timestamp < $1.value.timestamp })?.key {
                users.removeValue(forKey: oldestKey)
            }
        }
        users[key] = CacheEntry(value: user, timestamp: Date())
    }

    public func clear() async {
        works.removeAll()
        chapters.removeAll()
        users.removeAll()
    }
}

// MARK: - Disk Cache

/// A disk-based cache that persists data between app launches
public actor AO3DiskCache: AO3CacheProtocol {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let ttl: TimeInterval

    private enum CacheType: String {
        case work = "works"
        case chapter = "chapters"
        case user = "users"
    }

    /// Initialize a disk cache
    /// - Parameters:
    ///   - directory: Custom cache directory (default: system cache directory)
    ///   - ttl: Time to live in seconds (default: 86400 = 24 hours)
    public init(directory: URL? = nil, ttl: TimeInterval = 86400) throws {
        if let directory = directory {
            self.cacheDirectory = directory
        } else {
            guard let defaultCache = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                throw AO3Exception.generic("Could not access cache directory")
            }
            self.cacheDirectory = defaultCache.appendingPathComponent("AO3Kit", isDirectory: true)
        }

        self.ttl = ttl

        // Create cache directories
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        for type in [CacheType.work, .chapter, .user] {
            try? fileManager.createDirectory(
                at: cacheDirectory.appendingPathComponent(type.rawValue, isDirectory: true),
                withIntermediateDirectories: true
            )
        }
    }

    private func fileURL(for key: String, type: CacheType) -> URL {
        return cacheDirectory
            .appendingPathComponent(type.rawValue, isDirectory: true)
            .appendingPathComponent("\(key).json")
    }

    private func isExpired(_ url: URL) -> Bool {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return true
        }
        return Date().timeIntervalSince(modificationDate) > ttl
    }

    private func readFromDisk<T: Decodable>(_ url: URL, as type: T.Type) -> T? {
        guard fileManager.fileExists(atPath: url.path), !isExpired(url) else {
            try? fileManager.removeItem(at: url)
            return nil
        }

        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? AO3Utils.jsonDecoder.decode(type, from: data)
    }

    private func writeToDisk<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? AO3Utils.jsonEncoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public func getWork(_ id: Int) async -> AO3Work? {
        let url = fileURL(for: "\(id)", type: .work)
        return readFromDisk(url, as: AO3Work.self)
    }

    public func setWork(_ work: AO3Work) async {
        let url = fileURL(for: "\(work.id)", type: .work)
        writeToDisk(work, to: url)
    }

    public func getChapter(workID: Int, chapterID: Int) async -> AO3Chapter? {
        let url = fileURL(for: "\(workID)_\(chapterID)", type: .chapter)
        return readFromDisk(url, as: AO3Chapter.self)
    }

    public func setChapter(_ chapter: AO3Chapter) async {
        let url = fileURL(for: "\(chapter.workID)_\(chapter.id)", type: .chapter)
        writeToDisk(chapter, to: url)
    }

    public func getUser(username: String, pseud: String) async -> AO3User? {
        let key = "\(username)_\(pseud)".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? username
        let url = fileURL(for: key, type: .user)
        return readFromDisk(url, as: AO3User.self)
    }

    public func setUser(_ user: AO3User) async {
        let key = "\(user.username)_\(user.pseud)".addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? user.username
        let url = fileURL(for: key, type: .user)
        writeToDisk(user, to: url)
    }

    public func clear() async {
        for type in [CacheType.work, .chapter, .user] {
            let dir = cacheDirectory.appendingPathComponent(type.rawValue, isDirectory: true)
            try? fileManager.removeItem(at: dir)
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }
}
