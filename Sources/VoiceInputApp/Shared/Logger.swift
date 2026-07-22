import Foundation
import os

enum AppLogger {
    private static let subsystem = "com.smg.flowtype"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let asr = Logger(subsystem: subsystem, category: "asr")
    static let paste = Logger(subsystem: subsystem, category: "paste")
    static let readiness = Logger(subsystem: subsystem, category: "readiness")
    static let diagnostics = Logger(subsystem: subsystem, category: "diagnostics")
    static let performance = Logger(subsystem: subsystem, category: "performance")
}
