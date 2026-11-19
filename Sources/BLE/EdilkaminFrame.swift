import CommonCrypto
import Foundation

/// Framing and crypto for the Bluetooth protocol Edilkamin stoves use when they are
/// not bound to Wi-Fi/the cloud (local "The Mind" app control over BLE).
///
/// The app talks a Modbus-RTU-style command wrapped in a fixed 20-byte envelope,
/// AES-128/CBC/PKCS7-encrypted as a whole. The key, IV and envelope layout below are
/// not a secret of this device: they are published openly, for the same
/// interoperability purpose (controlling one's own stove without the vendor app), by
/// the open-source project https://github.com/netmb/Edilkamin_BT, which documents
/// having found them in the official app and verified them against a real stove.
enum EdilkaminFrame {
    /// AES-128 key, constant across devices of this product line (see module doc).
    static let key: [UInt8] = [
        0x80, 0x29, 0x47, 0x46, 0xdb, 0x35, 0x4d, 0xb7,
        0x4c, 0x37, 0x01, 0xcf, 0x30, 0xef, 0xdd, 0x65,
    ]
    /// Fixed CBC IV used for every frame (see module doc).
    static let iv: [UInt8] = [
        0xda, 0x1a, 0x55, 0x73, 0x49, 0xf2, 0x5c, 0x64,
        0x1b, 0x1a, 0x21, 0xd2, 0x6f, 0x5b, 0x21, 0x8a,
    ]
    /// 16-byte constant embedded in every envelope, after the timestamp (see module doc).
    static let fixedEnvelopeKey: [UInt8] = [
        0x31, 0xdd, 0x34, 0x51, 0x26, 0x39, 0x20, 0x23,
        0x9f, 0x4b, 0x68, 0x20, 0xe7, 0x25, 0xfc, 0x75,
    ]

    enum FrameError: LocalizedError {
        case cryptoFailed
        case badLength
        case badCRC

        var errorDescription: String? {
            switch self {
            case .cryptoFailed: "Échec du chiffrement AES."
            case .badLength: "Trame de taille inattendue."
            case .badCRC: "CRC invalide dans la réponse du poêle."
            }
        }
    }

    /// CRC16/MODBUS: a public, standard checksum algorithm (not vendor-specific).
    static func crc16Modbus(_ bytes: [UInt8]) -> UInt16 {
        var crc: UInt16 = 0xFFFF
        for byte in bytes {
            crc ^= UInt16(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xA001
                } else {
                    crc >>= 1
                }
            }
        }
        return crc
    }

    /// Builds the 32-byte plaintext envelope: 4-byte big-endian Unix timestamp,
    /// 16-byte fixed key, the 6-byte Modbus command, its CRC16 (low byte first),
    /// then PKCS7 padding up to the next multiple of 16.
    private static func plaintextEnvelope(for command: [UInt8]) -> [UInt8] {
        var ts = UInt32(Date().timeIntervalSince1970).bigEndian
        let timestamp = withUnsafeBytes(of: &ts) { Array($0) }
        var frame = timestamp + fixedEnvelopeKey + command
        let crc = crc16Modbus(command)
        frame += [UInt8(crc & 0xFF), UInt8(crc >> 8)]
        let blockSize = 16
        let padLength = blockSize - (frame.count % blockSize)
        frame += [UInt8](repeating: UInt8(padLength), count: padLength)
        return frame
    }

    /// Encrypts a 6-byte Modbus command (as issued by `EdilkaminRegisters`) into the
    /// ciphertext to write to the stove's write characteristic.
    static func encryptedCommand(_ command: [UInt8]) throws -> Data {
        Data(try aes(plaintextEnvelope(for: command), encrypt: true))
    }

    /// Decrypts a notification payload from the stove and returns the Modbus
    /// response (address, function, data…) with the envelope and CRC stripped.
    static func decodeResponse(_ ciphertext: Data) throws -> [UInt8] {
        let plain = try aes([UInt8](ciphertext), encrypt: false)
        guard plain.count >= 21, let padding = plain.last, padding >= 1, padding <= 16,
            plain.count - Int(padding) > 20
        else { throw FrameError.badLength }
        let unpadded = Array(plain[0..<(plain.count - Int(padding))])
        // Bytes 0..<4 = timestamp, 4..<20 = fixed key, 20... = Modbus response + CRC.
        let payloadWithCRC = Array(unpadded[20...])
        guard payloadWithCRC.count >= 2 else { throw FrameError.badLength }
        let response = Array(payloadWithCRC[0..<(payloadWithCRC.count - 2)])
        let receivedCRC = UInt16(payloadWithCRC[payloadWithCRC.count - 2])
            | (UInt16(payloadWithCRC[payloadWithCRC.count - 1]) << 8)
        guard crc16Modbus(response) == receivedCRC else { throw FrameError.badCRC }
        return response
    }

    private static func aes(_ input: [UInt8], encrypt: Bool) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: input.count + kCCBlockSizeAES128)
        var moved = 0
        let status = CCCrypt(
            CCOperation(encrypt ? kCCEncrypt : kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES128),
            CCOptions(0), // no CommonCrypto padding: we build/strip PKCS7 ourselves above
            key, key.count,
            iv,
            input, input.count,
            &output, output.count,
            &moved
        )
        guard status == kCCSuccess else { throw FrameError.cryptoFailed }
        return Array(output[0..<moved])
    }
}
