import { BadRequestException, ConflictException, Inject, Injectable, NotFoundException } from '@nestjs/common';
import { asc, eq, inArray } from 'drizzle-orm';
import { DB, Db } from '../db/database.module';
import { MenuBadge, menuCategories, MenuItem, menuItems, MenuNutrition, MenuPrice, menuSections } from '../db/schema';
import {
  CreateCategoryDto,
  CreateItemDto,
  CreateSectionDto,
  UpdateCategoryDto,
  UpdateItemDto,
  UpdateSectionDto,
} from './menu.dto';

export interface PublicMenuItem {
  id: string;
  title: string;
  description: string | null;
  portion: string | null;
  imageUrl: string | null;
  prices: MenuPrice[];
  badges: MenuBadge[];
  story: string | null;
  nutrition: MenuNutrition | null;
  allergens: string | null;
}

export interface PublicMenu {
  sections: {
    id: string;
    slug: string;
    title: string;
    categories: { id: string; title: string; items: PublicMenuItem[] }[];
  }[];
  disclaimer: string;
  updatedAt: string | null;
}

export const MENU_DISCLAIMER = 'Цены и состав блюд носят информационный характер, актуальное меню — в кофейне';

@Injectable()
export class MenuService {
  constructor(@Inject(DB) private readonly db: Db) {}

  /** Полное дерево меню для приложения: только видимые категории и доступные позиции. */
  async publicMenu(): Promise<PublicMenu> {
    const tree = await this.tree();
    let updatedAt: Date | null = null;
    const bump = (d: Date) => {
      if (!updatedAt || d > updatedAt) updatedAt = d;
    };

    const sections = tree.map((s) => {
      bump(s.updatedAt);
      return {
        id: s.id,
        slug: s.slug,
        title: s.title,
        categories: s.categories
          .filter((c) => c.visible)
          .map((c) => {
            bump(c.updatedAt);
            return {
              id: c.id,
              title: c.title,
              items: c.items
                .filter((i) => i.available)
                .map((i): PublicMenuItem => {
                  bump(i.updatedAt);
                  return {
                    id: i.id,
                    title: i.title,
                    description: i.description,
                    portion: i.portion,
                    imageUrl: i.imageUrl,
                    prices: i.prices,
                    badges: i.badges,
                    story: i.story,
                    nutrition: i.nutrition ?? null,
                    allergens: i.allergens,
                  };
                }),
            };
          })
          .filter((c) => c.items.length > 0),
      };
    });

    return {
      sections,
      disclaimer: MENU_DISCLAIMER,
      updatedAt: (updatedAt as Date | null)?.toISOString() ?? null,
    };
  }

  /** Полное дерево для админки, включая скрытое. */
  async tree() {
    const [sections, categories, items] = await Promise.all([
      this.db.select().from(menuSections).orderBy(asc(menuSections.sort), asc(menuSections.title)),
      this.db.select().from(menuCategories).orderBy(asc(menuCategories.sort), asc(menuCategories.title)),
      this.db.select().from(menuItems).orderBy(asc(menuItems.sort), asc(menuItems.title)),
    ]);
    const itemsByCat = new Map<string, MenuItem[]>();
    for (const i of items) {
      const list = itemsByCat.get(i.categoryId) ?? [];
      list.push(i);
      itemsByCat.set(i.categoryId, list);
    }
    return sections.map((s) => ({
      ...s,
      categories: categories
        .filter((c) => c.sectionId === s.id)
        .map((c) => ({ ...c, items: itemsByCat.get(c.id) ?? [] })),
    }));
  }

  // ─── Разделы ───

  async createSection(dto: CreateSectionDto) {
    const slug = dto.slug.trim().toLowerCase();
    if (!/^[a-z0-9-]+$/.test(slug)) {
      throw new BadRequestException({ error: 'slug_invalid', message: 'Slug: латиница, цифры и дефис' });
    }
    const [dup] = await this.db.select({ id: menuSections.id }).from(menuSections).where(eq(menuSections.slug, slug));
    if (dup) throw new ConflictException({ error: 'slug_taken', message: 'Раздел с таким slug уже есть' });
    const [s] = await this.db
      .insert(menuSections)
      .values({ slug, title: dto.title.trim(), sort: dto.sort ?? 0 })
      .returning();
    return s;
  }

  async updateSection(id: string, dto: UpdateSectionDto) {
    const [s] = await this.db
      .update(menuSections)
      .set({ ...(dto.title !== undefined && { title: dto.title.trim() }), ...(dto.sort !== undefined && { sort: dto.sort }) })
      .where(eq(menuSections.id, id))
      .returning();
    if (!s) throw new NotFoundException('Раздел не найден');
    return s;
  }

  async deleteSection(id: string) {
    const res = await this.db.delete(menuSections).where(eq(menuSections.id, id)).returning({ id: menuSections.id });
    if (!res.length) throw new NotFoundException('Раздел не найден');
  }

  // ─── Категории ───

  async createCategory(dto: CreateCategoryDto) {
    await this.assertSection(dto.sectionId);
    const [c] = await this.db
      .insert(menuCategories)
      .values({ sectionId: dto.sectionId, title: dto.title.trim(), sort: dto.sort ?? 0, visible: dto.visible ?? true })
      .returning();
    return c;
  }

