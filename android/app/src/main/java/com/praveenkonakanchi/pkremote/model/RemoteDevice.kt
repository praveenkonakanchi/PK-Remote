package com.praveenkonakanchi.pkremote.model

import java.util.Locale

data class RemoteDevice(
    val id: String,
    val name: String,
    val kind: String = "Google TV",
    val isAvailable: Boolean = true,
    val isPaired: Boolean = false,
    val serviceType: String? = null,
    val endpointHost: String? = null,
    val remotePort: Int? = null,
) {
    companion object {
        fun discovered(serviceName: String?, serviceType: String?): RemoteDevice? {
            val name = serviceName?.trim().orEmpty()
            val type = serviceType?.trim()?.trimEnd('.')?.lowercase(Locale.ROOT).orEmpty()
            if (name.isEmpty() || type.isEmpty()) return null
            return RemoteDevice(
                id = "$name|$type".lowercase(Locale.ROOT),
                name = name,
                serviceType = type,
            )
        }
    }
}
