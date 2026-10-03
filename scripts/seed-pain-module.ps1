#requires -Version 5.1
<#
Aslı App ağrı eğitimi. Yalnızca mevcut admin API'lerini kullanır.
Bu dosya hazırlık aşamasındadır; onay verilmeden production'a karşı çalıştırmayın.
Kaynaklar: https://www.iasp-pain.org/resources/terminology/
https://www.iasp-pain.org/education/curricula/iasp-interprofessional-pain-curriculum-outline/
https://www.iasp-pain.org/education/curricula/iasp-curriculum-outline-on-pain-for-nursing/
#>
param(
    [string]$ApiBaseUrl = 'https://api.nursing-app.com',
    [switch]$RepairMojibake
)

$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Console]::InputEncoding = $utf8
[Console]::OutputEncoding = $utf8
$OutputEncoding = $utf8
$base = $ApiBaseUrl.TrimEnd('/')
if ($base -notmatch '^https://') { throw 'API base URL HTTPS olmalıdır.' }

function Invoke-Api {
    param([string]$Method, [string]$Path, $Body = $null, [string]$Token = '')
    $headers = @{ Accept = 'application/json' }
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $params = @{ Method = $Method; Uri = "$base$Path"; Headers = $headers; ErrorAction = 'Stop' }
    if ($null -ne $Body) {
        $params.ContentType = 'application/json; charset=utf-8'
        $json = ConvertTo-Json -InputObject $Body -Depth 20 -Compress
        $params.Body = [System.Text.Encoding]::UTF8.GetBytes($json)
    }
    try { return Invoke-RestMethod @params }
    catch {
        $status = 'bilinmiyor'
        $responseBody = $_.ErrorDetails.Message
        if ($_.Exception.Response) {
            try { $status = [int]$_.Exception.Response.StatusCode } catch {}
            if (-not $responseBody) {
                try {
                    $stream = $_.Exception.Response.GetResponseStream()
                    if ($stream) {
                        $reader = New-Object System.IO.StreamReader($stream)
                        try { $responseBody = $reader.ReadToEnd() } finally { $reader.Dispose() }
                    }
                } catch {}
            }
        }
        Write-Error "API başarısız: $Method $Path | HTTP $status | Yanıt: $responseBody" -ErrorAction Continue
        throw 'Seed durduruldu.'
    }
}

function Assert-UniqueTitle($Items, [string]$Title, [string]$Kind, [string]$Property = 'title') {
    $matches = @($Items | Where-Object { $_.$Property -eq $Title })
    if ($matches.Count -gt 1) { throw "$Kind başlığı birden fazla kez mevcut: $Title" }
    if ($matches.Count -eq 1) { return $matches[0] }
    return $null
}

function Assert-CreatedId($Response, [string]$Kind) {
    $id = [guid]::Empty
    if (-not [guid]::TryParse([string]$Response.id, [ref]$id) -or $id -eq [guid]::Empty) {
        throw "$Kind oluşturma yanıtında geçerli Id yok."
    }
    return $id.ToString()
}

function Get-SingleId($Value, [string]$Kind) {
    if ($null -eq $Value -or $Value -is [array] -or $Value.id -is [array]) {
        throw "$Kind tek kayıt değil; birden fazla ID ile API çağrısı yapılmadı."
    }
    $id = [guid]::Empty
    if (-not [guid]::TryParse([string]$Value.id, [ref]$id) -or $id -eq [guid]::Empty) {
        throw "$Kind geçerli bir tekil ID içermiyor."
    }
    return $id.ToString()
}

function Get-ContentModules([string]$Token) {
    # Invoke-RestMethod, JSON dizisini PowerShell 5.1'de tek bir iç dizi olarak döndürebilir.
    $response = Invoke-Api GET '/api/education/content/modules' -Token $Token
    if ($null -eq $response) { return }
    return @($response | ForEach-Object { $_ })
}

function New-Question($Prompt, $Options, $Correct) {
    return @{ prompt = $Prompt; options = $Options; correct = $Correct }
}

function ConvertTo-LegacyMojibake([string]$Text) {
    # Windows PowerShell 5.1'in BOM'suz UTF-8 kaynak dosyasını Windows-1252 gibi okuması.
    $windows1252 = [System.Text.Encoding]::GetEncoding(1252)
    return $windows1252.GetString([System.Text.Encoding]::UTF8.GetBytes($Text))
}

function Convert-Expected([string]$Text, [int]$Level) {
    for ($i = 0; $i -lt $Level; $i++) { $Text = ConvertTo-LegacyMojibake $Text }
    return $Text
}

function Assert-NoMojibake($Value, [string]$Where) {
    $serialized = ConvertTo-Json -InputObject $Value -Depth 30 -Compress
    if ($serialized -match '[ÃÄÅ]') { throw "Mojibake saptandı: $Where" }
}

