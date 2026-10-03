package com.example.parchi

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.parchi/printer"
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private var socket: BluetoothSocket? = null
    private var output: OutputStream? = null
    private val lock = Any()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val mac = (call.arguments as? Map<*, *>)?.get("mac") as? String
                        if (mac.isNullOrBlank()) {
                            result.error("INVALID_MAC", "Printer MAC address is empty.", null)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val err = connectPrinter(mac)
                            mainHandler.post {
                                if (err == null) result.success(true)
                                else result.error("CONNECT_FAILED", err, null)
                            }
                        }.start()
                    }

                    "isConnected" -> result.success(isSocketConnected())

                    "writeBytes" -> {
                        // Accept both a bare byte array and {"bytes": byte array}.
                        val args = call.arguments
                        val bytes: ByteArray? = when (args) {
                            is ByteArray -> args
                            is Map<*, *> -> args["bytes"] as? ByteArray
                            else -> null
                        }
                        if (bytes == null) {
                            result.error("BAD_ARGS", "writeBytes needs a byte array.", null)
                            return@setMethodCallHandler
                        }
                        if (bytes.isEmpty()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }
                        Thread {
                            val err = writePrinter(bytes)
                            mainHandler.post {
                                if (err == null) result.success(true)
                                else result.error("WRITE_FAILED", err, null)
                            }
                        }.start()
                    }

                    "disconnect" -> {
                        Thread {
                            val ok = disconnectPrinter()
                            mainHandler.post { result.success(ok) }
                        }.start()
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasBluetoothPermission(): Boolean {
        return android.os.Build.VERSION.SDK_INT < android.os.Build.VERSION_CODES.S ||
                checkSelfPermission(Manifest.permission.BLUETOOTH_CONNECT) == PackageManager.PERMISSION_GRANTED
    }

    /** Returns null on success, or a readable error message. */
    @Suppress("MissingPermission")
    private fun connectPrinter(mac: String): String? = synchronized(lock) {
        if (!hasBluetoothPermission()) return "Bluetooth permission not granted."
        closeQuietly()

        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return "No Bluetooth adapter."
        if (!adapter.isEnabled) return "Bluetooth is off."

        adapter.cancelDiscovery()
        val device: BluetoothDevice = try {
            adapter.getRemoteDevice(mac)
        } catch (e: Exception) {
            return "Bad printer address: ${e.message}"
        }

        var lastErr = ""
        // Try secure, then insecure. A fresh socket every attempt.
        for (insecure in listOf(false, true)) {
            var s: BluetoothSocket? = null
            try {
                s = if (insecure) device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                else device.createRfcommSocketToServiceRecord(SPP_UUID)
                s.connect()
                socket = s
                output = s.outputStream
                return null
            } catch (e: Exception) {
                lastErr = e.message ?: e.javaClass.simpleName
                try { s?.close() } catch (_: Exception) {}
            }
        }
        return "Could not open connection: $lastErr"
    }

    private fun isSocketConnected(): Boolean = synchronized(lock) {
        try {
            socket?.isConnected == true && output != null
        } catch (_: Exception) {
            false
        }
    }

    /** Returns null on success, or a readable error message. */
    private fun writePrinter(bytes: ByteArray): String? = synchronized(lock) {
        val out = output ?: return "Not connected."
        val s = socket ?: return "Not connected."

        try {
            if (!s.isConnected) return "Socket is closed."

            // Small blocks + a short pause: cheap SPP printers have tiny buffers.
            val chunkSize = 512
            var offset = 0
            while (offset < bytes.size) {
                val count = minOf(chunkSize, bytes.size - offset)
                out.write(bytes, offset, count)
                out.flush()
                offset += count
                if (offset < bytes.size) Thread.sleep(20)
            }
            return null
        } catch (e: Exception) {
            closeQuietly()
            return "Write failed after link dropped: ${e.message ?: e.javaClass.simpleName}"
        }
    }

    private fun disconnectPrinter(): Boolean = synchronized(lock) {
        val had = socket != null || output != null
        closeQuietly()
        had
    }

    private fun closeQuietly() {
        try { output?.close() } catch (_: Exception) {}
        try { socket?.close() } catch (_: Exception) {}
        output = null
        socket = null
    }

    override fun onDestroy() {
        disconnectPrinter()
        super.onDestroy()
    }
}