# Test Planı

Her modül için iki senaryo var: biri normal, biri sınır durumu. Uygulama üzerinden ya da `curl` ile denenebilir. Uç noktalar anahtarsızdır.

## Modül 1 — E-posta özeti

| | Girdi | Beklenen çıktı |
|---|---|---|
| **Normal (acil)** | Konu: "Fatura #2231 ödenmedi – hesabınız yarın askıya alınacak". Gövde: "Merhaba, 4.850 TL tutarındaki faturanız 10 gündür ödenmemiştir. Yarın 17:00'ye kadar ödeme yapılmazsa hizmet durdurulacaktır." | `kategori: "fatura"`, `acil: true`, `ozet` en fazla 2 cümle ve tutarla tarihi içerir. `epostalar`'a `durum: tamam` olarak yazılır. Telegram'a gönderen, konu ve özet içeren 🚨 mesajı gider; `bildirim_gonderildi: true` olur. |
| **Sınır: acil olmayan** | Konu: "SON FIRSAT! Bugün %70 indirim, kaçırmayın". Pazarlama içerikli bülten. | `kategori: "bulten"`, `acil: false`. Mongo'ya yazılır ama **Telegram mesajı gitmez**: "Acil mi?" düğümünün false çıkışı boştur. |
| Ek: tekrar | Aynı e-posta ikinci kez tetiklenir | `Kaydı Başlat` E11000 verir, `Tekrar Kontrolü` sessizce atlar. LLM çağrısı yapılmaz, kayıt ikilenmez. |

## Modül 2 — Doküman sohbeti

Hazırlık: Uygulamada **Doküman ekle** ile şu metni indeksle: *"Kalite Politikası: Müşteri şikâyetleri 48 saat içinde yanıtlanır. İade süresi 14 gündür. Destek hattı hafta içi 09:00-18:00 açıktır."*

| | Girdi | Beklenen çıktı |
|---|---|---|
| **Normal** | "İade süresi kaç gün?" | `yanit` "14 gün" bilgisini içerir, `bilgi_bulundu: true`, `kaynaklar` doküman başlığını gösterir. |
| **Sınır: notlarda yok** | "Şirketin kuruluş yılı nedir?" | `yanit: "Notlarda bu bilgi yok."`, `bilgi_bulundu: false`, `kaynaklar: []`. Tahmin yürütmez. |
| Ek: bellek | "Peki destek hattı?" → "Cumartesi açık mı?" | İkinci soruda "o" bağlamı bellekten anlaşılır, yanıt dokümandan gelir: hafta içi açık, cumartesi bilgisi dokümanda yok. |

## Modül 3 — Yorum duygu analizi

| | Girdi (`POST /webhook/api/yorumlar`) | Beklenen çıktı |
|---|---|---|
| **Normal (olumsuz)** | `{"metin":"Siparişim 10 gün gecikti, müşteri hizmetleri de telefonu açmadı. Çok hayal kırıklığı."}` | Anında `202 {kid, analiz_durumu:"bekliyor"}`. Birkaç saniye sonra aynı `kid`'li belgede `duygu: "olumsuz"`, `gerekce` dolu. `EKIP_EPOSTA`'ya yorum metni ve gerekçe içeren e-posta gider; `ekip_bildirildi: true` olur. |
| **Sınır: nötr** | `{"metin":"Ürünün kargo ücreti ne kadar, hafta sonu teslimat var mı?"}` | `duygu: "notr"`, `gerekce: null`. **E-posta gitmez.** |
| Ek: model hatası | Ollama kapalıyken yorum eklenir | Yorum `bekliyor` durumunda kalır; 5 dakikalık tarama Ollama açılınca analiz eder. |

## Modül 4 — Haftalık bülten

| | Girdi | Beklenen çıktı |
|---|---|---|
| **Normal** | Geçerli 3 RSS kaynağı, `POST /webhook/api/bulten/simdi` | 5-7 haber; her birinde başlık, 2-3 cümle özet ve **kaynak bağlantısı**. Bağlantılar koddan eklenir, model uyduramaz. Giriş paragrafı vardır. E-posta gider. `bultenler` koleksiyonunda `hafta: "2026-W46"`, `durum: "gonderildi"`. |
| **Sınır: boş RSS** | `RSS_KAYNAKLARI` yalnızca son 7 günde yayın yapmamış bir kaynak (ya da geçersiz adres) | LLM çağrılmaz, e-posta gitmez. `bultenler`'e `durum: "bos"` yazılır, Telegram'a "📭 Bülten gönderilmedi" mesajı gider. Kaynak hataları mesajda listelenir. |

