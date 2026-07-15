package com.praveenkonakanchi.pkremote.ui.components

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteCommand

@Composable
fun RemoteButton(
    command: RemoteCommand,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    text: String? = null,
    prominent: Boolean = false,
    enabled: Boolean = true,
    onCommand: (RemoteCommand) -> Unit,
) {
    val content: @Composable () -> Unit = {
        Box(
            modifier = Modifier.padding(horizontal = 4.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (icon != null) {
                Icon(icon, contentDescription = null)
            } else {
                Text(
                    text = text ?: command.accessibilityLabel,
                    fontWeight = FontWeight.SemiBold,
                )
            }
        }
    }
    val buttonModifier = modifier
        .heightIn(min = 52.dp)
        .semantics { contentDescription = command.accessibilityLabel }

    if (prominent) {
        Button(
            onClick = { onCommand(command) },
            modifier = buttonModifier,
            enabled = enabled,
            shape = RoundedCornerShape(16.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
            ),
            content = { content() },
        )
    } else {
        FilledTonalButton(
            onClick = { onCommand(command) },
            modifier = buttonModifier,
            enabled = enabled,
            shape = RoundedCornerShape(16.dp),
            content = { content() },
        )
    }
}
