# Stuck Monitoring (PWA)

Aplikasi monitoring shipment stuck, Palangka Raya DC.

## Struktur

```
stuck-monitoring/
├── index.html               Aplikasi utama (login, dashboard, catatan)
├── sw.js                    Service worker (mode offline)
├── manifest.webmanifest     Pengaturan install PWA
├── icon.svg                 Ikon aplikasi
└── backend-users/
    └── Code.gs              Script Google Apps Script (login user) — dipasang di spreadsheet user, BUKAN dipakai Netlify
```

## Sumber data

- **Data shipment**: tab `Raw` di spreadsheet Monitoring Stuck, dibaca lewat link publik (Anyone with the link can view).
- **Database user**: spreadsheet terpisah dan privat, diakses lewat Google Apps Script (`API_URL` di `index.html`).

## Deploy ke Netlify

Repo ini tidak memerlukan build. Di Netlify, pilih site dari repo GitHub ini dengan:
- Build command: (kosongkan)
- Publish directory: `.`

## Mengubah pengaturan

Semua konfigurasi ada di bagian atas `<script>` pada `index.html`:
- `API_URL`: URL Web App Apps Script untuk login
- `SHEET_ID`: ID spreadsheet data shipment
- `SHEET_TAB`: nama tab data (default `Raw`)

Setelah mengubah kode, push ke GitHub. Netlify akan deploy otomatis.

## Catatan

- Password user tidak pernah disimpan dalam bentuk teks biasa; script menyimpannya sebagai hash SHA-256.
- Catatan tindak lanjut per shipment disimpan di browser masing-masing, tidak dibagikan antar pengguna.
- Setelah mengubah `backend-users/Code.gs`, deploy ulang Web App di Apps Script (**Deploy → Manage deployments → Edit → New version**).
