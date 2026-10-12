package com.goride.go_installer

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private companion object {
        const val CHANNEL = "goride/installer"
        const val REQ_NOTIF = 701
    }

    private fun canInstall(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            packageManager.canRequestPackageInstalls()

    private fun ensureNotifPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (checkSelfPermission("android.permission.POST_NOTIFICATIONS")
                != android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                requestPermissions(
                    arrayOf("android.permission.POST_NOTIFICATIONS"),
                    REQ_NOTIF
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger, CHANNEL
        )
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "canInstall" ->
                    result.success(canInstall())

                "openUnknownSources" -> {
                    var ok = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val i = Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES)
                            .setData(Uri.parse("package:$packageName"))
                        try {
                            startActivity(i)
                            ok = true
                        } catch (e: Exception) {
                            ok = false
                        }
                    } else {
                        ok = true
                    }
                    result.success(ok)
                }

                "openApp" -> {
                    val pkg = call.argument<String>("package") ?: ""
                    val launch = packageManager.getLaunchIntentForPackage(pkg)
                    if (launch != null) {
                        startActivity(launch)
                        result.success(true)
                    } else {
                        result.error("NOT_FOUND", "التطبيق غير مثبت", null)
                    }
                }

                "install" -> {
                    val url = call.argument<String>("url") ?: ""
                    val md5 = call.argument<String>("md5") ?: ""
                    val app = call.argument<String>("app") ?: "app"
                    val pkg = call.argument<String>("package") ?: ""
                    val cur = InstallerService.state.get()
                    val busy = cur.phase == InstallerService.PHASE_DOWNLOAD ||
                        cur.phase == InstallerService.PHASE_VERIFY ||
                        cur.phase == InstallerService.PHASE_INSTALLING
                    if (busy) {
                        result.error("BUSY", "يوجد تثبيت قيد التشغيل", null)
                        return@setMethodCallHandler
                    }
                    if (!canInstall()) {
                        result.error(
                            "NEED_PERMISSION",
                            "تحتاج السماح بتثبيت التطبيقات غير المعروفة لمثبّت GoRide",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    ensureNotifPermission()
                    InstallerService.start(this, app, pkg, url, md5)
                    result.success(true)
                }

                "getStatus" -> {
                    val app = InstallerService.currentApp ?: run {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    val s = InstallerService.state.get()
                    result.success(
                        mapOf(
                            "app" to app,
                            "phase" to s.phase,
                            "percent" to s.percent,
                            "message" to s.message
                        )
                    )
                }

                else -> result.notImplemented()
            }
        }
    }
}