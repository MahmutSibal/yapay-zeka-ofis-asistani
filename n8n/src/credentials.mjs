// Kullanım: node n8n/src/credentials.mjs
// .env'deki değerlerden n8n/build/credentials.json üretir (git'e girmez).
// `n8n import:credentials` bu dosyadaki düz metin değerleri N8N_ENCRYPTION_KEY ile şifreleyerek kaydeder.
// OAuth kimlik bilgileri (Gmail, Drive, LinkedIn) yalnızca client id/secret ile oluşturulur;
// n8n arayüzünde bir kez "Connect / Sign in" demen gerekir.
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CRED } from './lib.mjs';

const kok = dirname(dirname(dirname(fileURLToPath(import.meta.url))));
const envYolu = join(kok, '.env');
if (!existsSync(envYolu)) {
  console.error('.env bulunamadı. Önce: copy .env.example .env  ve değerleri doldur.');
  process.exit(1);
}
const env = Object.fromEntries(
  readFileSync(envYolu, 'utf8')
    .split(/\r?\n/)
    .filter((l) => /^\s*[A-Z0-9_]+\s*=/.test(l))
    .map((l) => {
      const i = l.indexOf('=');
      return [l.slice(0, i).trim(), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')];
    }),
);

const kayit = (anahtar, type, data) => {
  const [credType, { id, name }] = Object.entries(CRED[anahtar])[0];
  if (credType !== type) throw new Error(`Tip uyuşmazlığı: ${anahtar}`);
  return { id, name, type, data };
};

const liste = [];
const eksik = [];
const ekle = (kosul, uyari, fn) => (kosul ? liste.push(fn()) : eksik.push(uyari));

ekle(env.MONGODB_URI && !env.MONGODB_URI.includes('KULLANICI'), 'MONGODB_URI', () =>
  kayit('mongo', 'mongoDb', { configurationType: 'connectionString', connectionString: env.MONGODB_URI, database: env.MONGODB_DB || 'ofis_asistani' }),
);
ekle(env.OLLAMA_URL, 'OLLAMA_URL', () => kayit('ollama', 'ollamaApi', { baseUrl: env.OLLAMA_URL }));
ekle(env.TELEGRAM_BOT_TOKEN, 'TELEGRAM_BOT_TOKEN', () => kayit('telegram', 'telegramApi', { accessToken: env.TELEGRAM_BOT_TOKEN }));
ekle(env.TRELLO_API_KEY && env.TRELLO_API_TOKEN, 'TRELLO_API_KEY / TRELLO_API_TOKEN', () =>
  kayit('trello', 'trelloApi', { apiKey: env.TRELLO_API_KEY, apiToken: env.TRELLO_API_TOKEN }),
);
ekle(env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET, 'GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET (Gmail + Drive)', () =>
  kayit('gmail', 'gmailOAuth2', { clientId: env.GOOGLE_CLIENT_ID, clientSecret: env.GOOGLE_CLIENT_SECRET }),
);
if (env.GOOGLE_CLIENT_ID && env.GOOGLE_CLIENT_SECRET)
  liste.push(kayit('drive', 'googleDriveOAuth2Api', { clientId: env.GOOGLE_CLIENT_ID, clientSecret: env.GOOGLE_CLIENT_SECRET }));
ekle(env.LINKEDIN_CLIENT_ID && env.LINKEDIN_CLIENT_SECRET, 'LINKEDIN_CLIENT_ID / LINKEDIN_CLIENT_SECRET', () =>
  kayit('linkedin', 'linkedInOAuth2Api', { clientId: env.LINKEDIN_CLIENT_ID, clientSecret: env.LINKEDIN_CLIENT_SECRET }),
);

mkdirSync(join(kok, 'n8n', 'build'), { recursive: true });
writeFileSync(join(kok, 'n8n', 'build', 'credentials.json'), JSON.stringify(liste, null, 2), 'utf8');
console.log(`✓ ${liste.length} kimlik bilgisi yazıldı: ${liste.map((c) => c.name).join(', ')}`);
if (eksik.length) console.log(`! Atlananlar (.env'de boş): ${eksik.join('; ')}\n  Bunları sonra doldurup betiği tekrar çalıştırabilir ya da n8n arayüzünden ekleyebilirsin.`);
