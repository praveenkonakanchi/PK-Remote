package com.praveenkonakanchi.pkremote.pairing

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.math.BigInteger
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.cert.X509Certificate
import java.util.Date
import javax.security.auth.x500.X500Principal

internal data class PairingIdentity(
    val alias: String,
    val privateKey: PrivateKey,
    val certificate: X509Certificate,
) {
    val certificateFingerprint: ByteArray
        get() = MessageDigest.getInstance("SHA-256").digest(certificate.encoded)
}

internal class PairingIdentityStore(
    private val alias: String = DefaultAlias,
) {
    @Synchronized
    fun loadOrCreate(): PairingIdentity {
        val keyStore = loadKeyStore()
        val existing = keyStore.getEntry(alias, null) as? KeyStore.PrivateKeyEntry
        if (existing != null && existing.certificate is X509Certificate) {
            return PairingIdentity(alias, existing.privateKey, existing.certificate as X509Certificate)
        }
        if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
        generateIdentity()
        val created = loadKeyStore().getEntry(alias, null) as? KeyStore.PrivateKeyEntry
            ?: throw PairingException("Could not recover the Android pairing identity.")
        return PairingIdentity(alias, created.privateKey, created.certificate as X509Certificate)
    }

    fun keyStore(): KeyStore = loadKeyStore()

    internal fun delete() {
        loadKeyStore().let { if (it.containsAlias(alias)) it.deleteEntry(alias) }
    }

    private fun generateIdentity() {
        val now = System.currentTimeMillis()
        val serial = BigInteger(63, SecureRandom()).max(BigInteger.ONE)
        // Some Android Conscrypt versions perform the TLS client-certificate RSA operation
        // through RSA/ECB/NoPadding instead of Signature. PURPOSE_DECRYPT + NoPadding keeps
        // that operation inside Android Keystore while the private key remains non-exportable.
        val specification = KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_DECRYPT,
        )
            .setKeySize(2048)
            .setDigests(
                KeyProperties.DIGEST_NONE,
                KeyProperties.DIGEST_SHA256,
                KeyProperties.DIGEST_SHA384,
                KeyProperties.DIGEST_SHA512,
            )
            .setSignaturePaddings(
                KeyProperties.SIGNATURE_PADDING_RSA_PKCS1,
                KeyProperties.SIGNATURE_PADDING_RSA_PSS,
            )
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setCertificateSubject(X500Principal("CN=PK Remote"))
            .setCertificateSerialNumber(serial)
            .setCertificateNotBefore(Date(now - OneDayMillis))
            .setCertificateNotAfter(Date(now + TenYearsMillis))
            .setUserAuthenticationRequired(false)
            .build()
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, AndroidKeyStore).apply {
            initialize(specification)
            generateKeyPair()
        }
    }

    private fun loadKeyStore(): KeyStore = KeyStore.getInstance(AndroidKeyStore).apply { load(null) }

    private companion object {
        const val AndroidKeyStore = "AndroidKeyStore"
        const val DefaultAlias = "pk_remote_google_tv_identity_v3"
        const val OneDayMillis = 86_400_000L
        const val TenYearsMillis = OneDayMillis * 3_650
    }
}
