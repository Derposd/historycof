import { Module } from '@nestjs/common';
import { AdminMenuController, MenuController } from './menu.controller';
import { MenuService } from './menu.service';

@Module({
  controllers: [MenuController, AdminMenuController],
  providers: [MenuService],
})
export class MenuModule {}
