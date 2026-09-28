import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Delete,
  Get,
  HttpCode,
  Inject,
  Injectable,
  Logger,
  Module,
  NotFoundException,
  OnApplicationBootstrap,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { IsBoolean, IsEmail, IsIn, IsOptional, IsString, Length } from 'class-validator';
import { asc, count, eq } from 'drizzle-orm';
import * as bcrypt from 'bcryptjs';
import { APP_CONFIG, AppConfig } from '../config/configuration';
import { DB, Db } from '../db/database.module';
import { StaffUser, staffUsers } from '../db/schema';
import { CurrentPrincipal, Roles, StaffGuard, StaffPrincipal, StaffRole } from '../common/auth';

const publicStaff = (u: StaffUser) => ({
  id: u.id,
  email: u.email,
  name: u.name,
  role: u.role,
  active: u.active,
  lastLoginAt: u.lastLoginAt?.toISOString() ?? null,
  createdAt: u.createdAt.toISOString(),
});

class CreateStaffDto {
  @IsEmail() email: string;
  @IsString() @Length(1, 80) name: string;
  @IsString() @Length(10, 200, { message: 'Пароль не короче 10 символов' }) password: string;
  @IsIn(['admin', 'editor']) role: StaffRole;
}

class UpdateStaffDto {
  @IsOptional() @IsString() @Length(1, 80) name?: string;
  @IsOptional() @IsString() @Length(10, 200, { message: 'Пароль не короче 10 символов' }) password?: string;
  @IsOptional() @IsIn(['admin', 'editor']) role?: StaffRole;
  @IsOptional() @IsBoolean() active?: boolean;
}

@Injectable()
export class StaffService implements OnApplicationBootstrap {
  private readonly logger = new Logger(StaffService.name);

  constructor(
    @Inject(DB) private readonly db: Db,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  /** Первый администратор создаётся из ADMIN_BOOTSTRAP_EMAIL/PASSWORD, если сотрудников ещё нет. */
  async onApplicationBootstrap() {
    const { bootstrapEmail, bootstrapPassword } = this.config.admin;
    if (!bootstrapEmail || !bootstrapPassword) return;
    const [{ n }] = await this.db.select({ n: count() }).from(staffUsers);
    if (n > 0) return;
    await this.create({ email: bootstrapEmail, name: 'Администратор', password: bootstrapPassword, role: 'admin' });
    this.logger.log(`Создан первый администратор ${bootstrapEmail}`);
  }

  async list() {
    const rows = await this.db.select().from(staffUsers).orderBy(asc(staffUsers.createdAt));
    return rows.map(publicStaff);
  }

  async me(id: string) {
    const [u] = await this.db.select().from(staffUsers).where(eq(staffUsers.id, id));
    if (!u) throw new NotFoundException();
    return publicStaff(u);
  }

  async create(dto: CreateStaffDto) {
    const email = dto.email.toLowerCase().trim();
    const [dup] = await this.db.select({ id: staffUsers.id }).from(staffUsers).where(eq(staffUsers.email, email));
    if (dup) throw new ConflictException({ error: 'email_taken', message: 'Сотрудник с таким email уже есть' });
    const [u] = await this.db
      .insert(staffUsers)
      .values({ email, name: dto.name.trim(), role: dto.role, passwordHash: await bcrypt.hash(dto.password, 10) })
      .returning();
    return publicStaff(u);
  }

  async update(id: string, dto: UpdateStaffDto, actorId: string) {
    if (id === actorId && (dto.active === false || (dto.role && dto.role !== 'admin'))) {
      throw new BadRequestException({ error: 'self_lockout', message: 'Нельзя отключить или понизить самого себя' });
    }
    const values: Partial<typeof staffUsers.$inferInsert> = {};
    if (dto.name !== undefined) values.name = dto.name.trim();
    if (dto.role !== undefined) values.role = dto.role;
    if (dto.active !== undefined) values.active = dto.active;
    if (dto.password !== undefined) values.passwordHash = await bcrypt.hash(dto.password, 10);
    const [u] = await this.db.update(staffUsers).set(values).where(eq(staffUsers.id, id)).returning();
    if (!u) throw new NotFoundException('Сотрудник не найден');
    return publicStaff(u);
  }

  async remove(id: string, actorId: string) {
    if (id === actorId) throw new BadRequestException({ error: 'self_lockout', message: 'Нельзя удалить самого себя' });
    const res = await this.db.delete(staffUsers).where(eq(staffUsers.id, id)).returning({ id: staffUsers.id });
    if (!res.length) throw new NotFoundException('Сотрудник не найден');
  }
}

@Controller('admin/staff')
@UseGuards(StaffGuard)
export class AdminStaffController {
  constructor(private readonly staff: StaffService) {}

  @Get('me')
  me(@CurrentPrincipal() p: StaffPrincipal) {
    return this.staff.me(p.sub);
  }

  @Get()
  @Roles('admin')
  list() {
    return this.staff.list();
  }

  @Post()
  @Roles('admin')
  create(@Body() dto: CreateStaffDto) {
    return this.staff.create(dto);
  }

  @Patch(':id')
  @Roles('admin')
  update(@CurrentPrincipal() p: StaffPrincipal, @Param('id', ParseUUIDPipe) id: string, @Body() dto: UpdateStaffDto) {
    return this.staff.update(id, dto, p.sub);
  }

  @Delete(':id')
  @Roles('admin')
  @HttpCode(204)
  async remove(@CurrentPrincipal() p: StaffPrincipal, @Param('id', ParseUUIDPipe) id: string) {
    await this.staff.remove(id, p.sub);
  }
}

@Module({
  controllers: [AdminStaffController],
  providers: [StaffService],
})
export class StaffModule {}
