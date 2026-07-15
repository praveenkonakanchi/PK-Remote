package com.praveenkonakanchi.pkremote.pairing

import java.security.MessageDigest
import java.security.interfaces.RSAPublicKey

internal object PairingSecret {
    fun make(code: String, clientPublicKey: RSAPublicKey, serverPublicKey: RSAPublicKey): ByteArray {
        val normalizedCode = code.trim().uppercase()
        if (normalizedCode.length != 6 || normalizedCode.any { it !in "0123456789ABCDEF" }) {
            throw PairingException("Enter the 6-character code shown on your TV.")
        }
        val expectedFirstByte = normalizedCode.take(2).toInt(16)
        val suffix = normalizedCode.drop(2).chunked(2).map { it.toInt(16).toByte() }.toByteArray()
        val digest = MessageDigest.getInstance("SHA-256").digest(
            clientPublicKey.modulus.unsignedBytes() +
                clientPublicKey.publicExponent.unsignedBytes() +
                serverPublicKey.modulus.unsignedBytes() +
                serverPublicKey.publicExponent.unsignedBytes() +
                suffix,
        )
        if ((digest.first().toInt() and 0xff) != expectedFirstByte) {
            throw PairingException("The pairing code was not accepted. Check the code on your TV and try again.")
        }
        return digest
    }
}

private fun java.math.BigInteger.unsignedBytes(): ByteArray {
    val bytes = toByteArray().dropWhile { it == 0.toByte() }.toByteArray()
    return if (bytes.isEmpty()) byteArrayOf(0) else bytes
}
