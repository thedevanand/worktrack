package com.dev.alootrack

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Re-launches MainActivity after reboot so the Dart side can restore
 * the foreground service if a shift was active when the device powered down.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != "android.intent.action.LOCKED_BOOT_COMPLETED") return

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
            putExtra("boot_restore", true)
        }
        context.startActivity(launchIntent)
    }
}
