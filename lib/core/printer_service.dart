import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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

  List<BluetoothInfo> paired = [];
  bool connected = false;
  bool busy = false;
  bool btOn = true;
  String? error;

  Future<bool> _permission() async {
    try {
      final r = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
      if (r[Permission.bluetoothConnect]?.isGranted ?? false) return true;
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (_) {
      return false;
    }
  }

  /// Called once when the app opens.
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
          connected = await PrintBluetoothThermal.connectionStatus;
        }
      }
    } catch (e) {
      error = 'Bluetooth error: $e';
    }
    busy = false;
    notifyListeners();
  }

  Future<bool> connect(String mac, String name) async {
    busy = true;
    notifyListeners();
    var ok = false;
    try {
      if (await PrintBluetoothThermal.connectionStatus) {
        await PrintBluetoothThermal.disconnect;
      }
      ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
    } catch (_) {
      ok = false;
    }
    connected = ok;
    if (ok) {
      settings.lastMac = mac;
      settings.lastName = name;
    }
    busy = false;
    notifyListeners();
    return ok;
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
    connected = false;
    notifyListeners();
  }

  Future<void> forgetDefault() async {
    await disconnect();
    settings.lastMac = '';
    settings.lastName = '';
    notifyListeners();
  }

  /// Make sure we are connected, reconnecting to the saved printer if needed.
  Future<bool> ensureConnected() async {
    try {
      if (await PrintBluetoothThermal.connectionStatus) {
        connected = true;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    connected = false;
    final mac = settings.lastMac;
    if (mac.isEmpty) return false;
    if (!await _permission()) return false;
    return connect(mac, settings.lastName);
  }

  Future<void> send(
    Uint8List data,
    void Function(double) onProgress, {
    bool Function()? cancelled,
  }) async {
    const chunk = 900;
    for (var i = 0; i < data.length; i += chunk) {
      if (cancelled != null && cancelled()) throw PrintCancelled();
      final end = math.min(i + chunk, data.length);
      final ok = await PrintBluetoothThermal.writeBytes(data.sublist(i, end));
      if (!ok) {
        connected = false;
        notifyListeners();
        throw PrintFailure('The printer stopped responding. Check it is on, has paper and is nearby.');
      }
      onProgress(end / data.length);
      await Future.delayed(const Duration(milliseconds: 12));
    }
  }
}
