import { Workflow, WF_ID, code, codeNode, webhook, respond, ifNode, OP, mongoAggregate, mongoInsert, mongoUpdate } from './lib.mjs';

// ===========================================================================
// 07-Mobil-API — Flutter uygulamasının okuma uç noktaları + içerik kararı + görev durumu
// Uç noktalar kimlik doğrulamasızdır (uygulama otomatik bağlanır); n8n yalnızca yerel ağda tutulmalı.
// Aggregate pipeline'ları ifade içinde JSON.stringify ile kurulur; sorgu parametreleri yalnızca
// değer olarak (String/Number) kullanılır, operatör enjekte edilemez.
// ===========================================================================

// Ortak sayfalama ifadesi (sayfa=0,1,2...; sayfa başına 30)
const SAYFA = "{ \"$skip\": Math.min(Math.max(parseInt($json.query.sayfa) || 0, 0), 1000) * 30 }, { \"$limit\": 30 }";

export function mobilApi() {
  const wf = new Workflow('07-Mobil-API', WF_ID.api, 'Flutter mobil uygulaması için REST uç noktaları (GET listeler, içerik kararı, görev durumu, yeni konu).');

  // Tüm liste uç noktaları → "Liste Yanıtı" → "Yanıtla"
  codeNode(
    wf,
    'Liste Yanıtı',
    [700, 400],
    code([], () => {
      const veriler = $input
        .all()
        .map((i) => i.json)
        .filter((j) => j && Object.keys(j).length);
      return [{ json: { status: 200, body: { veriler, adet: veriler.length } } }];
    }),
  );
  respond(wf, 'Yanıtla', [1400, 400]);
  wf.link('Liste Yanıtı', 'Yanıtla');

  const liste = (ad, path, y, collection, queryExpr) => {
    const w = webhook(wf, `GET ${path}`, [0, y], `api/${path}`, 'GET');
    const m = mongoAggregate(wf, ad, [300, y], collection, queryExpr, { alwaysOutputData: true });
    wf.link(w, m).link(m, 'Liste Yanıtı');
  };

  // ---- Panel ----
  const panelPipeline = [
    { $match: { acil: true, $expr: { $gte: ['$alinma', { $dateSubtract: { startDate: '$$NOW', unit: 'day', amount: 7 } }] } } },
    { $count: 'n' },
    { $set: { k: 'acil_eposta_7g' } },
    ...[
      ['epostalar', { $expr: { $gte: ['$alinma', { $dateSubtract: { startDate: '$$NOW', unit: 'day', amount: 1 } }] } }, 'eposta_24s'],
      ['yorumlar', { duygu: 'olumsuz', $expr: { $gte: ['$olusturma', { $dateSubtract: { startDate: '$$NOW', unit: 'day', amount: 7 } }] } }, 'olumsuz_yorum_7g'],
      ['icerikler', { durum: 'onay_bekliyor' }, 'bekleyen_onay'],
      ['icerikler', { durum: 'sirada' }, 'siradaki_konu'],
      ['gorevler', { durum: 'acik' }, 'acik_gorev'],
      ['gorevler', { durum: 'acik', eksik_alanlar: { $ne: [] } }, 'eksik_gorev'],
      ['loglar', { $expr: { $gte: ['$tarih', { $dateSubtract: { startDate: '$$NOW', unit: 'day', amount: 1 } }] } }, 'hata_24s'],
    ].map(([coll, match, k]) => ({ $unionWith: { coll, pipeline: [{ $match: match }, { $count: 'n' }, { $set: { k } }] } })),
  ];
  webhook(wf, 'GET panel', [0, 0], 'api/panel', 'GET');
  mongoAggregate(wf, 'Panel Sayaçları', [300, 0], 'epostalar', JSON.stringify(panelPipeline), { alwaysOutputData: true });
  codeNode(
    wf,
    'Panel Yanıtı',
    [700, 0],
    code([], () => {
      const sayaclar = { acil_eposta_7g: 0, eposta_24s: 0, olumsuz_yorum_7g: 0, bekleyen_onay: 0, siradaki_konu: 0, acik_gorev: 0, eksik_gorev: 0, hata_24s: 0 };
      for (const { json } of $input.all()) if (json.k) sayaclar[json.k] = json.n;
      return [{ json: { status: 200, body: { sayaclar, zaman: new Date().toISOString() } } }];
    }),
  );
  wf.link('GET panel', 'Panel Sayaçları').link('Panel Sayaçları', 'Panel Yanıtı').link('Panel Yanıtı', 'Yanıtla');

  // ---- Listeler ----
  liste(
    'E-posta Listesi',
    'epostalar',
    200,
    'epostalar',
    `={{ JSON.stringify([
  { "$match": Object.assign({ durum: "tamam" },
      ["is", "fatura", "kisisel", "bulten", "diger"].includes($json.query.kategori) ? { kategori: $json.query.kategori } : {},
      $json.query.acil === "true" ? { acil: true } : {}) },
  { "$sort": { alinma: -1 } }, ${SAYFA},
  { "$project": { _id: 0, kid: 1, gonderen: 1, konu: 1, alinma: 1, ozet: 1, kategori: 1, acil: 1, gerekce: 1, bildirim_gonderildi: 1 } }
]) }}`,
  );
  liste(
    'Yorum Listesi',
    'yorumlar',
    400,
    'yorumlar',
    `={{ JSON.stringify([
  { "$match": ["olumlu", "olumsuz", "notr"].includes($json.query.duygu) ? { duygu: $json.query.duygu } : {} },
  { "$sort": { olusturma: -1 } }, ${SAYFA},
  { "$project": { _id: 0 } }
]) }}`,
  );
  liste(
    'Bülten Listesi',
    'bultenler',
    600,
    'bultenler',
    `={{ JSON.stringify([
  { "$sort": { olusturma: -1 } }, ${SAYFA},
  { "$project": { _id: 0, kid: 1, hafta: 1, konu_basligi: 1, giris: 1, haberler: 1, durum: 1, olusturma: 1 } }
]) }}`,
  );
  liste(
    'Görev Listesi',
    'gorevler',
    800,
    'gorevler',
    `={{ JSON.stringify([
  { "$match": ["acik", "tamam"].includes($json.query.durum) ? { durum: $json.query.durum } : {} },
  { "$sort": { durum: 1, tarih: 1, olusturma: -1 } }, ${SAYFA},
  { "$project": { _id: 0 } }
]) }}`,
  );
  liste(
    'İçerik Listesi',
    'icerikler',
    1000,
    'icerikler',
    `={{ JSON.stringify([
  { "$match": ["sirada", "onay_bekliyor", "onaylandi", "yayinlandi", "reddedildi_son"].includes($json.query.durum) ? { durum: $json.query.durum } : {} },
  { "$sort": { guncelleme: -1 } }, ${SAYFA},
  { "$project": { _id: 0, resume_url: 0 } }
]) }}`,
  );
  liste(
    'Log Listesi',
    'loglar',
    1200,
    'loglar',
    `={{ JSON.stringify([ { "$sort": { tarih: -1 } }, { "$limit": 50 }, { "$project": { _id: 0 } } ]) }}`,
  );

  // ---- POST api/icerikler : yeni konu sıraya ekle ----
  webhook(wf, 'POST icerikler', [0, 1450], 'api/icerikler', 'POST');
  codeNode(
    wf,
    'Konuyu Doğrula',
    [240, 1450],
    code(['uuid'], () => {
      const b = $input.first().json.body || {};
      const konu = String(b.konu || '').trim();
      if (konu.length < 5 || konu.length > 500) return [{ json: { ok: false, status: 400, body: { hata: 'Konu 5-500 karakter olmalı.' } } }];
      const simdi = new Date().toISOString();
      return [
        {
          json: {
            ok: true,
            kid: uuid(),
            konu,
            platform: b.platform === 'x' ? 'x' : 'linkedin',
            sira: Number.isFinite(Number(b.sira)) ? Number(b.sira) : Date.now(),
            durum: 'sirada',
            tur: 0,
            gecmis: [],
            olusturma: simdi,
            guncelleme: simdi,
          },
        },
      ];
    }),
  );
  ifNode(wf, 'Konu Geçerli mi?', [460, 1450], '={{ $json.ok }}', OP.isTrue);
  mongoInsert(wf, 'Konuyu Sıraya Ekle', [700, 1380], 'icerikler', 'kid,konu,platform,sira,durum,tur,gecmis,olusturma,guncelleme');
  codeNode(
    wf,
    'Konu Yanıtı',
    [940, 1380],
    code(['yanit'], () => {
      const k = $('Konuyu Doğrula').first().json;
      return yanit(201, { kid: k.kid, konu: k.konu, durum: k.durum });
    }),
  );
  wf.link('POST icerikler', 'Konuyu Doğrula')
    .link('Konuyu Doğrula', 'Konu Geçerli mi?')
    .link('Konu Geçerli mi?', 'Konuyu Sıraya Ekle', 0)
    .link('Konu Geçerli mi?', 'Yanıtla', 1)
    .link('Konuyu Sıraya Ekle', 'Konu Yanıtı')
    .link('Konu Yanıtı', 'Yanıtla');

  // ---- POST api/icerikler/karar : 06'daki Wait düğümünü sürdürür ----
  webhook(wf, 'POST icerik karar', [0, 1700], 'api/icerikler/karar', 'POST');
  codeNode(
    wf,
    'Kararı Doğrula',
    [240, 1700],
    code([], () => {
      const b = $input.first().json.body || {};
      const kid = String(b.kid || '').replace(/[^a-f0-9-]/gi, '');
      if (kid.length !== 36) return [{ json: { ok: false, status: 400, body: { hata: 'Geçersiz kid.' } } }];
      if (typeof b.onay !== 'boolean') return [{ json: { ok: false, status: 400, body: { hata: 'onay alanı true/false olmalı.' } } }];
      return [{ json: { ok: true, kid, onay: b.onay, geri_bildirim: String(b.geri_bildirim || '').slice(0, 1000), gorsel_iste: b.gorsel_iste === true } }];
    }),
  );
  ifNode(wf, 'Karar Geçerli mi?', [460, 1700], '={{ $json.ok }}', OP.isTrue);
  mongoAggregate(
    wf,
    'Bekleyen Taslağı Bul',
    [700, 1640],
    'icerikler',
    `={{ JSON.stringify([ { "$match": { kid: $json.kid, durum: "onay_bekliyor" } }, { "$limit": 1 }, { "$project": { _id: 0, kid: 1, resume_url: 1 } } ]) }}`,
    { alwaysOutputData: true },
  );
  codeNode(
    wf,
    'Sürdürme İsteği',
    [940, 1640],
    code([], () => {
      const d = $input.first().json;
      const k = $('Kararı Doğrula').first().json;
      if (!d.resume_url) return [{ json: { ok: false, status: 404, body: { hata: 'Onay bekleyen taslak bulunamadı (zaten karar verilmiş veya süresi dolmuş olabilir).' } } }];
      // Wait düğümü yalnızca localhost'tan kabul eder → aynı konteynere iç adresle git
      const url = d.resume_url.replace(/^https?:\/\/[^/]+/, 'http://127.0.0.1:5678');
      return [{ json: { ok: true, url, govde: { onay: k.onay, geri_bildirim: k.geri_bildirim, gorsel_iste: k.gorsel_iste } } }];
    }),
  );
  ifNode(wf, 'Taslak Bulundu mu?', [1160, 1640], '={{ $json.ok }}', OP.isTrue);
  wf.node(
    'Akışı Sürdür',
    'n8n-nodes-base.httpRequest',
    4.2,
    { method: 'POST', url: '={{ $json.url }}', sendBody: true, specifyBody: 'json', jsonBody: '={{ JSON.stringify($json.govde) }}', options: { timeout: 15000 } },
    [1400, 1580],
  );
  codeNode(
    wf,
    'Karar Yanıtı',
    [1620, 1580],
    code(['yanit'], () => {
      const k = $('Kararı Doğrula').first().json;
      return yanit(200, { kid: k.kid, karar: k.onay ? 'onaylandi' : 'reddedildi', mesaj: k.onay ? 'Onaylandı, paylaşım yayınlanıyor.' : 'Reddedildi, geri bildirimle yeni taslak hazırlanacak.' });
    }),
  );
  respond(wf, 'Karar Yanıtla', [1840, 1700]);
  wf.link('POST icerik karar', 'Kararı Doğrula')
    .link('Kararı Doğrula', 'Karar Geçerli mi?')
    .link('Karar Geçerli mi?', 'Bekleyen Taslağı Bul', 0)
    .link('Karar Geçerli mi?', 'Karar Yanıtla', 1)
    .link('Bekleyen Taslağı Bul', 'Sürdürme İsteği')
    .link('Sürdürme İsteği', 'Taslak Bulundu mu?')
    .link('Taslak Bulundu mu?', 'Akışı Sürdür', 0)
    .link('Taslak Bulundu mu?', 'Karar Yanıtla', 1)
    .link('Akışı Sürdür', 'Karar Yanıtı')
    .link('Karar Yanıtı', 'Karar Yanıtla');

  // ---- POST api/gorevler/durum : görevi tamamla / yeniden aç ----
  webhook(wf, 'POST gorev durum', [0, 1950], 'api/gorevler/durum', 'POST');
  codeNode(
    wf,
    'Görev Durumunu Doğrula',
    [240, 1950],
    code([], () => {
      const b = $input.first().json.body || {};
      const kid = String(b.kid || '').replace(/[^a-f0-9-]/gi, '');
      if (kid.length !== 36 || !['acik', 'tamam'].includes(b.durum)) return [{ json: { ok: false, status: 400, body: { hata: 'kid ve durum (acik|tamam) gerekli.' } } }];
      return [{ json: { ok: true, kid, durum: b.durum, guncelleme: new Date().toISOString() } }];
    }),
  );
  ifNode(wf, 'Görev İsteği Geçerli mi?', [460, 1950], '={{ $json.ok }}', OP.isTrue);
  mongoUpdate(wf, 'Görev Durumunu Kaydet', [700, 1890], 'gorevler', 'kid', 'durum,guncelleme');
  codeNode(
    wf,
    'Görev Yanıtı',
    [940, 1890],
    code(['yanit'], () => {
      const k = $('Görev Durumunu Doğrula').first().json;
      return yanit(200, { kid: k.kid, durum: k.durum });
    }),
  );
  respond(wf, 'Görev Yanıtla', [1160, 1950]);
  wf.link('POST gorev durum', 'Görev Durumunu Doğrula')
    .link('Görev Durumunu Doğrula', 'Görev İsteği Geçerli mi?')
    .link('Görev İsteği Geçerli mi?', 'Görev Durumunu Kaydet', 0)
    .link('Görev İsteği Geçerli mi?', 'Görev Yanıtla', 1)
    .link('Görev Durumunu Kaydet', 'Görev Yanıtı')
    .link('Görev Yanıtı', 'Görev Yanıtla');

  return wf;
}
