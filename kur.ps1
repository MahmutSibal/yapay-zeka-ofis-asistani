# Yapay Zekâ Ofis Asistanı — tek komutla kurulum (Windows PowerShell)
# Kullanım:  powershell -ExecutionPolicy Bypass -File .\kur.ps1            (Ollama host'ta çalışıyorsa)
#            powershell -ExecutionPolicy Bypass -File .\kur.ps1 -Ollama    (Ollama'yı da Docker'da başlat)
param([switch]$Ollama)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Adim($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }

if (-not (Test-Path .env)) {
  Copy-Item .env.example .env
  Write-Host ".env oluşturuldu. Değerleri doldurup betiği tekrar çalıştır." -ForegroundColor Yellow
  exit 1
}

# Boş şifreleme anahtarı ve API anahtarı varsa otomatik üret
$envMetin = Get-Content .env -Raw
if ($envMetin -match '(?m)^N8N_ENCRYPTION_KEY=\s*$') {
  $k = ([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N'))
  $envMetin = $envMetin -replace '(?m)^N8N_ENCRYPTION_KEY=\s*$', "N8N_ENCRYPTION_KEY=$k"
  Write-Host "N8N_ENCRYPTION_KEY üretildi."
}
[IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env'), $envMetin, (New-Object Text.UTF8Encoding $false))

Adim 'Workflow JSON dosyaları derleniyor'
node n8n/src/build.mjs
if ($LASTEXITCODE -ne 0) { throw 'Derleme başarısız' }

Adim 'Kimlik bilgileri .env içinden hazırlanıyor'
node n8n/src/credentials.mjs
if ($LASTEXITCODE -ne 0) { throw 'Kimlik bilgisi dosyası üretilemedi' }

Adim 'Docker konteynerleri başlatılıyor'
if ($Ollama) { docker compose --profile ollama up -d } else { docker compose up -d }
if ($LASTEXITCODE -ne 0) { throw 'docker compose başarısız (Docker Desktop açık mı?)' }

Adim 'n8n hazır olana kadar bekleniyor'
$hazir = $false
for ($i = 0; $i -lt 60; $i++) {
  try { if ((Invoke-WebRequest -UseBasicParsing http://localhost:5678/healthz -TimeoutSec 3).StatusCode -eq 200) { $hazir = $true; break } } catch {}
  Start-Sleep -Seconds 2
}
if (-not $hazir) { throw 'n8n 2 dakika içinde açılmadı: docker logs ofis-n8n' }

Adim 'Kimlik bilgileri ve akışlar n8n içine aktarılıyor'
docker exec ofis-n8n n8n import:credentials --input=/import/build/credentials.json
docker exec ofis-n8n n8n import:workflow --separate --input=/import/workflows
if ($LASTEXITCODE -ne 0) { throw 'İçe aktarma başarısız' }

Adim 'MongoDB Atlas indeksleri oluşturuluyor'
$uri = (Select-String -Path .env -Pattern '^MONGODB_URI=(.*)$').Matches[0].Groups[1].Value
if ($uri -and $uri -notmatch 'KULLANICI') {
  docker run --rm -v "${PSScriptRoot}\mongo:/s" mongo:7 mongosh $uri --quiet /s/init-indexes.js
} else {
  Write-Host 'MONGODB_URI doldurulmamış, indeks adımı atlandı.' -ForegroundColor Yellow
}

Write-Host "`nKurulum tamam. n8n: http://localhost:5678" -ForegroundColor Green
Write-Host 'Sıradaki adımlar (docs/kurulum-rehberi.md):'
Write-Host '  1) n8n arayüzünde Gmail, Google Drive ve LinkedIn kimlik bilgilerinde "Sign in" de.'
Write-Host '  2) Akışları sırayla Active yap (önce 00-Hata-Yakalayici).'
$ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notmatch '^(127\.|169\.254\.)' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1).IPAddress
Write-Host '  3) Mobil uygulama sunucuyu kendisi bulur (emülatör/localhost). Gerçek telefon için şu komutla derle:'
Write-Host "     cd mobil; flutter run --dart-define=SUNUCU=http://${ip}:5678" -ForegroundColor Yellow
Write-Host '  UYARI: Uç noktalar anahtarsızdır; 5678 portunu internete açma, yalnızca yerel ağda kullan.' -ForegroundColor Yellow
