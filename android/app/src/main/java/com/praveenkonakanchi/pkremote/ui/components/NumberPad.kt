package com.praveenkonakanchi.pkremote.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteCommand

@Composable
fun NumberPad(
    enabled: Boolean,
    onCommand: (RemoteCommand) -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        (1..9).chunked(3).forEach { row ->
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                row.forEach { number ->
                    RemoteButton(
                        command = RemoteCommand.Digit(number),
                        text = number.toString(),
                        modifier = Modifier.weight(1f),
                        enabled = enabled,
                        onCommand = onCommand,
                    )
                }
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Spacer(Modifier.weight(1f))
            RemoteButton(
                command = RemoteCommand.Digit(0),
                text = "0",
                modifier = Modifier.weight(1f),
                enabled = enabled,
                onCommand = onCommand,
            )
            Spacer(Modifier.weight(1f))
        }
    }
}
