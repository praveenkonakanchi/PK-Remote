package com.praveenkonakanchi.pkremote.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GridView
import androidx.compose.material.icons.rounded.SettingsRemote
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.praveenkonakanchi.pkremote.ui.screens.DevicesScreen
import com.praveenkonakanchi.pkremote.ui.screens.DeviceDetailScreen
import com.praveenkonakanchi.pkremote.ui.screens.RemoteScreen
import com.praveenkonakanchi.pkremote.ui.screens.StbModeScreen

private enum class Destination(val label: String, val icon: ImageVector) {
    Devices("Devices", Icons.Rounded.Tv),
    Remote("Remote", Icons.Rounded.SettingsRemote),
    StbMode("STB Mode", Icons.Rounded.GridView),
}

@Composable
fun PkRemoteApp() {
    val context = LocalContext.current.applicationContext
    val factory = remember(context) { PkRemoteViewModel.factory(context) }
    val viewModel: PkRemoteViewModel = viewModel(factory = factory)
    PkRemoteApp(viewModel)
}

@Composable
fun PkRemoteApp(viewModel: PkRemoteViewModel) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    var destinationName by rememberSaveable { mutableStateOf(Destination.Devices.name) }
    var detailDeviceId by rememberSaveable { mutableStateOf<String?>(null) }
    val destination = remember(destinationName) { Destination.valueOf(destinationName) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                Destination.entries.forEach { item ->
                    NavigationBarItem(
                        selected = item == destination,
                        onClick = { destinationName = item.name },
                        icon = { Icon(item.icon, contentDescription = null) },
                        label = { Text(item.label) },
                    )
                }
            }
        },
    ) { padding ->
        val detailDevice = detailDeviceId?.let { id -> state.devices.firstOrNull { it.id == id } }
        if (destination == Destination.Devices && detailDevice != null) {
            DeviceDetailScreen(
                device = detailDevice,
                pairingStatus = state.pairingStatus(detailDevice.id),
                onBack = { detailDeviceId = null },
                onPair = { viewModel.requestPairingCode(detailDevice.id) },
                onSubmitCode = { code -> viewModel.submitPairingCode(detailDevice.id, code) },
                onCancel = { viewModel.cancelPairing(detailDevice.id) },
                onForget = { viewModel.forgetPairing(detailDevice.id) },
                modifier = Modifier.padding(padding),
            )
        } else when (destination) {
            Destination.Devices -> DevicesScreen(
                devices = state.devices,
                selectedDeviceId = state.selectedDeviceId,
                discoveryStatus = state.discoveryStatus,
                onSelectDevice = { deviceId ->
                    viewModel.selectDevice(deviceId)
                    detailDeviceId = deviceId
                },
                onStartDiscovery = viewModel::startDiscovery,
                onStopDiscovery = viewModel::stopDiscovery,
                modifier = Modifier.padding(padding),
            )
            Destination.Remote -> RemoteScreen(
                device = state.selectedDevice,
                errorMessage = state.commandFeedback?.takeIf { it.surface == CommandSurface.Remote }?.message,
                onCommand = { viewModel.handleCommand(it, CommandSurface.Remote) },
                modifier = Modifier.padding(padding),
            )
            Destination.StbMode -> StbModeScreen(
                device = state.selectedDevice,
                shortcuts = state.shortcuts,
                errorMessage = state.commandFeedback?.takeIf { it.surface == CommandSurface.StbMode }?.message,
                onCommand = { viewModel.handleCommand(it, CommandSurface.StbMode) },
                modifier = Modifier.padding(padding),
            )
        }
    }
}
