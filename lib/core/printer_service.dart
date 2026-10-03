import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'settings.dart';

class PrintFailure implements Exception {
  PrintFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class PrintCancelled implements Exception {}

class PrinterService extends ChangeNotifier {
  PrinterService(this.settings);
  final AppSettings settings;

  static const MethodChannel _nativePrinter =
  MethodChannel('com.example.parchi/printer');

  List<BluetoothInfo> paired = [];
  bool connected = false;
  bool busy = false;
  bool btOn = true;
  String? error;
  String? lastNativeError;

  Future<bool> _permission() async {
    try {
      final r = await [
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();
      if (r[Permission.bluetoothConnect]?.isGranted ?? false) return true;
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> startup() async {
    await refresh();
    if (settings.autoConnect && settings.lastMac.isNotEmpty && !connected && btOn) {
      await connect(settings.lastMac, settings.lastName);
    }
  }

  Future<void> refresh() async {
    busy = true;
    notifyListeners();
    try {
      if (!await _permission()) {
        error = 'Allow Bluetooth permission to find your printer.';
        paired = [];
      } else {
        btOn = await PrintBluetoothThermal.bluetoothEnabled;
        if (!btOn) {
          error = 'Bluetooth is off. Turn it on to print.';
          paired = [];
          connected = false;
        } else {
          error = null;
          paired = await PrintBluetoothThermal.pairedBluetooths;
          connected = await _nativeIsConnected();
        }
      }
    } catch (e) {
      error = 'Bluetooth error: $e';
    }
    busy = false;
    notifyListeners();
  }

  Future<bool> _nativeIsConnected() async {
    try {
      return await _nativePrinter.invokeMethod<bool>('isConnected') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> connect(String mac, String name) async {
    busy = true;
    notifyListeners();

    var ok = false;
    try {
      if (!await _permission()) {
        error = 'Allow Bluetooth permission to connect to your printer.';
        return false;
      }

      ok = await _nativePrinter.invokeMethod<bool>(
        'connect',
        <String, dynamic>{'mac': mac},
      ) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('Native printer connect error: ${e.code}: ${e.message}');
      lastNativeError = e.message;
      ok = false;
    } catch (e) {
      debugPrint('Native printer connect error: $e');
      ok = false;
    } finally {
      busy = false;
    }

    connected = ok;
    if (ok) {
      error = null;
      settings.lastMac = mac;
      settings.lastName = name;
    } else {
      error = 'Could not connect to $name.' + (lastNativeError == null ? '' : ' ($lastNativeError)');
    }

    notifyListeners();
    return ok;
  }

  Future<void> disconnect() async {
    try {
      await _nativePrinter.invokeMethod<bool>('disconnect');
    } catch (e) {
      debugPrint('Native printer disconnect error: $e');
    }
    connected = false;
    notifyListeners();
  }

  Future<void> forgetDefault() async {
    await disconnect();
    settings.lastMac = '';
    settings.lastName = '';
    notifyListeners();
  }

  Future<bool> ensureConnected({bool forceReconnect = false}) async {
    if (!await _permission()) return false;

    if (forceReconnect) {
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 200));
    } else if (await _nativeIsConnected()) {
      connected = true;
      notifyListeners();
      return true;
    }

    final mac = settings.lastMac;
    if (mac.isEmpty) return false;

    return connect(mac, settings.lastName);
  }

  Future<bool> _nativeWrite(List<int> bytes) async {
    try {
      lastNativeError = null;
      // Kotlin reads call.argument<ByteArray>("bytes"), so this MUST be a map.
      return await _nativePrinter.invokeMethod<bool>(
        'writeBytes',
        <String, dynamic>{'bytes': Uint8List.fromList(bytes)},
      ) ??
          false;
    } on PlatformException catch (e) {
      lastNativeError = '${e.code}: ${e.message}';
      debugPrint('Native printer write error: $lastNativeError');
      return false;
    } catch (e) {
      lastNativeError = '$e';
      debugPrint('Native printer write error: $e');
      return false;
    }
  }

  Future<void> send(
      Uint8List data,
      void Function(double) onProgress, {
        bool Function()? cancelled,
      }) async {
    if (data.isEmpty) {
      onProgress(1);
      return;
    }

    const chunk = 1024;
    var reconnectUsed = false;

    Future<bool> writeRange(int start, int end) async {
      return _nativeWrite(data.sublist(start, end));
    }

    for (var i = 0; i < data.length; i += chunk) {
      if (cancelled != null && cancelled()) {
        await disconnect();
        throw PrintCancelled();
      }

      final end = math.min(i + chunk, data.length);
      var ok = await writeRange(i, end);

      if (!ok && !reconnectUsed && settings.lastMac.isNotEmpty) {
        reconnectUsed = true;
        debugPrint(
          'Native printer write failed at ' + i.toString() +
              '/' + data.length.toString() + '; reconnecting.',
        );

        await disconnect();
        await Future.delayed(const Duration(milliseconds: 250));

        final reconnected = await ensureConnected(forceReconnect: false);
        if (reconnected) {
          await Future.delayed(const Duration(milliseconds: 250));
          ok = await writeRange(i, end);
        }
      }

      if (!ok) {
        await disconnect();
        throw PrintFailure(
          'The printer dropped the connection while printing ($i bytes sent of ${data.length} bytes)${lastNativeError == null ? '' : ' [${lastNativeError!}]'}. Tap Reconnect to try again.',
        );
      }

      onProgress(end / data.length);
    }
  }
}