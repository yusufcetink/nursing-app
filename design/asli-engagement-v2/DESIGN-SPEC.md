# Aslı App — Tasarım ve motion specification

Bu paket yüksek görsel kalitede raster tasarım konseptleri içerir. Flutter uygulamasına entegrasyon yapılmadı; ekranlardaki kullanıcı, ders adları ve sayılar örnek veridir. Mevcut uygulama kaynakları değiştirilmedi.

## Görsel yön

Sıcak kâğıt, koyu mürekkep ve güçlü kobalt; mercan ve mint ile desteklenen, yetişkin öğrencilere yönelik editorial/soft 3D dil. Somut klinik nesneler modülü tanıtır; başarı görselleri aynı malzeme ailesini sürdürür. Ana görsel üzerinde uzun metin yoktur. Başlık, açıklama, durum ve CTA gerçek UI metinleri olarak ayrı yüzeyde bulunur.

Mevcut referanslar: ../asli-premium-mockups/02-home.png, 03-module.png ve 06-quiz-result.png. Kullanıcı mesajında ayrıca erişilebilir görsel eki yoktu. Yerel repository remote'u verilen GitHub adresiyle eşleşiyor.

## Ekran kararları

| Alan | Tasarım davranışı |
| --- | --- |
| Home | Kompakt karşılama, büyük modül kapağıyla devam alanı, 3/6 parçalı yay, güçlü devam CTA'sı, ince günlük aktivite şeridi, yatay modül seçkisi. Eşit ağırlıktaki panel tekrarını hiyerarşiyle kırar. |
| Günlük aktivite | Gerçek tamamlanan ders sayısı + güneş motifi. Kota, yapay seri, puan veya kaybetme baskısı eklemez. Sıfır aktivite: “Bir ders, yeni bir bakış.” |
| Modül kartı | Kapak, başlık, kısa açıklama, X/Y + durum, parçalı ilerleme, duruma göre Başla / Devam et / Yeniden incele. |
| Modül detayı | Tek devamlı rota; tamamlanan adımlar kompakt, güncel adım geniş ve eyleme hazır. Sıradaki adımlar metin ve ikonla ayırt edilir. Görsel önem mevcut derse verilir. |
| Quiz sonucu | 10 soruluk örnekte 8 dolu, 2 boş bölüm; %80, 8 doğru / 2 yanlış / 10 soru birlikte. Sonraki ders CTA'sı ekranın alt bölümünde. |
| Ders tamamlandı | Dersin üzerinde completion sheet; küçük sayfa/check illüstrasyonu, yalnız yeni segmentin dolması. |
| Modül tamamlandı | Daha büyük, modüle özgü başarı kartı; 6/6 check ve kapaktaki kalkanın reward yorumu. Ayrı rozet koleksiyonu veya sertifika özelliği değildir. |

Öğrenci bottom navigation'ı mevcut Eğitim / Profil hedeflerini korur. Yetkili kullanıcıdaki İçerik hedefi mevcut rol koşuluyla korunmalıdır. Home mockup'ındaki “Tümünü gör” aynı sayfadaki tam modül listesine açılma/odaklanma olarak ele alınır; yeni ekran gerektirmez. Günlük aktivite şeridi salt bilgi sunar; görseldeki chevron yeni bir hedef anlamına gelmez ve uygulamada kaldırılmalıdır.

## Modül kapak ailesi

| Modül | Nesne / metafor | Renk ve siluet |
| --- | --- | --- |
| Vital Bulgular | Stilize kalp, stetoskop, soyut dalga | Kobalt + mercan; dairesel odak |
| Ağrı Yönetimi | Merkezini saran yumuşak kabuklar | Mürdüm + şeftali; iç içe yaylar |
| Hasta Güvenliği | Korunan kalkan, check, kimlik bilekliği | Petrol + mint; dikey kalkan |
| Enfeksiyon Kontrolü | Hijyen pompası, damla, koruyucu halka | Kayısı + buz mavisi; uzun pompa |
| İlaç Uygulamaları | Stilize ampul ve kapsül | Lila + kobalt; dikey/yatay denge |
| Yara Bakımı | Gazlı bez rulosu ve pansuman | Orman yeşili + krem; diyagonal katman |

Bunlar konu tanıtım illüstrasyonlarıdır; prosedür veya anatomik referans çizimleri değildir.

### Admin tarafından değiştirilebilir kapak

Master dosyalar 1536×1024, 3:2 PNG. Üretim önerisi: 1200×800 WebP/JPEG, gerçek görsel içeriğine göre yaklaşık 150–300 KB hedefi; bu paketteki PNG'ler optimize edilmemiş master'lardır.

Her modül için görsel ayrı içerik varlığıdır. Önerilen minimum sözleşme: coverImageUrl ve gerekirse normalize focalPointX / focalPointY. Bunlar mevcut API'de var kabul edilmemelidir. Mobil EducationModule ve yönetim ContentModule modellerinde kapak alanı bulunmuyor; admin yükleme/API entegrasyonu ileride ayrıca uygulanmalıdır.

