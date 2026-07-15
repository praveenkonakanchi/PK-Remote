package com.praveenkonakanchi.pkremote.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Circle
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.material.icons.rounded.TvOff
import androidx.compose.material.icons.rounded.WarningAmber
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.lifecycle.compose.LifecycleStartEffect
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.ui.DiscoveryStatus

@Composable
fun DevicesScreen(
    devices: List<RemoteDevice>,
    selectedDeviceId: String?,
    discoveryStatus: DiscoveryStatus,
    onSelectDevice: (String) -> Unit,
    onStartDiscovery: () -> Unit,
    onStopDiscovery: () -> Unit,
    modifier: Modifier = Modifier,
) {
    LifecycleStartEffect(Unit) {
        onStartDiscovery()
        onStopOrDispose { onStopDiscovery() }
    }

    Column(
        modifier = modifier.fillMaxSize().padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("Devices", style = MaterialTheme.typography.headlineLarge, fontWeight = FontWeight.Bold)
            Spacer(Modifier.weight(1f))
            IconButton(
                onClick = onStartDiscovery,
                enabled = discoveryStatus != DiscoveryStatus.Searching,
                modifier = Modifier.semantics { contentDescription = "Refresh devices" },
            ) {
                if (discoveryStatus == DiscoveryStatus.Searching) {
                    CircularProgressIndicator(Modifier.size(24.dp), strokeWidth = 2.dp)
                } else {
                    Icon(Icons.Rounded.Refresh, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                }
            }
        }
        Text("Google TV", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        if (devices.isEmpty()) {
            EmptyDiscoveryState(
                discoveryStatus = discoveryStatus,
                onRetry = onStartDiscovery,
                modifier = Modifier.fillMaxWidth().weight(1f),
            )
        } else {
            Card(
                shape = RoundedCornerShape(24.dp),
                colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            ) {
                LazyColumn {
                    items(devices, key = { it.id }) { device ->
                        DeviceRow(
                            device = device,
                            selected = device.id == selectedDeviceId,
                            onClick = { onSelectDevice(device.id) },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyDiscoveryState(
    discoveryStatus: DiscoveryStatus,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val (title, description) = when (discoveryStatus) {
        DiscoveryStatus.Idle -> "No TVs found" to "Make sure your TV is on and connected to the same Wi-Fi network."
        DiscoveryStatus.Searching -> "Searching" to "Looking for Google TV devices on your local network."
        is DiscoveryStatus.Failed -> "Discovery failed" to discoveryStatus.message
    }
    val icon = when (discoveryStatus) {
        DiscoveryStatus.Idle -> Icons.Rounded.TvOff
        DiscoveryStatus.Searching -> Icons.Rounded.Search
        is DiscoveryStatus.Failed -> Icons.Rounded.WarningAmber
    }

    Box(modifier, contentAlignment = Alignment.Center) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.padding(24.dp),
        ) {
            Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.primary, modifier = Modifier.size(48.dp))
            Text(title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Text(description, color = MaterialTheme.colorScheme.onSurfaceVariant)
            when (discoveryStatus) {
                DiscoveryStatus.Searching -> CircularProgressIndicator(Modifier.size(28.dp), strokeWidth = 3.dp)
                is DiscoveryStatus.Failed -> Button(onClick = onRetry) { Text("Try again") }
                DiscoveryStatus.Idle -> Unit
            }
        }
    }
}

@Composable
private fun DeviceRow(device: RemoteDevice, selected: Boolean, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(16.dp)
            .semantics {
                contentDescription = "${device.name}, ${device.kind}, ${if (device.isPaired) "paired" else "available"}"
            },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Box(
            modifier = Modifier.size(48.dp).clip(RoundedCornerShape(14.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(Icons.Rounded.Tv, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
        }
        Column {
            Text(device.name, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(device.kind, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.weight(1f))
        when {
            selected -> Icon(Icons.Rounded.CheckCircle, "Selected", tint = MaterialTheme.colorScheme.primary)
            device.isPaired -> Icon(Icons.Rounded.CheckCircle, null, tint = MaterialTheme.colorScheme.primary)
            device.isAvailable -> Icon(
                Icons.Rounded.Circle,
                "Available",
                tint = Color(0xFF2EC866),
                modifier = Modifier.size(14.dp),
            )
        }
    }
}
