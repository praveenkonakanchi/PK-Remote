package com.praveenkonakanchi.pkremote.pairing

import android.content.Context
import android.util.Base64
import org.json.JSONObject
import java.security.MessageDigest

internal data class PairingCredential(
    val tvCertificateFingerprint: ByteArray,
    val clientCertificateFingerprint: ByteArray,
)

internal class PairingCredentialStore(
    context: Context,
    private val identityStore: PairingIdentityStore,
    preferencesName: String = DefaultPreferencesName,
) {
    private val preferences = context.getSharedPreferences(preferencesName, Context.MODE_PRIVATE)

    fun save(deviceId: String, credential: PairingCredential) {
        val encoded = JSONObject()
            .put("tv", credential.tvCertificateFingerprint.base64())
            .put("client", credential.clientCertificateFingerprint.base64())
            .toString()
        if (!preferences.edit().putString(deviceId, encoded).commit()) {
            throw PairingException("Could not save the pairing credential.")
        }
    }

    fun credential(deviceId: String): PairingCredential? {
        val encoded = preferences.getString(deviceId, null) ?: return null
        val credential = runCatching {
            JSONObject(encoded).let {
                PairingCredential(it.getString("tv").base64Bytes(), it.getString("client").base64Bytes())
            }
        }.getOrNull() ?: return null
        val currentFingerprint = identityStore.loadOrCreate().certificateFingerprint
        return credential.takeIf {
            MessageDigest.isEqual(it.clientCertificateFingerprint, currentFingerprint)
        }
    }

    fun isPaired(deviceId: String): Boolean = credential(deviceId) != null

    fun remove(deviceId: String) {
        if (!preferences.edit().remove(deviceId).commit()) {
            throw PairingException("Could not remove the pairing credential.")
        }
    }

    internal fun clear() {
        preferences.edit().clear().commit()
    }

    private companion object {
        const val DefaultPreferencesName = "google_tv_pairing_credentials_v1"
    }
}

private fun ByteArray.base64(): String = Base64.encodeToString(this, Base64.NO_WRAP)
private fun String.base64Bytes(): ByteArray = Base64.decode(this, Base64.NO_WRAP)
