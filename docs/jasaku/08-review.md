# Review

## Deskripsi

Fitur review memungkinkan customer memberikan rating bintang 1-5 dan teks ulasan opsional setelah pesanan selesai. Review dikirim satu kali per pesanan melalui bottom sheet.

## Flow

### 1. Trigger Review

Review dapat diakses dari dua tempat:
1. **Beranda**: Tap kartu pesanan `completed` → buka `ReviewBottomSheet`
2. **Daftar Pesanan**: Tap pesanan `completed` → detail bottom sheet → tombol **"Beri Rating & Review"**

### 2. Bottom Sheet Review

1. `ReviewBottomSheet` terbuka (scrollable, rounded top corners)
2. Menampilkan:
   - Judul: **"Beri Rating & Review"**
   - Subtitle: "Bagaimana pengalaman Anda dengan {providerName}?"
   - **Rating bintang**: 5 bintang interaktif (tap untuk pilih)
   - **TextField review** (opsional): max 500 karakter, 3 baris
   - Tombol **"Kirim Review"**

### 3. Submit Review

1. Customer pilih rating (1-5 bintang) — wajib
2. Tulis review (opsional)
3. Tap **"Kirim Review"**
4. `POST /api/reviews` dengan body:
   ```json
   {
     "orderId": "order-uuid",
     "providerId": "provider-uuid",
     "rating": 5,
     "review": "Sangat puas dengan hasil kerjanya!"
   }
   ```
5. Jika `review` kosong → field `review` dikirim `null`
6. Jika sukses → SnackBar "Review berhasil dikirim!" → bottom sheet tertutup
7. Jika gagal → SnackBar error message dari backend

### 4. Validasi

- Rating wajib dipilih (minimal 1 bintang)
- Tombol "Kirim Review" disabled jika rating = 0
- Review teks bersifat opsional (boleh kosong)

## API Endpoints

| Endpoint | Method | Keterangan |
|---|---|---|
| `/api/reviews` | POST | Kirim review |

### Request Body

```json
{
  "orderId": "uuid",
  "providerId": "uuid",
  "rating": 5,
  "review": "Teks review opsional, bisa null"
}
```

### Response (Sukses)

```json
{
  "data": {
    "id": "review-uuid",
    "rating": 5,
    "review": "Sangat puas!",
    "created_at": "2026-07-15T10:30:00Z"
  }
}
```

## Screen Files

| Screen | Path |
|---|---|
| Review Bottom Sheet | `features/orders/presentation/pages/review_bottom_sheet.dart` |

## Catatan

- Satu review per pesanan (backend seharusnya mencegah duplikasi)
- Review langsung terlihat di profil provider oleh customer lain
- Tidak ada fitur edit/hapus review dari customer

## Status

**(SUKSES)** — Fitur review berfungsi: rating bintang, teks opsional, dan pengiriman ke backend. Review ditampilkan di halaman profil provider.
