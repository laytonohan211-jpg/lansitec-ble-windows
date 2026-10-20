package com.flutter.lansitec.blue.flutter_blue

import android.os.Handler
import android.os.Looper
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import org.json.JSONTokener

class MainActivity: FlutterActivity() {
 private val pending = mutableMapOf<WebView, () -> Unit>()
 override fun configureFlutterEngine(engine: FlutterEngine) {
  super.configureFlutterEngine(engine)
  MethodChannel(engine.dartExecutor.binaryMessenger, "lansitec/connection").setMethodCallHandler { call, result ->
   try {
    when(call.method) {
     "status" -> {
      val manager = getSystemService(android.content.Context.LOCATION_SERVICE) as android.location.LocationManager
      val enabled = if(android.os.Build.VERSION.SDK_INT >= 28) manager.isLocationEnabled else
       manager.isProviderEnabled(android.location.LocationManager.GPS_PROVIDER) || manager.isProviderEnabled(android.location.LocationManager.NETWORK_PROVIDER)
      val bluetoothManager = getSystemService(android.content.Context.BLUETOOTH_SERVICE) as android.bluetooth.BluetoothManager
      val bluetoothEnabled = try { bluetoothManager.adapter?.isEnabled == true } catch (_: SecurityException) { false }
      result.success(mapOf("sdk" to android.os.Build.VERSION.SDK_INT, "location" to enabled, "bluetooth" to bluetoothEnabled))
     }
     "locationSettings" -> { startActivity(android.content.Intent(android.provider.Settings.ACTION_LOCATION_SOURCE_SETTINGS)); result.success(null) }
     else -> result.notImplemented()
    }
   } catch(e:Exception) { result.error("SETTINGS", e.message, null) }
  }
  MethodChannel(engine.dartExecutor.binaryMessenger, "lansitec/decoder").setMethodCallHandler { call, result ->
   if (call.method != "decode") { result.notImplemented(); return@setMethodCallHandler }
   val family = call.argument<String>("family") ?: ""
   val payload = call.argument<String>("payload") ?: ""
   if (family !in listOf("container", "badge", "gateway") || payload.length !in 2..8192 || payload.length % 2 != 0 || !payload.matches(Regex("[0-9A-Fa-f]+"))) {
    result.error("INVALID", "Invalid model or hexadecimal payload", null); return@setMethodCallHandler
   }
   try {
    val script = assets.open("decoders/$family.js").bufferedReader().use { it.readText() }
    val web = WebView(this)
    web.settings.javaScriptEnabled = true
    web.settings.blockNetworkLoads = true
    web.settings.allowFileAccess = false
    web.settings.allowContentAccess = false
    val handler = Handler(Looper.getMainLooper())
    var finished = false
    lateinit var timeout: Runnable
    fun finish(value: String) {
     if(finished) return
     finished = true
     handler.removeCallbacks(timeout)
     pending.remove(web)
     web.destroy()
     result.success(value)
    }
    timeout = Runnable { finish("{\"error\":\"Decoder timed out\"}") }
    pending[web] = { finish("{\"error\":\"Decoder closed\"}") }
    handler.postDelayed(timeout, 5000)
    web.webViewClient = object: WebViewClient() {
     override fun onPageFinished(view: WebView, url: String?) {
      if(finished) return
      web.evaluateJavascript("(function(){try{\n$script\nreturn JSON.stringify(decodeChecked(${JSONObject.quote(payload)}));}catch(e){return JSON.stringify({error:String(e.message||e)});}})()") { encoded ->
     val value = try { JSONTokener(encoded).nextValue() as? String } catch(e:Exception) { null }
     finish(value ?: "{\"error\":\"Decoder returned no result\"}")
      }
     }
    }
    web.loadDataWithBaseURL(null, "<html><head></head><body></body></html>", "text/html", "UTF-8", null)
   } catch(e:Exception) { result.error("DECODER", e.message, null) }
  }
 }
 override fun onDestroy() { pending.values.toList().forEach { it() }; super.onDestroy() }
}
