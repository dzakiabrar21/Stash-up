# Stash

Pelacak keuangan pribadi offline-first berbasis Flutter (Android & iOS).

## Fitur

- **Smart Receipt Scanner (Gemini AI)** — foto struk → nominal, toko, tanggal, kategori terisi otomatis.
- **Catat dengan Suara (Gemini AI)** — tekan ikon mikrofon di layar Catat transaksi, ucapkan mis. "makan siang padang tiga puluh lima ribu pakai BCA"; nominal, dompet, kategori, dan tanggal terisi otomatis untuk diperiksa. Seperti Scan struk, fitur ini butuh internet dan API key Gemini; rekaman dihapus dari HP setelah dikirim.
- **Multi-Wallet Ledger** — banyak dompet (BCA, Mandiri, Bank Jago, GoPay, OVO, Tunai, atau custom) dengan riwayat saldo dan transfer antar dompet.
- **Quick-Input Numpad** — kalkulator bawaan (`+ − × ÷`), dompet terakhir diingat, simpan dengan satu tap.
- **Visual Analytics (`fl_chart`)** — donut chart per kategori (bisa disentuh) dan bar chart tren 6 bulan (tap batang untuk pindah bulan).
- **100% Offline (SQLite)** — semua data di penyimpanan internal HP.
- **Ekspor CSV** — seluruh riwayat, UTF-8 dengan BOM agar rapi di Excel.

## Menjalankan

```bash
flutter pub get
flutter run
```

Pemindai struk butuh API key Gemini (gratis) dari <https://aistudio.google.com>.
Masukkan di **Pengaturan → Pemindai struk**. Key disimpan di Android Keystore / iOS Keychain
(`flutter_secure_storage`). Model default `gemini-3.6-flash` dan bisa diganti di Pengaturan.

## Struktur

```
lib/
  main.dart, app.dart          entry point, tema, navigasi bawah
  core/                        format Rupiah/tanggal, kategori, token desain (theme.dart),
                               evaluator numpad
  data/                        model, skema SQLite, repository (saldo & agregasi)
  services/                    klien Gemini bersama, pemindai struk & suara, ekspor CSV, pengaturan
  state/app_state.dart         ChangeNotifier (provider)
  ui/screens/                  Beranda, Catat transaksi, Dompet, Analitik, Pengaturan
  ui/widgets/                  numpad, daftar transaksi, pemilih dompet, komponen UI bersama
test/                          unit test numpad, repository (sqflite ffi), scanner, widget test
```

### Model data

- Nominal disimpan sebagai **integer Rupiah** (tanpa desimal).
- Saldo dompet = `saldo awal + pemasukan − pengeluaran − transfer keluar + transfer masuk`, dihitung di SQL.
- Transfer tidak dihitung sebagai pemasukan/pengeluaran di analitik.
- Menghapus dompet ikut menghapus transaksinya (`ON DELETE CASCADE`), dengan konfirmasi.

## Desain

Token warna, radius, bayangan, dan gradien ada di `lib/core/theme.dart` (`StashColors`,
`StashGradients`, `StashShadows`). Font **Plus Jakarta Sans** (lisensi SIL OFL 1.1, lihat `assets/fonts/OFL.txt`) sudah ter-bundle di
`assets/fonts/` untuk bobot 400–800, jadi tampilan sama persis tanpa internet.

## Landing page

Situs perkenalan + dokumentasi + unduh APK ada di [`landing/`](landing/) (statis, siap deploy ke Vercel dengan
Root Directory `landing`). Lihat [landing/README.md](landing/README.md).

## Merilis APK (Android)

APK siap bagikan ada di `dist/Stash-1.0.0.apk` (ditandatangani dengan kunci rilis, ~53 MB, mendukung
Android 7.0+ untuk arm64, arm32, dan x86_64).

SHA-256: `7122c024fbb0f47a89951dc904e41b1ceeca1be2edf290692533ed3d1a598daa`

**Cara memasang di HP orang lain**
1. Kirim file APK (WhatsApp, Drive, kabel USB, dll.).
2. Buka file-nya di HP. Jika diminta, izinkan *Instal aplikasi tidak dikenal* untuk aplikasi yang dipakai membuka file.
3. Untuk Scan struk dan Catat dengan suara, buka **Pengaturan** di Stash dan isi API key Gemini
   (gratis dari <https://aistudio.google.com/apikey>). Fitur lain tidak perlu key.

**Membuat build baru**

```bash
flutter build apk --release
```

Hasilnya di `build/app/outputs/flutter-apk/app-release.apk`. Naikkan `version` di `pubspec.yaml`
(angka setelah `+` adalah versionCode dan **harus selalu naik** agar bisa menimpa versi lama).
Jika tampilan hasil build tidak sesuai kode, jalankan `flutter clean` dulu.

**Kunci penandatangan — jangan sampai hilang**
- `android/keystore/stash-release.jks` dan `android/key.properties` (berisi password) dibuat khusus untuk app ini
  dan **tidak ikut git** (sudah di `.gitignore`).
- **Cadangkan kedua berkas itu** ke tempat aman (mis. flash disk atau password manager). Jika hilang, versi
  baru tidak bisa menimpa app yang sudah terpasang di HP orang; mereka harus menghapus app (dan datanya) dulu.
- Jangan membagikan kedua berkas itu kepada siapa pun.

Kebijakan privasi: lihat [PRIVACY.md](PRIVACY.md).

## Test

```bash
flutter test
```
