import { IsBoolean, IsEmail, IsNotEmpty, IsOptional, IsString, Length, Matches, MaxLength } from 'class-validator';

export class RequestOtpDto {
  @IsString()
  @MaxLength(32)
  phone: string;
}

export class VerifyOtpDto {
  @IsString()
  @MaxLength(32)
  phone: string;

  @IsString()
  @Matches(/^\d{4,6}$/, { message: 'Код должен состоять из цифр' })
  code: string;

  /**
   * Согласие на обработку ПДн — отдельный документ (152-ФЗ ст. 9, ред. с 01.09.2025).
   * Обязательно при первой регистрации. acceptPrivacyPolicy — прежнее имя поля (старые версии приложения).
   */
  @IsOptional()
  @IsBoolean()
  acceptPersonalData?: boolean;

  @IsOptional()
  @IsBoolean()
  acceptPrivacyPolicy?: boolean;

  /** Необязательное отдельное согласие на рекламу: новости и акции (38-ФЗ ст. 18). */
  @IsOptional()
  @IsBoolean()
  acceptMarketing?: boolean;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  name?: string;
}

export class RefreshDto {
  @IsString()
  @IsNotEmpty()
  refreshToken: string;
}

export class StaffLoginDto {
  @IsEmail()
  email: string;

  @IsString()
  @Length(1, 200)
  password: string;
}
