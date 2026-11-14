# Kurulum Rehberi

Kurulum yaklaşık 30-45 dakika sürer. Uzun kısmı Google ve LinkedIn OAuth uygulamalarını açmaktır.

## 0. Gerekenler

| Bileşen | Not |
|---|---|
| Docker Desktop | Çalışır durumda olmalı |
| Node.js 18+ | Derleme betikleri için (`node --version`) |
| Ollama | Ya bilgisayarında kurulu ya da `-Ollama` parametresiyle Docker'da |
| MongoDB Atlas hesabı | Ücretsiz M0 küme yeterli |
| Flutter 3.x | Mobil uygulama için |
| Donanım | `qwen2.5:7b` için ~8 GB RAM/VRAM; zayıf makinede `qwen2.5:3b` |

## 1. Gereken kimlik bilgileri

| Kimlik bilgisi | Nereden | `.env` anahtarı | Kullanan modül |
|---|---|---|---|
| MongoDB Atlas bağlantı dizesi | Atlas › Database › Connect › Drivers | `MONGODB_URI` | Tümü |
| Ollama adresi | Yerel | `OLLAMA_URL` | 01-06 |
| Telegram bot token'ı | Telegram'da @BotFather › `/newbot` | `TELEGRAM_BOT_TOKEN` | 00, 01, 04, 06 |
| Telegram chat ID | Bota bir mesaj at, sonra `https://api.telegram.org/bot<TOKEN>/getUpdates` adresindeki `chat.id` | `TELEGRAM_CHAT_ID` | aynı |
| Google OAuth istemcisi | Google Cloud Console (aşağıda) | `GOOGLE_CLIENT_ID/SECRET` | 01, 02b, 03, 04, 05 |
| Trello API anahtarı ve token | https://trello.com/power-ups/admin › yeni Power-Up › API key › Token | `TRELLO_API_KEY/TOKEN` | 05 |
| Trello liste ID'si | Panoyu aç, adrese `.json` ekle, `lists[].id` | `TRELLO_LIST_ID` | 05 |
| LinkedIn OAuth uygulaması | https://www.linkedin.com/developers › Create app | `LINKEDIN_CLIENT_ID/SECRET` | 06 |

### Google OAuth (Gmail + Drive)
1. https://console.cloud.google.com › yeni proje.
2. **APIs & Services › Library**: *Gmail API* ve *Google Drive API*'yi etkinleştir.
3. **OAuth consent screen**: External seç; kendi Gmail adresini *Test users* listesine ekle.
4. **Credentials › Create credentials › OAuth client ID › Web application**.
   - Authorized redirect URI: `http://localhost:5678/rest/oauth2-credential/callback`
5. Client ID ve Secret değerlerini `.env` dosyasına yaz.

### LinkedIn
1. Uygulama oluştur. **Products** sekmesinden *Share on LinkedIn* ve *Sign In with LinkedIn using OpenID Connect* ürünlerini ekle.
2. **Auth › Redirect URL**: `http://localhost:5678/rest/oauth2-credential/callback`
3. `LINKEDIN_PERSON` değeri: n8n'de LinkedIn düğümünü açınca *Person* listesinde adın görünür. Oradaki kimliği kopyala; `urn:li:person:` önekini yazma.

### MongoDB Atlas
1. Ücretsiz M0 küme oluştur. **Database Access**'te bir kullanıcı ekle.
2. **Network Access** listesine bilgisayarının IP'sini ekle. Test için `0.0.0.0/0` da olur, ama sonra daralt.
3. Bağlantı dizesini (`mongodb+srv://...`) `MONGODB_URI`'ye yaz.
4. İndeksleri `kur.ps1` oluşturur. Vektör indeksi oluşmazsa: **Atlas Search › Create Search Index › Atlas Vector Search › JSON Editor**'e `mongo/vector-index.json` içeriğini yapıştır. Koleksiyon `ofis_asistani.dokuman_parcalari` olmalı.

## 2. Kurulum adımları

```bash
copy .env.example .env
```

`.env` dosyasını doldur. Boş bıraktığın `N8N_ENCRYPTION_KEY` değerini betik kendisi üretir.

Ollama bilgisayarında çalışıyorsa:

