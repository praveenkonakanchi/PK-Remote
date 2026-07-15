package com.praveenkonakanchi.pkremote

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.praveenkonakanchi.pkremote.ui.PkRemoteApp
import com.praveenkonakanchi.pkremote.ui.theme.PkRemoteTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PkRemoteTheme {
                PkRemoteApp()
            }
        }
    }
}
