# Stash — landing page

Situs statis (HTML + CSS + JS biasa, tanpa build) untuk memperkenalkan Stash, memuat dokumentasi
singkat, dan menyediakan unduhan APK.

```
landing/
  index.html      halaman tunggal (fitur, tampilan, dokumentasi, privasi, unduh)
  styles.css      gaya (token warna sama dengan aplikasi)
  script.js       carousel, tab dokumentasi, menu mobile, salin checksum
  Stash.apk       APK rilis (URL tetap: /Stash.apk)
  vercel.json     header unduhan APK & cache
  assets/         font Plus Jakarta Sans (OFL), screenshot (WebP), ikon, gambar OG
```

## Menjalankan lokal

```bash
python -m http.server 8000 --directory landing
```

Buka <http://localhost:8000>.

## Deploy ke Vercel

1. Di Vercel pilih **Add New → Project** dan impor repo ini.
2. Atur **Root Directory** ke `landing`, **Framework Preset** ke *Other*, dan kosongkan Build Command
   serta Output Directory.
3. Deploy. Tombol **Unduh APK** otomatis menunjuk ke `/Stash.apk` di domain yang sama.

## Memperbarui versi aplikasi

1. `flutter build apk --release` lalu salin hasilnya ke `landing/Stash.apk`.
2. Perbarui nomor versi, ukuran file, dan **SHA-256** di `index.html`
   (`sha256sum landing/Stash.apk`), serta nama berkas di `vercel.json`.
3. Commit dan push; Vercel akan men-deploy ulang.

> Setiap APK yang di-commit menambah ±50 MB pada riwayat git. Jika repo mulai terlalu besar, pindahkan
> APK ke GitHub Releases dan arahkan tombol unduh ke sana.

## Mengganti screenshot

Ambil screenshot dari emulator, ubah ke lebar 540 px (WebP), dan timpa berkas di `assets/shots/`.
