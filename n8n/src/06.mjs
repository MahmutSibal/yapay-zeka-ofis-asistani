import { Workflow, WF_ID, CRED, code, codeNode, webhook, ifNode, OP, agent, mongoAggregate, mongoUpdate, telegram, schedule } from './lib.mjs';

// ===========================================================================
// 06-Sosyal-Medya — onaylı içerik ajanı
// Her gün 10:00 → sıradaki konu → AI Agent taslak → 'onay_bekliyor' + Telegram bildirimi
// → Wait (resume webhook; yalnızca 07-Mobil-API çağırır) → Onay? → LinkedIn
// Ret → geri bildirimle yeniden yaz (en fazla 3 tur). Zaman aşımı → konu sıraya geri döner.
// ===========================================================================
export const SOSYAL_SISTEM_ISTEMI = `Sen küçük bir işletmenin sosyal medya içerik yazarısın.

Görevin: Verilen konu için platforma uygun bir paylaşım taslağı hazırlamak.

Platform kuralları:
- linkedin: Profesyonel ama samimi ton. İlk satır dikkat çekici bir cümle olsun. 600-1200 karakter, kısa paragraflar. En fazla 2 emoji.
- x: En fazla 240 karakter, tek net mesaj.

Alanlar:
- metin: Paylaşım metni. Hashtag'leri metnin İÇİNE yazma.
- hashtagler: 3-5 adet, Türkçe karakter içermeyen, boşluksuz, başında # olan etiket (ör. "#yapayzeka").
- gorsel_istemi: Bu paylaşıma eşlik edecek görseli tarif eden 1-2 cümlelik Türkçe istem (görselin kendisi değil; sahne, stil ve renkleri anlat, görselde yazı olmasın).

Kesin kurallar:
- Doğrulanamayan istatistik, rakam, alıntı, müşteri adı veya iddia uydurma.
- Tur 2 veya 3 ise: önceki taslağı ve onaylayanın geri bildirimini dikkate alarak taslağı BAŞTAN yeniden yaz; geri bildirimdeki her isteği karşıla.
- Yalnızca Türkçe ve Latin alfabesiyle yaz. Yanıtı yalnızca istenen JSON biçiminde ver.`;

export const SOSYAL_SEMASI = {
  type: 'object',
  properties: {
    metin: { type: 'string', description: 'Paylaşım metni (hashtag içermez)' },
    hashtagler: { type: 'array', items: { type: 'string' }, minItems: 0, maxItems: 5 },
    gorsel_istemi: { type: 'string', description: 'Görsel üretimi için Türkçe tarif' },
  },
  required: ['metin', 'hashtagler', 'gorsel_istemi'],
  additionalProperties: false,
};

