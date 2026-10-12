package com.goride.go_installer

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageInstaller
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicReference

class InstallerService : Service() {

    companion object {
        const val ACTION = "com.goride.go_installer.INSTALLER_SERVICE"
        const val ACTION_INSTALL_RESULT = "com.goride.go_installer.INSTALL_SESSION"
        const val CHANNEL_ID = "goride_installer"
        const val NOTIF_ID = 42

        const val PHASE_IDLE = 0
        const val PHASE_DOWNLOAD = 1
        const val PHASE_VERIFY = 2
        const val PHASE_INSTALLING = 3
        const val PHASE_DONE = 4
        const val PHASE_ERROR = 5

        data class State(
            val phase: Int = PHASE_IDLE,
            val percent: Int = 0,
            val message: String = ""
        )

        val state = AtomicReference(State())
        var currentApp: String? = null

        fun start(
            ctx: Context,
            app: String,
            packageName: String,
            url: String,
            md5: String
        ) {
            currentApp = app
            state.set(State(PHASE_DOWNLOAD, 0))
            val i = Intent(ctx, InstallerService::class.java).apply {
                putExtra("app", app)
                putExtra("package", packageName)
                putExtra("url", url)
                putExtra("md5", md5)
                action = ACTION
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }
    }

    private var receiverRegistered = false
    private var wakeLock: PowerManager.WakeLock? = null
    private var notifiedStartTime = 0L

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val status = intent?.getIntExtra(PackageInstaller.EXTRA_STATUS, Int.MIN_VALUE)
            val app = intent?.getStringExtra("extra_app") ?: currentApp ?: "app"
            when (status) {
                PackageInstaller.STATUS_SUCCESS -> finishOk(app)
                PackageInstaller.STATUS_FAILURE,
                PackageInstaller.STATUS_FAILURE_ABORTED,
                PackageInstaller.STATUS_FAILURE_BLOCKED,
                PackageInstaller.STATUS_FAILURE_CONFLICT,
                PackageInstaller.STATUS_FAILURE_INCOMPATIBLE,
                PackageInstaller.STATUS_FAILURE_INVALID,
                PackageInstaller.STATUS_FAILURE_STORAGE -> {
                    val msg = intent?.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE)
                    fail(app, if (!msg.isNullOrBlank()) msg else statusText(status))
                }
            }
        }
    }

    private fun statusText(status: Int): String =
        if (status == PackageInstaller.STATUS_FAILURE_BLOCKED) {
            "تم إلغاء التثبيت — تحقق من إعدادات التثبيت من مصادر خارجية"
        } else {
            "فشل التثبيت — حاول مرة أخرى"
        }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null || intent.action != ACTION) {
            stopSelf()
            return START_NOT_STICKY
        }
        ensureReceiver()
        val app = intent.getStringExtra("app") ?: "app"
        val pkg = intent.getStringExtra("package") ?: ""
        val url = intent.getStringExtra("url") ?: return START_NOT_STICKY.stopNow()
        val md5 = intent.getStringExtra("md5") ?: ""
        currentApp = app

        createChannel()
        val notif = buildNotif("جارٍ التنزيل…", 0)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(NOTIF_ID, notif)
        }

        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "goride:install").apply {
            setReferenceCounted(false)
            acquire(30 * 60 * 1000L)
        }

        Thread {
            try {
                notifyProgress(PHASE_DOWNLOAD, 0, "جارٍ التنزيل…")
                val file = download(url, app) { p -> notifyProgress(PHASE_DOWNLOAD, p, "جارٍ التنزيل… $p%") }
                notifyProgress(PHASE_VERIFY, 0, "جارٍ التحقق من سلامة الملف…")
                if (md5.isNotEmpty() && !md5(file).equals(md5, ignoreCase = true)) {
                    fail(app, "الملف تالف أثناء التنزيل — أعد المحاولة")
                    return@Thread
                }
                startInstall(file, app)
            } catch (e: Exception) {
                fail(app, cleanError(e))
            }
        }.start()

        return START_NOT_STICKY
    }

    private fun Int.stopNow(): Int {
        stopSelf()
        return START_NOT_STICKY
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "تثبيت GoRide",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                setShowBadge(false)
                description = "شريط تقدم التنزيل والتثبيت"
            }
            nm.createNotificationChannel(ch)
        }
    }

    private fun launchIntent(app: String): PendingIntent {
        val pkg = intentForApp(app)
        val target = if (pkg != null) {
            Intent(Intent.ACTION_VIEW).setPackage(pkg)
        } else {
            Intent(this, MainActivity::class.java)
        }
        target.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        return PendingIntent.getActivity(
            this, 7, target,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun intentForApp(app: String): String? = when (app) {
        "driver" -> "com.goride.driver"
        "customer" -> "com.goride.customer"
        else -> null
    }

    private fun buildNotif(text: String, progress: Int): Notification {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(findOrCreateChannel())
        }
        val pi = launchIntent(currentApp ?: "")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_install)
            .setContentTitle("مثبّت GoRide")
            .setContentText(text)
            .setContentIntent(pi)
            .setOngoing(progress > 0 && progress < 100)
            .setOnlyAlertOnce(true)
            .setAutoCancel(true)
        if (progress > 0) {
            builder.setProgress(100, progress.coerceIn(0, 100), progress >= 100)
        }
        return builder.build()
    }

    private fun findOrCreateChannel(): NotificationChannel {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        var ch = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.getNotificationChannel(CHANNEL_ID)
        } else {
            null
        }
        if (ch == null) {
            ch = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationChannel(
                    CHANNEL_ID,
                    "تثبيت GoRide",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    setShowBadge(false)
                    description = "شريط تقدم التنزيل والتثبيت"
                }
            } else {
                null
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ch?.let { nm.createNotificationChannel(it) }
        }
        return ch!!
    }

    private fun notifyProgress(phase: Int, percent: Int, text: String) {
        state.set(State(phase, percent, text))
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (phase == PHASE_INSTALLING || percent >= 100) {
            nm.notify(NOTIF_ID, buildNotif(text, percent))
        } else {
            nm.notify(NOTIF_ID, buildNotif(text, percent))
        }
    }

    private fun finishOk(app: String) {
        state.set(State(PHASE_DONE, 100, "تم التثبيت بنجاح"))
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotif("تم التثبيت بنجاح", 100))
        val pkg = intentForApp(app)
        if (pkg != null) {
            try {
                val launch = packageManager.getLaunchIntentForPackage(pkg)
                if (launch != null) {
                    launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(launch)
                }
            } catch (_: Exception) {
            }
        }
        cleanup()
        // إزالة الإشعار بعد نجاح موجز
        Thread {
            try {
                Thread.sleep(4000)
                nm.cancel(NOTIF_ID)
            } catch (_: Exception) {
            }
        }.start()
    }

    private fun fail(app: String, message: String) {
        state.set(State(PHASE_ERROR, 0, message))
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIF_ID, buildNotif("فشل: $message", 0))
        cleanup()
    }

    private fun cleanup() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (_: Exception) {
        }
        wakeLock = null
        if (receiverRegistered) {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
            receiverRegistered = false
        }
        stopSelf()
    }

    private fun ensureReceiver() {
        if (receiverRegistered) return
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(
                    receiver,
                    IntentFilter(ACTION_INSTALL_RESULT),
                    Context.RECEIVER_NOT_EXPORTED
                )
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(receiver, IntentFilter(ACTION_INSTALL_RESULT))
            }
            receiverRegistered = true
        } catch (_: Exception) {
        }
    }

    private fun cleanError(e: Exception): String {
        val m = e.message ?: return "حدث خطأ غير متوقع"
        return when {
            m.contains("HTTP", ignoreCase = true) -> "تعذر الوصول للخادم — تحقق من الإنترنت"
            m.contains("Unable to resolve host", ignoreCase = true) ||
                m.contains("UnknownHost", ignoreCase = true) ->
                "تعذر الوصول للخادم — تحقق من الإنترنت"
            m.contains("handshake", ignoreCase = true) -> "منفذنا غير متاح — تحقق من الإنترنت"
            m.contains("SecurityException", ignoreCase = true) -> "لا تملك صلاحية التثبيت"
            else -> m
        }
    }

    private fun download(urlStr: String, app: String, onPercent: (Int) -> Unit): File {
        val dir = File(filesDir, "apks").apply { mkdirs() }
        val file = File(dir, "$app-${System.currentTimeMillis()}.apk")
        val url = URL(urlStr)
        var conn: HttpURLConnection? = null
        try {
            conn = (url.openConnection() as HttpURLConnection).apply {
                connectTimeout = 15000
                readTimeout = 30000
                instanceFollowRedirects = true
            }
            conn.connect()
            val code = conn.responseCode
            if (code !in 200..299) {
                throw IllegalStateException("HTTP $code")
            }
            val total = conn.contentLengthLong
            var done = 0L
            conn.inputStream.use { input ->
                FileOutputStream(file).use { out ->
                    val buf = ByteArray(65536)
                    while (true) {
                        val r = input.read(buf)
                        if (r < 0) break
                        out.write(buf, 0, r)
                        done += r
                        if (total > 0) {
                            onPercent(((done * 100) / total).toInt().coerceIn(0, 100))
                        }
                    }
                }
            }
        } finally {
            conn?.disconnect()
        }
        return file
    }

    private fun md5(file: File): String {
        val md = MessageDigest.getInstance("MD5")
        file.inputStream().use { ins ->
            val buf = ByteArray(65536)
            while (true) {
                val r = ins.read(buf)
                if (r < 0) break
                md.update(buf, 0, r)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    private val sessionCallback = object : PackageInstaller.SessionCallback() {
        override fun onCreated(sessionId: Int) {
        }

        override fun onBadgingChanged(sessionId: Int) {
        }

        override fun onActiveChanged(sessionId: Int, active: Boolean) {
        }

        override fun onProgressChanged(sessionId: Int, progress: Float) {
            val p = progress.toInt().coerceIn(0, 100)
            state.set(State(PHASE_INSTALLING, p, "جارٍ التثبيت… $p%"))
            notifyProgress(PHASE_INSTALLING, p, "جارٍ التثبيت… $p%")
        }

        override fun onFinished(sessionId: Int, success: Boolean) {
            try {
                packageManager.packageInstaller.unregisterSessionCallback(this)
            } catch (_: Exception) {
            }
        }
    }

    private fun startInstall(file: File, app: String) {
        val pm = packageManager
        val installer = pm.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        val sessionId = installer.createSession(params)
        val session = installer.openSession(sessionId)

        installer.registerSessionCallback(
            sessionCallback,
            Handler(Looper.getMainLooper())
        )

        val pending = PendingIntent.getBroadcast(
            this,
            sessionId,
            Intent(ACTION_INSTALL_RESULT).putExtra("extra_app", app),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        )

        try {
            val out: java.io.OutputStream =
                session.openWrite("app.apk", 0, file.length())
            try {
                val ins = java.io.FileInputStream(file)
                ins.use { input ->
                    val buf = ByteArray(65536)
                    while (true) {
                        val r = input.read(buf)
                        if (r < 0) break
                        out.write(buf, 0, r)
                    }
                    out.flush()
                }
            } finally {
                try {
                    out.close()
                } catch (_: Exception) {
                }
            }
            notifyProgress(PHASE_INSTALLING, 2, "جارٍ التثبيت…")
            session.commit(pending.intentSender)
        } catch (e: Exception) {
            try {
                session.abandon()
            } catch (_: Exception) {
            }
            try {
                installer.unregisterSessionCallback(sessionCallback)
            } catch (_: Exception) {
            }
            throw e
        }
    }

    override fun onDestroy() {
        try {
            wakeLock?.let {
                if (it.isHeld) it.release()
            }
        } catch (_: Exception) {
        }
        if (receiverRegistered) {
            try {
                unregisterReceiver(receiver)
            } catch (_: Exception) {
            }
            receiverRegistered = false
        }
        super.onDestroy()
    }
}