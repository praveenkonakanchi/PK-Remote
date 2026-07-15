package com.praveenkonakanchi.pkremote.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.FastForward
import androidx.compose.material.icons.rounded.FastRewind
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteCommand

@Composable
fun MediaControls(
    enabled: Boolean,
    onCommand: (RemoteCommand) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(modifier = modifier, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        RemoteButton(
            RemoteCommand.Rewind,
            modifier = Modifier.weight(1f),
            icon = Icons.Rounded.FastRewind,
            enabled = enabled,
            onCommand = onCommand,
        )
        RemoteButton(
            RemoteCommand.PlayPause,
            modifier = Modifier.weight(1f),
            icon = Icons.Rounded.PlayArrow,
            prominent = true,
            enabled = enabled,
            onCommand = onCommand,
        )
        RemoteButton(
            RemoteCommand.FastForward,
            modifier = Modifier.weight(1f),
            icon = Icons.Rounded.FastForward,
            enabled = enabled,
            onCommand = onCommand,
        )
    }
}
