import 'package:dio/dio.dart';

/// Демо-режим (`--dart-define=DEMO=true`): отвечает на запросы приложения
/// встроенными данными, без сервера. Нужен, чтобы установить APK и показать
/// приложение, пока backend не развёрнут. Все примеры явно помечены как демо.
class DemoInterceptor extends Interceptor {
  static const demoCode = '1234';

  final _feedback = <Map<String, dynamic>>[];
  Map<String, dynamic>? _guest;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final o = options;
    final method = o.method.toUpperCase();
    final path = o.path;
    Object? body;
    var status = 200;

    Never fail(int code, String error, String message) {
      throw DioException(
        requestOptions: o,
        response: Response(requestOptions: o, statusCode: code, data: {'statusCode': code, 'error': error, 'message': message}),
        type: DioExceptionType.badResponse,
      );
    }

    try {
      switch ((method, path)) {
        case ('POST', '/auth/otp/request'):
          body = {'resendInSec': 60, 'ttlSec': 300, 'isNewUser': _guest == null};
        case ('POST', '/auth/otp/verify'):
          final data = Map<String, dynamic>.from(o.data as Map);
          if (data['code'] != demoCode) fail(400, 'otp_invalid', 'Неверный код. В демо-версии код — $demoCode');
          _guest ??= {
            'id': 'demo-guest',
            'phone': data['phone'],
            'name': data['name'],
            'pushNewsEnabled': true,
            'consentRequired': false,
          };
          body = {'accessToken': 'demo', 'refreshToken': 'demo', 'expiresIn': 900, 'guest': _guest, 'isNewUser': true};
        case ('POST', '/auth/refresh'):
          body = {'accessToken': 'demo', 'refreshToken': 'demo', 'expiresIn': 900};
        case ('POST', '/auth/logout') || ('POST', '/devices'):
          status = 204;
        case ('GET', '/me') || ('POST', '/me/consent'):
          if (_guest == null) fail(401, 'unauthorized', 'Войдите заново');
          body = _guest;
        case ('PATCH', '/me'):
          _guest = {..._guest!, ...Map<String, dynamic>.from(o.data as Map)};
          body = _guest;
        case ('DELETE', '/me'):
          _guest = null;
          _feedback.clear();
          status = 204;
        case ('GET', '/news'):
          body = {'items': _news, 'nextBefore': null};
        case ('GET', final p) when p.startsWith('/news/'):
          body = _news.firstWhere((n) => n['id'] == p.substring(6), orElse: () => fail(404, 'not_found', 'Новость не найдена'));
        case ('GET', '/menu'):
          body = _menu;
        case ('GET', '/venue'):
          body = _venue;
        case ('GET', '/legal/privacy'):
          body = {'version': 'demo', 'markdown': _privacy};
        case ('GET', '/loyalty'):
          body = {
            'card': {'cardNumber': '7707 0000 0000', 'barcode': '770700000000'},
            'balance': 150,
            'wallets': [
              {'name': 'Бонусы', 'balance': 150},
            ],
            'guestName': _guest?['name'],
          };
        case ('GET', '/loyalty/transactions'):
          body = {
            'items': [
              {
                'id': 'demo-tx',
                'date': DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String(),
                'amount': 150,
                'kind': 'accrual',
                'title': 'Приветственные бонусы (демо)',
                'orderNumber': null,
              },
            ],
            'hasMore': false,
          };
        case ('POST', '/feedback'):
          final form = o.data as FormData;
          String field(String k) => form.fields.firstWhere((f) => f.key == k, orElse: () => MapEntry(k, '')).value;
          final entry = {
            'id': 'demo-${_feedback.length + 1}',
            'type': field('type'),
            'message': field('message'),
            'photoUrl': null,
            'status': 'sent',
            'reply': null,
            'createdAt': DateTime.now().toUtc().toIso8601String(),
            'answeredAt': null,
          };
          if (_guest != null) _feedback.insert(0, entry);
          status = 201;
          body = entry;
        case ('GET', '/feedback/mine'):
          body = _feedback;
        default:
          fail(404, 'not_found', 'В демо-версии этот раздел недоступен');
      }
    } on DioException catch (e) {
      return handler.reject(e);
    }
    handler.resolve(Response(requestOptions: o, statusCode: status, data: body));
  }
}