- Varsayılan oran 3:2. Kısa hero alanında kontrollü kırpma; önemli nesneler merkezde korunur.
- Merkez güvenli bölge ve en az %10 kenar toleransı. Dar thumbnail'da nesne okunmuyorsa 3:2 oran korunur; otomatik sert kırpma yapılmaz.
- Görsele başlık, ilerleme veya CTA gömülmez. Admin kapak değişikliği metin kontrastını etkilemez.
- Light/dark aynı master görseli kullanabilir; çevre yüzeyi ve ince border değişir. Otomatik karartma filtresi uygulanmaz.
- Yükleme sürerken alanın boyutu sabittir. Hata/kapak yok: yerel konu ikonu + düz tematik yüzey; başlık, progress ve CTA çalışır.
- Admin önizlemesi hero, standart kart ve küçük kart kırpmasını iki temada gösterir. Bu bir içerik yönetimi gereksinimidir; mockup'ta yeni öğrenci özelliği yoktur.

## Tasarım tokenları

| Rol | Light | Dark |
| --- | --- | --- |
| Sayfa | #F8F5EF | #14262C |
| Yüzey | #FFFFFF | #20363D |
| Ana metin | #192B32 | #F8F5EF |
| İkincil metin | #52636B | #BDCDD2 |
| Ana CTA | #294AC5 | #B8C6FF |
| CTA metni | #FFFFFF | #14262C |
| Başarı metni | #17765A | #9FE6C9 |
| Dekoratif mercan | #DF7355 | #F19A7E |

Hesaplanan düz renk kontrastları: ana light metin 13,47:1; ikincil light metin 5,75:1; beyaz/kobalt CTA 7,29:1; dark CTA 9,35:1; dark yüzey ana metni 11,65:1; light başarı metni 5,11:1; dark ikincil metin 7,74:1. Bunlar belirtilen token çiftleri içindir; AI raster mockup piksellerinin veya çalışan uygulamanın erişilebilirlik testi değildir. Uygulamada mockup'taki açık yeşil küçük metin yerine tanımlı koyu başarı metni kullanılmalıdır.

Tipografi: mevcut font ailesi korunabilir; yeni bağımlılık şart değil. Başlık 28–32 sp / 1,15–1,25 satır yüksekliği; modül başlığı 22–24 sp; body 16 sp / 1,45; yardımcı metin en az 14 sp. Kart içi 16–20 dp, ekran yatay 20 dp, ana CTA 52–56 dp; bütün dokunma hedefleri en az 48×48 dp. Kart köşesi 20–24 dp; sheet 28 dp.

390 dp tasarım başlangıcı; 320–430 dp genişliklerde yeniden akış gerekir. Yazı %200 olduğunda sabit kart yüksekliği kaldırılır, küçük kartlar tek sütuna geçer, hero metni ile progress alt alta dizilir. İçerik scroll olur, sabit CTA son içeriği örtmez. Raster çiftler ölçü cetveli değil görsel yön referansıdır.

## Kısa motion specification

| An | Süre / eğri | Görsel davranış | Dokunsal |
| --- | --- | --- | --- |
| Seçenek basımı | 80 ms giriş + 120 ms çıkış; easeOut | 1 → 0,985 → 1 scale. Seçim durumu görünür; doğruluk henüz ima edilmez. | İsteğe bağlı seçim hissi |
| Doğru yanıt | Toplam 320 ms; easeOutCubic, tek küçük overshoot | İlk 120 ms mint yüzey/border; 80–240 ms check çizimi; check 0,88 → 1,04 → 1. Tek düşük opaklıklı halo sönümü. Tüm ekran zıplamaz. | Onayda tek hafif darbe |
| Yanlış yanıt | 180 ms; easeOut | Seçili satır sıcak şeftali yüzeye crossfade. Bilgi ikonu ve “Birlikte bakalım”. Doğru seçenek check + etiketle ayrıca işaretlenir; açıklama doğal yüksekliğiyle açılır. Shake veya kırmızı ekran yok. | Yok |
| Ders tamamlandı | Sheet 280 ms; progress 480 ms; toplam yaklaşık 700 ms | Sheet 20 dp aşağıdan fade/slide. Yalnız yeni ders segmenti dolar. Küçük check 0,94 → 1; tek 220 ms halo. | Kayıt onayında tek hafif darbe |
| Modül tamamlandı | 850 ms; easeOutCubic | Son segment dolar; başarı kartı 12 dp yukarı gelerek belirir; rozet 0,94 → 1,02 → 1. En fazla iki kısa dekoratif ışık çizgisi 250 ms görünür ve söner. | Bir orta şiddette onay |
| Quiz sonucu | 700 ms; easeOutCubic | Halka doğru oranına kadar çizilir; sayı aynı zaman çizelgesinde artar, ikisi birlikte kesin sonuçta durur. Son 150 ms check belirir. CTA başlangıçtan itibaren görünür ve kullanılabilir. | Tek hafif darbe, isteğe bağlı |

