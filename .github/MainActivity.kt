import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dw/native")
            .setMethodCallHandler { call, result ->
                val pkg = call.argument<String>("package") ?: ""
                val key = call.argument<String>("key") ?: ""
                val prefs = getSharedPreferences("dw_local", MODE_PRIVATE)
                when (call.method) {
                    "installedApps" -> {
                        val icons = call.argument<Boolean>("icons") ?: true
                        Thread {
                            val apps = try {
                                listApps(icons)
                            } catch (e: Exception) {
                                emptyList<Map<String, Any?>>()
                            }
                            runOnUiThread { result.success(apps) }
                        }.start()
                    }
                    "launchApp" -> {
                        val intent = packageManager.getLaunchIntentForPackage(pkg)
                        result.success(if (intent == null) false else open(intent))
                    }
                    "openAppInfo" -> result.success(
                        open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + pkg)))
                    )
                    "uninstallApp" -> result.success(
                        open(Intent(Intent.ACTION_DELETE, Uri.parse("package:" + pkg)))
                    )
                    "openHomeSettings" -> result.success(open(Intent(Settings.ACTION_HOME_SETTINGS)))
                    "isDefaultLauncher" -> {
                        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                        val info = packageManager.resolveActivity(home, 0)
                        result.success(info?.activityInfo?.packageName == packageName)
                    }
                    "getLocal" -> result.success(prefs.getString(key, null))
                    "setLocal" -> {
                        val value = call.argument<String>("value")
                        if (value == null) prefs.edit().remove(key).apply()
                        else prefs.edit().putString(key, value).apply()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun open(intent: Intent): Boolean {
        return try {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun listApps(icons: Boolean): List<Map<String, Any?>> {
        val pm = packageManager
        val main = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(main, 0)
            .filter { it.activityInfo.packageName != packageName }
            .distinctBy { it.activityInfo.packageName }
            .map { info ->
                mapOf<String, Any?>(
                    "name" to info.loadLabel(pm).toString(),
                    "package" to info.activityInfo.packageName,
                    "icon" to (if (icons) iconBytes(info.loadIcon(pm)) else null)
                )
            }
            .sortedBy { (it["name"] as String).lowercase() }
    }

    private fun iconBytes(drawable: Drawable): ByteArray {
        val size = 128
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }
}
