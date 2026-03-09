# Zásady ochrany osobních údajů – Tepovka

**Verze:** 1.0  
**Aktualizace:** Březen 2026  
**Poskytovatel:** VUT Brno  
**Webové stránky:** https://mojetepovka.cz

---

## 1. Úvod

Aplikace **Tepovka** je wellness aplikace určena ke **měření a sledování srdeční frekvence a variability srdeční frekvence (HRV)** pomocí fotografického snímače telefonu.

Vaše zdraví a soukromí jsou pro nás prioritou. Tato zásada vysvětluje, jaké údaje sbíráme, jak je používáme a jaká práva máte.

---

## 2. Jaké údaje sbíráme?

### 2.1 Zdravotní Data
- **Srdeční frekvence (BPM)** - měření v reálném čase
- **Variabilita srdeční frekvence (HRV)** - SDNN, RMSSD, pNN50, SD1, SD2
- **Dechová frekvence (RR)** - počet dechu za minutu
- **Doba měření** - délka jednotlivého měření
- **Historie měření** - časové razítko a údaje časových řad

### 2.2 Technická Data
- **Údaje z fotoaparátu** - pouze záznamy intenzity signálu (zpracovány lokálně, nejsou uloženy)
- **Údaje iOS HealthKit** - pokud povolíte integraci s Apple Health
- **Údaje Android Health Connect** - pokud povolíte integraci
- **Metadata aplikace** - verze, jazyk, operační systém
- **Nastavení uživatele** - senior režim, haptika, ukládání záznamů

### 2.3 Údaje, které NESBÍRÁME
- ❌ Video či fotografie z fotoaparátu
- ❌ Polohu
- ❌ Kontakty nebo sociální profily
- ❌ Data mimo Tepovku nebo HealthKit
- ❌ Údaje bez vašeho souhlasu

---

## 3. Jak dlouho data uchováváme?

| Typ data | Uchování | Místo |
|----------|----------|--------|
| Měření (SIM) | According to your choice | Telefon (lokální) |
| HealthKit data | Stejně dlouho jako HealthKit | Apple Health / Health Connect |
| Metadata aplikace | Trvale nebo dokud app neodstraníte | Telefon |
| Backupy | Dokud je zálohování povoleno | Phone backup / iCloud / Google Drive |

---

## 4. Princip Zpracování Dat

### 4.1 Lokální Zpracování (VÝCHOZÍ)
- **Veškerá měření probíhají OFF-LINE na vašem telefonu**
- Žádná data se neposílají na servery
- Všechny výpočty (FFT, HRV, RR) probíhají lokálně
- Máte plnou kontrolu a vlastnictví svých dat

### 4.2 Volitelná Integrace
Pokud si zvolíte:
- ✅ **Uložení do aplikace** (výchozí) - data zůstávají v Tepovce
- ✅ **Apple Health / Health Connect** - data se sdílí s HealthKit (dle vašeho souhlasu)

### 4.3 Žádné Cloudové Synchronizace
- Tepovka **NEPŘEDÁVÁ** data na žádné servery třetích stran
- Nejsou registrovány žádné účty na serverech
- Žádné e-maily, přihlášení nebo cloudový backup Tepovky (pouze lokální telefon)

---

## 5. Sdílení Údajů s Třetími Stranami

### Apple Health (iOS)
- Data se sdílují **POUZE pokud vy aktivujete** přepínač v Nastavení
- Tepovka nemá přístup k ostatním HealthKit aplikacím
- Apple kontroluje přístup ke HealthKit - viz [Apple HealthKit Privacy](https://www.apple.com/healthkit/)

### Health Connect (Android)
- Data se sdílují **POUZE pokud vy aktivujete**
- Podobná kontrola jako u HealthKit
- Viz [Android Health Connect Privacy](https://developer.android.com/guide/health-and-fitness/health-connect)

### Třetí strany - NIKDY
- Tepovka se NIKDY nedělí s:
  - Sociálními sítěmi
  - Reklamními sítěmi
  - Analytickými firmami
  - Operátory
  - Jakýmkoli dalším subjektem bez výslovného práva

---

## 6. Bezpečnost

- ✅ **Šifrování přenosu** - veškerá komunikace (HealthKit) přes HTTPS
- ✅ **Lokální úložiště** - data chráněna tvým PIN/Face ID
- ✅ **Open-Source** - kód je veřejný; chyby lze hlásit komunite
- ✅ **Bezpečnostní audity** - pravidelné přezkoumání

---

## 7. Vaše Práva (GDPR, CCPA, apod.)

Máte právo na:

| Právo | Popis | Jak exercovat |
|------|-------|--------------|
| **Přístup** | Vidět svá data | Exportovat ze Settings |
| **Oprava** | Změnit/smazat data | Smazat měření přímo v app |
| **Zapomenutí** (Smazání) | Trvale smazat veškerá data | Uninstall + Odstranit storage |
| **Přenositelnost** | Stáhnout v CSV | Export funkce v Settings |
| **Odvolat souhlas** | Vypnout HealthKit sdílení | Settings > Health Sync |
| **Stížnost** | Kontaktovat regulátor | info@mojetepovka.cz |

---

## 8. Volání Trzetích Stran (Permissions)

### Android Permissions
```xml
<uses-permission android:name="android.permission.CAMERA" />
<!-- Jen pro měření PPG signálu -->

<uses-permission android:name="android.permission.INTERNET" />
<!-- Jen pro integrace HealthKit (volitelné) -->
```

### iOS Permissions
```xml
NSCameraUsageDescription
<!-- Fotoaparát: měření srdeční frekvence -->

NSHealthShareUsageDescription
NSHealthUpdateUsageDescription  
<!-- HealthKit: volitelná integrace -->

NSMicrophoneUsageDescription
<!-- Mikrofon: blesk při měření -->
```

---

## 9. Změny v Zásadách

Vyhrazujeme si právo tyto zásady aktualizovat. Budeme vás informovat:
- Prostřednictvím aplikace (v-app notifikace)
- Prostřednictvím webových stránek (mojetepovka.cz)
- **At least 30 days before changes take effect**

Pokud se změny vám nelíbí, můžete si aplikaci odinstalovat bez penalizace.

---

## 10. Kontakt

Máte dotazy o ochraně údajů?

📧 **Email:** privacy@mojetepovka.cz  
📞 **Telefon:** +420 541 146 111 (VUT Brno)  
🏢 **Adresa:** Vysoké učení technické v Brně, Technická 3058/10, 616 00 Brno  
🌐 **Web:** https://mojetepovka.cz  

Můžete také kontaktovat našeho **Data Protection Officer (DPO):**  
📧 **DPO Email:** dpo@vut.cz

---

## 11. Právní Základ

Tato aplikace je upravena v souladu s:
- 🇪🇺 **GDPR** (EU General Data Protection Regulation)
- 🇨🇿 **Zákon o ochraně osobních údajů** (ZOPOD)
- 🍎 **iOS Privacy Guidelines** (App Store Review)
- 🤖 **Google Play Policies** (Health & Fitness)

---

**Poslední aktualizace: 9. března 2026**

Kliknutím na "Přijmout" v aplikaci potvrzujete, že jste tuto zásadu přečetli a rozumíte jí.
