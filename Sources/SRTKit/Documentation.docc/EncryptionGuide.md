# Encryption Guide

Secure SRT streams with AES-CTR or AES-GCM encryption.

## Overview

SRTKit implements the full SRT encryption specification: PBKDF2 key derivation, RFC 3394 key wrap, AES-CTR and AES-GCM cipher modes, and automatic key rotation. All cryptographic operations use swift-crypto with no CommonCrypto or CryptoKit direct usage.

### Cipher Modes

SRTKit supports two cipher modes via ``CipherMode``:

| Mode | Description | Authentication | Overhead |
|------|-------------|---------------|----------|
| `.ctr` | AES-CTR | None | 0 bytes |
| `.gcm` | AES-GCM | 16-byte auth tag | 16 bytes per packet |

```swift
CipherMode.ctr.description  // "AES-CTR"
CipherMode.gcm.description  // "AES-GCM"
CipherMode.gcmTagSize       // 16
```

### Key Sizes

Three AES key sizes are available via ``KeySize``:

```swift
KeySize.aes128.rawValue       // 16 bytes
KeySize.aes192.rawValue       // 24 bytes
KeySize.aes256.rawValue       // 32 bytes

// Wrapped key size = key + 8 bytes (RFC 3394)
KeySize.aes128.wrappedSize    // 24
```

### AES-CTR Encrypt/Decrypt Roundtrip

```swift
let sek = Array(repeating: UInt8(0x42), count: 16)
let salt = Array(repeating: UInt8(0x01), count: 16)

let encryptor = try SRTEncryptor(
    sek: sek, salt: salt,
    cipherMode: .ctr, keySize: .aes128)
let decryptor = try SRTDecryptor(
    sek: sek, salt: salt,
    cipherMode: .ctr, keySize: .aes128)

let plaintext: [UInt8] = Array(0..<188)
let header: [UInt8] = [0x00, 0x00, 0x00, 0x2A]
let encrypted = try encryptor.encrypt(
    payload: plaintext,
    sequenceNumber: SequenceNumber(42),
    header: header)
let decrypted = try decryptor.decrypt(
    payload: encrypted,
    sequenceNumber: SequenceNumber(42),
    header: header)
// decrypted == plaintext
```

### AES-GCM Encrypt/Decrypt Roundtrip

```swift
let sek = Array(repeating: UInt8(0x55), count: 32)
let salt = Array(repeating: UInt8(0x02), count: 16)

let encryptor = try SRTEncryptor(
    sek: sek, salt: salt,
    cipherMode: .gcm, keySize: .aes256)
let decryptor = try SRTDecryptor(
    sek: sek, salt: salt,
    cipherMode: .gcm, keySize: .aes256)

let plaintext: [UInt8] = (0..<1316).map { UInt8($0 % 256) }
let header: [UInt8] = [0x00, 0x00, 0x00, 0x01]
let encrypted = try encryptor.encrypt(
    payload: plaintext,
    sequenceNumber: SequenceNumber(1),
    header: header)
// GCM adds 16-byte auth tag
// encrypted.count == plaintext.count + 16

let decrypted = try decryptor.decrypt(
    payload: encrypted,
    sequenceNumber: SequenceNumber(1),
    header: header)
// decrypted == plaintext
```

### Key Derivation

``KeyDerivation`` derives a Key Encryption Key (KEK) from a passphrase using PBKDF2:

```swift
let passphrase = "test-passphrase-1234"
let salt = KeyDerivation.generateSalt()
// salt.count == KeyDerivation.saltSize

let kek = try KeyDerivation.deriveKEK(
    passphrase: passphrase,
    salt: salt,
    keySize: .aes128)
// kek.count == 16

// Same inputs always produce the same output
let kek2 = try KeyDerivation.deriveKEK(
    passphrase: passphrase,
    salt: salt,
    keySize: .aes128)
// kek == kek2
```

Passphrases must be 10–79 characters:

```swift
// Too short — throws
try KeyDerivation.validatePassphrase("short")

// Valid length
try KeyDerivation.validatePassphrase("valid-pass-1234")
```

### Key Wrap (RFC 3394)

``KeyWrap`` wraps and unwraps session encryption keys using the KEK:

```swift
let key = Array(repeating: UInt8(0xAA), count: 16)
let kek = Array(repeating: UInt8(0xBB), count: 16)

let wrapped = try KeyWrap.wrap(key: key, withKEK: kek)
// wrapped.count == key.count + 8

let unwrapped = try KeyWrap.unwrap(wrappedKey: wrapped, withKEK: kek)
// unwrapped == key
```

### Key Rotation

``KeyRotation`` manages automatic session key rotation with a pre-announce phase:

```swift
var rotation = KeyRotation(
    configuration: .init(refreshRate: 10, preAnnounce: 3),
    initialKeyIndex: .even)
// rotation.activeKeyIndex == .even

for _ in 0..<15 {
    let action = rotation.packetSent()
    switch action {
    case .preAnnounce:
        // New key is announced but not yet active
        break
    case .switchKey:
        // Active key switched to the new key
        break
    case .none:
        break
    }
}
```

Key indices toggle between `.even` and `.odd`:

```swift
KeyRotation.KeyIndex.even.other  // .odd
KeyRotation.KeyIndex.odd.other   // .even
```

## Next Steps

- <doc:CallerGuide> — Encrypted caller setup
- <doc:ListenerGuide> — Encrypted listener setup
- <doc:InteroperabilityGuide> — Interop with libsrt encryption