```bash
powershell -ExecutionPolicy Bypass -File .\kur.ps1
```

Ollama'yı da Docker'da çalıştırmak istersen (bu durumda `.env` içinde `OLLAMA_URL=http://ollama:11434` olmalı):

```bash
powershell -ExecutionPolicy Bypass -File .\kur.ps1 -Ollama
```

Ollama host'taysa modelleri bir kez indir:

```bash
ollama pull qwen2.5:7b
```

```bash
ollama pull bge-m3
```

Betik sırasıyla şunları yapar:
1. 9 workflow JSON dosyasını derler ve doğrular.
2. Kimlik bilgilerini `.env`'den hazırlar.
3. n8n'i başlatır.
4. Kimlik bilgilerini ve akışları **sabit kimliklerle** içe aktarır. Bu sayede hata akışı bağlantısı ve kimlik bilgisi eşleşmesi kendiliğinden kurulur.
5. MongoDB indekslerini oluşturur.

## 3. n8n arayüzünde son adımlar (http://localhost:5678)

1. İlk açılışta sahip hesabını oluştur.
2. **Credentials** sayfasında *Gmail*, *Google Drive* ve *LinkedIn* için **Sign in with ...** de. Client ID ve Secret zaten dolu gelir.
3. Akışları şu sırayla **Publish/Active** yap:
   `00-Hata-Yakalayici` → `07-Mobil-API` → `02b`, `02`, `03`, `05` → `01`, `04`, `06`.
4. İlk doküman için uygulamada **Sohbet › Doküman ekle** ekranına metin yapıştır. Ya da şu isteği gönder: `POST /webhook/api/dokuman/indeksle {"drive_id": "..."}`.

## 4. Mobil uygulama

```bash
cd mobil
```

```bash
flutter run
```

Uygulama **sunucuyu kendisi bulur ve otomatik bağlanır**; API anahtarı ya da ayar ekranı yoktur.

- **Emülatör / web / masaüstü:** ek bir şey gerekmez. `10.0.2.2:5678` ve `localhost:5678` otomatik denenir.
- **Gerçek telefon:** bilgisayarla aynı Wi-Fi'da ol. Bilgisayarın IP'sini derlemeye göm (`kur.ps1` bu komutu IP'nle birlikte yazdırır):

```bash
flutter run --dart-define=SUNUCU=http://192.168.1.20:5678
```

  Windows Güvenlik Duvarı'nda 5678 portuna yerel ağ için izin ver. Otomatik bulamazsa uygulama "Sunucu bulunamadı" ekranında adresi elle girmene izin verir ve bir kez bağlandıktan sonra adresi hatırlar.
- **Güvenlik:** Uç noktalar anahtarsız olduğu için n8n'i **internete veya tünele açma**. Ev/ofis ağı dışından erişim gerekiyorsa webhook'lara kimlik doğrulama geri eklenmeli.

## 5. Sık karşılaşılan sorunlar

| Belirti | Çözüm |
|---|---|
| Uygulama "Uç nokta bulunamadı" diyor | `07-Mobil-API` akışı aktif değil |
| "Sunucu bulunamadı" | n8n çalışmıyor, `07-Mobil-API` aktif değil ya da telefon farklı ağda; gerçek telefonda `--dart-define=SUNUCU=...` ile derle veya adresi elle gir |
| AI düğümleri zaman aşımına uğruyor | Ollama erişilemiyor: `docker exec ofis-n8n wget -qO- $OLLAMA_URL/api/tags` ile kontrol et; ilk çağrıda model yüklenir ve 30-60 sn sürebilir |
| JSON şema hataları | Küçük model şemaya uymuyor olabilir; parser'daki otomatik düzeltme bir deneme daha yapar. Sürerse `qwen2.5:14b` veya bulut LLM kullan |
| Sohbet hep "Notlarda bu bilgi yok" diyor | Vektör indeksi yok ya da doküman indekslenmemiş; Atlas'ta `vektor_indeksi` durumunun *READY* olduğunu kontrol et |
| İçerik onayı "taslak bulunamadı" | Onay süresi dolmuş (varsayılan 24 saat); konu sıraya geri alınmıştır |
