# Integrace nového PPG/HRV pipeline

Tento dokument popisuje, jak napojit nově přidané moduly do existující appky.
Žádný stávající soubor nebyl změněn – integrace se dělá postupně, abys mohl
ověřit každý krok.

## Nové soubory

1. **`dsp_utils.dart`** – DSP primitivy: zero-phase `filtfilt`, Butterworth
   biquady, parabolická interpolace, robust statistika (MAD), lineární detrend.
2. **`pos_extractor.dart`** – POS algoritmus (Wang 2017) pro extrakci PPG
   ze všech tří RGB kanálů místo green-only.
3. **`unified_peak_detector.dart`** – **single source of truth** pro detekci
   peaků s sub-sample parabolickou interpolací polohy.
4. **`hrv_calculator.dart`** – kanonická HRV analýza s Malik filtrem, správným
   Baevsky SI a Lomb-Scargle frekvenční doménou.
5. **`motion_canceller.dart`** – NLMS adaptivní filtr s akcelerometrem jako
   reference.
6. **`signal_quality_index.dart`** – SQA index podle Elgendi 2016 (skewness,
   kurtosis, spectral purity, periodicity).
7. **`perfusion_index.dart`** – Perfusion Index místo nespolehlivého SpO2.

## Závislosti

Pro motion canceller potřebuješ `sensors_plus` v `pubspec.yaml`:

```yaml
dependencies:
  sensors_plus: ^6.0.1
```

Pak `flutter pub get`.

## Doporučený postup integrace (s ohledem na předchozí breakage)

### KROK 1 – ověř, že se to zkompiluje (zero risk)
```bash
flutter analyze lib/elements/
flutter build apk --debug
```

### KROK 2 – HRV výpočet v `records.dart` detail view (low risk)
Jen retrospektivní zobrazení. Datový sběr beze změny. Tohle přinese:
- správný Baevsky SI
- Malik filter na ektopické tepy
- čestné LF/HF (skryté pod 2 min záznamu)

V `records.dart` přidej import a v `_showRecordDetail` nahraď velký
if/else blok HRV výpočtu (~828–935) voláním `HrvCalculator.compute(ibisMs)`.

### KROK 3 – sjednotit peak detekci v `records.dart` detail view
Nahradit inline `_findPeaks` voláním `UnifiedPpgPeakDetector`.
Pozor: signál v `record.dataForPlot` je už jednou invertovaný; pro detekci
peaků jako max ho musíš invertovat znovu (`signal.map((v) => -v)`).

### KROK 4 – `HrvCalculator` v `ppg_algo.dart::_calculateFinalHrv`
`_allIbiIntervals` je v sekundách → vynásob 1000 před voláním.

### KROK 5 – `UnifiedPpgPeakDetector` v `home.dart` pro live BPM
Nahradit `PeakDetector.findPeaks` se zachováním `zeroPhase: false` (causal).

### KROK 6 – motion canceller v `home.dart`
Přidat `sensors_plus`, napojit NLMS. Začni s `stepSize = 0.05`.

### KROK 7 – nový quality index s 5 úrovněmi (UI změny)
Nahradit binární kvalitu enum-based s barevným odlišením.

### KROK 8 – POS extractor v `ppg_algo.dart` (HIGH RISK)
Mění magnitudu primárního signálu. Všechny downstream prahy v
`signal_quality_checker.dart` a v `_detectMotionArtifacts` budou potřeba
přeladit. **Nedělej dříve než vše ostatní funguje.**

### KROK 9 – SpO2 → Perfusion Index
UI změny v summary, records detail, PDF export.

## Kompatibilita se stávajícími záznamy

`HrvResult.toMap()` produkuje mapu s **všemi původními klíči** plus novými.
Stávající `Record.fromJson` bude fungovat beze změny.

Pokud chceš znovu zpracovat staré záznamy s novým algoritmem, použij
`PosExtractor.extractBatch` z uložených `rawRgbSamples`:

```dart
final pos = PosExtractor.extractBatch(
  red: record.rawRgbSamples.map((s) => (s['red'] as num).toDouble()).toList(),
  green: record.rawRgbSamples.map((s) => (s['green'] as num).toDouble()).toList(),
  blue: record.rawRgbSamples.map((s) => (s['blue'] as num).toDouble()).toList(),
  fs: 30.0,
);
final detector = UnifiedPpgPeakDetector(fs: 30.0);
final peaks = detector.detect(pos, zeroPhase: true);
final hrv = HrvCalculator.compute(detector.ibisMs(peaks));
```
