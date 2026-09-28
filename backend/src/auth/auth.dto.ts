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

  /** Согласие на обработку ПДн (152-ФЗ). Обязательно при первой регистрации. */
  @IsOptional()
  @IsBoolean()
  acceptPrivacyPolicy?: boolean;

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
