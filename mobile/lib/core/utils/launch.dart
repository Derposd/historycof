import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ссылки для контактов и маршрутов. Вынесены отдельно, чтобы покрыть тестами.
abstract final class Links {
  static Uri call(String phoneE164) => Uri(scheme: 'tel', path: phoneE164);

  static Uri whatsapp(String phoneE164) => Uri.https('wa.me', '/${phoneE164.replaceAll(RegExp(r'\D'), '')}');

  static Uri yandexMaps({required String address, double? lat, double? lng}) => lat != null && lng != null
      ? Uri.https('yandex.ru', '/maps/', {'rtext': '~$lat,$lng', 'rtt': 'auto'})
      : Uri.https('yandex.ru', '/maps/', {'text': address});

  static Uri twoGis({required String address, double? lat, double? lng}) => lat != null && lng != null
      ? Uri.parse('https://2gis.ru/routeSearch/rsType/car/to/$lng,$lat')
      : Uri.parse('https://2gis.ru/search/${Uri.encodeComponent(address)}');

  static Uri googleMaps({required String address, double? lat, double? lng}) => Uri.https(
    'www.google.com',
    '/maps/dir/',
    {'api': '1', 'destination': lat != null && lng != null ? '$lat,$lng' : address},
  );

  static Uri appleMaps({required String address, double? lat, double? lng}) =>
      Uri.https('maps.apple.com', '/', {'daddr': lat != null && lng != null ? '$lat,$lng' : address});
}

/// Открывает ссылку во внешнем приложении (карты, звонилка, WhatsApp).
/// Возвращает false, если открыть не удалось.
Future<bool> openExternal(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Не удалось открыть $uri: $e');
    return false;
  }
}
