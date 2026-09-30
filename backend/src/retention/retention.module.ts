import { Module } from '@nestjs/common';
import { GuestsModule } from '../guests/guests.module';
import { RetentionService } from './retention.service';

@Module({ imports: [GuestsModule], providers: [RetentionService], exports: [RetentionService] })
export class RetentionModule {}