final _now = DateTime.now().toUtc();

final _news = <Map<String, dynamic>>[
  {
    'id': 'demo-welcome',
    'title': 'Добро пожаловать в приложение History Coffee',
    'body': 'Теперь меню, бонусы и новости кофейни всегда под рукой. '
        'Покажите QR-код бариста, чтобы копить и тратить бонусы. '
        'Место для ваших историй: Нальчик, ул. Толстого, 43.\n\n'
        'Это демо-версия: новости будут публиковаться из админки кофейни.',
    'imageUrl': null,
    'pinned': true,
    'publishedAt': _now.toIso8601String(),
  },
  {
    'id': 'demo-card',
    'title': 'Как работает бонусная карта',
    'body': 'Войдите по номеру телефона на вкладке «Бонусы» — карта появится сразу. '
        'На кассе покажите QR-код: бариста отсканирует его, и бонусы начислятся или спишутся. '
        'Баланс и история операций обновляются в приложении.',
    'imageUrl': null,
    'pinned': false,
    'publishedAt': _now.subtract(const Duration(days: 2)).toIso8601String(),
  },
];

/// Структура меню — как на сайте. Из реальных позиций — только капучино из брифа;
/// «Пример блюда» показывает, как выглядят бейджи и «Блюдо с историей».
final _menu = <String, dynamic>{
  'disclaimer': 'Цены и состав блюд носят информационный характер, актуальное меню — в кофейне',
  'sections': [
    {
      'id': 'kitchen',
      'slug': 'kitchen',
      'title': 'Кухня',
      'categories': [
        {
          'id': 'breakfast',
          'title': 'Завтраки',
          'items': [
            {
              'id': 'demo-dish',
              'title': 'Пример блюда',
              'description': 'Демо-позиция: так в приложении выглядит блюдо. Настоящее меню вносится в админке.',
              'portion': null,
              'imageUrl': null,
              'prices': <Map<String, dynamic>>[],
              'badges': ['team_choice', 'story'],
              'story': 'Здесь будет короткая легенда блюда — для позиций с пометкой «Блюдо с историей».',
            },
          ],
        },
      ],
    },
    {
      'id': 'bar',
      'slug': 'bar',
      'title': 'Бар',
      'categories': [
        {
          'id': 'coffee',
          'title': 'Кофе',
          'items': [
            {
              'id': 'cappuccino',
              'title': 'Капучино',
              'description': null,
              'portion': null,
              'imageUrl': null,
              'prices': [
                {'label': 'S', 'amount': 270},
                {'label': 'L', 'amount': 290},
              ],
              'badges': <String>[],
              'story': null,
            },
          ],
        },
      ],
    },
  ],
};

final _venue = <String, dynamic>{
  'name': 'History Coffee',
  'tagline': 'Место для ваших историй',
  'address': 'г. Нальчик, ул. Толстого, 43',
  'lat': null,
  'lng': null,
  'phone': '+79604316223',
  'whatsapp': '+79604316223',
  'instagram': 'history.coffee.ru',
  'website': 'https://historycoffee.ru/',
  'legalName': 'ИП Жабоева А. Т.',
  'hours': [
    for (var d = 1; d <= 7; d++) {'day': d, 'open': d <= 5 ? '08:00' : '09:00', 'close': '23:00'},
  ],
};

const _privacy = '''# Политика обработки персональных данных

Это демо-версия приложения: данные никуда не отправляются и хранятся только до закрытия приложения.

В рабочей версии полный текст политики загружается с сервера кофейни и доступен в этом разделе.''';
