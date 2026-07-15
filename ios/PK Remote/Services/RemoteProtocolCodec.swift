import Foundation

nonisolated enum RemoteProtocolMessage: Equatable, Sendable {
    case configure
    case setActive(Int)
    case remoteError(isError: Bool, originalField: Int?)
    case ping(Int)
    case imeBatchEdit(imeCounter: Int, fieldCounter: Int)
    case other
}

nonisolated enum RemoteProtocolCodecError: Error {
    case malformedMessage
}

nonisolated enum RemoteKeyDirection: Int, Sendable {
    case startLong = 1
    case endLong = 2
    case short = 3
}

nonisolated struct RemoteProtocolCodec: Sendable {
    static func configure() -> Data {
        let deviceInfo = message([
            field(1, string: "iPhone"),
            field(2, string: "Apple"),
            field(3, varint: 1),
            field(4, string: "1"),
            field(5, string: "com.pk.PK-Remote"),
            field(6, string: "1.0.0")
        ])
        return envelope(
            field: 1,
            payload: message([
                field(1, varint: 622),
                field(2, bytes: deviceInfo)
            ])
        )
    }

    static func setActive(_ value: Int) -> Data {
        envelope(field: 2, payload: message([field(1, varint: UInt64(value))]))
    }

    static func pingResponse(_ value: Int) -> Data {
        envelope(field: 9, payload: message([field(1, varint: UInt64(value))]))
    }

    static func key(
        _ command: RemoteCommand,
        direction: RemoteKeyDirection = .short
    ) throws -> Data {
        guard let keyCode = AndroidTVKeyCode(command: command) else {
            throw RemoteCommandTransportError.unsupportedCommand
        }
        return envelope(
            field: 10,
            payload: message([
                field(1, varint: UInt64(keyCode.rawValue)),
                field(2, varint: UInt64(direction.rawValue))
            ])
        )
    }

    static func appLink(_ identifier: String) throws -> Data {
        let identifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else {
            throw RemoteCommandTransportError.unsupportedCommand
        }
        return envelope(
            field: 90,
            payload: message([field(1, string: identifier)])
        )
    }

    static func text(_ text: String, imeCounter: Int, fieldCounter: Int) throws -> Data {
        guard !text.isEmpty else { throw RemoteCommandTransportError.unsupportedCommand }
        let finalIndex = max(0, text.unicodeScalars.count - 1)
        let imeObject = message([
            field(1, varint: UInt64(finalIndex)),
            field(2, varint: UInt64(finalIndex)),
            field(3, string: text)
        ])
        let editInfo = message([
            field(1, varint: 1),
            field(2, bytes: imeObject)
        ])
        return envelope(
            field: 21,
            payload: message([
                field(1, varint: UInt64(imeCounter)),
                field(2, varint: UInt64(fieldCounter)),
                field(3, bytes: editInfo)
            ])
        )
    }

    static func decode(_ data: Data) throws -> RemoteProtocolMessage {
        var reader = RemoteProtobufReader(data: data)
        while let entry = try reader.next() {
            guard case .bytes(let payload) = entry.value else { continue }
            switch entry.number {
            case 1:
                return .configure
            case 2:
                return .setActive(try firstVarint(in: payload))
            case 3:
                let error = try remoteError(in: payload)
                return .remoteError(
                    isError: error.isError,
                    originalField: error.originalField
                )
            case 8:
                return .ping(try firstVarint(in: payload))
            case 21:
                let counters = try imeCounters(in: payload)
                return .imeBatchEdit(
                    imeCounter: counters.imeCounter,
                    fieldCounter: counters.fieldCounter
                )
            default:
                continue
            }
        }
        return .other
    }

    static func frame(_ payload: Data) -> Data {
        Data(varint(UInt64(payload.count))) + payload
    }

    static func extractFrame(from buffer: inout Data) throws -> Data? {
        guard let (length, prefixLength) = try decodeVarint(in: buffer) else { return nil }
        guard length <= 1_048_576 else { throw RemoteProtocolCodecError.malformedMessage }
        let totalLength = prefixLength + Int(length)
        guard buffer.count >= totalLength else { return nil }
        let payload = buffer.subdata(in: prefixLength..<totalLength)
        buffer.removeSubrange(0..<totalLength)
        return payload
    }

    private static func envelope(field number: Int, payload: Data) -> Data {
        message([field(number, bytes: payload)])
    }

    private static func firstVarint(in data: Data) throws -> Int {
        var reader = RemoteProtobufReader(data: data)
        while let entry = try reader.next() {
            if entry.number == 1, case .varint(let value) = entry.value {
                return Int(value)
            }
        }
        // Proto3 omits scalar fields whose value is zero.
        return 0
    }

    private static func imeCounters(in data: Data) throws -> (imeCounter: Int, fieldCounter: Int) {
        var imeCounter = 0
        var fieldCounter = 0
        var reader = RemoteProtobufReader(data: data)
        while let entry = try reader.next() {
            guard case .varint(let value) = entry.value else { continue }
            if entry.number == 1 { imeCounter = Int(value) }
            if entry.number == 2 { fieldCounter = Int(value) }
        }
        return (imeCounter, fieldCounter)
    }

    private static func remoteError(in data: Data) throws -> (
        isError: Bool,
        originalField: Int?
    ) {
        var isError = false
        var originalField: Int?
        var reader = RemoteProtobufReader(data: data)
        while let entry = try reader.next() {
            if entry.number == 1, case .varint(let value) = entry.value {
                isError = value != 0
            }
            if entry.number == 2, case .bytes(let message) = entry.value {
                var messageReader = RemoteProtobufReader(data: message)
                originalField = try messageReader.next()?.number
            }
        }
        return (isError, originalField)
    }

    private static func message(_ fields: [Data]) -> Data {
        fields.reduce(into: Data()) { $0.append($1) }
    }

    private static func field(_ number: Int, varint value: UInt64) -> Data {
        Data(varint(UInt64(number << 3))) + Data(varint(value))
    }

    private static func field(_ number: Int, string: String) -> Data {
        field(number, bytes: Data(string.utf8))
    }

    private static func field(_ number: Int, bytes: Data) -> Data {
        Data(varint(UInt64((number << 3) | 2)))
            + Data(varint(UInt64(bytes.count)))
            + bytes
    }

    private static func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while value != 0
        return bytes
    }

    private static func decodeVarint(in data: Data) throws -> (UInt64, Int)? {
        var value: UInt64 = 0
        for (index, byte) in data.prefix(10).enumerated() {
            value |= UInt64(byte & 0x7f) << UInt64(index * 7)
            if byte & 0x80 == 0 { return (value, index + 1) }
        }
        if data.count >= 10 { throw RemoteProtocolCodecError.malformedMessage }
        return nil
    }
}

