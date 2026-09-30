import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/utils/format.dart';

enum MenuBadge {
  teamChoice('team_choice', 'Выбор команды'),
  bestseller('bestseller', 'Хит продаж'),
  // По закону о русском языке (168-ФЗ, с 01.03.2026) надписи для покупателей — по-русски
  isNew('new', 'Новинка'),
  story('story', 'Блюдо с историей');

  const MenuBadge(this.code, this.label);

  final String code;
  final String label;

  static MenuBadge? fromCode(String code) => values.where((b) => b.code == code).firstOrNull;
}

class MenuPrice {
  const MenuPrice({required this.label, required this.amount});

  /// «S», «L», «250 мл»; пустая строка — единственный вариант.
  final String label;
  final int amount;

  factory MenuPrice.fromJson(Map<String, dynamic> j) =>
      MenuPrice(label: j['label'] as String? ?? '', amount: (j['amount'] as num).toInt());
}

/// Пищевая ценность на порцию (ПП РФ № 1515): все поля необязательны.
class MenuNutrition {
  const MenuNutrition({this.kcal, this.proteins, this.fats, this.carbs});

  final double? kcal;
  final double? proteins;
  final double? fats;
  final double? carbs;

  bool get isEmpty => kcal == null && proteins == null && fats == null && carbs == null;

  static MenuNutrition? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    double? n(String k) => (j[k] as num?)?.toDouble();
    final v = MenuNutrition(kcal: n('kcal'), proteins: n('proteins'), fats: n('fats'), carbs: n('carbs'));
    return v.isEmpty ? null : v;
  }
}

class MenuItem {
  const MenuItem({
    required this.id,
    required this.title,
    this.description,
    this.portion,
    this.imageUrl,
    this.prices = const [],
    this.badges = const [],
    this.story,
    this.nutrition,
    this.allergens,
  });

  final String id;
  final String title;
  final String? description;
  final String? portion;
  final String? imageUrl;
  final List<MenuPrice> prices;
  final List<MenuBadge> badges;
  final String? story;
  final MenuNutrition? nutrition;
  final String? allergens;

  /// «270 / 290 ₽» — компактная строка цен для карточки.
  String get priceLine {
    if (prices.isEmpty) return '';
    final amounts = prices.map((p) => formatNumber(p.amount)).join(' / ');
    return '$amounts ₽';
  }

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    portion: j['portion'] as String?,
    imageUrl: j['imageUrl'] as String?,
    prices: (j['prices'] as List<dynamic>? ?? const [])
        .map((e) => MenuPrice.fromJson(e as Map<String, dynamic>))
        .toList(),
    badges: (j['badges'] as List<dynamic>? ?? const [])
        .map((e) => MenuBadge.fromCode(e as String))
        .whereType<MenuBadge>()
        .toList(),
    story: j['story'] as String?,
    nutrition: MenuNutrition.fromJson(j['nutrition'] as Map<String, dynamic>?),
    allergens: j['allergens'] as String?,
  );
}

class MenuCategory {
  const MenuCategory({required this.id, required this.title, required this.items});

  final String id;
  final String title;
  final List<MenuItem> items;

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
    id: j['id'] as String,
    title: j['title'] as String,
    items: (j['items'] as List<dynamic>).map((e) => MenuItem.fromJson(e as Map<String, dynamic>)).toList(),
  );
}

class MenuSection {
  const MenuSection({required this.id, required this.slug, required this.title, required this.categories});

  final String id;

  /// kitchen | bar
  final String slug;
  final String title;
  final List<MenuCategory> categories;

  factory MenuSection.fromJson(Map<String, dynamic> j) => MenuSection(
    id: j['id'] as String,
    slug: j['slug'] as String,
    title: j['title'] as String,
    categories: (j['categories'] as List<dynamic>)
        .map((e) => MenuCategory.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class MenuData {
  const MenuData({required this.sections, required this.disclaimer});

  final List<MenuSection> sections;
  final String disclaimer;

  factory MenuData.fromJson(Map<String, dynamic> j) => MenuData(
    sections: (j['sections'] as List<dynamic>).map((e) => MenuSection.fromJson(e as Map<String, dynamic>)).toList(),
    disclaimer:
        j['disclaimer'] as String? ?? 'Цены и состав блюд носят информационный характер, актуальное меню — в кофейне',
  );
}

final menuProvider = FutureProvider<MenuData>((ref) async {
  final json = await ref.watch(apiClientProvider).get<Map<String, dynamic>>('/menu', auth: false);
  return MenuData.fromJson(json);
});
