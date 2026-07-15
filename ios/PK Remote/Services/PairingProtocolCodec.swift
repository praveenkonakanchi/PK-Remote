import Foundation

nonisolated enum PairingMessageKind: Int, Sendable {
    case pairingRequest = 10
    case pairingRequestAcknowledgement = 11
    case options = 20
    case configuration = 30
    case configurationAcknowledgement = 31
    case secret = 40
    case secretAcknowledgement = 41
}

nonisolated enum PairingProtocolCodecError: Error {
    case malformedMessage
    case unsuccessfulStatus(Int)
    case unexpectedMessage
}

nonisolated struct PairingProtocolCodec: Sendable {
    static func pairingRequest(clientName: String) -> Data {
        envelope(
            kind: .pairingRequest,
            payload: message([
                field(1, string: "atvremote"),
                field(2, string: clientName)
            ])
        )
    }

    static func options() -> Data {
        let hexadecimalEncoding = message([
            field(1, varint: 3),
            field(2, varint: 6)
        ])
        return envelope(
            kind: .options,
            payload: message([
                field(1, bytes: hexadecimalEncoding),
                field(3, varint: 1)
            ])
        )
    }

    static func configuration() -> Data {
        let hexadecimalEncoding = message([
            field(1, varint: 3),
            field(2, varint: 6)
        ])
        return envelope(
            kind: .configuration,
            payload: message([
                field(1, bytes: hexadecimalEncoding),
                field(2, varint: 1)
            ])
        )
    }

    static func secret(_ secret: Data) -> Data {
        envelope(kind: .secret, payload: message([field(1, bytes: secret)]))
    }

    static func decodeKind(from data: Data) throws -> PairingMessageKind {
        var reader = ProtobufReader(data: data)
        var status: Int?
        var kind: PairingMessageKind?

        while let entry = try reader.next() {
            if entry.number == 2, case .varint(let value) = entry.value {
                status = Int(value)
            } else if let candidate = PairingMessageKind(rawValue: entry.number) {
                kind = candidate
            }
        }

        guard status == 200 else {
            throw PairingProtocolCodecError.unsuccessfulStatus(status ?? -1)
        }
        guard let kind else { throw PairingProtocolCodecError.unexpectedMessage }
        return kind
    }

    static func frame(_ payload: Data) -> Data {
        Data(varint(UInt64(payload.count))) + payload
    }

    static func extractFrame(from buffer: inout Data) throws -> Data? {
        guard let (length, prefixLength) = try decodeVarint(in: buffer) else { return nil }
        guard length <= 1_048_576 else { throw PairingProtocolCodecError.malformedMessage }
        let totalLength = prefixLength + Int(length)
        guard buffer.count >= totalLength else { return nil }
        let payload = buffer.subdata(in: prefixLength..<totalLength)
        buffer.removeSubrange(0..<totalLength)
        return payload
    }

    private static func envelope(kind: PairingMessageKind, payload: Data) -> Data {
        message([
            field(1, varint: 2),
            field(2, varint: 200),
            field(kind.rawValue, bytes: payload)
        ])
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
        if data.count >= 10 { throw PairingProtocolCodecError.malformedMessage }
        return nil
    }
}

nonisolated private struct ProtobufReader {
    enum Value {
        case varint(UInt64)
        case bytes(Data)
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
        case 2:
            let length = Int(try readVarint())
            guard length >= 0, index + length <= data.count else {
                throw PairingProtocolCodecError.malformedMessage
            }
            defer { index += length }
            return Entry(number: number, value: .bytes(data.subdata(in: index..<(index + length))))
        default:
            throw PairingProtocolCodecError.malformedMessage
        }
    }

    private mutating func readVarint() throws -> UInt64 {
        var value: UInt64 = 0
        for shift in stride(from: 0, through: 63, by: 7) {
            guard index < data.count else { throw PairingProtocolCodecError.malformedMessage }
            let byte = data[index]
            index += 1
            value |= UInt64(byte & 0x7f) << UInt64(shift)
            if byte & 0x80 == 0 { return value }
        }
        throw PairingProtocolCodecError.malformedMessage
    }
}
