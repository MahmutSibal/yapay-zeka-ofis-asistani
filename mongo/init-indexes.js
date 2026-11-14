// MongoDB Atlas — koleksiyonlar ve indeksler (idempotent; tekrar çalıştırmak güvenli)
// Çalıştırma (Docker ile, mongosh kurmadan):
//   docker run --rm -v "%cd%\mongo:/s" mongo:7 mongosh "<MONGODB_URI>" /s/init-indexes.js
// Not: Bağlantı dizesinde veritabanı adı yoksa aşağıdaki DB adı kullanılır.

const DB_ADI = 'ofis_asistani';
const d = db.getSiblingDB(DB_ADI);

function koleksiyon(ad) {
  if (!d.getCollectionNames().includes(ad)) d.createCollection(ad);
  return d.getCollection(ad);
}

// Her belgede uygulama tarafından üretilen benzersiz "kid" (UUID string) alanı vardır.
// ObjectId yerine bunu kullanmamızın nedeni: n8n MongoDB düğümünde güncelleme anahtarı olarak
// string alan kullanmak, ObjectId dönüşümüyle uğraşmaktan çok daha güvenilir.
const tumu = ['epostalar', 'yorumlar', 'bultenler', 'gorevler', 'icerikler', 'loglar'];
for (const ad of tumu) koleksiyon(ad).createIndex({ kid: 1 }, { unique: true, name: 'kid_benzersiz' });

koleksiyon('epostalar').createIndex({ gmail_id: 1 }, { unique: true, name: 'gmail_id_benzersiz' });
koleksiyon('epostalar').createIndex({ acil: 1, alinma: -1 });
koleksiyon('epostalar').createIndex({ kategori: 1, alinma: -1 });

koleksiyon('yorumlar').createIndex({ analiz_durumu: 1, olusturma: 1 });
koleksiyon('yorumlar').createIndex({ duygu: 1, olusturma: -1 });

koleksiyon('bultenler').createIndex({ hafta: 1 }, { unique: true, name: 'hafta_benzersiz' });

koleksiyon('gorevler').createIndex({ toplanti_id: 1 });
koleksiyon('gorevler').createIndex({ durum: 1, tarih: 1 });

koleksiyon('icerikler').createIndex({ durum: 1, sira: 1 });

koleksiyon('loglar').createIndex({ tarih: -1 });
koleksiyon('loglar').createIndex({ tarih: 1 }, { expireAfterSeconds: 60 * 60 * 24 * 90, name: 'ttl_90_gun' });

// RAG ve sohbet belleği koleksiyonları (n8n düğümleri yazar)
koleksiyon('dokuman_parcalari');
koleksiyon('sohbet_gecmisi');

// Atlas Vector Search indeksi (M0 ücretsiz kümede de çalışır).
// mongosh sürümün createSearchIndex desteklemiyorsa mongo/vector-index.json içeriğini
// Atlas arayüzünden (Atlas Search > Create Index > JSON Editor) elle ekle.
try {
  const mevcut = d.dokuman_parcalari.getSearchIndexes().map((i) => i.name);
  if (!mevcut.includes('vektor_indeksi')) {
    d.dokuman_parcalari.createSearchIndex({
      name: 'vektor_indeksi',
      type: 'vectorSearch',
      definition: {
        fields: [
          { type: 'vector', path: 'embedding', numDimensions: 1024, similarity: 'cosine' },
          { type: 'filter', path: 'metadata.namespace' },
        ],
      },
    });
    print('vektor_indeksi oluşturuldu (hazır olması 1-2 dk sürebilir).');
  }
} catch (e) {
  print('UYARI: vektör indeksi oluşturulamadı, Atlas arayüzünden ekle: ' + e.message);
}

print('Tamam: ' + DB_ADI + ' koleksiyonları ve indeksleri hazır.');
