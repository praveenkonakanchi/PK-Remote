package com.praveenkonakanchi.pkremote.ui

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscovery
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscoveryEvent
import com.praveenkonakanchi.pkremote.discovery.NsdDeviceDiscovery
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class PkRemoteViewModel(
    private val deviceDiscovery: DeviceDiscovery,
    initialState: PkRemoteUiState = PkRemoteUiState(),
) : ViewModel() {
    private val _uiState = MutableStateFlow(initialState)
    val uiState: StateFlow<PkRemoteUiState> = _uiState.asStateFlow()

    fun selectDevice(deviceId: String) {
        _uiState.update { state ->
            if (state.devices.any { it.id == deviceId }) {
                state.copy(selectedDeviceId = deviceId)
            } else {
                state
            }
        }
    }

    fun startDiscovery() {
        if (_uiState.value.discoveryStatus == DiscoveryStatus.Searching) return
        _uiState.update { it.copy(discoveryStatus = DiscoveryStatus.Searching) }
        deviceDiscovery.start(::applyDiscoveryEvent)
    }

    fun stopDiscovery() {
        deviceDiscovery.stop()
        _uiState.update { state ->
            if (state.discoveryStatus == DiscoveryStatus.Searching) {
                state.copy(discoveryStatus = DiscoveryStatus.Idle)
            } else {
                state
            }
        }
    }

    fun handleCommand(command: RemoteCommand) {
        // Milestone 1 intentionally records only harmless local UI intent.
        _uiState.update { it.copy(lastCommand = command) }
    }

    override fun onCleared() {
        deviceDiscovery.stop()
    }

    private fun applyDiscoveryEvent(event: DeviceDiscoveryEvent) {
        when (event) {
            is DeviceDiscoveryEvent.Failed -> _uiState.update {
                it.copy(discoveryStatus = DiscoveryStatus.Failed(event.message))
            }
            is DeviceDiscoveryEvent.Snapshot -> _uiState.update { state ->
                val devices = event.devices.distinctBy { it.id }.sortedWith(
                    compareBy(String.CASE_INSENSITIVE_ORDER) { it.name },
                )
                val selectedDeviceId = state.selectedDeviceId
                    ?.takeIf { selected -> devices.any { it.id == selected } }
                    ?: devices.firstOrNull { it.isPaired }?.id
                    ?: devices.firstOrNull()?.id
                state.copy(
                    devices = devices,
                    selectedDeviceId = selectedDeviceId,
                    discoveryStatus = DiscoveryStatus.Idle,
                )
            }
        }
    }

    companion object {
        fun factory(context: Context): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T = modelClass.cast(
                PkRemoteViewModel(NsdDeviceDiscovery(context.applicationContext)),
            ) ?: error("Unsupported ViewModel: ${modelClass.name}")
        }
    }
}
