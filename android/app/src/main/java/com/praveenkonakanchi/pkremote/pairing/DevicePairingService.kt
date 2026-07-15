package com.praveenkonakanchi.pkremote.pairing

import com.praveenkonakanchi.pkremote.model.RemoteDevice

internal interface DevicePairingService : AutoCloseable {
    suspend fun requestPairingCode(device: RemoteDevice)
    suspend fun pair(device: RemoteDevice, code: String)
    suspend fun cancel(device: RemoteDevice)
    override fun close()
}

internal class PairingException(message: String, cause: Throwable? = null) : Exception(message, cause)
