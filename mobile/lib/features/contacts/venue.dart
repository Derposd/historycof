/// Часы работы по ISO-дню недели: 1 — понедельник … 7 — воскресенье.
class DayHours {
  const DayHours({required this.day, this.open, this.close});

  final int day;

  /// «08:00»; null — выходной.
  final String? open;
  final String? close;

  bool get isDayOff => open == null || close == null;

  factory DayHours.fromJson(Map<String, dynamic> j) =>
      DayHours(day: (j['day'] as num).toInt(), open: j['open'] as String?, close: j['close'] as String?);
}

class Venue {
  const Venue({
    required this.name,
    required this.tagline,
    required this.address,
    required this.phone,
    required this.whatsapp,
    required this.legalName,
    required this.hours,
    this.telegram = '',
    this.vk = '',
    this.inn = '',
    this.ogrn = '',
    this.legalAddress = '',
    this.website,
    this.lat,
    this.lng,
  });

  final String name;
  final String tagline;
  final String address;
  final double? lat;
  final double? lng;
  final String phone;
  final String whatsapp;

  /// Telegram и ВКонтакте — необязательные (Instagram не используем: Meta признана в РФ экстремистской).
  final String telegram;
  final String vk;
  final String? website;
  final List<DayHours> hours;

  /// Сведения о продавце (ЗоЗПП, ст. 9).
  final String legalName;
  final String inn;
  final String ogrn;
  final String legalAddress;

  factory Venue.fromJson(Map<String, dynamic> j) => Venue(
    name: j['name'] as String,
    tagline: j['tagline'] as String? ?? '',
    address: j['address'] as String,
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    phone: j['phone'] as String,
    whatsapp: j['whatsapp'] as String,
    telegram: j['telegram'] as String? ?? '',
    vk: j['vk'] as String? ?? '',
    website: j['website'] as String?,
    legalName: j['legalName'] as String? ?? '',
    inn: j['inn'] as String? ?? '',
    ogrn: j['ogrn'] as String? ?? '',
    legalAddress: j['legalAddress'] as String? ?? '',
    hours: (j['hours'] as List<dynamic>).map((e) => DayHours.fromJson(e as Map<String, dynamic>)).toList(),
  );

  /// Данные из брифа — показываем, пока не пришёл ответ сервера или нет сети.
  static const fallback = Venue(
    name: 'History Coffee',
    tagline: 'Место для ваших историй',
    address: 'г. Нальчик, ул. Толстого, 43',
    phone: '+79604316223',
    whatsapp: '+79604316223',
    website: 'https://historycoffee.ru/',
    legalName: 'ИП Жабоева А. Т.',
    hours: [
      DayHours(day: 1, open: '08:00', close: '23:00'),
      DayHours(day: 2, open: '08:00', close: '23:00'),
      DayHours(day: 3, open: '08:00', close: '23:00'),
      DayHours(day: 4, open: '08:00', close: '23:00'),
      DayHours(day: 5, open: '08:00', close: '23:00'),
      DayHours(day: 6, open: '09:00', close: '23:00'),
      DayHours(day: 7, open: '09:00', close: '23:00'),
    ],
  );
}

class OpenState {
  const OpenState({required this.isOpen, this.closesAt, this.nextOpenDay, this.nextOpenTime});

  final bool isOpen;
  final String? closesAt;
  final int? nextOpenDay;
  final String? nextOpenTime;
}

const weekdayNames = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
const weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

int _minutes(String hhmm) {
  final p = hhmm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

/// Нальчик живёт по московскому времени (UTC+3, без перехода на летнее время),
/// поэтому статус считаем в МСК независимо от часового пояса телефона.
DateTime mskNow([DateTime? utcNow]) => (utcNow ?? DateTime.now()).toUtc().add(const Duration(hours: 3));

/// Та же логика, что и на backend (src/venue/hours.ts): поддерживает выходные
/// и смены после полуночи.
OpenState computeOpenState(List<DayHours> hours, DateTime msk) {
  final byDay = {for (final h in hours) h.day: h};
  final day = msk.weekday; // 1..7
  final minutes = msk.hour * 60 + msk.minute;
  int prev(int d) => d == 1 ? 7 : d - 1;
  int next(int d) => d == 7 ? 1 : d + 1;

  final y = byDay[prev(day)];
  if (y != null && !y.isDayOff && _minutes(y.close!) < _minutes(y.open!) && minutes < _minutes(y.close!)) {
    return OpenState(isOpen: true, closesAt: y.close);
  }

  final t = byDay[day];
  if (t != null && !t.isDayOff) {
    final o = _minutes(t.open!);
    final c = _minutes(t.close!);
    if (minutes >= o && (c < o || minutes < c)) return OpenState(isOpen: true, closesAt: t.close);
    if (minutes < o) return OpenState(isOpen: false, nextOpenDay: day, nextOpenTime: t.open);
  }

  var d = next(day);
  for (var i = 0; i < 7; i++, d = next(d)) {
    final h = byDay[d];
    if (h != null && !h.isDayOff) return OpenState(isOpen: false, nextOpenDay: d, nextOpenTime: h.open);
  }
  return const OpenState(isOpen: false);
}

/// «Открыто до 23:00» / «Откроется сегодня в 08:00» / «Откроется завтра в 09:00».
String describeOpenState(OpenState s, DateTime msk) {
  if (s.isOpen) return 'Открыто до ${s.closesAt}';
  if (s.nextOpenDay == null) return 'Закрыто';
  final today = msk.weekday;
  final tomorrow = today == 7 ? 1 : today + 1;
  final when = s.nextOpenDay == today
      ? 'сегодня'
      : s.nextOpenDay == tomorrow
      ? 'завтра'
      : 'в ${_accusative(weekdayNames[s.nextOpenDay! - 1])}';
  return 'Закрыто · откроется $when в ${s.nextOpenTime}';
}

String _accusative(String day) => switch (day) {
  'среда' => 'среду',
  'пятница' => 'пятницу',
  'суббота' => 'субботу',
  _ => day,
};
