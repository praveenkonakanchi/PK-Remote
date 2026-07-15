package com.praveenkonakanchi.pkremote.ui.screens

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.Keyboard
import androidx.compose.material.icons.rounded.Lock
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.praveenkonakanchi.pkremote.model.RemoteAppCatalogItem
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
    errorMessage: String? = null,
    onCommand: (RemoteCommand) -> Unit,
    onAddShortcut: (RemoteAppShortcut) -> Unit,
    onReplaceShortcut: (RemoteAppShortcut) -> Unit,
    onRemoveShortcut: (String) -> Unit,
    onMoveShortcut: (String, Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val enabled = device?.isPaired == true
    var isKeyboardVisible by remember { mutableStateOf(false) }
    var keyboardText by remember { mutableStateOf("") }
    var pickerTarget by remember { mutableStateOf<RemoteAppShortcut?>(null) }
    var isPickerVisible by remember { mutableStateOf(false) }
    var managedShortcut by remember { mutableStateOf<RemoteAppShortcut?>(null) }
    var customEditorTarget by remember { mutableStateOf<RemoteAppShortcut?>(null) }
    var isCustomEditorVisible by remember { mutableStateOf(false) }

    if (isKeyboardVisible) {
        KeyboardInputDialog(
            text = keyboardText,
            onTextChange = { keyboardText = it },
            onDismiss = {
                isKeyboardVisible = false
                keyboardText = ""
            },
            onSend = {
                if (keyboardText.isNotEmpty()) onCommand(RemoteCommand.EnterText(keyboardText))
                isKeyboardVisible = false
                keyboardText = ""
            },
        )
    }

    managedShortcut?.let { shortcut ->
        ShortcutManagementDialog(
            shortcut = shortcut,
            index = shortcuts.indexOfFirst { it.id == shortcut.id },
            shortcutCount = shortcuts.size,
            onDismiss = { managedShortcut = null },
            onReplace = {
                managedShortcut = null
                pickerTarget = shortcut
                isPickerVisible = true
            },
            onMove = { offset ->
                onMoveShortcut(shortcut.id, offset)
                managedShortcut = null
            },
            onRemove = {
                onRemoveShortcut(shortcut.id)
                managedShortcut = null
            },
        )
    }

    if (isPickerVisible) {
        ShortcutPickerDialog(
            currentShortcut = pickerTarget,
            shortcuts = shortcuts,
            onDismiss = { isPickerVisible = false },
            onSelect = { shortcut ->
                if (pickerTarget == null) onAddShortcut(shortcut) else onReplaceShortcut(shortcut)
                isPickerVisible = false
            },
            onAdvanced = {
                customEditorTarget = pickerTarget
                isPickerVisible = false
                isCustomEditorVisible = true
            },
        )
    }

    if (isCustomEditorVisible) {
        CustomShortcutDialog(
            currentShortcut = customEditorTarget,
            onDismiss = { isCustomEditorVisible = false },
            onSave = { shortcut ->
                if (customEditorTarget == null) onAddShortcut(shortcut) else onReplaceShortcut(shortcut)
                isCustomEditorVisible = false
            },
        )
    }

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
                RemoteButton(
                    RemoteCommand.Keyboard,
                    Modifier.weight(1f),
                    Icons.Rounded.Keyboard,
                    enabled = enabled,
                    onCommand = { isKeyboardVisible = true },
                )
                RemoteButton(RemoteCommand.StbSettings, Modifier.weight(1f), Icons.Rounded.Settings, enabled = enabled, onCommand = onCommand)
            }
            PortalControls(enabled, onCommand)
            MediaControls(enabled = enabled, onCommand = onCommand)
            ShortcutGrid(
                shortcuts = shortcuts,
                launchEnabled = enabled,
                onLaunch = { onCommand(RemoteCommand.LaunchApp(it.launchIdentifier)) },
                onManage = { managedShortcut = it },
                onAdd = {
                    pickerTarget = null
                    isPickerVisible = true
                },
            )
            if (errorMessage != null) {
                Text(errorMessage, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodyMedium)
            }
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
private fun KeyboardInputDialog(
    text: String,
    onTextChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onSend: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("TV Keyboard") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text("Select a text field on your TV, then enter the text to send.")
                OutlinedTextField(
                    value = text,
                    onValueChange = onTextChange,
                    label = { Text("Text") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Send),
                    keyboardActions = KeyboardActions(onSend = { if (text.isNotEmpty()) onSend() }),
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = { Button(onClick = onSend, enabled = text.isNotEmpty()) { Text("Send") } },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
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
                contentPadding = PaddingValues(horizontal = 4.dp),
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Box(Modifier.size(9.dp).background(color, CircleShape))
                    Spacer(Modifier.width(6.dp))
                    Text(title, maxLines = 1, style = MaterialTheme.typography.labelLarge)
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ShortcutGrid(
    shortcuts: List<RemoteAppShortcut>,
    launchEnabled: Boolean,
    onLaunch: (RemoteAppShortcut) -> Unit,
    onManage: (RemoteAppShortcut) -> Unit,
    onAdd: () -> Unit,
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
                        Surface(
                            modifier = Modifier
                                .weight(1f)
                                .heightIn(min = 58.dp)
                                .combinedClickable(
                                    onClick = { if (launchEnabled) onLaunch(shortcut) },
                                    onLongClick = { onManage(shortcut) },
                                )
                                .semantics { contentDescription = "Open ${shortcut.displayName}" },
                            shape = RoundedCornerShape(16.dp),
                            color = MaterialTheme.colorScheme.secondaryContainer,
                        ) {
                            Column(
                                modifier = Modifier.padding(4.dp),
                                horizontalAlignment = Alignment.CenterHorizontally,
                                verticalArrangement = Arrangement.Center,
                            ) {
                                Text(shortcut.initials, color = MaterialTheme.colorScheme.primary, fontWeight = FontWeight.Bold)
                                Text(shortcut.displayName, maxLines = 1, style = MaterialTheme.typography.labelSmall)
                            }
                        }
                    } else {
                        FilledTonalButton(
                            onClick = onAdd,
                            modifier = Modifier.weight(1f).heightIn(min = 58.dp)
                                .semantics { contentDescription = "Add app shortcut" },
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

@Composable
private fun ShortcutPickerDialog(
    currentShortcut: RemoteAppShortcut?,
    shortcuts: List<RemoteAppShortcut>,
    onDismiss: () -> Unit,
    onSelect: (RemoteAppShortcut) -> Unit,
    onAdvanced: () -> Unit,
) {
    val occupied = shortcuts.filterNot { it.id == currentShortcut?.id }
    val available = RemoteAppCatalogItem.verified.filter { item ->
        occupied.none { shortcut ->
            shortcut.catalogId == item.id || normalizedIdentifier(shortcut.launchIdentifier) == normalizedIdentifier(item.launchIdentifier)
        }
    }
    Dialog(onDismissRequest = onDismiss) {
        Surface(shape = RoundedCornerShape(28.dp), color = MaterialTheme.colorScheme.surface) {
            Column(Modifier.padding(vertical = 20.dp)) {
                Text(
                    if (currentShortcut == null) "Add Shortcut" else "Replace Shortcut",
                    modifier = Modifier.padding(horizontal = 24.dp),
                    style = MaterialTheme.typography.headlineSmall,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    "Popular Apps",
                    modifier = Modifier.padding(start = 24.dp, top = 16.dp, end = 24.dp, bottom = 6.dp),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.primary,
                )
                LazyColumn(Modifier.heightIn(max = 380.dp)) {
                    items(available, key = { it.id }) { item ->
                        TextButton(
                            onClick = { onSelect(item.makeShortcut(currentShortcut?.id ?: java.util.UUID.randomUUID().toString())) },
                            modifier = Modifier.fillMaxWidth(),
                            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 10.dp),
                        ) {
                            ShortcutIcon(item.initials)
                            Text(item.displayName, modifier = Modifier.weight(1f).padding(start = 12.dp), textAlign = TextAlign.Start)
                            Icon(Icons.Rounded.Add, contentDescription = null)
                        }
                    }
                    item {
                        HorizontalDivider(Modifier.padding(vertical = 6.dp))
                        TextButton(
                            onClick = onAdvanced,
                            modifier = Modifier.fillMaxWidth(),
                            contentPadding = PaddingValues(horizontal = 24.dp, vertical = 10.dp),
                        ) {
                            Text("Advanced / Custom Shortcut", modifier = Modifier.weight(1f), textAlign = TextAlign.Start)
                        }
                    }
                }
                TextButton(onClick = onDismiss, modifier = Modifier.align(Alignment.End).padding(end = 16.dp)) { Text("Cancel") }
            }
        }
    }
}

@Composable
private fun ShortcutManagementDialog(
    shortcut: RemoteAppShortcut,
    index: Int,
    shortcutCount: Int,
    onDismiss: () -> Unit,
    onReplace: () -> Unit,
    onMove: (Int) -> Unit,
    onRemove: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(shortcut.displayName) },
        text = {
            Column {
                TextButton(onClick = onReplace, modifier = Modifier.fillMaxWidth()) { Text("Replace Shortcut") }
                TextButton(onClick = { onMove(-1) }, enabled = index > 0, modifier = Modifier.fillMaxWidth()) { Text("Move Earlier") }
                TextButton(onClick = { onMove(1) }, enabled = index in 0 until shortcutCount - 1, modifier = Modifier.fillMaxWidth()) { Text("Move Later") }
                TextButton(onClick = onRemove, modifier = Modifier.fillMaxWidth()) {
                    Text("Remove Shortcut", color = MaterialTheme.colorScheme.error)
                }
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Done") } },
    )
}

@Composable
private fun CustomShortcutDialog(
    currentShortcut: RemoteAppShortcut?,
    onDismiss: () -> Unit,
    onSave: (RemoteAppShortcut) -> Unit,
) {
    var displayName by remember(currentShortcut?.id) { mutableStateOf(currentShortcut?.displayName.orEmpty()) }
    var launchIdentifier by remember(currentShortcut?.id) { mutableStateOf(currentShortcut?.launchIdentifier.orEmpty()) }
    val valid = displayName.isNotBlank() && launchIdentifier.isNotBlank()
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Advanced Shortcut") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Custom shortcuts require a Remote v2 launch identifier supported by your TV.")
                OutlinedTextField(
                    value = displayName,
                    onValueChange = { displayName = it },
                    label = { Text("Display name") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = launchIdentifier,
                    onValueChange = { launchIdentifier = it },
                    label = { Text("Launch identifier") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        },
        confirmButton = {
            Button(
                onClick = {
                    onSave(
                        RemoteAppShortcut.custom(
                            id = currentShortcut?.id ?: java.util.UUID.randomUUID().toString(),
                            displayName = displayName,
                            launchIdentifier = launchIdentifier,
                        ),
                    )
                },
                enabled = valid,
            ) { Text("Save") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}

@Composable
private fun ShortcutIcon(initials: String) {
    Surface(shape = RoundedCornerShape(8.dp), color = MaterialTheme.colorScheme.primary) {
        Text(
            initials,
            modifier = Modifier.size(32.dp).padding(top = 6.dp),
            color = MaterialTheme.colorScheme.onPrimary,
            fontWeight = FontWeight.Bold,
            textAlign = TextAlign.Center,
        )
    }
}

private fun normalizedIdentifier(identifier: String) = identifier.trim().lowercase().trimEnd('/')
