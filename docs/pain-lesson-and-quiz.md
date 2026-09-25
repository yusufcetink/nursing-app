# Aslı App — Ağrı dersi ve tek attempt quiz

## Eklenen içerik

Development başlangıcında mevcut `DevelopmentEducationSeeder`, `PainLessonSeed` üzerinden
**Ağrı ve Konfor** modülünü ve **Ağrı Türleri, Ağrının Değerlendirilmesi ve Hemşirelik Yaklaşımı**
dersini ekler. Önceden var olan hasta kimliği dersi korunur.

22 dakikalık ders; giriş, tanım, türler, OPQRST, ölçek seçimi, hemşirelik yaklaşımı,
üç kısa vaka, kayıt örneği, özet ve mini tekrar bölümlerinden oluşur. Mevcut blok
sistemine yalnızca `Callout`, `Comparison`, `Case`, `Summary`, `Recall` eklenmiştir.
İçerik yönetimi ekranı da bu blokları okuyabilir, oluşturabilir ve düzenleyebilir.

Kaynak veri: `backend/src/AsliApp.Api/Education/SeedAssets/Pain/lesson.json`.
Bu dosyada 18 soru, dört seçenek, doğru seçenek indeksi, soru kategorisi ve öğretici
gerekçe bulunur. Dağılım: 5 temel bilgi, 7 ayırt etme, 6 klinik vaka.
Bu dosya yalnızca backend seed girdisidir; öğrenciye veya statik dosya endpoint'ine sunulmaz.

Sekiz PNG, mevcut `LessonMedia` + `Image` blokları ve yetkili media endpoint'i ile sunulur:

| Anahtar | Görsel | Bölüm |
| --- | --- | --- |
| hero | Ağrı: bir sayıdan fazlası | Giriş |
| duration | Akut ve kronik ağrı | Ağrı türleri |
| mechanisms | Mekanizmayı ayırt et | Ağrı türleri |
| pqrst | OPQRST ile sor | Değerlendirme |
| scales | NRS ve VAS | Ölçekler |
| faces | Yüz ölçeğinde seçimi hasta yapar | Ölçekler |
| care | Bakım döngüsünü tamamla | Hemşirelik yaklaşımı |
| recap | Ağrı bakımında altı anahtar | Özet |

Her görselin `title`, `section`, `caption`, ayrıntılı `prompt` alanları JSON içindeki
`visuals` listesinde bulunur. Yerel görseller, metin ve karşılaştırma kartlarından oluşan
eğitim infografikleridir; daha ayrıntılı illüstrasyonlar için prompt'lar hazırdır.
PNG'lerin üretim kaynağı `backend/tools/GeneratePainLessonMedia.ps1` dosyasıdır.
FACES görseli özgün klinik ölçeğin kopyası veya yerine kullanılacak bir ölçek değildir.

