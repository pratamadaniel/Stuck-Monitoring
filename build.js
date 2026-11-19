/**
 * Build untuk Netlify.
 * Menyalin file aplikasi ke folder dist/ dan mengisi SUPABASE_URL serta
 * SUPABASE_ANON_KEY dari Environment Variables Netlify.
 */
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, '..');
const OUT = path.join(SRC, 'dist');
const FILES = ['index.html', 'sw.js', 'manifest.webmanifest', 'icon.svg'];

const url = process.env.SUPABASE_URL;
const key = process.env.SUPABASE_ANON_KEY;

if (!url || !key) {
  console.error('ERROR: SUPABASE_URL dan SUPABASE_ANON_KEY harus diisi di Netlify (Site configuration > Environment variables).');
  process.exit(1);
}

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(OUT, { recursive: true });

for (const file of FILES) {
  let content = fs.readFileSync(path.join(SRC, file), 'utf8');
  if (file === 'index.html') {
    content = content
      .replace("'__SUPABASE_URL__'", JSON.stringify(url))
      .replace("'__SUPABASE_ANON_KEY__'", JSON.stringify(key));
    if (content.includes('__SUPABASE_')) {
      console.error('ERROR: placeholder Supabase tidak ditemukan di index.html');
      process.exit(1);
    }
  }
  fs.writeFileSync(path.join(OUT, file), content);
}

console.log('Build selesai: ' + FILES.length + ' file di dist/');
