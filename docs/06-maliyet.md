# Tahmini Aylık Maliyet

Varsayım: küçük ekip. Ayda yaklaşık 1.500 e-posta, 300 yorum, 4 bülten, 20 toplantı ve 30 sosyal medya taslağı. Sohbette günde 30 soru.

| Kalem | Seçim | Aylık maliyet |
|---|---|---|
| LLM | **Ollama (yerel)** | **0 ₺** — yalnızca elektrik. 7B model GPU'da ~50-80 W; günde birkaç saat yükte kabaca 30-80 ₺ |
| Embedding | bge-m3 (yerel) | 0 ₺ |
| n8n | Self-hosted Community Edition (Docker) | 0 ₺ |
| Veritabanı | MongoDB Atlas M0 | 0 ₺ (512 MB; bu hacimde birkaç yıl yeter) |
| Gmail / Drive API | Google ücretsiz kota | 0 ₺ |
| Telegram Bot API | — | 0 ₺ |
| Trello | Free plan | 0 ₺ (pano başına 10 iş birliği sınırı) |
| LinkedIn paylaşım API'si | Kişisel paylaşım | 0 ₺ |
| X (Twitter) API | Kullanılmıyor | X'te paylaşım yapmak ücretli API katmanı gerektirir |
| Erişim tüneli (isteğe bağlı) | Cloudflare Tunnel | 0 ₺ |
| **Toplam** | | **≈ 0 ₺ + elektrik** |

Karşılaştırma: Aynı hacmi bulut LLM ile (ör. küçük bir API modeli) çalıştırmak kabaca ayda 1-5 USD tutar. Çoğu maliyet e-posta özetlerinden gelir. Fiyatlar sık değiştiği için güncel tarifeyi sağlayıcının sitesinden kontrol et.

## Ücretsiz katmanda kalmak için öneriler

1. **Atlas M0 depolaması:** `loglar` 90 gün sonra kendiliğinden silinir (TTL indeksi). E-posta gövdesi Mongo'ya yazılmaz, yalnızca özet saklanır. Yine de yılda bir eski `epostalar` kayıtlarını arşivle.
2. **Vektör deposu:** M0 kümede vektör indeksi sayısı sınırlı. Tek koleksiyon ve tek indeks (`vektor_indeksi`) kullanılıyor; yeni doküman türü için yeni koleksiyon açmak yerine metadata ile ayır.
3. **Gmail kotası:** Tetikleyici 2 dakikada bir, en fazla 10 e-posta çeker. Promosyon ve sosyal kategoriler sorguda hariç; bu kotayı ve LLM yükünü azaltır.
4. **n8n yürütme geçmişi:** `EXECUTIONS_DATA_MAX_AGE=336` (14 gün) disk şişmesini önler.
5. **Ollama belleği:** `keepAlive: 30m` modeli yarım saat bellekte tutar. Bilgisayarı başka işler için kullanıyorsan `5m` yap. Zayıf donanımda `qwen2.5:3b`'ye geç.
6. **Trello:** Ücretsiz plan sınırına yaklaşırsan Notion ücretsiz planına geçilebilir. Yalnızca `05`'teki Trello düğümü değişir.
7. **Sosyal medya:** X yerine LinkedIn kullanılıyor (ücretsiz). X gerekiyorsa taslak üretip onaydan sonra elle paylaşmak ücretsiz alternatiftir.
