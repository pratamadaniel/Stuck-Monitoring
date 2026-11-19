/**
 * STUCK MONITORING - Database user di Google Sheet (privat)
 *
 * Tab "Users", baris 1 = header:
 *   A: Username | B: Name | C: Password | D: Level | E: Active
 *
 *   Level  : Admin atau SuperAdmin
 *   Active : TRUE (aktif) atau FALSE (nonaktif)
 *   Password: ketik teks biasa. Script otomatis mengubahnya menjadi hash.
 */

const USERS_SHEET = 'Users';
const LEVELS = ['Admin', 'SuperAdmin'];

/* Jalankan SEKALI dari editor Apps Script: membuat tab Users dan akun awal */
function setupSheet() {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  let sh = ss.getSheetByName(USERS_SHEET);
  if (!sh) sh = ss.insertSheet(USERS_SHEET);
  sh.clear();
  sh.getRange(1, 1, 1, 5).setValues([['Username', 'Name', 'Password', 'Level', 'Active']]).setFontWeight('bold');
  sh.getRange(2, 1, 2, 5).setValues([
    ['admin',      'Admin',       hashPw('admin123'), 'Admin',      true],
    ['superadmin', 'Super Admin', hashPw('super123'), 'SuperAdmin', true]
  ]);
  sh.setFrozenRows(1);
  sh.autoResizeColumns(1, 5);
}

/* Hash SHA-256 */
function hashPw(plain) {
  const digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, String(plain), Utilities.Charset.UTF_8);
  return 'sha256$' + digest.map(b => ('0' + (b & 0xff).toString(16)).slice(-2)).join('');
}

/* Otomatis: password teks biasa yang baru diketik di kolom C diubah menjadi hash */
function onEdit(e) {
  const r = e.range;
  if (r.getSheet().getName() !== USERS_SHEET) return;
  if (r.getColumn() !== 3 || r.getRow() < 2) return;
  const v = String(r.getValue());
  if (!v || v.indexOf('sha256$') === 0) return;
  r.setValue(hashPw(v));
}

function readUsers() {
  const sh = SpreadsheetApp.getActiveSpreadsheet().getSheetByName(USERS_SHEET);
  return sh.getDataRange().getValues().slice(1)
    .map(row => ({
      username: String(row[0]).trim(),
      name: String(row[1]).trim(),
      hash: String(row[2]),
      level: String(row[3]).trim(),
      active: String(row[4]).toUpperCase() === 'TRUE'
    }))
    .filter(u => u.username);
}

/* Endpoint: menerima POST dari aplikasi web */
function doPost(e) {
  let out;
  try {
    const b = JSON.parse(e.postData.contents);
    if (b.action !== 'login') throw new Error('Aksi tidak dikenal');

    const username = String(b.username || '').trim();
    const password = String(b.password || '');
    const u = readUsers().find(x => x.username === username);

    const ok = u && u.active && LEVELS.indexOf(u.level) >= 0 && hashPw(password) === u.hash;
    out = { ok: true, data: ok ? [{ username: u.username, name: u.name, level: u.level }] : [] };
  } catch (err) {
    out = { ok: false, error: err.message };
  }
  return ContentService.createTextOutput(JSON.stringify(out)).setMimeType(ContentService.MimeType.JSON);
}
