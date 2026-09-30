import 'dart:async';

import 'package:flutter/foundation.dart';
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
  _registerFontLicenses();
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

  // Push инициализируем после первого кадра, не задерживая запуск (профиль нужен, чтобы
  // привязать устройство к вошедшему гостю).
  await container.read(authControllerProvider.future).catchError((_) => null);
  await container.read(pushServiceProvider).init();
}

/// Шрифты распространяются по SIL Open Font License 1.1: коммерческое использование
/// и встраивание разрешены, но текст лицензии должен поставляться вместе со шрифтом.
void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (pkg, file) in [
      ('Cormorant Garamond (шрифт)', 'assets/fonts/OFL-CormorantGaramond.txt'),
      ('Golos Text (шрифт)', 'assets/fonts/OFL-GolosText.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([pkg], await rootBundle.loadString(file));
    }
  });
}
