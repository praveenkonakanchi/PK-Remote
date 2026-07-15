package com.praveenkonakanchi.pkremote.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.rounded.KeyboardArrowRight
import androidx.compose.material.icons.rounded.KeyboardArrowDown
import androidx.compose.material.icons.rounded.KeyboardArrowUp
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteCommand

@Composable
fun DPad(
    enabled: Boolean,
    onCommand: (RemoteCommand) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Spacer(Modifier.weight(1f))
            RemoteButton(
                command = RemoteCommand.Up,
                icon = Icons.Rounded.KeyboardArrowUp,
                modifier = Modifier.weight(1f),
                enabled = enabled,
                onCommand = onCommand,
            )
            Spacer(Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            RemoteButton(
                command = RemoteCommand.Left,
                icon = Icons.AutoMirrored.Rounded.KeyboardArrowLeft,
                modifier = Modifier.weight(1f),
                enabled = enabled,
                onCommand = onCommand,
            )
            RemoteButton(
                command = RemoteCommand.Select,
                text = "OK",
                prominent = true,
                modifier = Modifier.weight(1f),
                enabled = enabled,
                onCommand = onCommand,
            )
            RemoteButton(
                command = RemoteCommand.Right,
                icon = Icons.AutoMirrored.Rounded.KeyboardArrowRight,
                modifier = Modifier.weight(1f),
                enabled = enabled,
                onCommand = onCommand,
            )
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Spacer(Modifier.weight(1f))
            RemoteButton(
                command = RemoteCommand.Down,
                icon = Icons.Rounded.KeyboardArrowDown,
                modifier = Modifier.weight(1f),
                enabled = enabled,
                onCommand = onCommand,
            )
            Spacer(Modifier.weight(1f))
        }
    }
}
