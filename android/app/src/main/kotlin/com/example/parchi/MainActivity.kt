package com.example.parchi

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.pm.PackageManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.io.OutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "com.example.parchi/printer"
        private val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    }

    private var socket: BluetoothSocket? = null
    private var output: OutputStream? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "connect" -> {
                        val mac = call.argument<String>("mac")
                        if (mac.isNullOrBlank()) {
                            result.error("INVALID_MAC", "Printer MAC address is empty.", null)
                            return@setMethodCallHandler
                        }

                        Thread {
                            val ok = connectPrinter(mac)
                            mainHandler.post { result.success(ok) }
                        }.start()
                    }

                    "isConnected" -> {
                        result.success(isSocketConnected())
                    }

                    "writeBytes" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null || bytes.isEmpty()) {
                            result.success(true)
                            return@setMethodCallHandler
                        }

                        Thread {
                            val ok = writePrinter(bytes)
                            mainHandler.post { result.success(ok) }
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

    @Suppress("MissingPermission")
    private fun connectPrinter(mac: String): Boolean {
        if (!hasBluetoothPermission()) return false

        disconnectPrinter()

        val adapter = BluetoothAdapter.getDefaultAdapter() ?: return false
        if (!adapter.isEnabled) return false

        return try {
            adapter.cancelDiscovery()
            val device: BluetoothDevice = adapter.getRemoteDevice(mac)

            var newSocket: BluetoothSocket? = null
            try {
                newSocket = device.createRfcommSocketToServiceRecord(SPP_UUID)
                newSocket.connect()
            } catch (_: IOException) {
                try {
                    newSocket?.close()
                } catch (_: IOException) {
                }
                newSocket = device.createInsecureRfcommSocketToServiceRecord(SPP_UUID)
                newSocket.connect()
            }

            socket = newSocket
            output = newSocket.getOutputStream()
            true
        } catch (_: Exception) {
            try {
                newSocketClose()
            } catch (_: Exception) {
            }
            false
        }
    }

    private fun isSocketConnected(): Boolean {
        return try {
            socket?.isConnected == true && output != null
        } catch (_: Exception) {
            false
        }
    }

    private fun writePrinter(bytes: ByteArray): Boolean {
        val out = output ?: return false
        val currentSocket = socket ?: return false

        return try {
            if (!currentSocket.isConnected) return false

            // Thermal printers are much more reliable when a raster ticket
            // is sent in small blocks instead of one large Bluetooth write.
            val chunkSize = 1024
            var offset = 0

            while (offset < bytes.size) {
                if (!currentSocket.isConnected) return false

                val count = minOf(chunkSize, bytes.size - offset)
                out.write(bytes, offset, count)
                out.flush()
                offset += count

                // Give cheap SPP printers time to drain their small buffers.
                if (offset < bytes.size) {
                    Thread.sleep(12)
                }
            }

            true
        } catch (_: Exception) {
            disconnectPrinter()
            false
        }
    }

    private fun disconnectPrinter(): Boolean {
        var closedSomething = false

        try {
            output?.close()
            closedSomething = true
        } catch (_: Exception) {
        }

        try {
            socket?.close()
            closedSomething = true
        } catch (_: Exception) {
        }

        output = null
        socket = null
        return closedSomething
    }

    private fun newSocketClose() {
        try {
            output?.close()
        } catch (_: Exception) {
        }
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        output = null
        socket = null
    }

    override fun onDestroy() {
        disconnectPrinter()
        super.onDestroy()
    }
}
