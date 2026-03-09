# PPG Algoritmus - Kritické opravy (9. března 2026)

## Přehled změn

Byly opraveny tři kritické problémy v PPG algoritmu, které se vyskytovaly před validační studií:

---

## 1. ✅ Sliding Window Processing místo Blokového Bufferování

### Problém
- Algoritmus čekal na naplnění 300 snímků (~10 sekund) před zpracováním
- Uživatel tak slyšel výsledek až po 10 sekundách
- Přechod mezi bloky ztrácel kontinuitu IBI intervalů pro výpočet HRV
- Výsledky byly skokové, nikoliv plynulé

### Řešení
**Nový sliding window system** (lib/ppg_algo.dart):

```dart
// Konstanty nahrazeny:
static const int _slidingWindowSize = 60;      // 2 sekund oken (30 FPS)
static const int _slideInterval = 30;          // Zpracování každou 1 sekundu
```

**Výhody:**
- ✅ Zpracování každých ~1 sekundy místo 10 sekund
- ✅ Plynulé výsledky bez skokování
- ✅ 50% překrytí oken zajistí kontinuitu IBI
- ✅ Uživatel vidí okamžité feedback

**Implementace v `processImage()`:**
- Nová čítač `_framesProcessedSinceLastUpdate` sleduje počet snímků
- Když dosáhne `_slideInterval` (30), zpracuje poslední `_slidingWindowSize` (60) snímků
- Buffer je zakonzervován do maximální velikosti `_maxFrameBufferSize` (300)
- Starší data jsou postupně odstraňována, aby se zachovalo překrytí

---

## 2. ✅ Lokální Framerate per Batch místo Globálního Průměru

### Problém
- Framerate byl počítán jako **globální running average**: `_frameRate = (_frameRate + currentFps) / 2`
- Při krátkém zpomalení (GC pause, systémový interrupt) se odhad deformoval
- Deformovaný framerate následně ovlivnil VŠECHNY následné výpočty IBI a peak detection
- Exponenciální šíření chyby

### Řešení
**Lokální framerate per batch** (lib/ppg_algo.dart):

```dart
// Nová metoda pro výpočet lokálního framerate:
double _calculateLocalFrameRate() {
  if (_timestamps.length < 2) return 0.0;
  
  final int timeDiff = _timestamps.last - _timestamps.first;
  if (timeDiff <= 0) return 0.0;
  
  final int frameCount = _timestamps.length - 1;
  return (frameCount * 1000.0) / timeDiff;  // Lokální FPS z aktuálního batchu
}
```

**Výhody:**
- ✅ Každý batch má svůj vypočítaný framerate
- ✅ Není ovlivněn předchozími zpomalením
- ✅ Robustnější zpracování
- ✅ Přesnější detekce peaků

**Aplikace:**
- `_localFrameRate` se počítá pro každý sliding window batch
- Používá se v `_calculateHeartRate(signal, localFrameRate)` místo globálního `_frameRate`
- Globální `_frameRate` se stále počítá pro referenci, ale nepoužívá se v kritických výpočtech

---

## 3. ✅ Průběžný Výpočet HRV Metrik (místo pouze na konci měření)

### Problém
- Metriky SDNN, RMSSD, pNN50, SD1, SD2 se počítaly **pouze jednou** na konci měření v `getSummary()`
- Během měření nebyl dostupný žádný HRV indikátor
- Uživatel nemohl vidět průběh HRV během měření
- Všechna data se počítala až po skončení měření

### Řešení
**Nová metoda `_updateContinuousHrv()`** (lib/ppg_algo.dart):

```dart
void _updateContinuousHrv() {
  if (_allIbiIntervals.length < 2) return;
  
  // Používá pouze POSLEDNÍ 300 IBI pro HRV (poslední ~5 minut)
  final List<double> recentIbis = _allIbiIntervals.length > 300
      ? _allIbiIntervals.sublist(_allIbiIntervals.length - 300)
      : _allIbiIntervals;
  
  // Vypočítá SDNN, RMSSD, pNN50, SD1, SD2 z recent IBIs
  // ...
  
  print('HRV (continuous): SDNN=... RMSSD=... pNN50=... (z ${recentIbis.length} IBIs)');
}
```

