const express = require('express');
const { Pool } = require('pg');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

const pool = new Pool({
    host: process.env.DB_HOST,
    database: process.env.DB_NAME || 'app_production',
    user: process.env.DB_USER || 'dbadmin',
    password: process.env.DB_PASSWORD || 'SecurePostgresPass123!',
    port: 5432
});

const initDb = async () => {
    await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id SERIAL PRIMARY KEY,
      username VARCHAR(100) NOT NULL,
      address TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  `);
};
initDb().then(() => console.log("Database initialized")).catch(console.error);

app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

app.post('/api/users', async (req, res) => {
    const { username, address } = req.body;
    try {
        const result = await pool.query('INSERT INTO users (username, address) VALUES (\$1, \$2) RETURNING *', [username, address]);
        res.status(201).json(result.rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.get('/api/users', async (req, res) => {
    try {
        const result = await pool.query('SELECT * FROM users ORDER BY created_at DESC');
        res.json(result.rows);
    } catch (err) { res.status(500).json({ error: err.message }); }
});

app.listen(8080, () => console.log('Backend live on port 8080'));
