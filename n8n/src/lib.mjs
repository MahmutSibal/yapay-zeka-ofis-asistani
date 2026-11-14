// n8n workflow JSON üretici yardımcıları.
// Akış tanımları src/0X-*.mjs dosyalarında; `node n8n/src/build.mjs` ile n8n/workflows/*.json üretilir.
import { createHash } from 'node:crypto';

// ---------------------------------------------------------------------------
// Sabit kimlikler (CLI ile içe aktarımda korunur → hata akışı bağlantısı ve
// kimlik bilgisi eşleşmesi kendiliğinden kurulur)
// ---------------------------------------------------------------------------
export const WF_ID = {
  hata: 'OfisAsistan00Hat',
  eposta: 'OfisAsistan01Epo',
  sohbet: 'OfisAsistan02Dok',
  indeks: 'OfisAsistan02Ind',
  yorum: 'OfisAsistan03Yor',
  bulten: 'OfisAsistan04Bul',
  gorev: 'OfisAsistan05Gor',
  sosyal: 'OfisAsistan06Sos',
  api: 'OfisAsistan07Api',
};

export const CRED = {
  mongo: { mongoDb: { id: 'ofisMongoAtlas01', name: 'MongoDB Atlas' } },
  ollama: { ollamaApi: { id: 'ofisOllama000001', name: 'Ollama (yerel)' } },
  telegram: { telegramApi: { id: 'ofisTelegram0001', name: 'Telegram Bot' } },
  gmail: { gmailOAuth2: { id: 'ofisGmail0000001', name: 'Gmail' } },
  drive: { googleDriveOAuth2Api: { id: 'ofisGDrive000001', name: 'Google Drive' } },
  trello: { trelloApi: { id: 'ofisTrello000001', name: 'Trello' } },
  linkedin: { linkedInOAuth2Api: { id: 'ofisLinkedIn0001', name: 'LinkedIn' } },
};

