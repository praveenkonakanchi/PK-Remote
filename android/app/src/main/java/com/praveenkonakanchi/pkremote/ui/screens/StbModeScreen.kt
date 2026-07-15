package com.praveenkonakanchi.pkremote.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteAppShortcut
import com.praveenkonakanchi.pkremote.model.RemoteCommand
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.ui.components.DPad
import com.praveenkonakanchi.pkremote.ui.components.MediaControls
import com.praveenkonakanchi.pkremote.ui.components.RemoteButton

@Composable
fun StbModeScreen(
    device: RemoteDevice?,
    shortcuts: List<RemoteAppShortcut>,
    onCommand: (RemoteCommand) -> Unit,
    modifier: Modifier = Modifier,
) {
    val enabled = device?.isPaired == true
    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val sectionSpacing = if (maxHeight < 700.dp) 6.dp else 10.dp
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(sectionSpacing),
        ) {
            Text(
                "STB Mode",
                modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            DPad(enabled = enabled, onCommand = onCommand)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                RemoteButton(RemoteCommand.Home, Modifier.weight(1f), Icons.Rounded.Home, enabled = enabled, onCommand = onCommand)
                RemoteButton(RemoteCommand.Back, Modifier.weight(1f), Icons.AutoMirrored.Rounded.ArrowBack, enabled = enabled, onCommand = onCommand)
                RemoteButton(RemoteCommand.Keyboard, Modifier.weight(1f), Icons.Rounded.Keyboard, enabled = enabled, onCommand = onCommand)
                RemoteButton(RemoteCommand.StbSettings, Modifier.weight(1f), Icons.Rounded.Settings, enabled = enabled, onCommand = onCommand)
            }
            PortalControls(enabled, onCommand)
            MediaControls(enabled = enabled, onCommand = onCommand)
            ShortcutGrid(shortcuts, enabled, onCommand)
            if (!enabled) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Lock, null, tint = Color(0xFFFF922B))
                    Text("Pair this TV from Devices to enable STB controls.", color = Color(0xFFFF922B))
                }
            }
        }
    }
}

@Composable
private fun PortalControls(enabled: Boolean, onCommand: (RemoteCommand) -> Unit) {
    val actions = listOf(
        Triple(RemoteCommand.View, "View", Color(0xFFFF3B30)),
        Triple(RemoteCommand.Sort, "Sort", Color(0xFF2EC866)),
        Triple(RemoteCommand.Favorites, "Favorites", Color(0xFFFFCC00)),
        Triple(RemoteCommand.Find, "Find", Color(0xFF2196F3)),
    )
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        actions.forEach { (command, title, color) ->
            FilledTonalButton(
                onClick = { onCommand(command) },
                modifier = Modifier.weight(1f).heightIn(min = 52.dp)
                    .semantics { contentDescription = command.accessibilityLabel },
                enabled = enabled,
                shape = RoundedCornerShape(16.dp),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 4.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(
                        modifier = Modifier
                            .size(9.dp)
                            .background(color, CircleShape),
                    )
                    Spacer(Modifier.width(6.dp))
                    Text(title, maxLines = 1, style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}

@Composable
private fun ShortcutGrid(
    shortcuts: List<RemoteAppShortcut>,
    enabled: Boolean,
    onCommand: (RemoteCommand) -> Unit,
) {
    val cells: List<RemoteAppShortcut?> = buildList {
        addAll(shortcuts.take(RemoteAppShortcut.MaximumCount))
        if (size < RemoteAppShortcut.MaximumCount) add(null)
    }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        cells.chunked(4).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                row.forEach { shortcut ->
                    if (shortcut != null) {
                        FilledTonalButton(
                            onClick = { onCommand(RemoteCommand.LaunchApp(shortcut.launchIdentifier)) },
                            modifier = Modifier.weight(1f).heightIn(min = 58.dp)
                                .semantics { contentDescription = "Open ${shortcut.displayName}" },
                            enabled = enabled,
                            shape = RoundedCornerShape(16.dp),
                            contentPadding = androidx.compose.foundation.layout.PaddingValues(4.dp),
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(shortcut.initials, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                                Text(shortcut.displayName, maxLines = 1, style = MaterialTheme.typography.labelSmall)
                            }
                        }
                    } else {
                        FilledTonalButton(
                            onClick = {},
                            modifier = Modifier.weight(1f).heightIn(min = 58.dp)
                                .semantics { contentDescription = "Add app shortcut" },
                            enabled = enabled,
                            shape = RoundedCornerShape(16.dp),
                        ) {
                            Icon(Icons.Rounded.Add, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}
