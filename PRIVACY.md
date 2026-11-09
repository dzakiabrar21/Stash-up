# Kebijakan Privasi Stash

Terakhir diperbarui: 9 November 2026

Stash adalah aplikasi pencatat keuangan pribadi yang menyimpan datamu **di HP-mu sendiri**.

## Yang disimpan di HP

- Dompet, saldo, dan semua transaksi disimpan dalam database SQLite di penyimpanan internal aplikasi.
- Data ini **tidak dikirim ke server mana pun** oleh Stash dan tidak ada akun pengguna.
- Jika kamu menghapus aplikasi, data ikut terhapus. Gunakan **Ekspor CSV** di Pengaturan untuk membuat cadangan.

## Fitur yang memakai internet (opsional)

Dua fitur memakai layanan **Google Gemini** dengan **API key milikmu sendiri**:

| Fitur | Yang dikirim ke Google | Kapan |
|---|---|---|
| Scan struk | Foto struk yang kamu pilih/foto | Hanya saat kamu menekan Scan struk dan memilih gambar |
| Catat dengan suara | Rekaman suara pendek (maks. 30 detik) beserta daftar nama dompetmu dan tanggal hari ini | Hanya saat kamu menekan ikon mikrofon lalu Selesai |

- Rekaman suara disimpan sementara di HP hanya sampai dikirim, lalu dihapus.
- Data transaksi lain (nominal, saldo, riwayat) **tidak pernah** dikirim.
- Pemrosesan oleh Google tunduk pada kebijakan Google untuk Gemini API (<https://ai.google.dev/gemini-api/terms>). Ketentuan penggunaan data pada paket gratis dan berbayar berbeda; periksa sebelum memakai.
- API key disimpan terenkripsi di perangkat (Android Keystore / iOS Keychain) dan hanya dikirim ke Google sebagai kredensial.

Tanpa internet atau tanpa API key, semua fitur lain tetap berfungsi penuh.

## Izin yang diminta

- **Kamera / galeri** — untuk memilih foto struk.
- **Mikrofon** — hanya saat merekam catatan suara.
- **Internet** — hanya untuk Scan struk dan Catat dengan suara.

## Pelacakan

Stash tidak memakai iklan, analitik, atau pelacak pihak ketiga.

## Kontak

Pertanyaan tentang privasi: buka *issue* di <https://github.com/dzakiabrar21/Stash-up/issues>.