# Content block metni Flutter'da ilk satırı kart başlığı olarak gösterilir.
# API enum değeri Case'dir; istemcide CaseStudy olarak görünür.
$lessons = @(
    @{
        title = 'Ağrıya Giriş ve Temel Kavramlar'; description = 'Ağrının anlamı, öznel deneyim ve bakımda hastanın bildirimi.'; minutes = 9
        quiz = 'Ağrıya Giriş — Bilgi Kontrolü'
        blocks = @(
            ,@('Heading', 'Ağrıyı anlamak')
            ,@('Text', 'Ağrı, gerçek veya olası doku hasarıyla ilişkili ya da buna benzeyen hoş olmayan duyusal ve duygusal bir deneyimdir. Ağrı yalnızca bir doku sinyali değildir.')
            ,@('Callout', "Hastanın deneyimi esastır`nAğrı kişiye özgüdür. Kendini ifade edebilen hastanın bildirdiği ağrı ciddiye alınır; görünür hasar olmaması deneyimi geçersiz kılmaz.")
            ,@('Text', 'Biyolojik süreçler, duygu durumu, önceki deneyimler, uyku, kültür ve sosyal çevre ağrı yaşantısını etkileyebilir. Hemşire bu etkenleri yargılamadan sorar.')
            ,@('Comparison', "Ağrı ve nosisepsiyon`nNosisepsiyon: Zararlı veya zarar verme potansiyeli taşıyan uyaranın sinir sistemi tarafından işlenmesidir.`nAğrı: Kişinin yaşadığı duyusal ve duygusal deneyimdir. İkisi aynı şey değildir; ağrı, nosiseptör etkinliği olmadan da yaşanabilir.")
            ,@('Heading', 'Süre ve etki')
            ,@('Comparison', "Akut ve kronik`nAkut: Yeni başlayan, bir yaralanma veya hastalıkla ilişkili olabilen ağrıdır.`nKronik: Genellikle üç aydan uzun süren veya tekrarlayan ağrıdır. Süre, şiddeti tek başına göstermez.")
            ,@('Case', "İki hasta, iki deneyim`nAynı ameliyatı geçiren iki kişi farklı ağrı puanları bildirebilir. Her hastaya ağrının yeri, işlev üzerindeki etkisi ve bakım hedefi ayrı sorulur.")
            ,@('Text', 'Ağrı uyku, hareket, solunum, katılım ve yaşam kalitesini etkileyebilir. Değerlendirme yalnızca şiddeti değil, kişinin neleri yapabildiğini de kapsar.')
            ,@('Recall', "Sen olsaydın ne sorardın?`nHasta ‘Çok ağrım var’ dediğinde önce hangi açık uçlu soruyla deneyimini anlamaya başlarsın?")
            ,@('Summary', "Akılda kalsın`nAğrı öznel bir deneyimdir. Hastayı dinle, işlevi sorgula ve bulguları bağlam içinde değerlendir.")
        )
        questions = @(
            (New-Question 'Ağrının güncel tanımında hangi iki yön birlikte yer alır?' @('Duyusal ve duygusal deneyim','Yalnızca doku hasarı','Sadece refleks yanıtı','Tek başına kas gerginliği') 0)
            (New-Question 'Nosisepsiyon ile ağrı arasındaki ilişkiyi en doğru hangi ifade açıklar?' @('Her zaman aynı olgudur','Nosisepsiyon sinirsel işlemleme, ağrı deneyimdir','Ağrı yalnızca nosisepsiyondan önce olur','Nosisepsiyon yalnızca kronik ağrıda olur') 1)
            (New-Question 'Kendini ifade edebilen hastanın ağrısı için temel başlangıç bilgisi nedir?' @('Yüz ifadesi','Laboratuvar sonucu','Hastanın özbildirimi','Odadaki kişinin yorumu') 2)
            (New-Question 'Aynı girişimden sonra hastaların farklı ağrı bildirmesi en çok neyi gösterir?' @('Birinin yanıldığını','Ölçeğin gereksizliğini','Ağrının ölçülemediğini','Deneyimin kişiye özgü olduğunu') 3)
            (New-Question 'Ağrı deneyimini hangi etkenler birlikte etkileyebilir?' @('Biyolojik, psikolojik ve sosyal etkenler','Yalnızca doku boyutu','Yalnızca yaş ve boy','Sadece görüntüleme bulgusu') 0)
            (New-Question 'Kronik ağrı için yaygın kullanılan süre eşiği hangisidir?' @('Bir haftadan uzun','Üç aydan uzun','Yalnızca bir yıldan uzun','Ameliyat bitene kadar') 1)
            (New-Question 'Akut ve kronik ağrı hakkında hangi ifade doğrudur?' @('Kronik ağrı hafiftir','Akut ağrı daima kısa sürer','Süre ile şiddet farklı boyutlardır','İkisi aynı anda bulunamaz') 2)
            (New-Question 'Görünür doku hasarı bulunmayan bir hastanın ağrı bildirimi karşısında ilk yaklaşım nedir?' @('Bildirimi reddetmek','Yalnızca yakınını dinlemek','Ölçümü ertelemek','Deneyimini dinleyip değerlendirmek') 3)
            (New-Question 'Ağrının işlevsel etkisine hangi örnek girer?' @('Uyku ve hareketin zorlaşması','Ağrının yalnızca yerinin belirtilmesi','Puanın tek başına kaydedilmesi','Önceki tanının tekrarlanması') 0)
            (New-Question 'Ağrı değerlendirmesinde hangisi yargılayıcı olmayan sorudur?' @('Gerçekten mi ağrıyor?','Ağrı günlük işlerini nasıl etkiliyor?','Buna dayanamaz mısın?','Neden abartıyorsun?') 1)
            (New-Question 'Ağrı bildirmeyen ama konuşamayan hasta için hangi sonuç uygundur?' @('Kesin ağrısı yoktur','Ağrı puanı sıfırdır','Davranış ve bağlam da değerlendirilir','Değerlendirme yapılmaz') 2)
            (New-Question 'Hemşirelik eğitiminde ağrı bakımının temel hedefi hangisidir?' @('Herkese aynı planı uygulamak','Yalnızca sayıyı azaltmak','Bildirimi kontrol etmek','Deneyim ve işlevi birlikte izlemek') 3)
        )
    }
    @{
        title = 'Ağrı Türleri ve Mekanizmaları'; description = 'Nosiseptif, nöropatik ve nosiplastik mekanizmaları klinik ipuçlarıyla ayırt etme.'; minutes = 11
        quiz = 'Ağrı Türleri — Bilgi Kontrolü'
        blocks = @(
            ,@('Heading', 'Mekanizma için ipuçları')
            ,@('Text', 'Ağrı türleri klinik değerlendirmeye yol gösterir. Tek bir sıfat ya da belirti kesin mekanizma tanısı koydurmaz; öykü, muayene ve ekip değerlendirmesi birlikte gerekir.')
            ,@('Comparison', "Nosiseptif: somatik ve visseral`nSomatik ağrı deri, kas, kemik veya eklem kaynaklı olabilir; çoğu kez daha iyi lokalize edilir.`nVisseral ağrı iç organlarla ilişkili olabilir; derin, yaygın veya yansıyan biçimde hissedilebilir.")
            ,@('Case', "Burkulan ayak bileği`nHasta ağrıyı bileğinde belirgin bir noktada gösterir. Bu tablo somatik nosiseptif mekanizmayı düşündürür; şişlik ve işlev kaybı da değerlendirilir.")
            ,@('Comparison', "Nöropatik ve nosiplastik`nNöropatik ağrı somatosensoriyel sinir sisteminin lezyonu veya hastalığıyla ilişkilidir.`nNosiplastik ağrı, belirgin doku hasarı ya da somatosensoriyel lezyon kanıtı olmadan değişmiş nosisepsiyonla ilişkili olabilir. Her ikisi klinik değerlendirme gerektirir.")
            ,@('Callout', "Kesin genellemeden kaçın`nYanma nöropatik ağrıda görülebilir, ancak her yanıcı ağrı nöropatik değildir. Belirtiyi hastanın öyküsü ve diğer bulgularla birlikte yorumla.")
            ,@('Comparison', "Allodini ve hiperaljezi`nAllodini: Normalde ağrılı olmayan bir uyaranın ağrıya yol açmasıdır; örneğin hafif dokunuşun ağrılı algılanması.`nHiperaljezi: Normalde ağrılı bir uyarana verilen ağrı yanıtının artmasıdır. Bu bulgular tek başına mekanizmayı kanıtlamaz.")
            ,@('Case', "Diyabetli hastada ayak ağrısı`nAyaklarda yanma ve uyuşma, diyabetik nöropati olasılığını düşündürür. Duyusal değişiklik, dağılım, cilt bütünlüğü ve güvenlik gereksinimi değerlendirilir.")
            ,@('Case', "Uzun süren yaygın ağrı`nAylarca yaygın ağrı yaşayan kişide tek bir mekanizma varsayma. Uyku, işlev, duyarlılık ve önceki değerlendirmeler birlikte ele alınır.")
            ,@('Text', 'Karma ağrıda birden çok mekanizma katkıda bulunabilir. Örneğin bir hastada doku kaynaklı ağrı ile sinir sistemi kaynaklı ağrı aynı dönemde görülebilir.')
            ,@('Recall', "Mekanizmayı nasıl sorgularsın?`nAğrının yerini, yayılımını, duyusal değişiklikleri ve doku/sinir sistemi öyküsünü hangi sırayla sorarsın?")
            ,@('Summary', "Akılda kalsın`nSomatik, visseral, nöropatik ve nosiplastik ipuçlarını ayır; tek bulgudan kesin tanı koyma. Karma mekanizma olasılığını açık tut.")
        )
        questions = @(
            (New-Question 'Nosiseptif ağrı hangi süreçle ilişkilidir?' @('Somatosensoriyel sinir lezyonu','Sinir dışı dokuda nosiseptör etkinleşmesi','Yalnızca duygu durumu değişimi','Belirgin doku hasarı olmadan değişmiş nosisepsiyon') 1)
            (New-Question 'Burkulan ayak bileğinde iyi lokalize ağrı en çok hangi türü düşündürür?' @('Visseral ağrı','Nosiplastik ağrı','Somatik nosiseptif ağrı','Santral nöropatik ağrı') 2)
            (New-Question 'Karında derin ve yerini göstermesi güç ağrı için hangi açıklama daha olasıdır?' @('Yalnızca allodini','Yalnızca somatik ağrı','Kesin nöropati','Visseral ağrı olasılığı') 3)
            (New-Question 'Nöropatik ağrının tanımında hangi yapı önemlidir?' @('Somatosensoriyel sinir sistemi','Yalnızca kas dokusu','Yalnızca iç organ duvarı','Sadece psikolojik süreçler') 0)
            (New-Question 'Diyabetli hastada ayaklarda yanma ve uyuşma olduğunda en uygun yorum nedir?' @('Nöropati kesin dışlanır','Nöropatik mekanizma düşünülebilir','Her yanma tanıyı doğrular','Yalnızca visseral ağrıdır') 1)
            (New-Question 'Hafif dokunuşun ağrılı algılanması hangi terimdir?' @('Hiperaljezi','Yansıyan ağrı','Allodini','Karma ağrı') 2)
            (New-Question 'Normalde ağrılı bir uyaranın beklenenden daha ağrılı algılanması nedir?' @('Allodini','Nosisepsiyon','Visseral ağrı','Hiperaljezi') 3)
            (New-Question 'Nosiplastik ağrı hakkında hangisi uygundur?' @('Değişmiş nosisepsiyonla ilişkili olabilir','Daima görünür doku hasarı vardır','Tek başına yanma ile doğrulanır','Sinir lezyonu zorunludur') 0)
            (New-Question '“Her yanıcı ağrı nöropatiktir” ifadesine yaklaşım nasıl olmalı?' @('Kesin tanı olarak alınmalı','Diğer bulgularla birlikte değerlendirilmeli','Yalnızca şiddete göre onaylanmalı','Hasta söylemi göz ardı edilmeli') 1)
            (New-Question 'Doku yaralanması ve eşlik eden sinir hasarı bulunan hastada ne düşünülebilir?' @('Sadece akut ağrı','Sadece visseral ağrı','Karma mekanizma','Ağrı yokluğu') 2)
            (New-Question 'Yaygın ve uzun süreli ağrıda hemşirenin ilk yaklaşımı hangisidir?' @('Tek mekanizmayı kesinleştirmek','Yalnızca görüntüleme istemek','Bildirimi reddetmek','İşlev, uyku ve duyarlılığı da sorgulamak') 3)
            (New-Question 'Allodini ve hiperaljezi için hangi ifade doğrudur?' @('Klinik bulgudur; mekanizmayı tek başına kanıtlamaz','Yalnızca visseral ağrıda görülür','Birbirinin eş anlamlısıdır','Her zaman aynı uyarana yanıt verir') 0)
        )
    }
    @{
        title = 'Ağrının Değerlendirilmesi'; description = 'Özbildirim, uygun ölçek, sistematik sorgulama, kayıt ve yeniden değerlendirme.'; minutes = 12
        quiz = 'Ağrı Değerlendirmesi — Bilgi Kontrolü'
        blocks = @(
            ,@('Heading', 'Önce hastayı dinle')
            ,@('Text', 'Kendini ifade edebilen hastada ağrının özbildirimi temel kaynaktır. Hastanın seçtiği sözcükleri kaydet; puanı tek başına yorumlama.')
            ,@('Comparison', "Ölçekler`nNRS: Hasta ağrısını 0 (ağrı yok) ile 10 (en şiddetli ağrı) arasında puanlar.`nVAS: Hasta ağrısını bir çizgi üzerinde işaretler; uygulama ve yorumlama becerisine uygunluk değerlendirilir.`nYüz ifadeli ölçek: Yaşına ve bilişsel/iletişim durumuna uygun hastalarda kullanılabilir.")
            ,@('Callout', "Ölçeği uygun seç`nAynı hastada izlem boyunca mümkün olduğunca aynı uygun ölçeği kullan. Sayısal puan verememek ağrının olmadığı anlamına gelmez.")
            ,@('Heading', 'Sistematik sorgulama')
            ,@('Text', 'Başlangıç ve süreyi; yer, yayılım ve karakteri; artıran/azaltan etkenleri; eşlik eden belirtileri sor. Şiddetin yanında uyku, hareket ve bakım etkinliklerine etkisini değerlendir.')
            ,@('Comparison', "OPQRST hatırlatıcısı`nO: Başlangıç. P: Artıran/azaltan etken. Q: Karakter. R: Yer ve yayılım.`nS: Şiddet ve işlev etkisi. T: Zaman örüntüsü. Bu yapı görüşmenin yerini almaz; soruları düzenler.")
            ,@('Case', "Puan aynı, durum farklı`nİki hasta ağrısını 6/10 bildirir. Biri rahat nefes alırken diğeri öksüremiyor. Kayıtta puanla birlikte işlevsel etki de yer almalıdır.")
            ,@('Text', 'İletişimi kısıtlı hastada yüz ifadesi, hareket, seslenme, bakım sırasında tepki ve klinik bağlam birlikte gözlenir. Uygun gözlemsel araç ve yakınlarından alınan bilgi yardımcı olabilir; kişinin özbildirimi mümkünse yine istenir.')
            ,@('Case', "Sözlü yanıt sınırlı`nYaşlı hasta sayısal puan veremiyor ve pozisyon değişiminde yüzünü buruşturuyor. Ağrı olasılığını değerlendir, uygun araç kullan ve ekiple paylaş.")
            ,@('Callout', "Kayıt ve yeniden değerlendirme`nYer, şiddet, karakter, zaman, işlev etkisi, uygulanan girişim ve yanıtı kaydet. Müdahaleden sonra kurum uygulaması ve girişimin beklenen etkisine uygun zamanda yeniden değerlendir.")
            ,@('Recall', "Sen olsaydın ne yapardın?`nAğrısı 7/10 olan hastaya bir girişim uyguladın. Yeniden değerlendirmede hangi bilgileri karşılaştırırsın?")
            ,@('Summary', "Akılda kalsın`nÖzbildirimi merkeze al; uygun ölçek seç; çok boyutlu sorgula; kaydet ve müdahale sonrası yeniden değerlendir.")
        )
        questions = @(
            (New-Question 'Kendini ifade edebilen hastada ağrı için birincil kaynak hangisidir?' @('Yalnızca nabız','Hastanın özbildirimi','Yalnızca yakın görüşü','Önceki tetkik') 1)
            (New-Question 'NRS 0–10 ölçeğinde 0 neyi belirtir?' @('Düşük düzeyde ağrı','Orta düzeyde ağrı','Ağrı olmaması','Şu an ölçülemeyen ağrı') 2)
            (New-Question 'VAS için hangi açıklama doğrudur?' @('Yalnızca sözel sayı seçimi içerir','Her hastaya aynı biçimde uygulanır','Yüz ifadelerinden biri seçilir','Hasta çizgi üzerinde işaretleme yapar') 3)
            (New-Question 'Hasta 6/10 ağrı söylüyor ve öksürmekten kaçınıyor. Kayıtta ne bulunmalı?' @('Puan ve öksürmeye etkisi','Sadece puan','Yalnızca tanı adı','Sadece oda numarası') 0)
            (New-Question 'Ağrının başlangıcını sorgulayan soru hangisidir?' @('Ağrı nereye yayılıyor?','Ne zaman ve nasıl başladı?','Şiddeti kaç puan?','Hangi girişim yapıldı?') 1)
            (New-Question 'OPQRST içindeki R hangi bilgiyi düzenler?' @('Uyku kalitesini','İlaç geçmişini','Yer ve yayılımı','Tedavi yanıtını') 2)
            (New-Question 'Hasta karın ağrısına bulantı eşlik ettiğini söylüyor. Hemşire ne yapmalı?' @('Bulantıyı dışlamalı','Yalnızca puan istemeli','Ölçeği bırakmalı','Eşlik eden belirtiyi kaydetmeli') 3)
            (New-Question 'Sayısal ölçek kullanamayan hasta için en uygun yaklaşım hangisidir?' @('Uygun alternatif veya gözlemsel araç değerlendirmek','Ağrıyı sıfır kaydetmek','Değerlendirmeyi sonlandırmak','Yalnızca nabzı temel almak') 0)
            (New-Question 'Pozisyon değişiminde yüzünü buruşturan iletişimi kısıtlı hastada ne yapılmalı?' @('Ağrı yok sayılmalı','Davranış ve klinik bağlam birlikte değerlendirilmeli','Sadece aileye puan verdirilmeli','Kayıt için konuşması beklenmeli') 1)
            (New-Question 'Müdahale sonrasında yeniden değerlendirmede hangi bilgi karşılaştırılır?' @('Yalnızca oda sıcaklığı','Yalnızca bakım saati','Ağrı, işlev ve girişime yanıt','Yalnızca taburculuk tarihi') 2)
            (New-Question 'Ağrı değerlendirmesinde artıran ve azaltan etkenleri sormak ne sağlar?' @('Tanıyı tek başına doğrular','Ölçeği gereksiz kılar','Ağrıyı daima bitirir','Örüntüyü ve bakım gereksinimini anlamayı') 3)
            (New-Question 'Çocuk sayısal puan vermekte zorlanıyor. Yüz ifadeli ölçek nasıl kullanılmalı?' @('Yaş ve iletişim durumuna uygunluğu değerlendirilerek','Her yetişkine de otomatik uygulanarak','Özbildirimi tümüyle kaldırarak','Tüm yüzler aynı puan sayılarak') 0)
        )
    }
    @{
        title = 'Hemşirelikte Ağrı Yönetimi'; description = 'Bireyselleştirilmiş, güvenli ve yeniden değerlendirilen hemşirelik bakımı.'; minutes = 12
        quiz = 'Hemşirelikte Ağrı Yönetimi — Bilgi Kontrolü'
        blocks = @(
            ,@('Heading', 'Kişiye uygun plan')
            ,@('Text', 'Ağrı yönetimi hastanın hedefleri, işlevi, klinik durumu ve bakım planına göre bireyselleştirilir. Hastayla birlikte ulaşılabilir bir rahatlık ve işlev hedefi belirlenir.')
            ,@('Comparison', "Birlikte düşünülen yaklaşımlar`nFarmakolojik: Hekim istemi ve kurum uygulamalarına uygun tedavinin güvenli uygulanması ve etkisinin izlenmesi.`nNonfarmakolojik: Uygun pozisyon, gevşeme, dikkat dağıtma, çevresel düzenleme ve eğitim. Bunlar gerektiğinde planlanan tedaviyle birlikte ele alınır.")
            ,@('Text', 'Hastanın tercihine ve durumuna uygun pozisyon verme, gevşeme ve dikkat dağıtma rahatlığı destekleyebilir. Girişimin etkisi hastanın özbildirimi ve işleviyle değerlendirilir.')
            ,@('Callout', "Sıcak/soğuk güvenliği`nUygulamadan önce cilt durumu, duyu kaybı, dolaşım, hasta tercihi ve kurum protokolünü değerlendir. Uygun olmayan uygulamayı sürdürme; cildi ve yanıtı izle.")
            ,@('Case', "Gece artan ağrı`nHasta gürültü nedeniyle uyuyamadığını ve ağrısının arttığını bildiriyor. Ortamı düzenle, uygun rahatlatıcı yaklaşımı seç, planlanan tedaviyi gözden geçir ve yeniden değerlendir.")
            ,@('Text', 'Hasta eğitiminde ağrıyı erken bildirme, kullanılan ölçeği anlama, güvenli rahatlatıcı yöntemler ve yeni ya da kötüleşen belirtileri ekibe iletme üzerinde durulur.')
            ,@('Heading', 'İzle ve paylaş')
            ,@('Text', 'Uygulama sonrası ağrı şiddeti, işlev ve yan etkileri izlenir. Beklenen etki görülmezse, ağrı belirgin kötüleşirse veya güvenlik sorunu gelişirse sağlık ekibine zamanında bildirilir.')
            ,@('Callout', "Bakım sürekliliği`nGirişimin ne zaman, hangi amaçla yapıldığını; öncesi ve sonrası değerlendirmeyi; hastanın yanıtını ve ekip iletişimini kaydet. Sonraki bakım verenin planı anlayabilmesini sağla.")
            ,@('Recall', "Sen olsaydın ne yapardın?`nRahatlatıcı girişim sonrası ağrı ve hareket kısıtlılığı sürüyor. Hangi bilgiyi yeniden değerlendirip ekibe aktarırsın?")
            ,@('Summary', "Akılda kalsın`nPlanı kişiselleştir, yöntemleri güvenli kullan, etki ve yan etkiyi izle, etkisiz kontrolde ekiple iletişim kur.")
        )
        questions = @(
            (New-Question 'Bireyselleştirilmiş ağrı bakımında ilk temel adım hangisidir?' @('Herkese aynı yöntemi vermek','Yalnızca tanıya bakmak','Hastanın hedef ve durumunu değerlendirmek','İşlevi kaydetmemek') 2)
            (New-Question 'Farmakolojik ve nonfarmakolojik yaklaşımlar için hangi ifade uygundur?' @('Birlikte planlanabilir','Birbirini daima dışlar','İkisi de izlem gerektirmez','Yalnızca şiddete bağlıdır') 0)
            (New-Question 'Pozisyon verme girişiminin etkisi nasıl değerlendirilir?' @('Sadece saat kaydıyla','Özbildirim ve işlevle','Yalnızca görüntülemeyle','Yalnızca aile görüşüyle') 1)
            (New-Question 'Duyu kaybı olan hastada sıcak uygulama düşünülüyorsa ilk işlem nedir?' @('Süreyi uzatmak','Isıyı artırmak','Uygunluk ve cilt güvenliğini değerlendirmek','Önce kaydı kapatmak') 2)
            (New-Question 'Soğuk uygulama sırasında ciltte sorun görülürse ne yapılmalı?' @('Uygulamayı hızlandırmak','Hastayı yalnız bırakmak','Belirtiyi görmezden gelmek','Uygulamayı durdurup değerlendirmek') 3)
            (New-Question 'Gevşeme ve dikkat dağıtma yöntemleri için hangisi doğrudur?' @('Hasta tercihi ve klinik duruma göre seçilir','Tüm hastalarda eşit etkilidir','Yeniden değerlendirme gerekmez','Yan etki izlemi yerine geçer') 0)
            (New-Question 'Ağrıya bağlı uykusuzluk bildiren hastada çevresel yaklaşım hangisidir?' @('Işığı ve gürültüyü artırmak','Uygun olduğunda ortamı sakinleştirmek','Görüşmeyi tümüyle bırakmak','Yalnızca puanı kaydetmek') 1)
            (New-Question 'Hasta eğitiminde hangi mesaj uygundur?' @('Ağrıyı gizlemesi','Yalnızca taburcu olunca bildirmesi','Yeni veya kötüleşen belirtileri bildirmesi','Ölçeği rastgele seçmesi') 2)
            (New-Question 'Girişimden sonra ağrı sürüyorsa hemşire ne yapmalıdır?' @('Sonucu kaydetmemeli','Aynı planı sorgusuz sürdürmeli','Hastayı bekletmeli','Yeniden değerlendirip ekibe bildirmeli') 3)
            (New-Question 'Ağrı bakımında güvenlik izlemi neleri kapsar?' @('Etki, yan etki ve klinik değişiklikleri','Yalnızca başlangıç ağrı puanını','Sadece girişim tamamlanma saatini','Yalnızca hastanın ilk tercihini') 0)
            (New-Question 'Bakım kaydı için hangi içerik en yararlıdır?' @('Yalnızca girişim adı','Önceki durum, girişim ve sonraki yanıt','Sadece tarih','Yalnızca hekim adı') 1)
            (New-Question 'Etkisiz ağrı kontrolü bakım sürekliliğinde nasıl ele alınır?' @('Kayıt dışı bırakılır','Yalnızca sözlü unutulur','Ekibe aktarılır ve plan yeniden gözden geçirilir','Hasta bildiriminden bağımsız sayılır') 2)
        )
    }
    @{
        title = 'Klinik Vakalarla Ağrı Yönetimi'; description = 'Dört kısa vakada değerlendirme, güvenli girişim, kayıt ve yeniden değerlendirme.'; minutes = 14
        quiz = 'Klinik Ağrı Vakaları'
        blocks = @(
            ,@('Heading', 'Vaka 1: Ameliyat sonrası')
            ,@('Case', "Akut ağrı`nHasta ameliyat sonrası kesi çevresinde 7/10 ağrı bildiriyor; derin nefes almakta zorlanıyor. İlk değerlendirmede başlangıç, yer, şiddet, karakter, yaşam bulguları ve solunum/işlev etkisini sorgula. Yeni veya beklenmedik bulguları ekibe bildir.")
            ,@('Text', 'Uygun bakım planı ve güvenli rahatlatıcı girişimden sonra ağrı puanını, nefes alma ve hareketi yeniden değerlendir. Girişim, zaman ve yanıtı kaydet.')
            ,@('Recall', "Sen olsaydın ne yapardın?`nAğrı puanı azaldı ama hasta hâlâ derin nefes alamıyor. Sonraki değerlendirmende neye odaklanırsın?")
            ,@('Heading', 'Vaka 2: Diyabetli hasta')
            ,@('Case', "Ayaklarda yanma`nDiyabetli hasta iki ayağında yanma ve uyuşma anlatıyor. Nöropatik mekanizma düşünülebilir; yalnızca sözcükten kesin tanı koyma. Dağılım, duyusal değişiklik, cilt bütünlüğü, işlev ve güvenliği değerlendir.")
            ,@('Text', 'Hastanın sözcüklerini ve bulguları kaydet. Planlanan bakımın etkisini ve ayak güvenliği gereksinimini yeniden değerlendir; yeni ya da artan bulguları ekiple paylaş.')
            ,@('Recall', "Sen olsaydın ne yapardın?`nYanma ile birlikte yeni duyu kaybı bildiriliyor. Hangi bilgileri kaydedip kime aktarırsın?")
            ,@('Heading', 'Vaka 3: İletişimi kısıtlı yaşlı hasta')
            ,@('Case', "Pozisyon değişiminde huzursuzluk`nHasta sayısal puan veremiyor, bakım sırasında yüzünü buruşturuyor. Önce iletişim kurabileceği yolu dene; davranış, hareket, yakın bilgisi ve klinik bağlamı birlikte değerlendir. Uygun gözlemsel araçtan yararlan.")
            ,@('Text', 'Gözlenen davranışı, bakım anını, kullanılan aracı ve girişimi kaydet. Müdahale sonrasında aynı uygun yaklaşımla yeniden değerlendir; ağrı yokluğu varsayma.')
            ,@('Recall', "Sen olsaydın ne yapardın?`nHasta konuşamıyor ama hareket ettirilince geri çekiliyor. İlk güvenli değerlendirmen ne olur?")
            ,@('Heading', 'Vaka 4: Uzun süredir yaygın ağrı')
            ,@('Case', "Günlük yaşamda zorlanma`nHasta aylardır yaygın ağrı, kötü uyku ve hareket kısıtlılığı bildiriyor. Süre, dağılım, önceki değerlendirmeler, işlev ve duygusal/sosyal etkiyi sorgula. Tek mekanizma veya tedavi sonucu varsayma.")
            ,@('Text', 'Hastayla gerçekçi işlev hedefini konuş. Ağrı ve işlevin başlangıç durumunu, bakım girişimini ve sonraki yanıtı kaydet; yeni akut yakınmayı ayrıca değerlendir.')
            ,@('Recall', "Sen olsaydın ne yapardın?`nKronik ağrısı olan hasta bugün farklı ve ani başlayan ağrı söylüyor. Hangi yeni bilgiyi öncelikle sorgularsın?")
            ,@('Summary', "Ortak yaklaşım`nHer vakada özbildirimi veya uygun gözlemsel bulguları al; işlev ve güvenliği değerlendir; girişimi kaydet; yanıtı yeniden değerlendir ve gerektiğinde ekibe bildir.")
        )
        questions = @(
            (New-Question 'Ameliyat sonrası hasta 7/10 ağrı ve derin nefes alamama bildiriyor. İlk adım nedir?' @('Yalnızca puanı kaydetmek','Sadece taburculuğu beklemek','Ölçeği kaldırmak','Ağrı ile solunum/işlevi birlikte değerlendirmek') 3)
            (New-Question 'Ameliyat sonrası girişimle ağrı 4/10 oldu, nefes alma hâlâ zor. Ne yapılır?' @('İşlevi yeniden değerlendirip ekiple paylaşmak','İzlemi bitirmek','Sadece sayıdaki düşüşü yeterli saymak','Kayıt tutmamak') 0)
            (New-Question 'Diyabetli hastada yanma ve uyuşma için en uygun yorum hangisidir?' @('Kesin visseral ağrı','Nöropatik mekanizma olasılığı','Ağrı olmadığı','Kesin nosiplastik ağrı') 1)
            (New-Question 'Diyabetli hastada ayak ağrısı değerlendirmesine hangi bulgu eklenmeli?' @('Yalnızca ağrı puanının önceki değeri','Sadece ağrının ilk söylendiği saat','Duyu ve cilt bütünlüğü','Yalnızca yakınların ağrı yorumu') 2)
            (New-Question 'İletişimi kısıtlı yaşlı hasta pozisyon değişiminde yüzünü buruşturuyor. İlk yaklaşım?' @('Ağrıyı yok saymak','Puanı sıfır yazmak','Sadece yakınına karar verdirmek','İletişim yolu ve davranışsal bulguları değerlendirmek') 3)
            (New-Question 'Gözlemsel değerlendirme sonrası girişim yapıldı. Yeniden değerlendirme nasıl olmalı?' @('Aynı uygun yaklaşım ve klinik bağlamla','Yalnızca bir kez nabız ölçerek','Hiç kayıt tutmadan','Sadece başka hastayla karşılaştırarak') 0)
            (New-Question 'Aylarca yaygın ağrısı olan hastada hangi bilgi bakım planına katkı sağlar?' @('Yalnızca son görüntüleme','Uyku, işlev ve hastanın hedefleri','Yalnızca tek bir ağrı puanı','Sadece eski tanı başlığı') 1)
            (New-Question 'Kronik ağrısı olan kişi bugün yeni ve ani ağrı bildiriyor. Hemşire ne yapmalı?' @('Eski ağrıyla aynı saymak','Bildirimi ertelemek','Yeni başlangıç ve eşlik eden bulguları değerlendirmek','Yalnızca eski puanı kopyalamak') 2)
            (New-Question 'Vaka 1 için yeniden değerlendirme kaydı hangisini içermelidir?' @('Yalnızca verilen girişim adını','Sadece ilk ağrı puanını','Yalnızca ziyaret saatini','Önce/sonra ağrı, işlev ve yanıtı') 3)
            (New-Question 'Ayakta yanma ve yeni duyu kaybı olduğunda ne yapılmalı?' @('Bulguyu kaydedip ekibe iletmek','Yalnızca rahat ayakkabı önermek','Kesin tanıyı tek başına koymak','Yeni bulguyu önemsiz saymak') 0)
            (New-Question 'Yaygın ağrıda tek bir mekanizma varsaymamak neden önemlidir?' @('Ölçek kullanmamak için','Birden çok etken veya mekanizma olabileceği için','İşlevi göz ardı etmek için','Kayıttan kaçınmak için') 1)
            (New-Question 'Dört vakanın ortak güvenli izlem adımı hangisidir?' @('Aynı girişimi herkese uygulamak','Sadece şiddeti görmek','Girişim sonrası yanıtı yeniden değerlendirmek','Hastanın bildirimini düzeltmek') 2)
        )
    }
)