export function sosyalMedya() {
  const wf = new Workflow(
    '06-Sosyal-Medya',
    WF_ID.sosyal,
    "Her gün sıradaki konu için LinkedIn taslağı üretir, mobil uygulamadan onay bekler; onaysız yayın yapmaz, ret gelirse en fazla 3 tur yeniden yazar.",
  );

  schedule(wf, 'Her Gün 10:00', [0, -100], '0 0 10 * * *');
  webhook(wf, 'Elle Başlat', [0, 100], 'api/icerik/simdi', 'POST', 'onReceived');

  mongoAggregate(
    wf,
    'Sıradaki Konu',
    [240, 0],
    'icerikler',
    JSON.stringify([{ $match: { durum: 'sirada' } }, { $sort: { sira: 1, olusturma: 1 } }, { $limit: 1 }, { $project: { _id: 0, resume_url: 0 } }]),
    { alwaysOutputData: true },
  );
  ifNode(wf, 'Konu Var mı?', [460, 0], '={{ $json.kid }}', OP.notEmpty);
  telegram(wf, 'Konu Kalmadı Uyarısı', [700, 180], 'ℹ️ <b>Sosyal medya</b>\nSırada bekleyen içerik konusu yok. Mobil uygulamadan yeni konu ekleyebilirsin.');

  codeNode(
    wf,
    'İlk Tur Bağlamı',
    [700, -100],
    code([], () => {
      const d = $input.first().json;
      return [{ json: { kid: d.kid, konu: d.konu, platform: d.platform === 'x' ? 'x' : 'linkedin', tur: 1, onceki_metin: '', geri_bildirim: '', gecmis: Array.isArray(d.gecmis) ? d.gecmis : [] } }];
    }),
  );

  // İlk tur ve yeniden yazım turları buradan geçer → sonraki düğümler bağlamı tek yerden okur
  codeNode(
    wf,
    'Taslak Bağlamı',
    [940, -100],
    code([], () => {
      return [{ json: $input.first().json }];
    }),
  );

  agent(wf, 'İçerik Yaz', [1180, -100], {
    text:
      '=Platform: {{ $json.platform }}\n' +
      'Konu: {{ $json.konu }}\n' +
      'Tur: {{ $json.tur }} / 3\n\n' +
      "{{ $json.tur > 1 ? 'Önceki taslak:\\n\"\"\"\\n' + $json.onceki_metin + '\\n\"\"\"\\nOnaylayanın geri bildirimi: ' + ($json.geri_bildirim || '(geri bildirim verilmedi; farklı bir yaklaşım dene)') + '\\n\\nBu geri bildirime göre taslağı baştan yeniden yaz.' : 'İlk taslağı yaz.' }}",
    systemMessage: SOSYAL_SISTEM_ISTEMI,
    schema: SOSYAL_SEMASI,
    temperature: 0.7,
  });

  codeNode(
    wf,
    'Taslağı Hazırla',
    [1500, -100],
    code(['tr', 'html'], () => {
      const b = $('Taslak Bağlamı').itemMatching(0).json;
      const o = $input.first().json.output || {};
      const sinir = b.platform === 'x' ? 280 : 3000;

      const hashtagler = [
        ...new Set(
          (Array.isArray(o.hashtagler) ? o.hashtagler : [])
            .map((h) => '#' + duzelt(h).replace(/^#+/, '').replace(/\s+/g, ''))
            .filter((h) => h.length > 2),
        ),
      ].slice(0, 5);
      let metin = duzelt(o.metin).replace(/(^|\s)#[\p{L}\p{N}_]+/gu, '$1').replace(/ {2,}/g, ' ').trim();
      const ek = hashtagler.length ? '\n\n' + hashtagler.join(' ') : '';
      if (metin.length + ek.length > sinir) metin = metin.slice(0, sinir - ek.length - 1).replace(/\s+\S*$/, '') + '…';
      if (!metin) throw new Error('Model boş içerik üretti.');
      const gorsel_istemi = duzelt(o.gorsel_istemi);
      const simdi = new Date().toISOString();

      const gecmis = [...(b.gecmis || []), { tur: b.tur, metin, hashtagler, tarih: simdi, karar: null, geri_bildirim: null }];
      const tg = [
        '📝 <b>Onay bekleyen paylaşım</b> (tur ' + b.tur + '/3, ' + b.platform + ')',
        '<b>Konu:</b> ' + esc(b.konu),
        '',
        esc(metin + ek).slice(0, 3500),
        '',
        '👉 Mobil uygulamada <b>İçerik Onayı</b> ekranından onayla ya da geri bildirimle reddet. Onay gelmeden hiçbir şey yayınlanmaz.',
      ].join('\n');

      return [
        {
          json: {
            kid: b.kid,
            konu: b.konu,
            platform: b.platform,
            tur: b.tur,
            metin,
            hashtagler,
            gorsel_istemi,
            paylasim_metni: metin + ek,
            gecmis,
            durum: 'onay_bekliyor',
            // Wait düğümünün sürdürme adresi; uygulamaya hiçbir zaman gönderilmez (07 projeksiyonda çıkarır)
            resume_url: $execution.resumeUrl,
            guncelleme: simdi,
            tg_metin: tg,
          },
        },
      ];
    }),
  );

  mongoUpdate(wf, 'Taslağı Onaya Sun', [1720, -100], 'icerikler', 'kid', 'metin,hashtagler,gorsel_istemi,durum,tur,gecmis,resume_url,guncelleme');
  telegram(wf, 'Onay İsteği Bildirimi', [1940, -100], "={{ $('Taslağı Hazırla').item.json.tg_metin }}");

  wf.node(
    'Onay Bekle',
    'n8n-nodes-base.wait',
    1.1,
    {
      resume: 'webhook',
      httpMethod: 'POST',
      responseMode: 'onReceived',
      limitWaitTime: true,
      limitType: 'afterTimeInterval',
      resumeAmount: '={{ Number($env.ICERIK_ONAY_SURESI_SAAT || 24) }}',
      resumeUnit: 'hours',
      // Sürdürme adresini yalnızca aynı konteynerdeki 07-Mobil-API çağırabilir
      options: { ipWhitelist: '127.0.0.1,::1,::ffff:127.0.0.1' },
    },
    [2160, -100],
  );

  codeNode(
    wf,
    'Kararı Oku',
    [2380, -100],
    code(['tr'], () => {
      const w = $input.first().json;
      let t;
      try {
        t = $('Taslağı Hazırla').itemMatching(0).json;
      } catch (e) {
        t = $('Taslağı Hazırla').last().json;
      }
      const b = w && typeof w.body === 'object' ? w.body : null;
      const yanit_geldi = !!(b && Object.prototype.hasOwnProperty.call(b, 'onay'));
      // Yalnızca boolean true onaydır; "true" metni, 1 vb. kabul edilmez
      const onay = yanit_geldi && b.onay === true;
      const geri_bildirim = yanit_geldi ? duzelt(b.geri_bildirim).slice(0, 1000) : '';
      const simdi = new Date().toISOString();

      const gecmis = (t.gecmis || []).map((g) => ({ ...g }));
      const son = gecmis[gecmis.length - 1];
      if (son) {
        son.karar = !yanit_geldi ? 'zaman_asimi' : onay ? 'onay' : 'ret';
        son.geri_bildirim = geri_bildirim || null;
        son.karar_tarihi = simdi;
      }
      const { tg_metin, ...temiz } = t;
      return [{ json: { ...temiz, yanit_geldi, onay, geri_bildirim, gorsel_iste: onay && b.gorsel_iste === true, gecmis, resume_url: null, guncelleme: simdi } }];
    }),
  );

  ifNode(wf, 'Yanıt Geldi mi?', [2600, -100], '={{ $json.yanit_geldi }}', OP.isTrue, '', true);
  // Katı tip denetimi: yalnızca gerçek boolean true yayın dalını açar
  ifNode(wf, 'Onaylandı mı?', [2820, -200], '={{ $json.onay }}', OP.isTrue, '', true);

  // ---- Onay dalı ----
  codeNode(
    wf,
    'Onay Kaydı',
    [3040, -360],
    code([], () => {
      const k = $input.first().json;
      return [{ json: { ...k, durum: 'onaylandi' } }];
    }),
  );
  mongoUpdate(wf, 'Onayı Kaydet', [3260, -360], 'icerikler', 'kid', 'durum,gecmis,resume_url,guncelleme');
  ifNode(wf, 'Görsel İstendi mi?', [3480, -360], "={{ $('Kararı Oku').item.json.gorsel_iste }}", OP.isTrue, '', true);

  // İsteğe bağlı görsel dalı: GORSEL_API_URL, istemi alıp PNG/JPEG baytları döndüren bir servis olmalı
  wf.node(
    'Görsel Üret (isteğe bağlı)',
    'n8n-nodes-base.httpRequest',
    4.2,
    {
      method: 'POST',
      url: '={{ $env.GORSEL_API_URL }}',
      sendBody: true,
      specifyBody: 'json',
      jsonBody: "={{ JSON.stringify({ prompt: $('Kararı Oku').item.json.gorsel_istemi }) }}",
      options: { timeout: 300000, response: { response: { responseFormat: 'file', outputPropertyName: 'data' } } },
    },
    [3700, -480],
  );

  const linkedin = (name, pos, kategori) =>
    wf.node(
      name,
      'n8n-nodes-base.linkedIn',
      1,
      {
        resource: 'post',
        operation: 'create',
        authentication: 'standard',
        postAs: 'person',
        person: '={{ $env.LINKEDIN_PERSON }}',
        text: "={{ $('Kararı Oku').item.json.paylasim_metni }}",
        shareMediaCategory: kategori,
        ...(kategori === 'IMAGE' ? { binaryPropertyName: 'data' } : {}),
        additionalFields: { visibility: 'PUBLIC' },
      },
      pos,
      { credentials: CRED.linkedin },
    );
  linkedin("LinkedIn'de Görselli Paylaş", [3920, -480], 'IMAGE');
  linkedin("LinkedIn'de Paylaş", [3920, -280], 'NONE');

  codeNode(
    wf,
    'Yayın Sonucu',
    [4140, -360],
    code(['html'], () => {
      const k = $('Kararı Oku').first().json;
      const simdi = new Date().toISOString();
      return [
        {
          json: {
            kid: k.kid,
            durum: 'yayinlandi',
            yayin_id: $input.first().json.urn || '',
            yayin_tarihi: simdi,
            guncelleme: simdi,
            tg_metin: '✅ <b>Paylaşım yayınlandı</b> (' + esc(k.platform) + ')\n<b>Konu:</b> ' + esc(k.konu),
          },
        },
      ];
    }),
  );
  mongoUpdate(wf, 'Yayınlandı Olarak İşaretle', [4360, -360], 'icerikler', 'kid', 'durum,yayin_id,yayin_tarihi,guncelleme', { dateFields: 'yayin_tarihi,guncelleme' });
  telegram(wf, 'Yayın Bildirimi', [4580, -360], "={{ $('Yayın Sonucu').first().json.tg_metin }}");

  // ---- Ret dalı ----
  ifNode(wf, 'Tur Hakkı Var mı?', [3040, -60], '={{ $json.tur }}', OP.numLt, 3);
  codeNode(
    wf,
    'Yeniden Yazım Bağlamı',
    [3260, 60],
    code([], () => {
      const k = $input.first().json;
      return [{ json: { kid: k.kid, konu: k.konu, platform: k.platform, tur: k.tur + 1, onceki_metin: k.metin, geri_bildirim: k.geri_bildirim, gecmis: k.gecmis } }];
    }),
  );
  codeNode(
    wf,
    'Son Ret Kaydı',
    [3260, -160],
    code(['html'], () => {
      const k = $input.first().json;
      return [
        {
          json: {
            ...k,
            durum: 'reddedildi_son',
            tg_metin: '❌ <b>Paylaşım 3 turda da reddedildi</b>\n<b>Konu:</b> ' + esc(k.konu) + '\nKonu "reddedildi_son" olarak işaretlendi; yeniden denemek için uygulamadan tekrar sıraya ekleyebilirsin.',
          },
        },
      ];
    }),
  );
  mongoUpdate(wf, 'Reddedildi Olarak İşaretle', [3480, -160], 'icerikler', 'kid', 'durum,gecmis,resume_url,guncelleme');
  telegram(wf, 'Ret Bildirimi', [3700, -160], "={{ $('Son Ret Kaydı').first().json.tg_metin }}");

  // ---- Zaman aşımı dalı ----
  codeNode(
    wf,
    'Zaman Aşımı Kaydı',
    [2820, 120],
    code(['html'], () => {
      const k = $input.first().json;
      return [
        {
          json: {
            ...k,
            durum: 'sirada',
            tg_metin: '⏰ <b>Onay süresi doldu</b>\n<b>Konu:</b> ' + esc(k.konu) + '\nTaslak yayınlanmadı; konu sıraya geri alındı, yarın yeniden denenecek.',
          },
        },
      ];
    }),
  );
  mongoUpdate(wf, 'Sıraya Geri Al', [3040, 120], 'icerikler', 'kid', 'durum,gecmis,resume_url,guncelleme');
  telegram(wf, 'Zaman Aşımı Bildirimi', [3260, 240], "={{ $('Zaman Aşımı Kaydı').first().json.tg_metin }}");

  wf.link('Her Gün 10:00', 'Sıradaki Konu')
    .link('Elle Başlat', 'Sıradaki Konu')
    .link('Sıradaki Konu', 'Konu Var mı?')
    .link('Konu Var mı?', 'İlk Tur Bağlamı', 0)
    .link('Konu Var mı?', 'Konu Kalmadı Uyarısı', 1)
    .link('İlk Tur Bağlamı', 'Taslak Bağlamı')
    .link('Taslak Bağlamı', 'İçerik Yaz')
    .link('İçerik Yaz', 'Taslağı Hazırla')
    .link('Taslağı Hazırla', 'Taslağı Onaya Sun')
    .link('Taslağı Onaya Sun', 'Onay İsteği Bildirimi')
    .link('Onay İsteği Bildirimi', 'Onay Bekle')
    .link('Onay Bekle', 'Kararı Oku')
    .link('Kararı Oku', 'Yanıt Geldi mi?')
    .link('Yanıt Geldi mi?', 'Onaylandı mı?', 0)
    .link('Yanıt Geldi mi?', 'Zaman Aşımı Kaydı', 1)
    .link('Onaylandı mı?', 'Onay Kaydı', 0)
    .link('Onaylandı mı?', 'Tur Hakkı Var mı?', 1)
    .link('Onay Kaydı', 'Onayı Kaydet')
    .link('Onayı Kaydet', 'Görsel İstendi mi?')
    .link('Görsel İstendi mi?', 'Görsel Üret (isteğe bağlı)', 0)
    .link('Görsel İstendi mi?', "LinkedIn'de Paylaş", 1)
    .link('Görsel Üret (isteğe bağlı)', "LinkedIn'de Görselli Paylaş")
    .link("LinkedIn'de Görselli Paylaş", 'Yayın Sonucu')
    .link("LinkedIn'de Paylaş", 'Yayın Sonucu')
    .link('Yayın Sonucu', 'Yayınlandı Olarak İşaretle')
    .link('Yayınlandı Olarak İşaretle', 'Yayın Bildirimi')
    .link('Tur Hakkı Var mı?', 'Yeniden Yazım Bağlamı', 0)
    .link('Tur Hakkı Var mı?', 'Son Ret Kaydı', 1)
    .link('Yeniden Yazım Bağlamı', 'Taslak Bağlamı')
    .link('Son Ret Kaydı', 'Reddedildi Olarak İşaretle')
    .link('Reddedildi Olarak İşaretle', 'Ret Bildirimi')
    .link('Zaman Aşımı Kaydı', 'Sıraya Geri Al')
    .link('Sıraya Geri Al', 'Zaman Aşımı Bildirimi');
  return wf;
}
