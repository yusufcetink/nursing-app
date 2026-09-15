# Ders Detayı V2

Referans: `13-lesson-detail-light-dark.png`. Built-in ImageGen ile üretildi.
Örnek başlık, süre, ilerleme ve video içeriği yalnızca tasarım örneğidir.
Flutter ekranı gerçek lesson/content block verilerini ve sırasını kullanır.

## Uygulama

- Mevcut global light/dark tema; 20 px yatay boşluk, 34 px güçlü başlık.
- Üstte modül başlığı ve gerçek modül tamamlanma oranı, ardından ders sırası/süre.
- İçerik Heading/Text/Image/Video sırası değişmez; olmayan medya eklenmez.
- Medya kartı 18 px radius, tema yüzeyi ve ince kenarlık. Video seek/play ve süre
  controller verisinden gelir. Mockup video karesi uygulama asseti değildir.
- Hazır olduğunda paneli mevcut tamamlanma durumu ile gösterilir.
- Dersi Tamamla / Quiz'e Geç mevcut kaydetme, analytics ve routing akışını kullanır.
- Bookmark, özet sekmesi veya yeni özellik eklenmez.

## Üretim istemi

```text
Use case: ui-mockup. Create a NEW Aslı App V2 LESSON DETAIL reference board, LIGHT and DARK full mobile screens side by side. Supplied image is STYLE REFERENCE ONLY: follow its sophisticated adult nursing app typography, cobalt/periwinkle, warm ivory and deep teal palette, restrained coral, generous editorial hierarchy. This is LESSON DETAIL, not a module list. Brand centered Aslı App and back arrow, compact top. At 390 logical px screen content gutters20. Exact light #F8F5EF background #192B32 text #294AC5 primary, dark #14262C background #F8F5EF text #20363D cards #B8C6FF primary. Manrope-like type.
Below brand: small module label VİTAL BULGULAR, right 3 / 6 ders tamamlandı; six slim progress segments 3 filled; compact DERS 04 left and clock 8 dk right; very bold 34pt two line title Nabız değerlendirmesi; description Nabzı gözlemle, değerlendir ve kaydet.
Content flow: thin section header ANLATIM with hairline; 16:9 video card with 18px radius. Show a paused clinical teaching video still of nurse checking adult wrist pulse, minimal no decorative characters. SMALL caption under video Nabız değerlendirmesi, play icon and ordinary horizontal seek line, duration 03:24. This is an EXAMPLE of server video content, not a bundled illustration. Below actual lesson heading İlk gözlem 23pt bold; paragraph Hasta ile iletişim kurarak değerlendirmeye hazırlan. 16pt. Then roomy apricot/teal tinted callout with small outlined check-circle, bold Hazır olduğunda and secondary Bu adımı tamamlayarak ilerleyebilirsin. No invented medical advice.
Footer in scroll content: full width rounded rectangle cobalt/periwinkle button Dersi Tamamla with right arrow. Below phone bottom retain unobtrusive two tab app navigation Eğitim and Profil. No bookmark, summary tab, note taking, fabricated quiz score, no quiz before completion, no decorative heart cover replacing content. Display sample content only as mockup; UI will render actual Heading/Text/Image/Video blocks in stored order. Premium production quality, clean crisp Turkish glyphs, subtle borders no excessive shadows. Portrait board around 1024x1536. Make both themes identical layout and content.
```
