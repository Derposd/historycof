import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  SetMetadata,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import type { Request } from 'express';

export type StaffRole = 'admin' | 'editor';

export interface GuestPrincipal {
  typ: 'guest';
  sub: string;
}

export interface StaffPrincipal {
  typ: 'staff';
  sub: string;
  role: StaffRole;
}

export type Principal = GuestPrincipal | StaffPrincipal;

type AuthedRequest = Request & { principal?: Principal };

function extractBearer(req: Request): string | null {
  const header = req.headers.authorization;
  if (!header) return null;
  const [scheme, token] = header.split(' ');
  return scheme?.toLowerCase() === 'bearer' && token ? token : null;
}

async function verify(jwt: JwtService, req: Request): Promise<Principal | null> {
  const token = extractBearer(req);
  if (!token) return null;
  try {
    return await jwt.verifyAsync<Principal>(token);
  } catch {
    throw new UnauthorizedException('Токен недействителен или истёк');
  }
}

/** Требует авторизованного гостя (мобильное приложение). */
@Injectable()
export class GuestGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    const principal = await verify(this.jwt, req);
    if (!principal || principal.typ !== 'guest') throw new UnauthorizedException();
    req.principal = principal;
    return true;
  }
}

/** Пускает всех; если передан валидный токен гостя — прикрепляет его. */
@Injectable()
export class OptionalGuestGuard implements CanActivate {
  constructor(private readonly jwt: JwtService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    const principal = await verify(this.jwt, req).catch(() => null);
    if (principal?.typ === 'guest') req.principal = principal;
    return true;
  }
}

export const ROLES_KEY = 'staff_roles';
/** Ограничивает эндпоинт ролями сотрудников. Без декоратора — любой сотрудник. */
export const Roles = (...roles: StaffRole[]) => SetMetadata(ROLES_KEY, roles);

@Injectable()
export class StaffGuard implements CanActivate {
  constructor(
    private readonly jwt: JwtService,
    private readonly reflector: Reflector,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    const principal = await verify(this.jwt, req);
    if (!principal || principal.typ !== 'staff') throw new UnauthorizedException();
    const roles = this.reflector.getAllAndOverride<StaffRole[] | undefined>(ROLES_KEY, [
      ctx.getHandler(),
      ctx.getClass(),
    ]);
    if (roles?.length && !roles.includes(principal.role)) {
      throw new ForbiddenException('Недостаточно прав');
    }
    req.principal = principal;
    return true;
  }
}

export const CurrentPrincipal = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): Principal | undefined =>
    ctx.switchToHttp().getRequest<AuthedRequest>().principal,
);