if ($lessons.Count -ne 5) { throw 'Katalogda tam 5 ders olmalıdır.' }
foreach ($item in $lessons) {
    if ($item.questions.Count -ne 12) { throw "Quiz tam 12 soru içermeli: $($item.title)" }
    for ($i = 0; $i -lt $item.questions.Count; $i++) {
        $q = $item.questions[$i]
        if ($q.options.Count -ne 4 -or $q.correct -lt 0 -or $q.correct -gt 3 -or
            @($q.options | Select-Object -Unique).Count -ne 4) {
            throw "Geçersiz soru/seçenek: $($item.title) #$i"
        }
    }
}

$moduleTitle = 'Ağrı Yönetimi'
$moduleDescription = 'Hemşirelik bakımında ağrının tanınması, değerlendirilmesi, sınıflandırılması ve güvenli yönetimine yönelik temel eğitim modülü.'

function Assert-SeedIdentity($Candidate, [string]$Token, [int]$Level) {
    $candidateId = Get-SingleId $Candidate 'Pain modülü'
    $detail = Invoke-Api GET "/api/education/content/modules/$candidateId" -Token $Token
    if ($detail.title -cne (Convert-Expected $moduleTitle $Level) -or
        $detail.description -cne (Convert-Expected $moduleDescription $Level) -or
        $detail.lessons.Count -gt $lessons.Count) {
        throw "Modül seed kimliğiyle eşleşmiyor ($candidateId); silme iptal edildi."
    }
    $score = 0
    foreach ($lesson in $detail.lessons) {
        $matches = @(0..4 | Where-Object { $lesson.title -ceq (Convert-Expected $lessons[$_].title $Level) })
        if ($matches.Count -ne 1) { throw "Modülde beklenmeyen ders var ($candidateId); silme iptal edildi." }
        $index = $matches[0]
        $expected = $lessons[$index]
        if ($lesson.description -cne (Convert-Expected $expected.description $Level) -or
            $lesson.order -ne $index -or $lesson.estimatedDurationMinutes -ne $expected.minutes) {
            throw "Modülde değiştirilmiş ders var ($candidateId); silme iptal edildi."
        }
        $lessonId = Get-SingleId $lesson 'Ders'
        $lessonDetail = Invoke-Api GET "/api/education/content/lessons/$lessonId" -Token $Token
        $score += 1
        if ($lessonDetail.blocks.Count -gt $expected.blocks.Count -or $lessonDetail.quizzes.Count -gt 1) {
            throw "Derste beklenmeyen içerik var ($lessonId); silme iptal edildi."
        }
        foreach ($block in $lessonDetail.blocks) {
            $found = @($expected.blocks | Where-Object {
                $_[0] -ceq $block.blockType -and
                (Convert-Expected $_[1] $Level) -ceq $block.textContent
            })
            if ($found.Count -ne 1) { throw "Derste değiştirilmiş blok var ($lessonId); silme iptal edildi." }
            $score += 1
        }
        foreach ($quiz in $lessonDetail.quizzes) {
            if ($quiz.title -cne (Convert-Expected $expected.quiz $Level)) {
                throw "Derste beklenmeyen quiz var ($lessonId); silme iptal edildi."
            }
            $quizId = Get-SingleId $quiz 'Quiz'
            $quizDetail = Invoke-Api GET "/api/education/content/quizzes/$quizId" -Token $Token
            if ($quizDetail.questions.Count -gt 12) { throw "Quizde beklenmeyen soru var ($quizId); silme iptal edildi." }
            $score += 1
            foreach ($question in $quizDetail.questions) {
                if ($question.order -lt 0 -or $question.order -ge 12) {
                    throw "Quizde beklenmeyen soru sırası var ($quizId); silme iptal edildi."
                }
                $expectedQuestion = $expected.questions[$question.order]
                if ($question.prompt -cne (Convert-Expected $expectedQuestion.prompt $Level) -or
                    $question.options.Count -gt 4) {
                    throw "Quizde değiştirilmiş soru var ($quizId); silme iptal edildi."
                }
                $score += 1
                foreach ($option in $question.options) {
                    if ($option.order -lt 0 -or $option.order -ge 4 -or
                        $option.text -cne (Convert-Expected $expectedQuestion.options[$option.order] $Level) -or
                        $option.isCorrect -ne ($option.order -eq $expectedQuestion.correct)) {
                        throw "Quizde değiştirilmiş seçenek var ($quizId); silme iptal edildi."
                    }
                    $score += 1
                }
            }
        }
    }
    return [pscustomobject]@{ id = $candidateId; level = $Level; score = $score; isPublished = $detail.isPublished }
}