nonisolated private enum AndroidTVKeyCode: Int {
    case home = 3
    case back = 4
    case digit0 = 7
    case digit1 = 8
    case digit2 = 9
    case digit3 = 10
    case digit4 = 11
    case digit5 = 12
    case digit6 = 13
    case digit7 = 14
    case digit8 = 15
    case digit9 = 16
    case up = 19
    case down = 20
    case left = 21
    case right = 22
    case select = 23
    case volumeUp = 24
    case volumeDown = 25
    case power = 26
    case menu = 82
    case playPause = 85
    case next = 87
    case previous = 88
    case rewind = 89
    case fastForward = 90
    case mute = 91
    case programRed = 183
    case programGreen = 184
    case programYellow = 185
    case programBlue = 186

    init?(command: RemoteCommand) {
        switch command {
        case .power: self = .power
        case .home: self = .home
        case .back: self = .back
        case .menu: self = .menu
        case .openGoogleTVSettings: self = .home
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .select: self = .select
        case .volumeUp: self = .volumeUp
        case .volumeDown: self = .volumeDown
        case .mute: self = .mute
        case .digit(let number):
            guard (0...9).contains(number),
                  let key = Self(rawValue: Self.digit0.rawValue + number) else { return nil }
            self = key
        case .previous: self = .previous
        case .playPause: self = .playPause
        case .next: self = .next
        case .rewind: self = .rewind
        case .fastForward: self = .fastForward
        case .view: self = .programRed
        case .sort: self = .programGreen
        case .favorites: self = .programYellow
        case .find: self = .programBlue
        case .text, .launchApp: return nil
        }
    }
}

nonisolated private struct RemoteProtobufReader {
    enum Value {
        case varint(UInt64)
        case bytes(Data)
        case ignored
    }

    struct Entry {
        let number: Int
        let value: Value
    }

    private let data: Data
    private var index = 0

    init(data: Data) {
        self.data = data
    }

    mutating func next() throws -> Entry? {
        guard index < data.count else { return nil }
        let key = try readVarint()
        let number = Int(key >> 3)
        switch key & 0x07 {
        case 0:
            return Entry(number: number, value: .varint(try readVarint()))
        case 1:
            try skip(byteCount: 8)
            return Entry(number: number, value: .ignored)
        case 2:
            let length = Int(try readVarint())
            guard index + length <= data.count else {
                throw RemoteProtocolCodecError.malformedMessage
            }
            defer { index += length }
            return Entry(number: number, value: .bytes(data.subdata(in: index..<(index + length))))
        case 5:
            try skip(byteCount: 4)
            return Entry(number: number, value: .ignored)
        default:
            throw RemoteProtocolCodecError.malformedMessage
        }
    }

    private mutating func skip(byteCount: Int) throws {
        guard index + byteCount <= data.count else {
            throw RemoteProtocolCodecError.malformedMessage
        }
        index += byteCount
    }

    private mutating func readVarint() throws -> UInt64 {
        var value: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard index < data.count else { throw RemoteProtocolCodecError.malformedMessage }
            let byte = data[index]
            index += 1
            value |= UInt64(byte & 0x7f) << UInt64(shift)
            if byte & 0x80 == 0 { return value }
        }
        throw RemoteProtocolCodecError.malformedMessage
    }
}
