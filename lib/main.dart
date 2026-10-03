import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:parchi/app.dart';
import 'core/history.dart';
import 'core/printer_service.dart';
import 'core/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await AppSettings.load();
  final history = await HistoryStore.load(settings);
  final templates = await TemplateStore.load();
  final printer = PrinterService(settings);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: history),
        ChangeNotifierProvider.value(value: templates),
        ChangeNotifierProvider.value(value: printer),
      ],
      child:  const ParchiApp(),
    ),
  );
}
