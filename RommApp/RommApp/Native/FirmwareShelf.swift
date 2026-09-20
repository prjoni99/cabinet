import Foundation

/// One copy of each platform's firmware on this device, downloaded the
/// first time any game on that platform needs it and reused by every
/// launch and every keep after that.
///
/// Before this, a platform's BIOS came down once per game on Apple TV,
/// and on iPhone once per launch of any game not kept, straight into
/// that launch's own directory: small next to a CD image, but across an
/// arcade library it added up to a few hundred megabytes of redundant
/// downloads and duplicated cache (the roadmap's rough edge, fixed
/// 2026-09-20). Kept games already mirror firmware into one bios folder
/// per platform in Files; this is the same shape on the private side.
///
/// Lives under Caches on purpose. On tvOS that is the only storage tier
/// there is, and on iOS a purged shelf simply refills on the next launch
/// that wants it. A kept game links what it needs into its own directory
/// at keep time, so its offline promise never depends on this surviving.
///
/// Files are matched by name, and by size when the server reports one.
/// RomM has no firmware version, so a replaced BIOS uploaded under the
/// same name at the same size goes unnoticed; the per-launch download
/// had the same blind spot, since it too asked only by name.
///
/// Deliberately downloads everything the platform lists rather than only
/// what its core is known to want. The launcher's own name table covers
/// the CD consoles, but an arcade board's BIOS set (neogeo.zip and its
/// kind) is served as firmware under whatever name it was uploaded with,
/// and FBNeo and MAME find it in the system directory by that name. A
/// filter built from the table would have quietly broken Neo Geo.
enum FirmwareShelf {
    static var root: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("native-firmware", isDirectory: true)
    }

    static func directory(platformId: Int) -> URL {
        root.appendingPathComponent(String(platformId), isDirectory: true)
    }

    /// Every firmware file the server lists for a platform, as local URLs
    /// on the shelf, downloading only what is not already there. Files
    /// the server itself has lost (`missingFromFS`) are skipped, as they
    /// always were.
    ///
    /// `requireAll` is the difference between a launch and a keep. A
    /// launch tolerates one BIOS failing to come down and boots with
    /// whatever did, since the core may never have wanted that file,
    /// while a keep promises a boot-ready directory and fails loudly
    /// instead. Throws either way when the list itself cannot be fetched.
    static func files(platformId: Int, session: Session, requireAll: Bool) async throws -> [URL] {
        let list = try await session.firmware(platformId: platformId)
        let dir = directory(platformId: platformId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var urls: [URL] = []
        for firmware in list where !firmware.missingFromFS {
            let url = dir.appendingPathComponent(firmware.fileName)
            if isShelved(url, expectedSize: firmware.fileSizeBytes) {
                urls.append(url)
                continue
            }
            do {
                try await fetch(session.firmwareContentRequest(firmware), to: url)
                urls.append(url)
            } catch {
                if requireAll { throw error }
            }
        }
        return urls
    }

    /// Puts shelved files into a launch or keep directory under their own
    /// names, which is where the per-launch download used to leave them
    /// and where a core that looks a BIOS up by its server name expects
    /// it. Hard links where the volume allows, so the bytes exist once;
    /// a copy where it refuses. Returns what is actually in place, ready
    /// for `NativeLauncher.stageFirmware` to alias under the core's own
    /// names. A file already present is left alone.
    static func place(_ urls: [URL], in dir: URL) -> [URL] {
        let manager = FileManager.default
        var placed: [URL] = []
        for url in urls {
            let target = dir.appendingPathComponent(url.lastPathComponent)
            if !manager.fileExists(atPath: target.path) {
                do {
                    try manager.linkItem(at: url, to: target)
                } catch {
                    try? manager.copyItem(at: url, to: target)
                }
            }
            if manager.fileExists(atPath: target.path) { placed.append(target) }
        }
        return placed
    }

    private static func isShelved(_ url: URL, expectedSize: Int64?) -> Bool {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64
        else { return false }
        guard let expectedSize, expectedSize > 0 else { return true }
        return size == expectedSize
    }

    /// Streamed to a temp file by the system and moved into place, never
    /// held in memory, the same rule every ROM download here follows. No
    /// progress: a BIOS is at most a few megabytes.
    private static func fetch(_ request: URLRequest, to url: URL) async throws {
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: tempURL)
            throw NSError(
                domain: "FirmwareShelf",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) for \(url.lastPathComponent)"]
            )
        }
        try? FileManager.default.removeItem(at: url)
        try FileManager.default.moveItem(at: tempURL, to: url)
    }
}
