import { DynamicModule, Global, Module } from '@nestjs/common';
import { APP_CONFIG, AppConfig, loadConfig } from './configuration';

@Global()
@Module({})
export class AppConfigModule {
  static forRoot(override?: Partial<AppConfig>): DynamicModule {
    const config = { ...loadConfig(), ...override };
    return {
      module: AppConfigModule,
      providers: [{ provide: APP_CONFIG, useValue: config }],
      exports: [APP_CONFIG],
    };
  }
}
