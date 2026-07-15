package com.praveenkonakanchi.pkremote.ui

import androidx.lifecycle.ViewModel
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class PkRemoteViewModel : ViewModel() {
    private val _uiState = MutableStateFlow(PkRemoteUiState())
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

    fun handleCommand(command: RemoteCommand) {
        // Milestone 1 intentionally records only harmless local UI intent.
        _uiState.update { it.copy(lastCommand = command) }
    }
}
