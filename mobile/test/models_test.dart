import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/core/api/api_exception.dart';
import 'package:history_coffee/core/utils/launch.dart';
import 'package:history_coffee/features/feedback/feedback.dart';
import 'package:history_coffee/features/menu/menu_models.dart';

void main() {
  group('MenuItem', () {
    test('две цены и бейджи; неизвестный бейдж игнорируется', () {
      final item = MenuItem.fromJson({
        'id': '1',
        'title': 'Капучино',
        'prices': [
          {'label': 'S', 'amount': 270},
          {'label': 'L', 'amount': 290},
        ],
        'badges': ['bestseller', 'story', 'future_badge'],
      });
      expect(item.priceLine, '270 / 290 ₽');
      expect(item.badges, [MenuBadge.bestseller, MenuBadge.story]);
    });

    test('без цен — пустая строка', () {
      expect(MenuItem.fromJson({'id': '1', 'title': 'Сезонное'}).priceLine, '');
    });
  });

  group('ApiException', () {
    DioException err(int status, Object data) => DioException(
          requestOptions: RequestOptions(path: '/x'),
          response: Response(requestOptions: RequestOptions(path: '/x'), statusCode: status, data: data),
        );

    test('строковое сообщение и код', () {
      final e = ApiException.fromDio(err(400, {'error': 'otp_invalid', 'message': 'Неверный код', 'attemptsLeft': 3}));
      expect(e.message, 'Неверный код');
      expect(e.code, 'otp_invalid');
      expect(e.data['attemptsLeft'], 3);
    });

    test('массив сообщений валидации — берём первое', () {
      final e = ApiException.fromDio(err(400, {'message': ['Сообщение от 3 до 3000 символов', 'x']}));
      expect(e.message, 'Сообщение от 3 до 3000 символов');
    });

    test('нет ответа — сетевая ошибка', () {
      final e = ApiException.fromDio(DioException(requestOptions: RequestOptions(path: '/x')));
      expect(e.isNetwork, isTrue);
      expect(e.message, 'Нет соединения с интернетом');
    });

    test('фолбэк по статусу', () {
      expect(ApiException.fromDio(err(503, 'oops')).message, 'Сервис временно недоступен');
    });
  });

  group('FeedbackEntry', () {
    test('статусы и тип', () {
      final f = FeedbackEntry.fromJson({
        'id': 'f1',
        'type': 'thanks',
        'message': 'Спасибо!',
        'status': 'answered',
        'reply': 'Ждём снова',
        'createdAt': '2026-09-27T10:00:00.000Z',
        'answeredAt': '2026-09-27T12:00:00.000Z',
      });
      expect(f.type, FeedbackType.thanks);
      expect(f.status.label, 'Отвечено');
    });
  });

  group('Links', () {
    test('звонок и WhatsApp', () {
      expect(Links.call('+79604316223').toString(), 'tel:+79604316223');
      expect(Links.whatsapp('+79604316223').toString(), 'https://wa.me/79604316223');
      expect(Links.instagram('history.coffee.ru').toString(), 'https://instagram.com/history.coffee.ru/');
    });

    test('маршрут по адресу, пока нет координат', () {
      final y = Links.yandexMaps(address: 'г. Нальчик, ул. Толстого, 43');
      expect(y.host, 'yandex.ru');
      expect(y.queryParameters['text'], 'г. Нальчик, ул. Толстого, 43');
      final g = Links.googleMaps(address: 'г. Нальчик, ул. Толстого, 43');
      expect(g.queryParameters['destination'], 'г. Нальчик, ул. Толстого, 43');
    });

    test('маршрут по координатам', () {
      final y = Links.yandexMaps(address: '', lat: 43.48, lng: 43.6);
      expect(y.queryParameters['rtext'], '~43.48,43.6');
      expect(Links.twoGis(address: '', lat: 43.48, lng: 43.6).toString(), 'https://2gis.ru/routeSearch/rsType/car/to/43.6,43.48');
    });
  });
}
