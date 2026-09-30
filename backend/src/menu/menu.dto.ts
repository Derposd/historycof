import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUrl,
  IsUUID,
  Length,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { MENU_BADGES, MenuBadge } from '../db/schema';

/** Пищевая ценность на порцию — все поля необязательны (ПП РФ № 1515). */
export class MenuNutritionDto {
  @IsOptional() @IsNumber({ maxDecimalPlaces: 1 }) @Min(0) @Max(5000) kcal?: number | null;
  @IsOptional() @IsNumber({ maxDecimalPlaces: 1 }) @Min(0) @Max(1000) proteins?: number | null;
  @IsOptional() @IsNumber({ maxDecimalPlaces: 1 }) @Min(0) @Max(1000) fats?: number | null;
  @IsOptional() @IsNumber({ maxDecimalPlaces: 1 }) @Min(0) @Max(1000) carbs?: number | null;
}

export class MenuPriceDto {
  @IsString()
  @MaxLength(30)
  label: string;

  @IsInt()
  @Min(0)
  @Max(1_000_000)
  amount: number;
}

export class CreateSectionDto {
  @IsString()
  @Length(1, 40)
  slug: string;

  @IsString()
  @Length(1, 80)
  title: string;

  @IsOptional()
  @IsInt()
  sort?: number;
}

export class UpdateSectionDto {
  @IsOptional()
  @IsString()
  @Length(1, 80)
  title?: string;

  @IsOptional()
  @IsInt()
  sort?: number;
}

export class CreateCategoryDto {
  @IsUUID()
  sectionId: string;

  @IsString()
  @Length(1, 80)
  title: string;

  @IsOptional()
  @IsInt()
  sort?: number;

  @IsOptional()
  @IsBoolean()
  visible?: boolean;
}

export class UpdateCategoryDto {
  @IsOptional()
  @IsUUID()
  sectionId?: string;

  @IsOptional()
  @IsString()
  @Length(1, 80)
  title?: string;

  @IsOptional()
  @IsInt()
  sort?: number;

  @IsOptional()
  @IsBoolean()
  visible?: boolean;
}

export class CreateItemDto {
  @IsUUID()
  categoryId: string;

  @IsString()
  @Length(1, 120)
  title: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  portion?: string | null;

  @IsOptional()
  @IsUrl({ require_tld: false })
  @MaxLength(1000)
  imageUrl?: string | null;

  @IsArray()
  @ArrayMaxSize(4)
  @ValidateNested({ each: true })
  @Type(() => MenuPriceDto)
  prices: MenuPriceDto[];

  @IsOptional()
  @IsArray()
  @IsIn(MENU_BADGES, { each: true })
  badges?: MenuBadge[];

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  story?: string | null;

  @IsOptional()
  @ValidateNested()
  @Type(() => MenuNutritionDto)
  nutrition?: MenuNutritionDto | null;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  allergens?: string | null;

  @IsOptional()
  @IsBoolean()
  available?: boolean;

  @IsOptional()
  @IsInt()
  sort?: number;
}

export class UpdateItemDto {
  @IsOptional()
  @IsUUID()
  categoryId?: string;

  @IsOptional()
  @IsString()
  @Length(1, 120)
  title?: string;

  @IsOptional()
  @IsString()
  @MaxLength(1000)
  description?: string | null;

  @IsOptional()
  @IsString()
  @MaxLength(40)
  portion?: string | null;

  @IsOptional()
  @IsUrl({ require_tld: false })
  @MaxLength(1000)
  imageUrl?: string | null;

  @IsOptional()
  @IsArray()
  @ArrayMaxSize(4)
  @ValidateNested({ each: true })
  @Type(() => MenuPriceDto)
  prices?: MenuPriceDto[];

  @IsOptional()
  @IsArray()
  @IsIn(MENU_BADGES, { each: true })
  badges?: MenuBadge[];

  @IsOptional()
  @IsString()
  @MaxLength(2000)
  story?: string | null;

  @IsOptional()
  @ValidateNested()
  @Type(() => MenuNutritionDto)
  nutrition?: MenuNutritionDto | null;

  @IsOptional()
  @IsString()
  @MaxLength(300)
  allergens?: string | null;

  @IsOptional()
  @IsBoolean()
  available?: boolean;

  @IsOptional()
  @IsInt()
  sort?: number;
}

export class ReorderDto {
  @IsArray()
  @IsUUID('all', { each: true })
  ids: string[];
}