Klinik içerik kaynakları:
[IASP terminoloji](https://www.iasp-pain.org/resources/terminology/),
[Open RN Nursing Fundamentals — Comfort](https://www.ncbi.nlm.nih.gov/books/NBK591809/),
[Wong-Baker kullanım yönergesi](https://wongbakerfaces.org/instructions-use/),
[Royal Children's Hospital ağrı değerlendirmesi](https://www.rch.org.au/rchcpg/hospital_clinical_guideline_index/Pain_Assessment_and_Measurement/).

## Veritabanı ve migration

`20260921201350_QuizAttemptResume` mevcut `QuizAttempts` tablosuna başlangıç zamanı,
sunucuya özel JSON snapshot, concurrency sürümü ve eski sonuçları işaretleyen
`IsArchived` alanını ekler. `CompletedAtUtc` artık nullable'dır.

`UserId + QuizId` için `IsArchived = 0` filtreli unique index ikinci öğrenci attempt'ını
engeller. Eski sürümde aynı kullanıcı/quiz için birden çok sonuç varsa migration en yeni
sonucu mevcut attempt olarak tutar, daha eski sonuçları arşivler; sonuçlar ve cevaplar
silinmez, profil geçmişinde görünmeye devam eder. Yeni öğrenci akışı arşivlenmiş attempt
oluşturamaz. Eski tamamlanmış attempt'lar snapshot olmadan da sonuç olarak okunur.

Migration yalnızca seçtiğiniz yerel geliştirme veritabanına uygulanmalıdır. API
migration'ları başlangıçta otomatik uygulamaz. Mevcut backend README'deki auth, JWT,
SQL Server ve harici dosya depolama ayarlarını kullanın. Backend ve mobil sürümünü birlikte
güncelleyin; eski `/check` ve toplu `/submit` endpoint'leri kaldırılmıştır.

```powershell
Set-Location C:\Projects\backend
dotnet tool restore
# ConnectionStrings__DefaultConnection seçtiğiniz yerel DB'yi göstermeli.
dotnet ef database update --project src/AsliApp.Infrastructure --startup-project src/AsliApp.Api --configuration Release
dotnet run --project src/AsliApp.Api --configuration Release
```

Development ortamında seed etkinleşir. Sabit kimlikler ve atomik DB kaydı sayesinde
yeniden çalıştırma modül, ders, quiz veya soruları çoğaltmaz. Var olan içerik editörünün
değişikliklerini veya öğrenci sonuçlarını üzerine yazmaz. Görseller mevcut `IFileStorage`
aracılığıyla yapılandırılmış harici depoya kopyalanır.

## API akışı

Tüm öğrenci çağrıları mevcut JWT ile yapılır; kullanıcı kimliği token'dan alınır.

1. `GET /api/education/lessons/{lessonId}/quiz/attempt`: yalnızca durum okur. Henüz
   başlanmadıysa `NotStarted`, `attemptId: null`; kayıt oluşturmaz.
2. `POST /api/education/lessons/{lessonId}/quiz/start`: ilk çağrıda attempt oluşturur;
   sonraki çağrılarda aynı attempt'i döndürür. Tamamlanmışsa sonuç döner, yeni attempt açılmaz.
3. `POST /api/education/quiz-attempts/{attemptId}/answers`:

   ```json
   { "questionId": "...", "selectedOptionId": "..." }
   ```

   Sıradaki soru doğrulanır. Başarılı kayıt tamamlanmadan Flutter sonraki soruya geçmez.
   Aynı soru/aynı seçenek tekrarı 200 ile mevcut durumu döndürür; farklı seçenek 409,
   sıra dışı soru veya yanlış seçenek ilişkisi 400, başka kullanıcının attempt'ı 404 döner.
   Son cevap attempt'i tamamlar ve backend skoru hesaplar. Kaydı yapılmış son cevabın
   yanıtı ağda kaybolsa da aynı isteği tekrar göndermek güvenlidir.

Yanıtlar `quiz`, `answers`, `answeredCount`, `status` ve yalnızca completion sonrası
`result` taşır. Öğrenci DTO'larında doğru seçenek veya `IsCorrect` yoktur. Snapshot hem
soruları/seçenekleri hem sunucu cevap anahtarını sabitler; doğru anahtar öğrenci DTO'suna
aktarılmaz. Sıra karıştırılmaz; başlangıçtaki sıralama snapshot içinde sabittir.

Flutter ders kartı: **Quiz’e Başla**, **Quiz’e Devam Et + n / 18**, veya
**Quiz Tamamlandı + doğru/yanlış/skor** gösterir. Tamamlanmış durumda tekrar çözme butonu yoktur.
Quiz ekranından çıkıp geri girildiğinde backend attempt'i yeniden yüklenir. InProgress
attempt'lar tamamlanmış quiz geçmişine ve sonuç istatistiklerine dahil edilmez.
Ders okuma progress'i mevcut ayrı tamamlama akışını korur.

## Admin reset

Sadece `Admin` rolüyle:

```http
DELETE /api/education/admin/users/{userId}/quizzes/{quizId}/attempt
Authorization: Bearer <admin-token>
```

204 döner. İlgili kullanıcının bu quiz'e ait güncel/arşivli attempt'larını, cevaplarını,
sonuçlarını ve ilgili dersin progress kaydını tek DB işlemiyle temizler. Student ve
ContentEditor 403 alır. Quiz/ders içeriği ve diğer kullanıcıların kayıtları korunur.
Reset sonrasında ders ekranını yeniden açın; **Quiz’e Başla** görünür.

## Elle kontrol

1. Migration sonrası API'yi Development ortamında başlatın; Ağrı ve Konfor modülünü açın.
2. Sekiz görseli, kartları ve vaka örneklerini light/dark modda okuyun.
3. Quiz’e Başla: Soru 1 / 18 görünmeli. Seçip onaylayın.
4. Yedi cevap sonrası uygulamayı kapatıp açın: kart 7 / 18, quiz Soru 8 / 18 göstermeli.
5. Cevabı onaylamadan bağlantıyı kesin: sonraki soruya geçmemeli. Bağlantı dönünce aynı
   cevabı tekrar gönderin; DB'de çoğalmamalı.
6. Tamamlayın: doğru/yanlış/skor ve tamamlandı durumu görünmeli. Yeniden açmak ikinci
   attempt oluşturmamalı. Postman ile farklı cevap gönderme 409 dönmeli.
7. Admin reset uygulayın; sonra yeniden başlayın. Başka kullanıcı ve ContentEditor ile
   reset denemelerinin reddedildiğini kontrol edin.

## Otomatik doğrulama

```powershell
dotnet build backend/AsliApp.sln -c Release -m:1
dotnet test backend/AsliApp.sln -c Release -m:1
# Gerçek SQL Server yarış/constraint testi; bu adla ayrılmış test DB'si kullanılır:
$env:ASLI_TEST_SQLSERVER = 'Server=(localdb)\AsliAppLocal;Database=AsliAppResumeValidation;Trusted_Connection=True;TrustServerCertificate=True'
dotnet test backend/AsliApp.sln -c Release --no-build
Set-Location mobile
flutter analyze
flutter test
flutter build apk --debug
```

SQL testi, ortam değişkeni yoksa açıkça skipped görünür. Varsa migration'ları yalnızca
`AsliAppResumeValidation` öneki taşıyan test DB'sine uygular; altı eşzamanlı start ve
altı aynı cevap isteğini ayrı DbContext'lerle çalıştırır. Normal API testleri mevcut
test application factory'sini kullanır. Gerçek API'ye bağlı analytics testi mevcut
opt-in çalışma biçimini korur.

## Değişen ana dosyalar

21 Eylül 2026 doğrulaması: Release backend build başarılı; gerçek SQL Server testi dahil
65 backend testi geçti. Flutter analyze temiz; 162 Flutter testi geçti, mevcut opt-in
gerçek API analytics testi atlandı. Android debug APK başarıyla üretildi. Android build
mevcut Firebase eklentilerinin gelecekteki Kotlin Gradle uyumluluğuna ilişkin uyarı verdi;
build başarısını etkilemedi. Mevcut çalışan geliştirme API'si veya onun DB'si yeniden
başlatılmadı/değiştirilmedi; migration ve seed ayrı `AsliAppResumeValidation` DB'sinde doğrulandı.

- API: `EducationService.Attempts.cs`, `QuizAttemptsController.cs`, `EducationService.cs`,
  `EducationController.cs`, `EducationContracts.cs`.
- Domain/persistence: `QuizAttempt.cs`, `LessonContentBlock.cs`, `AppDbContext.cs`, yeni
  migration ve EF tarafından üretilen designer/snapshot.
- Seed: `PainLessonSeed.cs`, `DevelopmentEducationSeeder.cs`, `SeedAssets/Pain/*`, API csproj,
  görsel üretim script'i.
- Flutter: quiz model/repository/controller/page, `LessonQuizCard`, lesson model/parser/page,
  `LessonContentCard`, mevcut content management model/parser/form.
- Testler: backend attempt/seed/SQL testleri; Flutter repository/controller/durum kartı,
  quiz/sonuç/navigasyon testlerinin yeni akışa uyarlanması.
