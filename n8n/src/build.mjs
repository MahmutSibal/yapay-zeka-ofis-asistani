// Kullanım: node n8n/src/build.mjs
// n8n/workflows/*.json dosyalarını üretir ve temel doğrulamaları yapar.
import { mkdirSync, writeFileSync, readdirSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { hataYakalayici, epostaOzet } from './00-01.mjs';
import { dokumanSohbet, dokumanIndeksle } from './02.mjs';
import { yorumDuygu } from './03.mjs';
import { haftalikBulten } from './04.mjs';
import { toplantiGorev } from './05.mjs';
import { sosyalMedya } from './06.mjs';
import { mobilApi } from './07.mjs';

const kok = dirname(dirname(fileURLToPath(import.meta.url)));
const hedef = join(kok, 'workflows');
mkdirSync(hedef, { recursive: true });
for (const f of readdirSync(hedef)) if (f.endsWith('.json')) rmSync(join(hedef, f));

const akislar = [hataYakalayici, epostaOzet, dokumanSohbet, dokumanIndeksle, yorumDuygu, haftalikBulten, toplantiGorev, sosyalMedya, mobilApi].map((f) => f());

const hatalar = [];
function denetle(wf) {
  const adlar = new Set(wf.nodes.map((n) => n.name));
  const hedefler = new Set();
  for (const [kaynak, turler] of Object.entries(wf.connections)) {
    if (!adlar.has(kaynak)) hatalar.push(`${wf.name}: bağlantı kaynağı yok: ${kaynak}`);
    for (const cikislar of Object.values(turler)) for (const c of cikislar) for (const b of c) hedefler.add(b.node);
  }
  for (const n of wf.nodes) {
    const tetik = /Trigger|webhook|scheduleTrigger|errorTrigger/i.test(n.type);
    const bagli = hedefler.has(n.name) || Object.keys(wf.connections).includes(n.name);
    if (!tetik && !bagli) hatalar.push(`${wf.name}: bağlantısız düğüm: ${n.name}`);
    if (n.type === 'n8n-nodes-base.code') {
      try {
        new Function(`return (async () => {\n${n.parameters.jsCode}\n})`);
      } catch (e) {
        hatalar.push(`${wf.name} / ${n.name}: Code sözdizimi hatası: ${e.message}`);
      }
    }
    // İfadelerin içinde erken kapanan "}}" var mı?
    const tara = (v, yol) => {
      if (typeof v === 'string' && v.startsWith('=')) {
        for (const m of v.matchAll(/\{\{([\s\S]*?)\}\}/g)) {
          try {
            new Function(`return (${m[1]})`);
          } catch (e) {
            hatalar.push(`${wf.name} / ${n.name} / ${yol}: ifade ayrıştırılamadı: ${e.message}`);
          }
        }
      } else if (v && typeof v === 'object') for (const [k, x] of Object.entries(v)) tara(x, `${yol}.${k}`);
    };
    tara(n.parameters, 'parameters');
  }
}

for (const wf of akislar) {
  denetle(wf);
  const dosya = join(hedef, `${wf.name}.json`);
  writeFileSync(dosya, JSON.stringify(wf.toJSON(), null, 2) + '\n', 'utf8');
  console.log(`✓ ${wf.name}.json  (${wf.nodes.length} düğüm)`);
}

// ---------------------------------------------------------------------------
// docs/03-modul-referansi.md — düğüm listesi, If koşulları, sistem istemleri ve şemalar (koddan üretilir)
// ---------------------------------------------------------------------------
const m01 = await import('./00-01.mjs');
const m02 = await import('./02.mjs');
const m03 = await import('./03.mjs');
const m04 = await import('./04.mjs');
const m05 = await import('./05.mjs');
const m06 = await import('./06.mjs');
const istemler = {
  '01-Eposta-Ozet': [['E-postayı Analiz Et', m01.EPOSTA_SISTEM_ISTEMI, m01.EPOSTA_SEMASI]],
  '02-Dokuman-Sohbet': [['Doküman Asistanı', m02.SOHBET_SISTEM_ISTEMI, m02.SOHBET_SEMASI]],
  '03-Yorum-Duygu': [
    ['Duygu Sınıflandır (Text Classifier sistem istemi)', m03.SINIFLANDIRMA_ISTEMI, null],
    ['Olumsuzluk Gerekçesi', null, m03.GEREKCE_SEMASI],
  ],
  '04-Haftalik-Bulten': [['Bülteni Hazırla', m04.BULTEN_SISTEM_ISTEMI, m04.BULTEN_SEMASI]],
  '05-Toplanti-Gorev': [['Görevleri Çıkar', m05.GOREV_SISTEM_ISTEMI, m05.GOREV_SEMASI]],
  '06-Sosyal-Medya': [['İçerik Yaz', m06.SOSYAL_SISTEM_ISTEMI, m06.SOSYAL_SEMASI]],
};
const kisaTip = (t) => t.replace('n8n-nodes-base.', '').replace('@n8n/n8n-nodes-langchain.', 'ai.');
const ozet = (n) => {
  const p = n.parameters;
  const parca = [];
  if (p.path) parca.push(`${p.httpMethod || 'GET'} /webhook/${p.path}`);
  if (p.rule?.interval) parca.push(`cron \`${p.rule.interval[0].expression}\``);
  if (p.collection) parca.push(`${p.operation} → \`${p.collection}\`${p.updateKey ? ` (anahtar: ${p.updateKey}${p.upsert ? ', upsert' : ''})` : ''}`);
  if (p.fields) parca.push(`alanlar: ${p.fields}`);
  if (n.type.endsWith('lmChatOllama')) parca.push(`model: $env.OLLAMA_MODEL, sıcaklık ${p.options.temperature}`);
  if (p.resume) parca.push(`resume: ${p.resume}, süre sınırı: ${p.limitWaitTime ? 'var' : 'yok'}`);
  if (p.conditions?.conditions) {
    const c = p.conditions.conditions[0];
    parca.push(`koşul: \`${c.leftValue.replace(/^=/, '')}\` ${c.operator.operation}${c.rightValue !== '' ? ' ' + c.rightValue : ''}${p.conditions.options.typeValidation === 'strict' ? ' (katı tip)' : ''}`);
  }
  if (p.categories) parca.push('kategoriler: ' + p.categories.categories.map((c) => c.category).join(' / '));
  if (n.onError) parca.push(`hata: ${n.onError}`);
  return parca.join(' · ');
};
let md = '# Modül Referansı\n\n> Bu dosya `node n8n/src/build.mjs` ile kaynak koddan üretilir; elle düzenleme.\n\n';
for (const wf of akislar) {
  md += `## ${wf.name}\n\n${wf.description}\n\n| # | Düğüm | Tip | Kritik parametreler |\n|---|---|---|---|\n`;
  wf.nodes.forEach((n, i) => (md += `| ${i + 1} | ${n.name} | \`${kisaTip(n.type)}\` | ${ozet(n).replace(/\|/g, '\\|')} |\n`));
  for (const [ad, istem, sema] of istemler[wf.name] || []) {
    md += `\n### ${ad}\n\n`;
    if (istem) md += '**Sistem istemi**\n\n```text\n' + istem + '\n```\n\n';
    if (sema) md += '**JSON çıktı şeması**\n\n```json\n' + JSON.stringify(sema, null, 2) + '\n```\n';
  }
  md += '\n';
}
writeFileSync(join(dirname(kok), 'docs', '03-modul-referansi.md'), md, 'utf8');
console.log('✓ docs/03-modul-referansi.md');

if (hatalar.length) {
  console.error('\nDOĞRULAMA HATALARI:\n' + hatalar.map((h) => ' - ' + h).join('\n'));
  process.exit(1);
}
console.log('\nTüm akışlar doğrulandı.');
