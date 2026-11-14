# Yapay Zekâ Ofis Asistanı

Tek bir n8n kurulumunda çalışan, 6 modüllü yapay zekâ otomasyon paketi ve Flutter mobil uygulaması.

- **Backend:** n8n (Docker), uygulamaya webhook'lar üzerinden REST API sunar
- **LLM:** Ollama, yerel (`qwen2.5:7b` + `bge-m3` embedding)
- **Veritabanı:** MongoDB Atlas (RAG için Atlas Vector Search dahil)
- **Mobil:** Flutter (Riverpod + Dio, Material 3, açık/koyu tema). Sunucuyu kendisi bulup **otomatik bağlanır**, API anahtarı yoktur; n8n yalnızca yerel ağda kullanılmalıdır.
- **Bildirim:** Telegram

| # | Modül | Tetikleyici | Mobil ekran |
|---|---|---|---|
| 01 | E-posta özeti ve aciliyet | Gmail (2 dk'da bir) | E-posta |
| 02 | Doküman tabanlı sohbet (RAG) | `POST /api/sohbet` | Sohbet |
| 03 | Yorum duygu analizi | `POST /api/yorumlar` + 5 dk'lık tarama | Yorumlar |
| 04 | Haftalık haber bülteni | Pzt 09:00 | Bültenler |
| 05 | Toplantı notundan görev | `POST /api/toplanti` | Toplantı / Görevler |
| 06 | Onaylı sosyal medya içeriği | Her gün 10:00 | İçerik Onayı |
| 00 | Ortak hata akışı | Error Trigger | Hata Kayıtları |
| 07 | Mobil API | Webhook'lar | Panel ve listeler |

## Sunumdaki 6 çalışma

Bu repo, sunumda anlatılan 6 otomasyon çalışmasının çalışan örnekleridir:

| Çalışma | Sunumdaki örnek | Akış dosyası |
|---|---|---|
| Gelen kutusu | 1 – E-posta özeti ve aciliyet | [01-Eposta-Ozet.json](n8n/workflows/01-Eposta-Ozet.json) |
| Bilgi bankası sohbeti | 2 – Doküman tabanlı soru-cevap | [02-Dokuman-Sohbet.json](n8n/workflows/02-Dokuman-Sohbet.json) + [02b-Dokuman-Indeksle.json](n8n/workflows/02b-Dokuman-Indeksle.json) |
| Müşteri sesi | 3 – Yorum duygu analizi | [03-Yorum-Duygu.json](n8n/workflows/03-Yorum-Duygu.json) |
| Haftalık bülten | 4 – RSS'ten bülten | [04-Haftalik-Bulten.json](n8n/workflows/04-Haftalik-Bulten.json) |
| Toplantı takibi | 5 – Notlardan görev | [05-Toplanti-Gorev.json](n8n/workflows/05-Toplanti-Gorev.json) |
| İçerik takvimi | 6 – Onaylı sosyal medya paylaşımı | [06-Sosyal-Medya.json](n8n/workflows/06-Sosyal-Medya.json) |

Her JSON dosyası n8n'e doğrudan içe aktarılabilir: **Workflows › Import from File**.

## Hızlı başlangıç

```bash
copy .env.example .env
```

`.env` dosyasını doldur, ardından:

```bash
powershell -ExecutionPolicy Bypass -File .\kur.ps1
```

```bash
cd mobil && flutter run
```

Ayrıntılar: [docs/04-kurulum-rehberi.md](docs/04-kurulum-rehberi.md)

## Klasör yapısı

```
docker-compose.yml        n8n (+ isteğe bağlı Ollama)
.env.example              tüm yapılandırma
kur.ps1                   derle → başlat → içe aktar → indeksler
mongo/                    Atlas indeks betiği + vektör indeksi tanımı
n8n/src/                  akış tanımları (JS) — kaynak burası
n8n/workflows/            üretilen, içe aktarılabilir n8n JSON'ları
mobil/                    Flutter uygulaması
docs/                     mimari, modül referansı, kurulum, test, maliyet
```

Akışları değiştirmek için `n8n/src/*.mjs` dosyalarını düzenle, ardından `node n8n/src/build.mjs` çalıştır. Bu komut JSON'ları ve `docs/03-modul-referansi.md`'yi yeniden üretir; Code düğümlerini ve ifadeleri sözdizimi açısından doğrular. n8n arayüzünde yaptığın değişiklikleri kalıcı tutmak istersen akışı oradan dışa aktar; aksi hâlde bir sonraki derleme o değişikliklerin üzerine yazar.

## Dokümanlar

1. [Mimari ve veri şeması](docs/01-mimari-ve-veri-semasi.md)
2. [Modül referansı](docs/03-modul-referansi.md): düğüm listeleri, sistem istemleri, JSON şemaları, If koşulları
3. [Kurulum rehberi](docs/04-kurulum-rehberi.md)
4. [Test planı](docs/05-test-plani.md)
5. [Maliyet](docs/06-maliyet.md)
