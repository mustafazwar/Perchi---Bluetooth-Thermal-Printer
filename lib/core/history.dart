import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'settings.dart';

class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.title,
    required this.kind,
    required this.at,
    required this.copies,
    required this.ok,
    required this.source,
    this.error,
    this.savedRows = 0,
  });

  final String id;
  final String title;
  final JobKind kind;
  final int at;
  final int copies;
  final bool ok;
  final String? error;
  final Map<String, dynamic> source;
  final int savedRows;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.index,
        'at': at,
        'copies': copies,
        'ok': ok,
        'error': error,
        'source': source,
        'saved': savedRows,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'],
        title: j['title'],
        kind: JobKind.values[j['kind']],
        at: j['at'],
        copies: j['copies'],
        ok: j['ok'],
        error: j['error'],
        source: Map<String, dynamic>.from(j['source'] as Map),
        savedRows: j['saved'] ?? 0,
      );
}

class HistoryStore extends ChangeNotifier {
  HistoryStore._(this._p, this._s, this._items);
  final SharedPreferences _p;
  final AppSettings _s;
  final List<HistoryEntry> _items;

  static Future<HistoryStore> load(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('history');
    var items = <HistoryEntry>[];
    if (raw != null) {
      try {
        items = (jsonDecode(raw) as List)
            .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {}
    }
    final st = HistoryStore._(p, s, items);
    st._prune();
    return st;
  }

  /// Newest first.
  List<HistoryEntry> get items => List.unmodifiable(_items);

  void _prune() {
    final cutoff = DateTime.now().subtract(Duration(days: _s.historyDays)).millisecondsSinceEpoch;
    final dead = _items.where((e) => e.at < cutoff).toList();
    while (_items.length - dead.length > 300) {
      dead.add(_items[_items.length - 1 - dead.length]);
    }
    for (final e in dead) {
      _deleteFile(e);
      _items.remove(e);
    }
  }

  void _deleteFile(HistoryEntry e) {
    final path = e.source['path'];
    if (path is String) {
      try {
        final f = File(path);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }
  }

  Future<void> _save() => _p.setString('history', jsonEncode(_items.map((e) => e.toJson()).toList()));

  Future<void> add(HistoryEntry e) async {
    _items.insert(0, e);
    _prune();
    await _save();
    notifyListeners();
  }

  Future<void> remove(String id) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    _deleteFile(_items[i]);
    _items.removeAt(i);
    await _save();
    notifyListeners();
  }

  Future<void> clear() async {
    for (final e in _items) {
      _deleteFile(e);
    }
    _items.clear();
    await _save();
    notifyListeners();
  }

  Future<void> pruneNow() async {
    _prune();
    await _save();
    notifyListeners();
  }
}

class TemplateStore extends ChangeNotifier {
  TemplateStore._(this._p, this._items);
  final SharedPreferences _p;
  final List<Map<String, dynamic>> _items;

  static Future<TemplateStore> load() async {
    final p = await SharedPreferences.getInstance();
    var items = <Map<String, dynamic>>[];
    final raw = p.getString('templates');
    if (raw != null) {
      try {
        items = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    return TemplateStore._(p, items);
  }

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);

  Future<void> save(String name, ReceiptData d) async {
    _items.removeWhere((e) => e['name'] == name);
    _items.insert(0, {'name': name, 'at': DateTime.now().millisecondsSinceEpoch, 'data': d.toJson()});
    await _p.setString('templates', jsonEncode(_items));
    notifyListeners();
  }

  Future<void> remove(String name) async {
    _items.removeWhere((e) => e['name'] == name);
    await _p.setString('templates', jsonEncode(_items));
    notifyListeners();
  }
}
