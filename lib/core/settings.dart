import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppSettings extends ChangeNotifier {
  AppSettings._(this._p);
  final SharedPreferences _p;

  static Future<AppSettings> load() async => AppSettings._(await SharedPreferences.getInstance());

  void _put(String k, Object v) {
    if (v is int) {
      _p.setInt(k, v);
    } else if (v is bool) {
      _p.setBool(k, v);
    } else if (v is String) {
      _p.setString(k, v);
    }
    notifyListeners();
  }

  // 0 system, 1 light, 2 dark
  int get themeIndex => _p.getInt('theme') ?? 0;
  set themeIndex(int v) => _put('theme', v);
  ThemeMode get themeMode => ThemeMode.values[themeIndex.clamp(0, 2)];

  int get paperMm => _p.getInt('paperMm') ?? 58;
  set paperMm(int v) => _put('paperMm', v);

  int get darkness => _p.getInt('darkness') ?? 60;
  set darkness(int v) => _put('darkness', v);

  int get styleIndex => _p.getInt('style') ?? 0;
  set styleIndex(int v) => _put('style', v);

  bool get trim => _p.getBool('trim') ?? true;
  set trim(bool v) => _put('trim', v);

  bool get stitch => _p.getBool('stitch') ?? true;
  set stitch(bool v) => _put('stitch', v);

  int get feedLines => _p.getInt('feed') ?? 3;
  set feedLines(int v) => _put('feed', v);

  bool get autoCut => _p.getBool('autoCut') ?? false;
  set autoCut(bool v) => _put('autoCut', v);

  bool get printWithoutAsking => _p.getBool('noAsk') ?? false;
  set printWithoutAsking(bool v) => _put('noAsk', v);

  bool get autoConnect => _p.getBool('autoConnect') ?? true;
  set autoConnect(bool v) => _put('autoConnect', v);

  String get lastMac => _p.getString('lastMac') ?? '';
  set lastMac(String v) => _put('lastMac', v);

  String get lastName => _p.getString('lastName') ?? '';
  set lastName(String v) => _put('lastName', v);

  bool get onboarded => _p.getBool('onboarded') ?? false;
  set onboarded(bool v) => _put('onboarded', v);

  int get historyDays => _p.getInt('historyDays') ?? 30;
  set historyDays(int v) => _put('historyDays', v);

  /// A fresh options object for a new print job.
  PrintOptions defaults() => PrintOptions(
        paperMm: paperMm,
        darkness: darkness,
        style: ImageStyle.values[styleIndex.clamp(0, 2)],
        trim: trim,
        stitch: stitch,
        feedLines: feedLines,
        autoCut: autoCut,
      );
}
