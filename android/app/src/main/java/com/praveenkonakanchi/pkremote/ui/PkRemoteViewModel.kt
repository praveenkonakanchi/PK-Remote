package com.praveenkonakanchi.pkremote.ui

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscovery
import com.praveenkonakanchi.pkremote.discovery.DeviceDiscoveryEvent
import com.praveenkonakanchi.pkremote.discovery.NsdDeviceDiscovery
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.pairing.DevicePairingService
import com.praveenkonakanchi.pkremote.pairing.GoogleTvPairingService
import com.praveenkonakanchi.pkremote.pairing.PairingCredentialStore
import com.praveenkonakanchi.pkremote.pairing.PairingIdentityStore
import com.praveenkonakanchi.pkremote.remote.GoogleTvRemoteCommandService
import com.praveenkonakanchi.pkremote.remote.RemoteCommandService
import com.praveenkonakanchi.pkremote.remote.RemoteTransportException
import com.praveenkonakanchi.pkremote.shortcuts.AppShortcutStore
import com.praveenkonakanchi.pkremote.shortcuts.SharedPreferencesAppShortcutStore
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
    private val shortcutStore: AppShortcutStore? = null,
    initialState: PkRemoteUiState = PkRemoteUiState(),
) : ViewModel() {
    private val storedShortcuts = shortcutStore?.load()
    private val initialShortcuts = sanitizeShortcuts(storedShortcuts ?: initialState.shortcuts)
    private val _uiState = MutableStateFlow(initialState.copy(shortcuts = initialShortcuts))
    val uiState: StateFlow<PkRemoteUiState> = _uiState.asStateFlow()

    init {
        if (storedShortcuts == null) shortcutStore?.save(initialShortcuts)
    }

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
                    val message = if (
                        command is RemoteCommand.LaunchApp && error is RemoteTransportException.AppLaunchRejected
                    ) {
                        val displayName = _uiState.value.shortcuts.firstOrNull {
                            normalizedIdentifier(it.launchIdentifier) == normalizedIdentifier(command.launchIdentifier)
                        }?.displayName ?: "this app"
                        "Couldn’t open $displayName. Make sure the app is installed on your TV, then try again."
                    } else {
                        error.message ?: "Could not send the remote command."
                    }
                    showCommandFeedback(surface, message)
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

    fun addShortcut(shortcut: RemoteAppShortcut) {
        val state = _uiState.value
        if (state.shortcuts.size >= RemoteAppShortcut.MaximumCount) return
        val normalized = normalizeShortcut(shortcut)
        if (!isValidShortcut(normalized) || containsDuplicate(state.shortcuts, normalized)) {
            showCommandFeedback(CommandSurface.StbMode, "That app is already in your shortcuts.")
            return
        }
        updateShortcuts(state.shortcuts + normalized)
    }

    fun replaceShortcut(shortcut: RemoteAppShortcut) {
        val state = _uiState.value
        val index = state.shortcuts.indexOfFirst { it.id == shortcut.id }
        if (index < 0) return
        val normalized = normalizeShortcut(shortcut)
        if (!isValidShortcut(normalized) || containsDuplicate(state.shortcuts, normalized, shortcut.id)) {
            showCommandFeedback(CommandSurface.StbMode, "That app is already in your shortcuts.")
            return
        }
        val updated = state.shortcuts.toMutableList().apply { set(index, normalized) }
        updateShortcuts(updated)
    }

    fun removeShortcut(shortcutId: String) {
        updateShortcuts(_uiState.value.shortcuts.filterNot { it.id == shortcutId })
    }

    fun moveShortcut(shortcutId: String, offset: Int) {
        val shortcuts = _uiState.value.shortcuts.toMutableList()
        val source = shortcuts.indexOfFirst { it.id == shortcutId }
        if (source < 0) return
        val destination = (source + offset).coerceIn(0, shortcuts.lastIndex)
        if (source == destination) return
        val shortcut = shortcuts.removeAt(source)
        shortcuts.add(destination, shortcut)
        updateShortcuts(shortcuts)
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
                        shortcutStore = SharedPreferencesAppShortcutStore(applicationContext),
                    ),
                ) ?: error("Unsupported ViewModel: ${modelClass.name}")
            }
        }
    }

    private fun updateShortcuts(shortcuts: List<RemoteAppShortcut>) {
        val sanitized = sanitizeShortcuts(shortcuts)
        shortcutStore?.save(sanitized)
        _uiState.update { it.copy(shortcuts = sanitized) }
    }

    private fun sanitizeShortcuts(shortcuts: List<RemoteAppShortcut>): List<RemoteAppShortcut> =
        shortcuts.asSequence()
            .map(::normalizeShortcut)
            .filter(::isValidShortcut)
            .distinctBy { normalizedIdentifier(it.launchIdentifier) }
            .take(RemoteAppShortcut.MaximumCount)
            .toList()

    private fun normalizeShortcut(shortcut: RemoteAppShortcut): RemoteAppShortcut = shortcut.copy(
        displayName = shortcut.displayName.trim(),
        launchIdentifier = shortcut.launchIdentifier.trim(),
        initials = shortcut.initials.trim().take(2).uppercase().ifEmpty {
            shortcut.displayName.trim().take(1).uppercase().ifEmpty { "•" }
        },
    )

    private fun isValidShortcut(shortcut: RemoteAppShortcut): Boolean =
        shortcut.displayName.isNotEmpty() && shortcut.launchIdentifier.isNotEmpty()

    private fun containsDuplicate(
        shortcuts: List<RemoteAppShortcut>,
        candidate: RemoteAppShortcut,
        excludingId: String? = null,
    ): Boolean = shortcuts.any { existing ->
        existing.id != excludingId && (
            (candidate.catalogId != null && existing.catalogId == candidate.catalogId) ||
                normalizedIdentifier(existing.launchIdentifier) == normalizedIdentifier(candidate.launchIdentifier)
            )
    }

    private fun normalizedIdentifier(identifier: String) = identifier.trim().lowercase().trimEnd('/')
}

private fun PkRemoteUiState.withPairingStatus(deviceId: String, status: PairingStatus): PkRemoteUiState =
    copy(pairingStatuses = pairingStatuses + (deviceId to status))
