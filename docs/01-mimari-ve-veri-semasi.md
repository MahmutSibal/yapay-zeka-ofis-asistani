# Yapay Zekâ Ofis Asistanı — Mimari ve Veri Şeması (Adım 1 + 2)

> Durum: **Onaylandı ve uygulandı.** Modül ayrıntıları: [03-modul-referansi.md](03-modul-referansi.md) · Kurulum: [04-kurulum-rehberi.md](04-kurulum-rehberi.md)

## Orijinal şartnameden değişenler

| Konu | Şartname | Yeni karar |
|---|---|---|
| Veri deposu | Google Sheets (6 sayfa) | **MongoDB Atlas** (6 + 3 koleksiyon) |
| LLM | OpenAI / Gemini / Groq | **Ollama** (yerel, Docker'da) |
| Kullanıcı arayüzü | n8n Form + Telegram | **Flutter mobil uygulama** (+ Telegram bildirim olarak kalır) |
| Backend | — | **n8n** (Webhook'larla REST API sunar) |
| Satır kimliği (Modül 3) | `row_number` | `kid` (UUID metni, benzersiz indeksli) |
| Yorum tetikleyici (Modül 3) | Sheets Trigger | Webhook (uygulamadan ekleme) + 5 dk'lık yedek tarama |
| Paylaşım onayı (Modül 6) | Telegram | **Uygulamadaki onay ekranı** (Wait düğümü + resume URL); Telegram isteğe bağlı |

---

## 1. Genel mimari

```
┌──────────────────────────┐   HTTP (yerel ağ, anahtarsız)    ┌──────────────────────────────────────────┐
│   Flutter Mobil Uygulama │ ───────────────────────────────▶ │                n8n (Docker)              │
│                          │ ◀─────────────────────────────── │                                          │
│ Panel · E-postalar       │          JSON yanıtlar            │  07-Mobil-API   (okuma uç noktaları)     │
│ Sohbet · Yorumlar        │                                   │  01-Eposta-Ozet       (Gmail Trigger)    │
│ Bültenler · Toplantı     │                                   │  02-Dokuman-Sohbet    (Webhook / Chat)   │
│ İçerik Onayı · Loglar    │                                   │  03-Yorum-Duygu       (Webhook + Cron)   │
└──────────────────────────┘                                   │  04-Haftalik-Bulten   (Pzt 09:00)        │
                                                               │  05-Toplanti-Gorev    (Webhook)          │
                                                               │  06-Sosyal-Medya      (Her gün 10:00)    │
                                                               │  00-Hata-Yakalayici   (Error Trigger)    │
                                                               └──────┬──────────────┬───────────┬────────┘
                                                                      │              │           │
                              http://ollama:11434 (aynı Docker ağı)   │              │           │ dış servisler
                                                ┌─────────────────────┘              │           ▼
                                                ▼                                    │   Gmail · Telegram
                                     ┌─────────────────────┐                         │   Trello/Notion
                                     │   Ollama (Docker)   │                         │   LinkedIn/X · RSS
                                     │ qwen2.5:7b (sohbet) │                         │
                                     │ bge-m3 (embedding)  │                         ▼
                                     └─────────────────────┘            ┌──────────────────────────┐
                                                                        │     MongoDB Atlas        │
                                                                        │ db: ofis_asistani        │
                                                                        │ 9 koleksiyon + vektör    │
                                                                        │ indeksi (RAG)            │
                                                                        └──────────────────────────┘
```

### Temel ilkeler

1. **Flutter asla doğrudan Atlas'a bağlanmaz.** Bağlantı dizesi uygulamaya gömülürse APK'dan çıkarılabilir. Tüm okuma/yazma n8n üzerinden geçer.
2. **Otomatik bağlantı, anahtar yok:** Uygulama açılışta aday adresleri (son başarılı adres → `--dart-define=SUNUCU` → emülatör `10.0.2.2` → `localhost`) paralel dener ve `/webhook/api/panel` yanıt veren ilk n8n'e bağlanır. Webhook'larda kimlik doğrulama yoktur; bu yüzden **n8n yalnızca yerel ağda** çalıştırılmalı, 5678 portu internete/tünele açılmamalıdır. (İnternetten erişim gerekirse webhook'lara Header Auth geri eklenmeli.)
3. **Tek LLM kimlik bilgisi:** Tüm AI düğümleri aynı *Ollama* kimlik bilgisini (`http://ollama:11434`) kullanır. Sohbet modeli: `qwen2.5:7b` (Türkçe + JSON çıktısında 7-8B sınıfında en tutarlılardan). Embedding: `bge-m3` (çok dilli, 1024 boyut).
4. **Yapılandırılmış çıktı:** Her AI düğümünde Structured Output Parser + JSON şeması; küçük yerel modeller şemayı bazen bozduğu için parser'ın *Auto-fixing* sarmalayıcısı ve `temperature: 0.1–0.3` kullanılır.
5. **Hata yakalama:** Tek bir `00-Hata-Yakalayici` akışı (Error Trigger → MongoDB `loglar`'a ekle → Telegram uyarısı). Diğer 7 akışın ayarlarında *Error Workflow* olarak bu seçilir. (n8n'de Error Trigger her akışa ayrı konmaz; ortak hata akışı doğru yöntemdir.)
6. **Saat dilimi:** n8n'de `GENERIC_TIMEZONE=Europe/Istanbul`; MongoDB'de tarihler UTC `Date` olarak saklanır, uygulama yerel saate çevirir.
7. **İsimlendirme:** Akışlar `00-…`–`07-…`, düğüm adları Türkçe ve açıklayıcı (ör. "Acil mi?", "Görevleri Ayır").

### Mobil API uç noktaları (n8n Webhook)

Hepsi `POST/GET {N8N_URL}/webhook/api/...`, kimlik doğrulamasız (yerel ağ).

| Yöntem | Yol | Akış | İş |
|---|---|---|---|
| GET | `/api/panel` | 07 | Sayaçlar: acil e-posta, olumsuz yorum, bekleyen onay, açık görev |
| GET | `/api/epostalar?kategori=&acil=&sayfa=` | 07 | E-posta özet listesi |
| POST | `/api/sohbet` | 02 | `{oturum_id, mesaj}` → `{yanit, kaynaklar[]}` |
| GET / POST | `/api/yorumlar` | 07 / 03 | Listele / yeni yorum ekle (analizi tetikler) |
| GET | `/api/bultenler` | 07 | Bülten arşivi (HTML gövde dahil) |
| POST | `/api/bulten/simdi` | 04 | Bülteni elle tetikle (test için) |
| POST | `/api/toplanti` | 05 | `{baslik, notlar, katilimcilar[]}` → çıkarılan görevler |
| GET | `/api/gorevler?durum=` | 07 | Görev listesi |
| GET | `/api/icerikler?durum=onay_bekliyor` | 07 | Onay bekleyen taslaklar |
| POST | `/api/icerikler/:id/karar` | 07 | `{onay: bool, geri_bildirim}` → ilgili Wait düğümünü sürdürür |
| GET | `/api/loglar` | 07 | Son hatalar |

### Docker ağı ve erişim

- n8n ve Ollama **aynı compose ağında** olmalı; n8n'den Ollama adresi `http://ollama:11434`. (Ollama host'ta çalışıyorsa `http://host.docker.internal:11434`.)
- Android emülatörden n8n: `http://10.0.2.2:5678`. Gerçek telefondan: bilgisayarın LAN IP'si veya bir HTTPS tüneli (Cloudflare Tunnel / ngrok).
- **Telegram'dan buton/yanıt almak** (Telegram Trigger veya "Send and Wait") herkese açık HTTPS adres ister → tünel gerekir. Onay uygulamadan yapılırsa sadece mesaj göndermek yeterlidir, tünel şart değildir (telefon aynı ağdaysa).
- Atlas'ta *Network Access* listesine n8n'in çıktığı IP eklenmeli.

---

## 2. MongoDB şeması — veritabanı `ofis_asistani`

Ortak alanlar: her belgede `kid: string` (UUID, **benzersiz indeks** — tüm güncellemeler bununla yapılır; n8n MongoDB düğümünde ObjectId dönüşümüyle uğraşmamak için `_id` dışarıya açılmaz), `olusturma: Date`, `guncelleme: Date`.

### `epostalar` (Modül 1)

| Alan | Tip | Not |
|---|---|---|
| `kid` | string | UUID |
| `gmail_id` | string | **unique** — aynı e-posta iki kez işlenmez |
| `thread_id` | string | |
| `gonderen` | string | `Ad <adres>` |
| `konu` | string | |
| `alinma` | Date | |
| `ozet` | string | en fazla 2 cümle |
| `kategori` | enum | `is` · `fatura` · `kisisel` · `bulten` · `diger` |
| `acil` | bool | |
| `gerekce` | string | |
| `bildirim_gonderildi` | bool | |

İndeksler: `{gmail_id:1}` unique, `{acil:1, alinma:-1}`, `{kategori:1, alinma:-1}`

### `dokuman_parcalari` (Modül 2 — RAG)

| Alan | Tip | Not |
|---|---|---|
| `text` | string | parça metni (~800 karakter, 100 örtüşme) |
| `embedding` | number[1024] | `bge-m3` |
| `metadata` | object | `{kaynak_dosya, drive_id, sayfa, parca_no}` |

Atlas Vector Search indeksi `vektor_indeksi`: `embedding`, 1024 boyut, `cosine`.
(Doküman kısaysa RAG yerine tüm metin sistem istemine konabilir; varsayılan RAG.)

### `sohbet_gecmisi` (Modül 2 — bellek)

n8n'in **MongoDB Chat Memory** düğümü kendi biçiminde yazar (`sessionId`, `messages[]`). Biz yalnızca koleksiyon adını veririz; şemayı elle yönetmeyiz. Pencere: son 10 mesaj.

### `yorumlar` (Modül 3)

| Alan | Tip | Not |
|---|---|---|
| `kid` | string | Şartnamedeki `row_number`'ın karşılığı; akış boyunca taşınır |
| `metin` | string | |
| `kaynak` | string | ör. `google`, `uygulama`, `eposta` |
| `musteri` | string \| null | |
| `duygu` | enum \| null | `olumlu` · `olumsuz` · `notr`; `null` = henüz analiz edilmedi |
| `gerekce` | string \| null | |
| `analiz_durumu` | enum | `bekliyor` · `tamam` · `hata` |
| `ekip_bildirildi` | bool | |

İndeksler: `{analiz_durumu:1}`, `{duygu:1, olusturma:-1}`

### `bultenler` (Modül 4)

| Alan | Tip | Not |
|---|---|---|
| `hafta` | string | `2026-W46` — **unique** (aynı hafta iki kez gönderilmez) |
| `konu_basligi` | string | e-posta konusu |
| `giris` | string | giriş paragrafı |
| `haberler` | array | `[{baslik, ozet, link, kaynak, yayin_tarihi}]` (5–7 adet) |
| `html` | string | gönderilen e-posta gövdesi |
| `alicilar` | string[] | |
| `durum` | enum | `gonderildi` · `bos` (RSS'te 7 günlük haber yok) · `hata` |

İndeks: `{hafta:1}` unique. Tekrar ayıklama: bu haftanın linkleri, önceki 4 bültenin `haberler.link` değerleriyle karşılaştırılır.

### `gorevler` (Modül 5)

| Alan | Tip | Not |
|---|---|---|
| `toplanti_id` | string | aynı toplantının görevlerini gruplar |
| `toplanti_basligi` | string | |
| `gorev` | string | |
| `sorumlu` | string \| null | notlarda yoksa `null` |
| `tarih` | string \| null | `YYYY-MM-DD`; notlarda yoksa `null` (Date değil: null tarih 1970'e dönüşürdü) |
| `eksik_alanlar` | string[] | ör. `["sorumlu","tarih"]` → kartta **EKSİK** |
| `kart_id` / `kart_url` | string | Trello/Notion |
| `durum` | enum | `acik` · `tamam` |

İndeksler: `{toplanti_id:1}`, `{durum:1, tarih:1}`

### `icerikler` (Modül 6)

| Alan | Tip | Not |
|---|---|---|
| `konu` | string | sıradaki konu (kullanıcı uygulamadan ekler) |
| `sira` | int | küçük olan önce |
| `durum` | enum | `sirada` · `taslak` · `onay_bekliyor` · `onaylandi` · `yayinlandi` · `reddedildi_son` · `hata` |
| `metin` | string | |
| `hashtagler` | string[] | |
| `gorsel_istemi` | string | |
| `gorsel_url` | string \| null | isteğe bağlı görsel dalı |
| `tur` | int | 1–3 (ret sonrası yeniden yazım sayısı) |
| `gecmis` | array | `[{tur, metin, geri_bildirim, karar, tarih}]` |
| `resume_url` | string \| null | Wait düğümünün sürdürme adresi (**uygulamaya gönderilmez**, yalnız n8n kullanır) |
| `platform` | enum | `linkedin` · `x` |
| `yayin_id` / `yayin_tarihi` | string / Date | |

İndeksler: `{durum:1, sira:1}`

### `loglar` (tüm akışlar)

| Alan | Tip | Not |
|---|---|---|
| `akis` | string | ör. `01-Eposta-Ozet` |
| `dugum` | string | hatayı veren düğüm |
| `hata` | string | mesaj |
| `yurutme_id` / `yurutme_url` | string | n8n execution linki |
| `seviye` | enum | `hata` · `uyari` · `bilgi` |
| `tarih` | Date | |

İndeks: `{tarih:-1}` + **TTL 90 gün** (`expireAfterSeconds: 7776000`).

---

## Varsayımlar (itiraz etmezsen bunlarla devam ederim)

1. **Hedef kullanıcı:** küçük işletme / tek ekip, aynı yerel ağda; uygulama anahtarsız ve otomatik bağlanır.
2. **Bildirim kanalı:** Telegram botu kalır (acil e-posta, olumsuz yorum, hata, onay hatırlatma). Mobil push (Firebase FCM) şimdilik kapsam dışı.
3. **Görev aracı:** Trello (n8n'de yerel düğümü sade). Notion istersen değiştiririm.
4. **Sosyal platform:** LinkedIn (n8n LinkedIn düğümü kişisel/organizasyon paylaşımı yapar). X API ücretli katman gerektirdiği için ikinci seçenek.
5. **Bülten konusu:** yapay zekâ; RSS kaynakları sonra verilecek, örnek olarak 3 Türkçe/İngilizce kaynakla doldururum.
6. **Doküman kaynağı:** Google Drive'daki bir klasör; ayrı bir "dokümanı indeksle" akışı (02b) parçalayıp Atlas'a yazar.
7. **Model:** `qwen2.5:7b`. Makinen 8 GB+ VRAM'e sahip değilse `qwen2.5:3b`'ye düşeriz (JSON kalitesi düşer).
8. **Flutter:** Riverpod + Dio + go_router, Material 3, yalnız Android/iOS (web değil).

## Şu an ortamda gördüklerim

- `Desktop\N8N` klasörü boş.
- Flutter 3.47.8 kurulu.
- Docker Desktop **çalışmıyor** (daemon'a bağlanılamadı) ve `localhost:11434`'te Ollama yanıt vermedi → kuruluma geçmeden önce Docker Desktop'ı başlatman gerekecek.

## Uygulama sırasında netleşen kararlar

- **Chat Trigger yerine Webhook:** Sohbet arayüzü Flutter uygulamasında olduğu için Modül 2 `POST /webhook/api/sohbet` ile tetiklenir. Ajan, bellek (MongoDB Chat Memory) ve doküman aracı (Atlas Vector Store) yapısı şartnamedeki gibidir.
- **Bülten HTML'i:** Model haberleri numarayla seçip özetler; HTML ve **kaynak bağlantıları koddan** eklenir. Böylece model bağlantı uyduramaz ve her haberin kaynağı garanti korunur.
- **E-posta tekrarı:** Önce `gmail_id` ile minimal kayıt açılır (benzersiz indeks), sonra LLM çalışır. Aynı e-posta iki kez işlenmez.
- **Onay güvenliği (Modül 6):** Wait düğümünün sürdürme adresi yalnızca 127.0.0.1'den kabul edilir ve yalnızca `07-Mobil-API` (taslak durumunu doğrulayarak) çağırır. Yayın dalı katı boolean `onay === true` ile açılır.
- **Görsel üretimi:** İsteğe bağlı `GORSEL_API_URL` dalı; onay ekranında "Görselle paylaş" seçilirse çalışır.