/** Aynı girdiden hep aynı UUID'yi üretir → yeniden derlemede düğüm kimlikleri değişmez. */
export function stableUuid(seed) {
  const h = createHash('sha1').update(seed).digest('hex');
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-4${h.slice(13, 16)}-a${h.slice(17, 20)}-${h.slice(20, 32)}`;
}

// ---------------------------------------------------------------------------
// Code düğümü gövdeleri gerçek JS fonksiyonları olarak yazılır (sözdizimi derlemede
// denetlenir); burada gövde metnine çevrilir.
// ---------------------------------------------------------------------------
function fnBody(fn) {
  const s = fn.toString();
  const body = s.slice(s.indexOf('{') + 1, s.lastIndexOf('}'));
  const lines = body.replace(/^\n+|\s+$/g, '').split('\n');
  const indent = Math.min(...lines.filter((l) => l.trim()).map((l) => l.match(/^ */)[0].length));
  return lines.map((l) => l.slice(indent)).join('\n');
}

// Code düğümlerinde ortak yardımcılar (her düğüme gerektiği kadar eklenir)
export const H = {
  uuid: fnBody(() => {
    /** Code düğümünde require gerektirmeyen UUID v4 */
    const uuid = () =>
      'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        const r = (Math.random() * 16) | 0;
        return (c === 'x' ? r : (r & 0x3) | 0x8).toString(16);
      });
  }),
  tr: fnBody(() => {
    // Qwen modelleri bazen Türkçe harfleri GBK "mojibake" karakterleriyle yazar (ı -> 谋, ş -> 艧 ...).
    const MOJIBAKE = { '莽': 'ç', '脟': 'Ç', '臒': 'ğ', '臑': 'Ğ', '谋': 'ı', '陌': 'İ', '枚': 'ö', '脰': 'Ö', '艧': 'ş', '艦': 'Ş', '眉': 'ü', '脺': 'Ü', '芒': 'â', '卯': 'î', '没': 'û' };
    const MOJIBAKE_RE = new RegExp('[' + Object.keys(MOJIBAKE).join('') + ']', 'g');
    /** Model metnini temizler: mojibake düzeltme, ** kaldırma, boşluk sadeleştirme */
    const duzelt = (s) =>
      String(s ?? '')
        .replace(MOJIBAKE_RE, (c) => MOJIBAKE[c])
        .replace(/\*\*/g, '')
        .replace(/[ \t]+/g, ' ')
        .trim();
  }),
  html: fnBody(() => {
    /** Telegram HTML ve e-posta gövdesi için kaçış */
    const esc = (s) => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
  }),
  yanit: fnBody(() => {
    /** Respond to Webhook düğümünün beklediği biçim */
    const yanit = (status, body) => [{ json: { status, body } }];
  }),
};

/** helpers: H anahtarları, fn: gövde fonksiyonu */
export function code(helpers, fn) {
  return [...helpers.map((k) => H[k]), fnBody(fn)].join('\n\n');
}

// ---------------------------------------------------------------------------
// Workflow kurucu
// ---------------------------------------------------------------------------
export class Workflow {
  constructor(name, id, description) {
    this.name = name;
    this.id = id;
    this.description = description;
    this.nodes = [];
    this.connections = {};
  }

  node(name, type, typeVersion, parameters, position, extra = {}) {
    if (this.nodes.some((n) => n.name === name)) throw new Error(`${this.name}: yinelenen düğüm adı "${name}"`);
    const n = { parameters, id: stableUuid(`${this.id}:${name}`), name, type, typeVersion, position };
    Object.assign(n, extra);
    if (type === 'n8n-nodes-base.webhook' || type === 'n8n-nodes-base.wait') n.webhookId = stableUuid(`${this.id}:${name}:webhook`);
    this.nodes.push(n);
    return name;
  }

  /** Ana akış bağlantısı */
  link(from, to, out = 0, inp = 0) {
    return this._connect(from, to, 'main', out, inp);
  }

  /** AI alt düğüm bağlantısı (model, bellek, araç, ayrıştırıcı...) */
  sub(from, to, type) {
    return this._connect(from, to, type, 0, 0);
  }

  _connect(from, to, type, out, inp) {
    for (const n of [from, to]) if (!this.nodes.some((x) => x.name === n)) throw new Error(`${this.name}: bilinmeyen düğüm "${n}"`);
    const c = (this.connections[from] ??= {});
    const arr = (c[type] ??= []);
    while (arr.length <= out) arr.push([]);
    arr[out].push({ node: to, type, index: inp });
    return this;
  }

  toJSON() {
    const settings = { executionOrder: 'v1', timezone: 'Europe/Istanbul', saveManualExecutions: true, callerPolicy: 'workflowsFromSameOwner' };
    if (this.id !== WF_ID.hata) settings.errorWorkflow = WF_ID.hata;
    return {
      id: this.id,
      name: this.name,
      description: this.description,
      active: false,
      nodes: this.nodes,
      connections: this.connections,
      settings,
      pinData: {},
      tags: [],
      meta: { templateCredsSetupCompleted: false },
    };
  }
}

// ---------------------------------------------------------------------------
// Sık kullanılan düğüm fabrikaları
// ---------------------------------------------------------------------------
export const T = {
  webhook: 'n8n-nodes-base.webhook',
  respond: 'n8n-nodes-base.respondToWebhook',
  code: 'n8n-nodes-base.code',
  if: 'n8n-nodes-base.if',
  mongo: 'n8n-nodes-base.mongoDb',
  telegram: 'n8n-nodes-base.telegram',
  gmail: 'n8n-nodes-base.gmail',
  agent: '@n8n/n8n-nodes-langchain.agent',
  chain: '@n8n/n8n-nodes-langchain.chainLlm',
  ollama: '@n8n/n8n-nodes-langchain.lmChatOllama',
  parser: '@n8n/n8n-nodes-langchain.outputParserStructured',
  schedule: 'n8n-nodes-base.scheduleTrigger',
};

export function codeNode(wf, name, pos, jsCode, extra = {}) {
  return wf.node(name, T.code, 2, { jsCode }, pos, extra);
}

/**
 * Kimlik doğrulamasız webhook (uygulama otomatik bağlanır).
 * UYARI: n8n'e (5678) erişebilen herkes bu uç noktaları çağırabilir → n8n'i yalnızca yerel ağda tut.
 */
export function webhook(wf, name, pos, path, httpMethod = 'POST', responseMode = 'responseNode') {
  const p = { httpMethod, path, responseMode, options: {} };
  if (responseMode === 'onReceived') p.options = { responseData: '{"durum":"baslatildi"}' };
  return wf.node(name, T.webhook, 2, p, pos);
}

/** {status, body} biçimindeki öğeyi JSON olarak döndürür */
export function respond(wf, name, pos, bodyExpr = '={{ JSON.stringify($json.body) }}', statusExpr = '={{ $json.status || 200 }}') {
  return wf.node(name, T.respond, 1.1, { respondWith: 'json', responseBody: bodyExpr, options: { responseCode: statusExpr } }, pos);
}

/** Basit If: tek koşul. op: {type, operation, singleValue?} */
export function ifNode(wf, name, pos, leftValue, operator, rightValue = '', strict = false) {
  return wf.node(
    name,
    T.if,
    2.2,
    {
      conditions: {
        options: { caseSensitive: true, leftValue: '', typeValidation: strict ? 'strict' : 'loose', version: 2 },
        conditions: [{ id: stableUuid(`${wf.id}:${name}:cond`), leftValue, rightValue, operator }],
        combinator: 'and',
      },
      looseTypeValidation: !strict,
      options: {},
    },
    pos,
  );
}
export const OP = {
  isTrue: { type: 'boolean', operation: 'true', singleValue: true },
  notEmpty: { type: 'string', operation: 'notEmpty', singleValue: true },
  numGt: { type: 'number', operation: 'gt' },
  numLt: { type: 'number', operation: 'lt' },
  strEq: { type: 'string', operation: 'equals' },
};

export function ollamaModel(wf, name, pos, temperature = 0.2) {
  return wf.node(
    name,
    T.ollama,
    1,
    {
      model: "={{ $env.OLLAMA_MODEL || 'qwen2.5:7b' }}",
      options: { temperature, numCtx: 8192, keepAlive: '30m' },
    },
    pos,
    { credentials: CRED.ollama },
  );
}

/** JSON şemalı Structured Output Parser (bozuk çıktıyı otomatik düzeltme açık → modele bağlanır) */
export function parser(wf, name, pos, schema, model) {
  const n = wf.node(name, T.parser, 1.3, { schemaType: 'manual', inputSchema: JSON.stringify(schema, null, 2), autoFix: true }, pos);
  wf.sub(model, n, 'ai_languageModel');
  return n;
}

/** Yapılandırılmış çıktılı AI Agent; model + parser bağlantılarını kurar */
export function agent(wf, name, pos, { text, systemMessage, schema, temperature = 0.2, maxIterations = 4 }) {
  const a = wf.node(
    name,
    T.agent,
    3.1,
    { promptType: 'define', text, hasOutputParser: true, options: { systemMessage, maxIterations, enableStreaming: false } },
    pos,
  );
  const m = ollamaModel(wf, `Ollama: ${name}`, [pos[0] - 80, pos[1] + 220], temperature);
  wf.sub(m, a, 'ai_languageModel');
  const p = parser(wf, `JSON Şeması: ${name}`, [pos[0] + 180, pos[1] + 220], schema, m);
  wf.sub(p, a, 'ai_outputParser');
  return { agent: a, model: m, parser: p };
}

export function mongoInsert(wf, name, pos, collection, fields, dateFields = 'olusturma,guncelleme', extra = {}) {
  return wf.node(
    name,
    T.mongo,
    1.5,
    { resource: 'document', operation: 'insert', collection, fields, options: { dateFields } },
    pos,
    { credentials: CRED.mongo, ...extra },
  );
}

export function mongoUpdate(wf, name, pos, collection, updateKey, fields, { dateFields = 'guncelleme', upsert = false } = {}, extra = {}) {
  return wf.node(
    name,
    T.mongo,
    1.5,
    { resource: 'document', operation: 'update', collection, updateKey, fields, upsert, options: { dateFields } },
    pos,
    { credentials: CRED.mongo, ...extra },
  );
}

export function mongoAggregate(wf, name, pos, collection, query, extra = {}) {
  return wf.node(name, T.mongo, 1.5, { resource: 'document', operation: 'aggregate', collection, query }, pos, {
    credentials: CRED.mongo,
    ...extra,
  });
}

export function telegram(wf, name, pos, text) {
  return wf.node(
    name,
    T.telegram,
    1.2,
    {
      resource: 'message',
      operation: 'sendMessage',
      chatId: '={{ $env.TELEGRAM_CHAT_ID }}',
      text,
      additionalFields: { parse_mode: 'HTML', appendAttribution: false, disable_web_page_preview: true },
    },
    pos,
    { credentials: CRED.telegram },
  );
}

export function gmailSend(wf, name, pos, sendTo, subject, message, emailType = 'html') {
  return wf.node(
    name,
    T.gmail,
    2.2,
    { resource: 'message', operation: 'send', sendTo, subject, emailType, message, options: { appendAttribution: false, senderName: 'Ofis Asistanı' } },
    pos,
    { credentials: CRED.gmail },
  );
}

export function schedule(wf, name, pos, cron) {
  return wf.node(name, T.schedule, 1.2, { rule: { interval: [{ field: 'cronExpression', expression: cron }] } }, pos);
}
