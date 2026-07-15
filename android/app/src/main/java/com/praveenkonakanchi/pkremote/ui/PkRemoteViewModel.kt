package com.praveenkonakanchi.pkremote.ui

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscovery
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscoveryEvent
import com.praveenkonakanchi.pkremote.discovery.NsdDeviceDiscovery
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.pairing.DevicePairingService
import com.praveenkonakanchi.pkremote.pairing.GoogleTvPairingService
import com.praveenkonakanchi.pkremote.pairing.PairingCredentialStore
import com.praveenkonakanchi.pkremote.pairing.PairingIdentityStore
import com.praveenkonakanchi.pkremote.remote.GoogleTvRemoteCommandService
import com.praveenkonakanchi.pkremote.remote.RemoteCommandService
import com.praveenkonakanchi.pkremote.remote.RemoteTransportException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

class PkRemoteViewModel internal constructor(
    private val deviceDiscovery: DeviceDiscovery,
    private val pairingService: DevicePairingService? = null,
    private val credentialStore: PairingCredentialStore? = null,
    private val remoteService: RemoteCommandService? = null,
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

    fun handleCommand(command: RemoteCommand, surface: CommandSurface = CommandSurface.Remote) {
        val device = _uiState.value.selectedDevice
        _uiState.update { it.copy(lastCommand = command, commandFeedback = null) }
        val service = remoteService ?: return
        if (device?.isPaired != true) {
            showCommandFeedback(surface, "Pair this TV from Devices before using controls.")
            return
        }
        viewModelScope.launch {
            runCatching { service.send(command, device) }
                .onFailure { error ->
                    if (error is RemoteTransportException && error.invalidatesPairing) {
                        runCatching { credentialStore?.remove(device.id) }
                        _uiState.update { state ->
                            state.copy(
                                devices = state.devices.map { current ->
                                    if (current.id == device.id) current.copy(isPaired = false) else current
                                },
                            ).withPairingStatus(
                                device.id,
                                PairingStatus.Failed("Pairing is no longer valid. Pair this TV again."),
                            )
                        }
                    }
                    showCommandFeedback(surface, error.message ?: "Could not send the remote command.")
                }
        }
    }

    fun requestPairingCode(deviceId: String) {
        val device = device(deviceId) ?: return
        val service = pairingService ?: return pairingUnavailable(deviceId)
        _uiState.update { it.withPairingStatus(deviceId, PairingStatus.RequestingCode) }
        viewModelScope.launch {
            runCatching { service.requestPairingCode(device) }
                .onSuccess { _uiState.update { it.withPairingStatus(deviceId, PairingStatus.AwaitingCode) } }
                .onFailure { error ->
                    _uiState.update {
                        it.withPairingStatus(
                            deviceId,
                            PairingStatus.Failed(error.message ?: "Could not start pairing."),
                        )
                    }
                }
        }
    }

    fun submitPairingCode(deviceId: String, code: String) {
        val device = device(deviceId) ?: return
        val service = pairingService ?: return pairingUnavailable(deviceId)
        val normalized = code.trim().uppercase()
        if (!normalized.matches(Regex("[0-9A-F]{6}"))) {
            _uiState.update {
                it.withPairingStatus(deviceId, PairingStatus.Failed("Enter the six-character code shown on your TV."))
            }
            return
        }
        _uiState.update { it.withPairingStatus(deviceId, PairingStatus.Pairing) }
        viewModelScope.launch {
            runCatching { service.pair(device, normalized) }
                .onSuccess {
                    _uiState.update { state ->
                        state.copy(
                            devices = state.devices.map { current ->
                                if (current.id == deviceId) current.copy(isPaired = true) else current
                            },
                        ).withPairingStatus(deviceId, PairingStatus.Paired)
                    }
                }
                .onFailure { error ->
                    _uiState.update {
                        it.withPairingStatus(
                            deviceId,
                            PairingStatus.Failed(error.message ?: "The TV did not accept the pairing code."),
                        )
                    }
                }
        }
    }

    fun cancelPairing(deviceId: String) {
        val device = device(deviceId) ?: return
        val fallback = if (credentialStore?.isPaired(deviceId) == true) PairingStatus.Paired else PairingStatus.Unpaired
        _uiState.update { it.withPairingStatus(deviceId, fallback) }
        viewModelScope.launch { pairingService?.cancel(device) }
    }

    fun forgetPairing(deviceId: String) {
        val device = device(deviceId) ?: return
        pairingService?.let { service -> viewModelScope.launch { service.cancel(device) } }
        remoteService?.let { service -> viewModelScope.launch { service.stopSession(device) } }
        runCatching { credentialStore?.remove(deviceId) }
            .onSuccess {
                _uiState.update { state ->
                    state.copy(
                        devices = state.devices.map { current ->
                            if (current.id == deviceId) current.copy(isPaired = false) else current
                        },
                    ).withPairingStatus(deviceId, PairingStatus.Unpaired)
                }
            }
            .onFailure { error ->
                _uiState.update {
                    it.withPairingStatus(
                        deviceId,
                        PairingStatus.Failed(error.message ?: "Could not forget this pairing."),
                    )
                }
            }
    }

    override fun onCleared() {
        deviceDiscovery.stop()
        pairingService?.close()
        remoteService?.close()
    }

    private fun applyDiscoveryEvent(event: DeviceDiscoveryEvent) {
        when (event) {
            is DeviceDiscoveryEvent.Failed -> _uiState.update {
                it.copy(discoveryStatus = DiscoveryStatus.Failed(event.message))
            }
            is DeviceDiscoveryEvent.Snapshot -> _uiState.update { state ->
                val devices = event.devices.distinctBy { it.id }.map { device ->
                    device.copy(isPaired = runCatching { credentialStore?.isPaired(device.id) == true }.getOrDefault(false))
                }.sortedWith(
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

    private fun device(deviceId: String): RemoteDevice? = _uiState.value.devices.firstOrNull { it.id == deviceId }

    private fun pairingUnavailable(deviceId: String) {
        _uiState.update {
            it.withPairingStatus(deviceId, PairingStatus.Failed("Secure pairing is not available."))
        }
    }

    private fun showCommandFeedback(surface: CommandSurface, message: String) {
        val feedback = CommandFeedback(surface, message)
        _uiState.update { it.copy(commandFeedback = feedback) }
        viewModelScope.launch {
            delay(4_000)
            _uiState.update { state ->
                if (state.commandFeedback == feedback) state.copy(commandFeedback = null) else state
            }
        }
    }

    companion object {
        fun factory(context: Context): ViewModelProvider.Factory = object : ViewModelProvider.Factory {
            override fun <T : ViewModel> create(modelClass: Class<T>): T {
                val applicationContext = context.applicationContext
                val identityStore = PairingIdentityStore()
                val credentialStore = PairingCredentialStore(applicationContext, identityStore)
                return modelClass.cast(
                    PkRemoteViewModel(
                        deviceDiscovery = NsdDeviceDiscovery(applicationContext),
                        pairingService = GoogleTvPairingService(identityStore, credentialStore),
                        credentialStore = credentialStore,
                        remoteService = GoogleTvRemoteCommandService(identityStore, credentialStore),
                    ),
                ) ?: error("Unsupported ViewModel: ${modelClass.name}")
            }
        }
    }
}

private fun PkRemoteUiState.withPairingStatus(deviceId: String, status: PairingStatus): PkRemoteUiState =
    copy(pairingStatuses = pairingStatuses + (deviceId to status))
