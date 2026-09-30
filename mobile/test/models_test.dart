import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/core/api/api_exception.dart';
import 'package:history_coffee/core/auth/guest_profile.dart';
import 'package:history_coffee/core/utils/launch.dart';
import 'package:history_coffee/features/chat/chat.dart';
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
      response: Response(
        requestOptions: RequestOptions(path: '/x'),
        statusCode: status,
        data: data,
      ),
    );

    test('строковое сообщение и код', () {
      final e = ApiException.fromDio(err(400, {'error': 'otp_invalid', 'message': 'Неверный код', 'attemptsLeft': 3}));
      expect(e.message, 'Неверный код');
      expect(e.code, 'otp_invalid');
      expect(e.data['attemptsLeft'], 3);
    });

    test('массив сообщений валидации — берём первое', () {
      final e = ApiException.fromDio(
        err(400, {
          'message': ['Сообщение от 3 до 3000 символов', 'x'],
        }),
      );
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
      expect(
        Links.twoGis(address: '', lat: 43.48, lng: 43.6).toString(),
        'https://2gis.ru/routeSearch/rsType/car/to/43.6,43.48',
      );
    });
  });

  group('законы РФ', () {
    test('бейдж «Новинка» — по-русски', () {
      expect(MenuBadge.fromCode('new')!.label, 'Новинка');
    });

    test('пищевая ценность: пустая — не показываем', () {
      expect(MenuNutrition.fromJson(null), isNull);
      expect(MenuNutrition.fromJson({'kcal': null}), isNull);
      final n = MenuNutrition.fromJson({'kcal': 412, 'proteins': 18.5})!;
      expect(n.kcal, 412);
      expect(n.proteins, 18.5);
      expect(n.fats, isNull);
    });

    test('согласие на рекламу по умолчанию не дано', () {
      expect(GuestProfile.fromJson({'id': 'g', 'phone': '+79990000001'}).pushNewsEnabled, isFalse);
    });
  });

  group('ChatMessage', () {
    test('сообщение гостя и ответ кофейни', () {
      final mine = ChatMessage.fromJson({
        'id': 'm1',
        'fromStaff': false,
        'text': 'Есть овсяное молоко?',
        'createdAt': '2026-09-30T08:25:00.000Z',
        'readAt': null,
      });
      expect(mine.fromStaff, isFalse);
      expect(mine.readAt, isNull);
      expect(mine.createdAt.toUtc(), DateTime.utc(2026, 9, 30, 8, 25));
      final reply = ChatMessage.fromJson({
        'id': 'm2',
        'fromStaff': true,
        'text': 'Да, есть',
        'createdAt': '2026-09-30T08:26:00.000Z',
        'readAt': '2026-09-30T08:27:00.000Z',
      });
      expect(reply.fromStaff, isTrue);
      expect(reply.readAt, isNotNull);
    });
  });
}
