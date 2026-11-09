require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { Pool } = require('pg');

async function runMigration() {
  const connectionString = process.env.DATABASE_URL;
  if (!connectionString) {
    console.error('No DATABASE_URL found in .env');
    process.exit(1);
  }

  console.log('Connecting to Neon Postgres database...');
  const pool = new Pool({
    connectionString,
    ssl: { rejectUnauthorized: false }
  });

  try {
    const schemaSql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    console.log('Executing schema.sql on Neon database...');
    await pool.query(schemaSql);
    console.log('✅ Schema migrated successfully to Neon!');

    // Check roles
    const rolesRes = await pool.query('SELECT name, display_name FROM roles');
    console.log('✅ Active roles count:', rolesRes.rows.length);
    rolesRes.rows.forEach(r => console.log(`   - ${r.name}: ${r.display_name}`));

    // Seed default admin if not exists
    const adminEmail = process.env.BOOTSTRAP_ADMIN_USERNAME || 'dicksondogbe49@gmail.com';
    const fallbackSalt = 'a1b2c3d4e5f60718293a4b5c6d7e8f90';
    const fallbackHash = '6dcd536244f7e38206789cf87fdced61d514aa091c40ae3c0135e0fa8bb52b8bc04d0ea12abc5174a9fb3f38f3b073854332f06238e4b1be054a13a620d978e3';

    await pool.query(`
      INSERT INTO users (username, password_hash, password_salt, role, email_verified)
      VALUES ($1, $2, $3, 'admin', 1)
      ON CONFLICT (username, role) DO NOTHING
    `, [adminEmail, fallbackHash, fallbackSalt]);

    console.log(`✅ Default admin account ready: ${adminEmail}`);

  } catch (err) {
    console.error('❌ Migration failed:', err.message);
  } finally {
    await pool.end();
  }
}

runMigration();
