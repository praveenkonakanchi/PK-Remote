package com.praveenkonakanchi.pkremote.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.VolumeDown
import androidx.compose.material.icons.automirrored.rounded.VolumeOff
import androidx.compose.material.icons.automirrored.rounded.VolumeUp
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.PowerSettingsNew
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material.icons.rounded.Tv
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.ui.components.DPad
import com.praveenkonakanchi.pkremote.ui.components.MediaControls
import com.praveenkonakanchi.pkremote.ui.components.NumberPad
import com.praveenkonakanchi.pkremote.ui.components.RemoteButton

@Composable
fun RemoteScreen(
    device: RemoteDevice?,
    onCommand: (RemoteCommand) -> Unit,
    modifier: Modifier = Modifier,
) {
    val enabled = device?.isPaired == true
    Column(
        modifier = modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text(
            "Remote",
            modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp),
            style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        )
        DeviceHeader(device)
        if (!enabled) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Lock, contentDescription = null, tint = Color(0xFFFF922B))
                Text("Pair this TV from Devices to enable remote controls.", color = Color(0xFFFF922B))
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            RemoteButton(RemoteCommand.Power, Modifier.weight(1f), Icons.Rounded.PowerSettingsNew, enabled = enabled, onCommand = onCommand)
            RemoteButton(RemoteCommand.Home, Modifier.weight(1f), Icons.Rounded.Home, enabled = enabled, onCommand = onCommand)
            RemoteButton(RemoteCommand.Back, Modifier.weight(1f), Icons.AutoMirrored.Rounded.ArrowBack, enabled = enabled, onCommand = onCommand)
            RemoteButton(RemoteCommand.GoogleTvQuickSettings, Modifier.weight(1f), Icons.Rounded.Settings, enabled = enabled, onCommand = onCommand)
        }
        DPad(enabled = enabled, onCommand = onCommand)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            RemoteButton(RemoteCommand.VolumeDown, Modifier.weight(1f), Icons.AutoMirrored.Rounded.VolumeDown, enabled = enabled, onCommand = onCommand)
            RemoteButton(RemoteCommand.Mute, Modifier.weight(1f), Icons.AutoMirrored.Rounded.VolumeOff, enabled = enabled, onCommand = onCommand)
            RemoteButton(RemoteCommand.VolumeUp, Modifier.weight(1f), Icons.AutoMirrored.Rounded.VolumeUp, enabled = enabled, onCommand = onCommand)
        }
        MediaControls(enabled = enabled, onCommand = onCommand)
        NumberPad(enabled = enabled, onCommand = onCommand)
        Spacer(Modifier.padding(bottom = 8.dp))
    }
}

@Composable
private fun DeviceHeader(device: RemoteDevice?) {
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Icon(Icons.Rounded.Tv, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Text(device?.name ?: "No device", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            Text(
                if (device?.isPaired == true) "Paired" else "Not paired",
                color = if (device?.isPaired == true) Color(0xFF2EC866) else Color(0xFFFF922B),
            )
        }
    }
}