Zamanlar öneridir. Hiçbir animasyon CTA'yı kilitlemez, otomatik ders geçişi yapmaz veya açıklamayı okumadan kapatmaz. Geri bildirim kullanıcı ilerleyene kadar kalır; animasyon bir kez oynar. Ses zorunlu değildir.

### Durum ve veri koşulları

1. Doğru/yanlış feedback yalnızca yetkili değerlendirme sonucu gelince tetiklenir. Mevcut QuizController cevapları topluyor, sunucu sonucunu son gönderimde alıyor. Dolayısıyla anlık doğruluk feedback'i mevcut akışta otomatik uygulanamaz; değerlendirme verisi geldiğinde gösterilir. Soru başına doğrulama gerekiyorsa ayrıca API/ürün kararı gerekir. Tahmine dayalı doğru rengi gösterilmez.
2. Ders reward'u completeLesson başarılı döndüğünde, modül reward'u bilinen ilerleme ilk kez toplam ders sayısına ulaştığında gösterilir. Ağ hatası başarı animasyonu değildir. Yeniden açılan sayfa ve provider rebuild aynı ödülü tekrar oynatmaz.
3. Ders sonunda quiz varsa mevcut ders/quiz sırası izlenir. “Sıradaki derse geç” yerine gerektiğinde “Quiz'e geç” kullanılır; mevcut değerlendirme atlanmaz. Aynı bitiş olayında quiz sonucu + lesson sheet + module sheet peş peşe yığılmaz; son modül tamamlanması daha güçlü state'e yükseltilir.
4. İstenen locked-next görseli modül mockup'ında örneklenmiştir. Mevcut uygulama derslere erişimi kilitlemiyor. Entegrasyonda mevcut erişim korunur: backend bir kilit durumu sağlamıyorsa kilit yerine numaralı açık node ve “Sırada” kullanılır. Tasarım kendi başına yeni kilitleme kuralı getirmez.
5. Quiz başarı mesajı mevcut >=80 görsel ton ayrımını koruyabilir. Düşük sonuçta “Her deneme bir adım.” ve gerçek oran gösterilir; uydurma geçme/kalma eşiği eklenmez. Sıfır doğru veya soru sayısı sıfırsa başarı rozeti gösterimi ve bölme işlemi ayrı ele alınır; sonuç yoksa %0 olarak sunulmaz.
6. Örnekte her quiz halkası bölümü bir sorudur. Değişken soru sayısında çok sık segmentler yerine okunabilir sürekli yay + doğru/toplam metni kullanılabilir. Modülde yüksek ders sayısında 6 sahte adım çizilmez; gerçek oranlı yay ve X/Y metni tercih edilir.
7. Yanıt inceleme CTA'sı ancak mevcut sonuç verisi ve ekran akışı desteklediğinde bağlanır. Eksik veriyle sahte inceleme sayfası oluşturulmaz.

### Hareket azaltma ve erişilebilirlik

MediaQuery.disableAnimationsOf(context) açıkken scale, glow, sayaç ve slide kaldırılır; son durum doğrudan gösterilir. Zorunlu olmayan titreşim kapatılır. Durum değişiminde Semantics liveRegion yalnızca tek nihai açıklama okur; sayaçtaki her sayı anons edilmez.

“3 / 6 ders tamamlandı”, “Şimdiki ders”, “Tamamlandı” ve gerekiyorsa kilit gerekçesi metin olarak bulunur. Durumlar renk + ikon + metinle aktarılır. Dekoratif illüstrasyonlar başlığı tekrar okutmaz. Sheet açıldığında odak başlığa taşınır; kapatılınca tetikleyiciye geri döner.

## Teslim ve doğrulama

12 PNG: beş light/dark ekran çifti (10 ekran durumu), bir component/feedback panosu, altı bağımsız kapak. Üretim promptları PROMPTS.md içinde. Galeri index.html ile yerel açılır.

Bütün görseller görsel olarak incelendi; quiz hero'sundaki gereksiz kitap/bitki/sloganlar ikinci geçişte kaldırıldı. Ana metin ve CTA hiyerarşisi, tema eşleşmesi ve örnek sonuç oranı kontrol edildi. Model çıktılarındaki dekoratif sloganlar ve arka plan detayları zorunlu UI içeriği değildir; uygulamada native metin ve bu sözleşme esas alınır.

Bu çalışma design/ altında kaldığından Flutter/.NET kaynakları değiştirilmedi; build, analyze ve uygulama testleri çalıştırılmadı. Gerçek uygulama entegrasyonunda repository'nin mobile/AGENTS.md format/analyze/test kontrolleri ile 320 dp, %200 metin, ekran okuyucu ve reduced-motion kontrolleri gerekir.

