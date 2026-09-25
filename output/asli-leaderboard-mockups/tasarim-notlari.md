# Aslı App — sıralama tasarımı

Dört yüksek detaylı PNG mockup. Bunlar görsel tasarım teslimidir; Flutter uygulaması veya çalışan API değildir. Veriler temsilidir. Örneklerde Yusuf ile Sen satırını ayırt etmek için oturum kullanıcısı Deniz seçildi.

## Akış

- Ana ekran: Tümünü Gör → Sıralama / Bu Hafta / Genel.
- Derse Göre: ders seçiciye dokununca aranabilir modal bottom sheet; ders seçimi ortak tarih filtresini korur.
- Ders detayı: Sıralamayı Gör → aynı ders seçili Sıralama / Bu Hafta / Derse Göre.
- Quiz sonuçları genel ve ders sıralamasını besler; ayrı quiz sıralama rotası yoktur.
- İlk üçteki kullanıcıya ayrıca Sen satırı gösterilmez. Tam listede kullanıcının satırı görünmüyorsa SafeArea içinde sabit kişisel özet gösterilir; satır görünür olunca gizlenir.

## Flutter uygulama ölçüleri

- Zemin #14282C; kart #21383F; kenar #324B52; ana vurgu #B9C2FF; metin #F3F5F2; ikincil metin #ACBBC0.
- Altın #CBB68B, gümüş #B8C6D3, bronz #BA9682 yalnızca ilk üç sıra vurgularında.
- 20 dp dış boşluk, 8/12/16/24 dp aralıklar, 20 dp kart yarıçapı, en az 48 dp etkileşim hedefleri.
- Başlık 24–28 sp, bölüm başlığı 20 sp, gövde 14–16 sp, ikincil metin en az 12 sp. Sistem yazı ölçeği desteklenir.
- SafeArea ve kaydırılabilir içerik kullanılır. Küçük ekranlarda bütün içerik tek viewport'a sıkıştırılmaz. Büyük yazıda ilk üç kartı dikey listeye dönüşebilir.
- Material SegmentedButton, modal bottom sheet, ListView/SliverList ve ortak sıralama satırı bileşeni yeterlidir. Görseldeki illüstrasyonlar ayrıca bağımsız varlık olarak hazırlanmalıdır.

## Yükleniyor, boş ve hata durumları

- Yükleniyor: filtreler yerinde kalır. Üç adet 40 dp daire ve altında iki kısa çizgiden oluşan soluk kart iskeleti; altında üç adet satır iskeleti. Renk #21383F / #324B52. Sıra veya sıfır puan gösterilmez. Ekran okuyucu: Sıralama yükleniyor.
- Boş: aynı kart alanında küçük lavanta kupa çizgi ikonu, Sıralama henüz oluşmadı. Alt metin: Quizlerini tamamlayarak sıralamada yerini al. Buton: Quizlere Git. Seçili ders varsa o dersin quizlerine yönlenir.
- Kullanıcı katılmamış: sıra yerine —, açıklama Bu dönem henüz quiz tamamlamadın. Kullanıcıya sahte sonuncu sıra atanmaz.
- Hata: Sıralama yüklenemedi. Tekrar dene bağlantısı. Mevcut veri varsa korunur ve güncellenemedi bilgisi gösterilir.
- Bir veya iki katılımcı varsa yalnızca gerçek katılımcılar gösterilir; yapay üçüncü kullanıcı oluşturulmaz.

## Veri anlamı

Genel görünüm seçili dönemde tüm derslerden gelen doğru cevap toplamını, tamamlanan quiz sayısını ve başarı oranını gösterir. Ders görünümünde payda dersin toplam soru sayısıdır; örnekte 54. Haftalık sonuç dönem kapsamında kalırken payda ders kapsamını anlatır. Başarı yüzdesinin hangi payda üzerinden hesaplandığı API sözleşmesinde açık olmalıdır.

Tekrar çözümlerinin nasıl sayılacağı ve eşitlik kuralı kullanıcı isteğinde belirlenmedi. Uygulamadan önce ürün kararı gerekir; aynı quizin tekrarları 54 soruluk paydanın üzerinde puan oluşturmamalıdır. Mockup verileri hesaplama kuralı olarak kullanılmamalıdır.

## Doğrulama

Görseller metin, sıralama hiyerarşisi ve yerleşim açısından görsel olarak incelendi. Genel ekrandaki fazladan alt gezinme ve tekrarlanan metrikler, ders ekranındaki bozuk arka plan düzeltildi. Ürün kodu değişmedi; ürün testi çalıştırılmadı. Üretim yöntemi: built-in image_gen. Tam istem seti prompts.md içindedir.
