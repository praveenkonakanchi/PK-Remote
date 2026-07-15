package com.praveenkonakanchi.pkremote.ui

import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice

data class PkRemoteUiState(
    val devices: List<RemoteDevice> = previewDevices,
    val selectedDeviceId: String? = "peekay-tv",
    val shortcuts: List<RemoteAppShortcut> = RemoteAppShortcut.defaults,
    val lastCommand: RemoteCommand? = null,
) {
    val selectedDevice: RemoteDevice?
        get() = devices.firstOrNull { it.id == selectedDeviceId }

    companion object {
        val previewDevices = listOf(
            RemoteDevice(id = "bedroom-tv", name = "My bedroom TV"),
            RemoteDevice(id = "peekay-tv", name = "peekay TV", isPaired = true),
        )
    }
}
