import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { join } from 'node:path';
import { loadConfig, loadDotEnv } from '../config/configuration';
import { createDb } from './database.module';

export async function runMigrations(databaseUrl: string): Promise<void> {
  const { pool, db } = createDb(databaseUrl);
  try {
    await migrate(db, { migrationsFolder: join(__dirname, '..', '..', 'drizzle') });
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  loadDotEnv();
  runMigrations(loadConfig().databaseUrl)
    .then(() => console.log('Миграции применены'))
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}
