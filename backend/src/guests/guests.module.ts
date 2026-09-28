import { Module } from '@nestjs/common';
import { DevicesController, MeController } from './guests.controller';
import { GuestsService } from './guests.service';

@Module({
  controllers: [MeController, DevicesController],
  providers: [GuestsService],
  exports: [GuestsService],
})
export class GuestsModule {}