  async updateCategory(id: string, dto: UpdateCategoryDto) {
    if (dto.sectionId) await this.assertSection(dto.sectionId);
    const values: Partial<typeof menuCategories.$inferInsert> = {};
    if (dto.sectionId !== undefined) values.sectionId = dto.sectionId;
    if (dto.title !== undefined) values.title = dto.title.trim();
    if (dto.sort !== undefined) values.sort = dto.sort;
    if (dto.visible !== undefined) values.visible = dto.visible;
    const [c] = await this.db.update(menuCategories).set(values).where(eq(menuCategories.id, id)).returning();
    if (!c) throw new NotFoundException('Категория не найдена');
    return c;
  }

  async deleteCategory(id: string) {
    const res = await this.db
      .delete(menuCategories)
      .where(eq(menuCategories.id, id))
      .returning({ id: menuCategories.id });
    if (!res.length) throw new NotFoundException('Категория не найдена');
  }

  // ─── Позиции ───

  async createItem(dto: CreateItemDto) {
    await this.assertCategory(dto.categoryId);
    const [i] = await this.db
      .insert(menuItems)
      .values({
        categoryId: dto.categoryId,
        title: dto.title.trim(),
        description: dto.description?.trim() || null,
        portion: dto.portion?.trim() || null,
        imageUrl: dto.imageUrl ?? null,
        prices: normalizePrices(dto.prices),
        badges: uniqueBadges(dto.badges ?? []),
        story: dto.story?.trim() || null,
        nutrition: cleanNutrition(dto.nutrition),
        allergens: dto.allergens?.trim() || null,
        available: dto.available ?? true,
        sort: dto.sort ?? 0,
      })
      .returning();
    return i;
  }

  async updateItem(id: string, dto: UpdateItemDto) {
    if (dto.categoryId) await this.assertCategory(dto.categoryId);
    const values: Partial<typeof menuItems.$inferInsert> = {};
    if (dto.categoryId !== undefined) values.categoryId = dto.categoryId;
    if (dto.title !== undefined) values.title = dto.title.trim();
    if (dto.description !== undefined) values.description = dto.description?.trim() || null;
    if (dto.portion !== undefined) values.portion = dto.portion?.trim() || null;
    if (dto.imageUrl !== undefined) values.imageUrl = dto.imageUrl;
    if (dto.prices !== undefined) values.prices = normalizePrices(dto.prices);
    if (dto.badges !== undefined) values.badges = uniqueBadges(dto.badges);
    if (dto.story !== undefined) values.story = dto.story?.trim() || null;
    if (dto.nutrition !== undefined) values.nutrition = cleanNutrition(dto.nutrition);
    if (dto.allergens !== undefined) values.allergens = dto.allergens?.trim() || null;
    if (dto.available !== undefined) values.available = dto.available;
    if (dto.sort !== undefined) values.sort = dto.sort;
    const [i] = await this.db.update(menuItems).set(values).where(eq(menuItems.id, id)).returning();
    if (!i) throw new NotFoundException('Позиция не найдена');
    return i;
  }

  async deleteItem(id: string) {
    const res = await this.db.delete(menuItems).where(eq(menuItems.id, id)).returning({ id: menuItems.id });
    if (!res.length) throw new NotFoundException('Позиция не найдена');
  }

  /** Порядок задаётся списком id — sort = индекс. */
  async reorder(kind: 'sections' | 'categories' | 'items', ids: string[]) {
    const table = kind === 'sections' ? menuSections : kind === 'categories' ? menuCategories : menuItems;
    await this.db.transaction(async (tx) => {
      const existing = await tx.select({ id: table.id }).from(table).where(inArray(table.id, ids));
      if (existing.length !== ids.length) throw new BadRequestException('Неизвестные id в списке');
      for (const [index, id] of ids.entries()) {
        await tx.update(table).set({ sort: index }).where(eq(table.id, id));
      }
    });
  }

  private async assertSection(id: string) {
    const [s] = await this.db.select({ id: menuSections.id }).from(menuSections).where(eq(menuSections.id, id));
    if (!s) throw new BadRequestException({ error: 'section_not_found', message: 'Раздел не найден' });
  }

  private async assertCategory(id: string) {
    const [c] = await this.db.select({ id: menuCategories.id }).from(menuCategories).where(eq(menuCategories.id, id));
    if (!c) throw new BadRequestException({ error: 'category_not_found', message: 'Категория не найдена' });
  }
}

function normalizePrices(prices: MenuPrice[]): MenuPrice[] {
  return prices.map((p) => ({ label: p.label.trim(), amount: Math.round(p.amount) }));
}

function uniqueBadges(badges: MenuBadge[]): MenuBadge[] {
  return [...new Set(badges)];
}

/** Пустые значения пищевой ценности убираем; если не указано ничего — null. */
function cleanNutrition(n: MenuNutrition | null | undefined): MenuNutrition | null {
  if (!n) return null;
  const out: MenuNutrition = {};
  for (const k of ['kcal', 'proteins', 'fats', 'carbs'] as const) {
    const v = n[k];
    if (typeof v === 'number' && Number.isFinite(v)) out[k] = Math.round(v * 10) / 10;
  }
  return Object.keys(out).length ? out : null;
}
