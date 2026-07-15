package com.praveenkonakanchi.pkremote.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.ErrorOutline
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.praveenkonakanchi.pkremote.model.RemoteDevice
import com.praveenkonakanchi.pkremote.ui.PairingStatus

@Composable
fun DeviceDetailScreen(
    device: RemoteDevice,
    pairingStatus: PairingStatus,
    onBack: () -> Unit,
    onPair: () -> Unit,
    onSubmitCode: (String) -> Unit,
    onCancel: () -> Unit,
    onForget: () -> Unit,
    modifier: Modifier = Modifier,
) {
    var code by rememberSaveable(device.id) { mutableStateOf("") }
    LaunchedEffect(pairingStatus) {
        if (pairingStatus !is PairingStatus.AwaitingCode) code = ""
    }

    Column(
        modifier = modifier.fillMaxSize().padding(horizontal = 20.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "Back to Devices")
            }
            Spacer(Modifier.weight(1f))
            Text(device.name, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.SemiBold)
            Spacer(Modifier.weight(1f))
            Spacer(Modifier.padding(24.dp))
        }

        Text("Device", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 8.dp)) {
                DetailRow("Name", device.name)
                DetailRow("Type", device.kind)
                DetailRow("Status", if (device.isAvailable) "Available" else "Unavailable")
            }
        }

        Text("Pairing", style = MaterialTheme.typography.titleMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Card(
            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
            modifier = Modifier.fillMaxWidth(),
        ) {
            PairingContent(
                device = device,
                pairingStatus = pairingStatus,
                code = code,
                onCodeChange = { value -> code = value.filter { it.isDigit() || it.uppercaseChar() in 'A'..'F' }.uppercase().take(6) },
                onPair = onPair,
                onSubmitCode = { onSubmitCode(code) },
                onCancel = onCancel,
                onForget = onForget,
                modifier = Modifier.padding(20.dp),
            )
        }
    }
}

@Composable
private fun DetailRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth().padding(vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, style = MaterialTheme.typography.bodyLarge)
        Spacer(Modifier.weight(1f))
        Text(value, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
private fun PairingContent(
    device: RemoteDevice,
    pairingStatus: PairingStatus,
    code: String,
    onCodeChange: (String) -> Unit,
    onPair: () -> Unit,
    onSubmitCode: () -> Unit,
    onCancel: () -> Unit,
    onForget: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        when (pairingStatus) {
            PairingStatus.Unpaired -> {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Lock, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Text("Pair securely to control ${device.name}.")
                }
                Button(onClick = onPair, modifier = Modifier.fillMaxWidth()) { Text("Pair Device") }
            }
            PairingStatus.RequestingCode -> ProgressContent("Requesting a pairing code…", onCancel)
            PairingStatus.AwaitingCode -> {
                Text("Enter the six-character code shown on your TV.")
                OutlinedTextField(
                    value = code,
                    onValueChange = onCodeChange,
                    label = { Text("Pairing code") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Characters,
                        keyboardType = KeyboardType.Ascii,
                        imeAction = ImeAction.Done,
                    ),
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(onClick = onSubmitCode, enabled = code.length == 6, modifier = Modifier.fillMaxWidth()) {
                    Text("Pair")
                }
                TextButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) { Text("Cancel") }
            }
            PairingStatus.Pairing -> ProgressContent("Completing secure pairing…", onCancel)
            PairingStatus.Paired -> {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.CheckCircle, contentDescription = null, tint = Color(0xFF2EC866))
                    Text("Paired", color = Color(0xFF2EC866), style = MaterialTheme.typography.titleMedium)
                }
                OutlinedButton(onClick = onPair, modifier = Modifier.fillMaxWidth()) { Text("Pair Again") }
                TextButton(onClick = onForget, modifier = Modifier.fillMaxWidth()) {
                    Text("Forget Pairing", color = MaterialTheme.colorScheme.error)
                }
            }
            is PairingStatus.Failed -> {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
                    Icon(Icons.Rounded.ErrorOutline, contentDescription = null, tint = MaterialTheme.colorScheme.error)
                    Text(pairingStatus.message, color = MaterialTheme.colorScheme.error)
                }
                Button(onClick = onPair, modifier = Modifier.fillMaxWidth()) { Text("Pair Again") }
                TextButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) { Text("Cancel") }
            }
        }
    }
}

@Composable
private fun ProgressContent(message: String, onCancel: () -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        CircularProgressIndicator()
        Text(message)
    }
    TextButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) { Text("Cancel") }
}
