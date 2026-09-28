import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:history_coffee/core/api/demo_interceptor.dart';
import 'package:history_coffee/features/contacts/venue.dart';
import 'package:history_coffee/features/loyalty/loyalty.dart';
import 'package:history_coffee/features/menu/menu_models.dart';

void main() {
  late Dio dio;
  setUp(() => dio = Dio(BaseOptions(baseUrl: 'https://demo.local'))..interceptors.add(DemoInterceptor()));

  test('вход: неверный код отклоняется, 1234 — пускает', () async {
    await dio.post<dynamic>('/auth/otp/request', data: {'phone': '+79001112233'});
    await expectLater(
      dio.post<dynamic>('/auth/otp/verify', data: {'phone': '+79001112233', 'code': '0000'}),
      throwsA(isA<DioException>().having((e) => e.response?.statusCode, 'status', 400)),
    );
    final res = await dio.post<Map<String, dynamic>>('/auth/otp/verify', data: {'phone': '+79001112233', 'code': '1234', 'name': 'Мадина'});
    expect(res.data!['guest']['name'], 'Мадина');
    final me = await dio.get<Map<String, dynamic>>('/me');
    expect(me.data!['phone'], '+79001112233');
  });

  test('данные разделов разбираются моделями приложения', () async {
    final menu = MenuData.fromJson((await dio.get<Map<String, dynamic>>('/menu')).data!);
    final coffee = menu.sections.firstWhere((s) => s.slug == 'bar').categories.first.items.first;
    expect(coffee.priceLine, '270 / 290 ₽');
    final venue = Venue.fromJson((await dio.get<Map<String, dynamic>>('/venue')).data!);
    expect(venue.hours.length, 7);
    final loyalty = LoyaltySummary.fromJson((await dio.get<Map<String, dynamic>>('/loyalty')).data!);
    expect(loyalty.balance, 150);
  });

  test('обращение вошедшего гостя появляется в «Мои обращения»', () async {
    await dio.post<dynamic>('/auth/otp/verify', data: {'phone': '+79001112233', 'code': '1234'});
    await dio.post<dynamic>('/feedback', data: FormData.fromMap({'type': 'thanks', 'message': 'Спасибо!'}));
    final mine = await dio.get<List<dynamic>>('/feedback/mine');
    expect(mine.data!.single['message'], 'Спасибо!');
  });
}
