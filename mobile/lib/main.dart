import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/auth/auth_controller.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));

  final container = ProviderContainer();
  runApp(UncontrolledProviderScope(container: container, child: const HistoryCoffeeApp()));

  // Push инициализируем после первого кадра, не задерживая запуск.
  final profile = await container.read(authControllerProvider.future).catchError((_) => null);
  await container.read(pushServiceProvider).init(newsEnabled: profile?.pushNewsEnabled ?? true);
}