**Výhody:**
- ✅ HRV metriky jsou dostupné BĚHEM měření
- ✅ Aktualizace po každém sliding window zpracování
- ✅ Uživatel vidí průběžný HRV indikátor
- ✅ Používá se poslední 300 IBI (rolling window) pro stabilitu

**Aplikace:**
- `_updateContinuousHrv()` se volá v `processImage()` po každém zpracování batchu
- Getter metody (`getSdnn()`, `getRmssd()`, atd.) vrací aktuální HRV hodnoty
- Na konci měření se volá `_calculateFinalHrv()` pro finální souhrn

---

## Technické Detaily

### Změněné Metody

1. **`processImage()` - NEW IMPLEMENTATION**
   - Namísto čekání na 300 snímků: zpracovává každých 30 snímků
   - Udržuje sliding window s překrytím
   - Volá `_updateContinuousHrv()` po každém zpracování

2. **`_calculateLocalFrameRate()` - NOVÁ**
   - Počítá framerate z aktuálního batchu
   - Odolnější vůči outlierům

3. **`_calculateHeartRate(signal, localFrameRate)` - PODPIS ZMĚNĚN**
   - Nyní přijímá data batchu a lokální framerate
   - Zamezuje používání globálního framerate

4. **`_estimateHrFrequencyDomain(signal, localFrameRate)` - PODPIS ZMĚNĚN**
   - Používá lokální framerate pro FFT

5. **`_estimateHrTimeDomain(signal, localFrameRate)` - PODPIS ZMĚNĚN**
   - Používá lokální framerate pro výpočet IBI

6. **`_updateContinuousHrv()` - NOVÁ**
   - Počítá HRV metriky průběžně
   - Volána po každém zpracování batchu

7. **`_calculateFinalHrv()` - ZACHOVÁN**
   - Nyní je alternativa pro finální sumarizaci
   - Počítá ze VŠECH IBI (nikoliv jenom recent)

### Nové Proměnné

```dart
// Sliding window variables
int _framesProcessedSinceLastUpdate = 0;
double _localFrameRate = 0.0;  // Current batch framerate
```

---

## Testing & Verifikace

### Co zkontrolovat během testu:

1. **Sliding Window funkčnost**
   - [ ] HR se aktualizuje každých ~1 sekundy (ne 10)
   - [ ] Nový HR je nejméně o 5-10 BPM plynulejší
   - [ ] Není viditelných skoků v grafu

2. **Framerate stabilita**
   - [ ] Log ukazuje konzistentní lokální framerate (±2-5%)
   - [ ] HRV hodnoty nejsou divoké skoky
   - [ ] Performance je kontrolovatelná

3. **HRV Monitoring**
   - [ ] Během měření vidím SDNN, RMSSD hodnoty
   - [ ] HRV indikátory se pomalu stabilizují (ne skoky)
   - [ ] Finální HRV se shoduje se souhrnem

---

## Backward Compatibility

- ✅ Všechny getter metody zůstávají stejné
- ✅ `getSummary()` vrací stejný výsledek (median BPM)
- ✅ Pokud starý kód volá `_calculateHeartRate()` bez parametrů → COMPILE ERROR (záměrné!)

---

## Další Doporučení

1. **Rozšíření v budoucnu:**
   - Adaptive sliding window velikost na základě kraje framerate
   - Detekce artefaktů (náhlé skokové změny HR)
   - Machine learning model pro predikci HRV stability

2. **Monitorování v Produkci:**
   - Sklízeí metrik: průměrná čekací doba na první HR, variabilita HR
   - Logging lokálního framerate pro diagnostiku problémů

---

## Soubory Změněny

- **lib/ppg_algo.dart** - Hlavní implementace všech oprav
  - Lines 43-52: Nové konstanty
  - Lines 100-200: `processImage()` nová implementace
  - Lines 200-250: `_calculateLocalFrameRate()` nová metoda
  - Lines 280-400: `_calculateHeartRate()` refaktor
  - Lines 400-500: `_estimateHrFrequencyDomain()` & `_estimateHrTimeDomain()` refaktor
  - Lines 680-750: `_updateContinuousHrv()` nová metoda
  - Lines 750-820: `_calculateFinalHrv()` zachován
  - Lines 900-920: `reset()` aktualizován
