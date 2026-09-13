# Aslı App — Görsel tasarım V2

[Galeriyi aç](index.html) · [Tasarım ve motion specification](DESIGN-SPEC.md) · [Üretim promptları](PROMPTS.md)

Beş light/dark ekran çifti, bir component/feedback panosu ve altı bağımsız nursing cover illustration. Flutter entegrasyonu bu tasarım tesliminin kapsamında yapılmadı.

- [Home](05-home-light-dark.png)
- [Modül kartları ve cevap feedback’i](10-components-feedback.png)
- [Öğrenme yolculuğu](06-module-light-dark.png)
- [Quiz sonucu](07-quiz-result-light-dark.png)
- [Ders tamamlandı](08-lesson-completed-light-dark.png)
- [Modül tamamlandı](09-module-completed-light-dark.png)

## Modül kapakları

- [Vital Bulgular](01-vital-cover.png)
- [Ağrı Yönetimi](02-pain-cover.png)
- [Hasta Güvenliği](03-safety-cover.png)
- [Enfeksiyon Kontrolü](04-infection-cover.png)
- [İlaç Uygulamaları](11-medication-cover.png)
- [Yara Bakımı](12-wound-cover.png)

## Motion özeti

- Doğru cevap: 320 ms check çizimi + tek hafif bounce.
- Yanlış cevap: 180 ms sıcak yüzey geçişi + açıklama; shake yok.
- Ders tamamlandı: yaklaşık 700 ms sheet ve yeni segment dolumu.
- Modül tamamlandı: 850 ms başarı kartı ve ölçülü rozet hareketi.
- Quiz sonucu: 700 ms skor ile eşzamanlı halka dolumu.
- Hareket azaltma açıkken son durum doğrudan gösterilir.

Kilitli ders ve soru başına doğruluk feedback'i mevcut veri/erişim koşullarıyla uyarlanmalıdır; detaylar specification içinde.