function Test-SeedLabel([string]$Actual, [string]$Expected) {
    foreach ($level in 0..2) {
        if ($Actual -ceq (Convert-Expected $Expected $level)) { return $true }
    }
    return $false
}

function Assert-MojibakeSeedFingerprint($Candidate, [string]$Token) {
    $candidateId = Get-SingleId $Candidate 'Bozuk pain modülü'
    if ($Candidate.title -cnotmatch '[ÃÄÅ]' -or
        -not (Test-SeedLabel $Candidate.title $moduleTitle) -or
        $Candidate.title -ceq $moduleTitle) {
        throw "Açıkça bozuk pain başlığı yok ($candidateId); silme iptal edildi."
    }
    $detail = Invoke-Api GET "/api/education/content/modules/$candidateId" -Token $Token
    if ($detail.id -ne $candidateId -or $detail.title -cne $Candidate.title -or
        $detail.lessons.Count -ne 5 -or -not $detail.isPublished) {
        throw "Bozuk modülün temel yapısı uyuşmuyor ($candidateId); silme iptal edildi."
    }
    $quizCount = 0; $questionCount = 0; $optionCount = 0; $blockCount = 0
    foreach ($index in 0..4) {
        $lessonMatches = @($detail.lessons | Where-Object { $_.order -eq $index })
        if ($lessonMatches.Count -ne 1 -or
            -not (Test-SeedLabel $lessonMatches[0].title $lessons[$index].title) -or
            -not $lessonMatches[0].isPublished) {
            throw "Ders yapısı uyuşmuyor ($candidateId, sıra $index); silme iptal edildi."
        }
        $lessonId = Get-SingleId $lessonMatches[0] 'Seed dersi'
        $lessonDetail = Invoke-Api GET "/api/education/content/lessons/$lessonId" -Token $Token
        $expected = $lessons[$index]
        if ($lessonDetail.educationModuleId -ne $candidateId -or
            $lessonDetail.blocks.Count -ne $expected.blocks.Count -or
            $lessonDetail.quizzes.Count -ne 1) {
            throw "Ders alt içeriği uyuşmuyor ($lessonId); silme iptal edildi."
        }
        for ($blockIndex = 0; $blockIndex -lt $expected.blocks.Count; $blockIndex++) {
            $blockMatches = @($lessonDetail.blocks | Where-Object { $_.sortOrder -eq $blockIndex })
            if ($blockMatches.Count -ne 1 -or
                $blockMatches[0].blockType -cne $expected.blocks[$blockIndex][0] -or
                $null -ne $blockMatches[0].media) {
                throw "Blok yapısı uyuşmuyor ($lessonId, sıra $blockIndex); silme iptal edildi."
            }
            $blockCount++
        }
        $quiz = $lessonDetail.quizzes[0]
        if (-not (Test-SeedLabel $quiz.title $expected.quiz) -or
            $quiz.order -ne 0 -or -not $quiz.isPublished) {
            throw "Quiz yapısı uyuşmuyor ($lessonId); silme iptal edildi."
        }
        $quizId = Get-SingleId $quiz 'Seed quiz'
        $quizDetail = Invoke-Api GET "/api/education/content/quizzes/$quizId" -Token $Token
        if ($quizDetail.lessonId -ne $lessonId -or $quizDetail.questions.Count -ne 12) {
            throw "Quiz soru sayısı uyuşmuyor ($quizId); silme iptal edildi."
        }
        $quizCount++
        foreach ($questionIndex in 0..11) {
            $questionMatches = @($quizDetail.questions | Where-Object { $_.order -eq $questionIndex })
            if ($questionMatches.Count -ne 1 -or
                [string]::IsNullOrWhiteSpace($questionMatches[0].prompt) -or
                $questionMatches[0].options.Count -ne 4) {
                throw "Soru yapısı uyuşmuyor ($quizId, sıra $questionIndex); silme iptal edildi."
            }
            $questionCount++
            $correctCount = 0
            foreach ($optionIndex in 0..3) {
                $optionMatches = @($questionMatches[0].options | Where-Object { $_.order -eq $optionIndex })
                if ($optionMatches.Count -ne 1 -or
                    [string]::IsNullOrWhiteSpace($optionMatches[0].text)) {
                    throw "Seçenek yapısı uyuşmuyor ($quizId, soru $questionIndex); silme iptal edildi."
                }
                if ($optionMatches[0].isCorrect) { $correctCount++ }
                $optionCount++
            }
            if ($correctCount -ne 1) { throw "Doğru cevap sayısı uyuşmuyor ($quizId); silme iptal edildi." }
        }
    }
    if ($quizCount -ne 5 -or $questionCount -ne 60 -or $optionCount -ne 240 -or $blockCount -ne 65) {
        throw "Seed fingerprint toplamları uyuşmuyor ($candidateId); silme iptal edildi."
    }
    Write-Host "Bozuk pain seed yapısı doğrulandı: $candidateId (5 ders, 65 blok, 5 quiz, 60 soru, 240 seçenek)"
    return $candidateId
}