## Modül 5 — Toplantıdan görev

| | Girdi (`POST /webhook/api/toplanti`) | Beklenen çıktı |
|---|---|---|
| **Normal** | Toplantı tarihi 2026-11-16 (Pazartesi). Notlar: "Ayşe müşteri teklifini 20 Kasım'a kadar gönderecek. Mehmet sunucu yedeklemesini bu Cuma tamamlayacak." | 2 görev: `{sorumlu:"Ayşe", tarih:"2026-11-20"}` ve `{sorumlu:"Mehmet", tarih:"2026-11-20"}` (bu Cuma). 2 Trello kartı açılır, `eksik_adet: 0`. |
| **Sınır: tarihsiz** | "Web sitesinin hakkımızda sayfası güncellenmeli. Selin bu konuya bakacak." | `{gorev:"Hakkımızda sayfasını güncelle", sorumlu:"Selin", tarih:null}`, `eksik_alanlar:["tarih"]`. Trello kartı **"[EKSİK: tarih] …"** başlığıyla açılır. Özet e-postasında "Eksik bilgiler" bölümünde listelenir. |
| Ek: görev yok | "Genel durum değerlendirildi, herkes memnun." | `adet: 0`, "Notlarda yapılacak bir iş bulunamadı." Trello'ya ve e-postaya dokunulmaz. |

## Modül 6 — Onaylı sosyal medya

| | Girdi | Beklenen çıktı |
|---|---|---|
| **Normal** | Konu ekle: "Küçük işletmelerde yapay zekâ ile zaman tasarrufu", sonra ▶ (şimdi üret) | Durum `onay_bekliyor` olur, Telegram'a bildirim gider. Uygulamada **Onayla** → LinkedIn'de paylaşılır, durum `yayinlandi` olur, `yayin_id` dolar. |
| **Sınır: reddedilen** | Taslağı "Daha kısa olsun, emoji kullanma" geri bildirimiyle **Reddet** | Akış aynı yürütmede tur 2'ye geçer; yeni taslak geri bildirime uyar. 3. ret sonrası `reddedildi_son` olur ve Telegram'a "3 turda reddedildi" mesajı gider. **LinkedIn düğümü hiç çalışmaz.** |
| Ek: güvenlik | `curl` ile resume URL'sine dışarıdan POST; ya da `{"onay":"true"}` (metin) | Resume URL yalnızca 127.0.0.1'den kabul edilir. API, metin `"true"` değerini 400 ile reddeder. "Onaylandı mı?" düğümü katı boolean denetimi yapar. |
| Ek: zaman aşımı | 24 saat yanıt verilmez | Durum `sirada`'ya döner, Telegram'a "⏰ süre doldu" gider, ertesi gün yeniden denenir. |

## Hata akışı (00)

Ollama'yı durdurup `01`'i tetikle → `loglar` koleksiyonuna kayıt düşer, Telegram'a "⚠️ Akış hatası" ve yürütme bağlantısı gider. Uygulamada **Hata Kayıtları** ekranında görünür.

## Bu oturumda doğrulananlar

- 9 akışın tamamı n8n **2.47.7**'ye CLI ile sabit kimlikleriyle aktarıldı.
- Tüm düğüm tipleri, sürümleri, parametre adları ve kimlik bilgisi tipleri n8n'in kendi `types/nodes.json` tanımlarıyla karşılaştırıldı; uyumsuzluk yok.
- `07-Mobil-API` yerel MongoDB üzerinde canlı test edildi:
  - doğrulama hataları → 400,
  - panel sayaçları, filtreli listeler, yeni konu (201), görev durumu, bulunamayan taslak (404) → doğru yanıt,
  - `resume_url` yanıtlarda görünmüyor,
  - Türkçe karakterler korunuyor.
- Flutter: `flutter analyze` temiz; widget testleri (otomatik bağlanınca panel açılır / sunucu yoksa yeniden arama ekranı) geçiyor. Web derlemesi test n8n'ine bağlanıp panel ve e-posta ekranlarını gerçek verilerle gösterdi.
- **Henüz denenmedi:** Ollama, Gmail, Telegram, Trello ve LinkedIn içeren uçtan uca çalıştırmalar. Bunlar senin kimlik bilgilerinle yukarıdaki senaryolarla yapılmalı.