$email = Read-Host 'Admin e-posta adresi'
$secure = Read-Host 'Admin şifresi' -AsSecureString
$ptr = [IntPtr]::Zero
try {
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    Write-Host 'Oturum açılıyor...'
    $login = Invoke-Api POST '/api/auth/login' @{ email = $email; password = $password; rememberMe = $false }
} finally {
    $password = $null
    if ($ptr -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    $secure = $null
}
$token = $login.accessToken
if (-not $token) { throw 'Login yanıtında accessToken yok.' }
if (@($login.user.roles) -notcontains 'Admin') { throw 'Bu işlem Admin rolü gerektirir.' }

Write-Host 'Mevcut modüller kontrol ediliyor...'
$modules = @(Get-ContentModules $token)
foreach ($entry in $modules) {
    $entryId = Get-SingleId $entry 'Modül listesi öğesi'
    Write-Host "  $entryId | $($entry.title)"
}
$candidates = @()
foreach ($entry in $modules) {
    for ($level = 0; $level -le 2; $level++) {
        if ($entry.title -ceq (Convert-Expected $moduleTitle $level)) {
            $candidates += [pscustomobject]@{
                id = (Get-SingleId $entry 'Pain modülü'); level = $level; item = $entry
            }
            break
        }
    }
}
$recognizedIds = @($candidates | ForEach-Object { $_.id })
$unrecognizedPain = @($modules | Where-Object {
    $recognizedIds -notcontains $_.id -and $_.title -match 'AÄŸr|AÃ°r|YÃ¶netimi'
})
if ($unrecognizedPain.Count) {
    throw 'Tanınmayan mojibake pain başlığı bulundu; hiçbir kayıt değiştirilmedi.'
}
$correctCandidates = @($candidates | Where-Object { $_.level -eq 0 })
$brokenCandidates = @($candidates | Where-Object { $_.level -gt 0 })
if ($correctCandidates.Count -gt 1) {
    throw 'Birden fazla doğru Ağrı Yönetimi modülü var; hiçbir kayıt değiştirilmedi.'
}
if ($correctCandidates.Count -eq 1) {
    # Doğru Unicode modülü için mevcut birebir seed/idempotency kontrolü korunur.
    $null = Assert-SeedIdentity $correctCandidates[0].item $token 0
}
if ($brokenCandidates.Count -and -not $RepairMojibake) {
    throw 'Bozuk pain seed modülü bulundu. İnceleme sonrası -RepairMojibake ile yeniden çalıştırın.'
}
$unrelated = @($modules | Where-Object { $recognizedIds -notcontains $_.id } |
    ForEach-Object { [pscustomobject]@{ id = $_.id; title = $_.title } })
if ($RepairMojibake) {
    $deleteIds = @()
    foreach ($candidate in $brokenCandidates) {
        # Silmeden önce bütün bozuk adaylar yalnızca yapısal fingerprint ile doğrulanır.
        $deleteIds += Assert-MojibakeSeedFingerprint $candidate.item $token
    }
    foreach ($candidateId in $deleteIds) {
        Write-Host "Soft-delete hedef module ID: $candidateId"
        $null = Invoke-Api DELETE "/api/education/modules/$candidateId" -Token $token
        $remaining = @(Get-ContentModules $token)
        if (@($remaining | Where-Object { $_.id -eq $candidateId }).Count) {
            throw "Silinen modül API listesinden kaybolmadı: $candidateId"
        }
    }
}
$modules = @(Get-ContentModules $token)
foreach ($entry in $unrelated) {
    if (@($modules | Where-Object { $_.id -eq $entry.id -and $_.title -ceq $entry.title }).Count -ne 1) {
        throw "İlgisiz modül korunamadı: $($entry.id)"
    }
}
$module = Assert-UniqueTitle $modules $moduleTitle 'Modül'
if (-not $module) {
    $moduleOrder = 0
    while (@($modules | Where-Object { $_.order -eq $moduleOrder }).Count) { $moduleOrder++ }
    $created = Invoke-Api POST '/api/education/modules' @{
        title = $moduleTitle
        description = $moduleDescription
        order = $moduleOrder
        isPublished = $false
    } -Token $token
    $moduleId = Assert-CreatedId $created 'Modül'
    $module = @{ id = $moduleId; order = $moduleOrder; isPublished = $false }
    Write-Host "Modül oluşturuldu: $moduleId"
} else { Write-Host "Modül yeniden kullanılıyor: $($module.id)" }
$moduleId = Get-SingleId $module 'Seçilen modül'

foreach ($lessonIndex in 0..4) {
    $item = $lessons[$lessonIndex]
    $moduleDetail = Invoke-Api GET "/api/education/content/modules/$moduleId" -Token $token
    $lesson = Assert-UniqueTitle $moduleDetail.lessons $item.title 'Ders'
    if (-not $lesson) {
        $created = Invoke-Api POST "/api/education/modules/$moduleId/lessons" @{
            title = $item.title; description = $item.description
            estimatedDurationMinutes = $item.minutes; order = $lessonIndex; isPublished = $false
        } -Token $token
        $lessonId = Assert-CreatedId $created 'Ders'
        $lesson = @{ id = $lessonId; isPublished = $false }
        Write-Host "Ders oluşturuldu: $($item.title)"
    } else { Write-Host "Ders yeniden kullanılıyor: $($item.title)" }
    $lessonDetail = Invoke-Api GET "/api/education/content/lessons/$($lesson.id)" -Token $token
    for ($blockIndex = 0; $blockIndex -lt $item.blocks.Count; $blockIndex++) {
        $block = $item.blocks[$blockIndex]
        $found = @($lessonDetail.blocks | Where-Object {
            $_.blockType -eq $block[0] -and $_.textContent -eq $block[1]
        })
        if ($found.Count -gt 1) { throw "Aynı blok tekrar edilmiş: $($item.title) #$blockIndex" }
        if ($found.Count -eq 0) {
            $order = $blockIndex
            while (@($lessonDetail.blocks | Where-Object { $_.sortOrder -eq $order }).Count) { $order++ }
            $created = Invoke-Api POST "/api/education/lessons/$($lesson.id)/blocks" @{
                blockType = $block[0]; textContent = $block[1]; mediaId = $null; sortOrder = $order
            } -Token $token
            $blockId = Assert-CreatedId $created 'Blok'
            $lessonDetail = Invoke-Api GET "/api/education/content/lessons/$($lesson.id)" -Token $token
            if (-not @($lessonDetail.blocks | Where-Object { $_.id -eq $blockId }).Count) {
                throw "Oluşturulan blok okunamadı: $blockId"
            }
            Write-Host "  Blok eklendi: $($block[0]) #$blockIndex"
        }
    }
    $desiredOrders = @()
    for ($blockIndex = 0; $blockIndex -lt $item.blocks.Count; $blockIndex++) {
        $block = $item.blocks[$blockIndex]
        $matches = @($lessonDetail.blocks | Where-Object {
            $_.blockType -eq $block[0] -and $_.textContent -eq $block[1]
        })
        if ($matches.Count -ne 1) { throw "Blok eşleşmesi belirsiz: $($item.title) #$blockIndex" }
        $desiredOrders += @{ blockId = $matches[0].id; sortOrder = $blockIndex }
    }
    $extraBlocks = @($lessonDetail.blocks | Where-Object { $desiredOrders.blockId -notcontains $_.id } | Sort-Object sortOrder)
    foreach ($extra in $extraBlocks) {
        $desiredOrders += @{ blockId = $extra.id; sortOrder = $desiredOrders.Count }
    }
    $needsReorder = $false
    foreach ($entry in $desiredOrders) {
        $current = @($lessonDetail.blocks | Where-Object { $_.id -eq $entry.blockId })[0]
        if ($current.sortOrder -ne $entry.sortOrder) { $needsReorder = $true; break }
    }
    if ($needsReorder) {
        $null = Invoke-Api PUT "/api/education/lessons/$($lesson.id)/blocks/reorder" @{
            blocks = $desiredOrders
        } -Token $token
        Write-Host "  Blok sırası düzenlendi: $($item.title)"
    }
    $quiz = Assert-UniqueTitle $lessonDetail.quizzes $item.quiz 'Quiz'
    if (-not $quiz) {
        $created = Invoke-Api POST "/api/education/lessons/$($lesson.id)/quizzes" @{
            title = $item.quiz; order = 0; isPublished = $false
        } -Token $token
        $quizId = Assert-CreatedId $created 'Quiz'
        $quiz = @{ id = $quizId; isPublished = $false }
        Write-Host "  Quiz oluşturuldu: $($item.quiz)"
    } else { Write-Host "  Quiz yeniden kullanılıyor: $($item.quiz)" }
    for ($questionIndex = 0; $questionIndex -lt 12; $questionIndex++) {
        $expected = $item.questions[$questionIndex]
        $quizDetail = Invoke-Api GET "/api/education/content/quizzes/$($quiz.id)" -Token $token
        $question = Assert-UniqueTitle $quizDetail.questions $expected.prompt 'Soru' 'prompt'
        if (-not $question) {
            if (@($quizDetail.questions | Where-Object { $_.order -eq $questionIndex }).Count) {
                throw "Soru sırası dolu: $($item.quiz) #$questionIndex"
            }
            $created = Invoke-Api POST "/api/education/quizzes/$($quiz.id)/questions" @{
                prompt = $expected.prompt; order = $questionIndex
            } -Token $token
            $questionId = Assert-CreatedId $created 'Soru'
            $question = @{ id = $questionId; options = @() }
            Write-Host "    Soru eklendi: $($questionIndex + 1)/12"
        } elseif ($question.order -ne $questionIndex) {
            throw "Soru sırası farklı: $($item.quiz) #$questionIndex"
        }
        for ($optionIndex = 0; $optionIndex -lt 4; $optionIndex++) {
            $quizDetail = Invoke-Api GET "/api/education/content/quizzes/$($quiz.id)" -Token $token
            $question = @($quizDetail.questions | Where-Object { $_.id -eq $question.id })[0]
            $optionText = $expected.options[$optionIndex]
            $existing = @($question.options | Where-Object { $_.text -eq $optionText })
            if ($existing.Count -gt 1) { throw "Seçenek tekrar edilmiş: $($expected.prompt)" }
            if ($existing.Count -eq 1) {
                if ($existing[0].order -ne $optionIndex -or $existing[0].isCorrect -ne ($optionIndex -eq $expected.correct)) {
                    throw "Mevcut seçenek farklı: $($expected.prompt)"
                }
                continue
            }
            if (@($question.options | Where-Object { $_.order -eq $optionIndex }).Count) {
                throw "Seçenek sırası dolu: $($expected.prompt)"
            }
            $created = Invoke-Api POST "/api/education/questions/$($question.id)/options" @{
                text = $optionText; isCorrect = ($optionIndex -eq $expected.correct); order = $optionIndex
            } -Token $token
            $optionId = Assert-CreatedId $created 'Seçenek'
            $updatedQuiz = Invoke-Api GET "/api/education/content/quizzes/$($quiz.id)" -Token $token
            $updatedQuestion = @($updatedQuiz.questions | Where-Object { $_.id -eq $question.id })[0]
            if (-not @($updatedQuestion.options | Where-Object { $_.id -eq $optionId }).Count) {
                throw "Oluşturulan seçenek okunamadı: $optionId"
            }
        }
    }
    $quizDetail = Invoke-Api GET "/api/education/content/quizzes/$($quiz.id)" -Token $token
    if ($quizDetail.questions.Count -ne 12) { throw "Quiz soru sayısı 12 değil: $($item.quiz)" }
    foreach ($q in $quizDetail.questions) {
        if ($q.options.Count -ne 4 -or @($q.options | Where-Object isCorrect).Count -ne 1) {
            throw "Quiz seçenekleri geçersiz: $($item.quiz)"
        }
    }
    if (-not $quizDetail.isPublished) {
        $null = Invoke-Api PUT "/api/education/quizzes/$($quiz.id)" @{
            title = $item.quiz; order = 0; isPublished = $true
        } -Token $token
        Write-Host "  Quiz yayınlandı: $($item.quiz)"
    }
    if (-not $lessonDetail.isPublished) {
        $null = Invoke-Api PUT "/api/education/lessons/$($lesson.id)" @{
            title = $item.title; description = $item.description
            estimatedDurationMinutes = $item.minutes; order = $lessonIndex; isPublished = $true
        } -Token $token
        Write-Host "Ders yayınlandı: $($item.title)"
    }
}
if (-not $module.isPublished) {
    $null = Invoke-Api PUT "/api/education/modules/$moduleId" @{
        title = $moduleTitle
        description = $moduleDescription
        order = $module.order; isPublished = $true
    } -Token $token
    Write-Host 'Modül yayınlandı.'
}
Write-Host 'Yayınlanan Türkçe içerik API üzerinden doğrulanıyor...'
$finalModules = @(Get-ContentModules $token)
foreach ($entry in $unrelated) {
    if (@($finalModules | Where-Object { $_.id -eq $entry.id -and $_.title -ceq $entry.title }).Count -ne 1) {
        throw "İlgisiz modül son kontrolde bulunamadı: $($entry.id)"
    }
}
$remainingPain = @($finalModules | Where-Object {
    $_.title -ceq (Convert-Expected $moduleTitle 0) -or
    $_.title -ceq (Convert-Expected $moduleTitle 1) -or
    $_.title -ceq (Convert-Expected $moduleTitle 2)
})
if ($remainingPain.Count -ne 1) {
    throw "Repair sonrası pain seed modülü sayısı 1 değil: $($remainingPain.Count)"
}
$finalModuleSummary = Assert-UniqueTitle $finalModules $moduleTitle 'Modül'
if (-not $finalModuleSummary -or $finalModuleSummary.id -ne $moduleId -or
    -not $finalModuleSummary.isPublished) {
    throw 'Doğru başlıklı yayınlanmış modül API yanıtında bulunamadı.'
}
$finalModule = Invoke-Api GET "/api/education/content/modules/$moduleId" -Token $token
if ($finalModule.title -cne 'Ağrı Yönetimi') { throw 'Modül başlığı Türkçe doğrulamasından geçmedi.' }
Assert-NoMojibake $finalModule 'modül ve ders listesi'
foreach ($item in $lessons) {
    $finalLesson = Assert-UniqueTitle $finalModule.lessons $item.title 'Ders'
    if (-not $finalLesson -or -not $finalLesson.isPublished) {
        throw "Ders başlığı/yayını Türkçe doğrulamasından geçmedi: $($item.title)"
    }
    $finalLessonDetail = Invoke-Api GET "/api/education/content/lessons/$($finalLesson.id)" -Token $token
    if ($finalLessonDetail.title -cne $item.title) { throw "Ders başlığı farklı: $($item.title)" }
    Assert-NoMojibake $finalLessonDetail "ders $($item.title)"
    $finalQuizSummary = Assert-UniqueTitle $finalLessonDetail.quizzes $item.quiz 'Quiz'
    if (-not $finalQuizSummary -or -not $finalQuizSummary.isPublished) {
        throw "Quiz başlığı/yayını farklı: $($item.quiz)"
    }
    $finalQuiz = Invoke-Api GET "/api/education/content/quizzes/$($finalQuizSummary.id)" -Token $token
    Assert-NoMojibake $finalQuiz "quiz $($item.quiz)"
}
Write-Host 'Tamamlandı: 1 modül, 5 ders, 5 quiz, 60 soru ve 240 seçenek kontrol edildi.'

