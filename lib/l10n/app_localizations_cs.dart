// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class L10nCs extends L10n {
  L10nCs([String locale = 'cs']) : super(locale);

  @override
  String get commonCancel => 'Zrušit';

  @override
  String get commonSave => 'Uložit';

  @override
  String get commonClose => 'Zavřít';

  @override
  String get commonNote => 'Poznámka';

  @override
  String get commonTapForExplanation => 'Tip: klepni pro vysvětlení';

  @override
  String get navMenu => 'Domů';

  @override
  String get navMeasure => 'Měření';

  @override
  String get navInfo => 'Info';

  @override
  String get homeReady => 'Připraveno k měření';

  @override
  String get homeMeasuring => 'Probíhá měření';

  @override
  String get homeGetReady => 'Připravte se…';

  @override
  String get homeStartButton => 'Zahájit měření';

  @override
  String get homeStopButton => 'Zastavit měření';

  @override
  String get homeDurationLabel => 'Délka měření';

  @override
  String get homeSwitchCamera => 'Přepnout kameru';

  @override
  String get homeChangeCamera => 'Změnit kameru';

  @override
  String get homeTorchOn => 'Zapnout blesk';

  @override
  String get homeTorchOff => 'Vypnout blesk';

  @override
  String get homeQualityLabel => 'Kvalita';

  @override
  String get homeBpmUnit => 'bpm';

  @override
  String homeSecondsSuffix(int seconds) {
    return '$seconds s';
  }

  @override
  String get homeNoReading => '--';

  @override
  String get homeCameraSwitchFailed =>
      'Nepodařilo se přepnout kameru. Zkuste to znovu.';

  @override
  String get homeDurationOutOfRange =>
      'Zadejte dobu trvání mezi 10 a 300 sekundami';

  @override
  String get homeAdjustingCamera => 'Nastavuji kameru…';

  @override
  String get homeCameraSettingsChanged =>
      'Nastavení kamery se během měření změnilo. Záznam není vhodný pro výpočet saturace — zopakujte ho.';

  @override
  String get homeRedChannelClipped =>
      'Červený kanál byl přepálený. Upravte přiložení prstu a měření zopakujte.';

  @override
  String get qualityGood => 'Dobrá';

  @override
  String get qualityMedium => 'Střední';

  @override
  String get qualityBad => 'Špatná';

  @override
  String get qualityNoFinger => 'Žádný prst';

  @override
  String get qualityPoorContact => 'Špatný kontakt';

  @override
  String get ttsCountdown => 'Nahrávání začne za tři, dva, jedna.';

  @override
  String get ttsMeasurementEnd => 'Měření ukončeno.';

  @override
  String get ttsSignalGood => 'Signál je dobrý.';

  @override
  String get ttsSignalWorse => 'Signál je horší, nehýbejte se.';

  @override
  String get ttsPoorContact => 'Špatný kontakt s kamerou.';

  @override
  String get ttsPlaceFinger => 'Přiložte prst na kameru.';

  @override
  String get ttsTestVoice => 'Testovací hlas funguje.';

  @override
  String get introTitle => 'Domovská stránka';

  @override
  String get introStartMeasurement => 'Začít měření';

  @override
  String get introRecords => 'Záznamy';

  @override
  String get summaryTitle => 'Výsledek';

  @override
  String get summaryAverageHeartRate => 'Průměrná tepová frekvence:';

  @override
  String get summaryNotesHint => 'Zadejte své poznámky k měření...';

  @override
  String get summaryTabSignal => 'Signál';

  @override
  String get summaryTabRecovery => 'Zotavení';

  @override
  String get summarySaveToHealth => 'Uložit (zapíše do Apple Health)';

  @override
  String get summaryInNorm => 'Jste v normě';

  @override
  String get summaryRest => 'Odpočívejte';

  @override
  String get summaryContinueActivity => 'Pokračujte v běžné aktivitě';

  @override
  String get summaryShortRest => 'Doporučujeme krátký odpočinek';

  @override
  String get summarySpo2Pending =>
      'Poznámka: Hodnota SpO2 se právě připravuje a nemusí být okamžitě aktuální.';

  @override
  String get summaryInvalidHeartRate =>
      'Neplatná tepová frekvence (≤ 0). Záznam nebyl uložen.';

  @override
  String get summarySavedToHealth => 'Úspěšně uloženo do Apple Health';

  @override
  String get summaryHealthSaveError => 'Chyba při ukládání do Apple Health';

  @override
  String get metricsHrvAnalysis => 'HRV Analýza';

  @override
  String get metricsAverageRr => 'Průměrný RR';

  @override
  String get metricsRespiratoryRate => 'Dechová frekvence';

  @override
  String metricsBreathsPerMinute(String value) {
    return '$value dechů/min';
  }

  @override
  String get metricsHeartRateRecovery => 'Zotavení srdeční frekvence';

  @override
  String get metricsHeartRate => 'Tepová frekvence';

  @override
  String get metricsRecoveryIntro =>
      'Měří pokles tepové frekvence po zátěži. Vyšší pokles za 60–120 s obvykle značí lepší kardiovaskulární kondici a rychlejší zotavení.';

  @override
  String get tipRmssd =>
      'Root Mean Square of Successive Differences – citlivé na krátkodobou, parasympatickou aktivitu. Vyšší hodnoty obvykle znamenají lepší regeneraci a nižší stres.';

  @override
  String get tipSdnn =>
      'Standardní odchylka NN intervalů – celková variabilita srdeční frekvence za celé měření. Odráží kombinaci krátkodobých i dlouhodobých vlivů.';

  @override
  String get tipPnn50 =>
      'Podíl po sobě jdoucích NN intervalů, které se liší o více než 50 ms. Vyšší procento obvykle ukazuje na silnější parasympatickou aktivitu.';

  @override
  String get tipMeanRr =>
      'Průměrná délka NN (RR) intervalu v milisekundách. Nepřímo souvisí s klidovou tepovou frekvencí (delší RR = nižší BPM).';

  @override
  String get tipSd1 =>
      'SD1 (Poincaré) – krátkodobá HRV (beat-to-beat variabilita). Blízce souvisí s RMSSD a parasympatikem.';

  @override
  String get tipSd2 =>
      'SD2 (Poincaré) – dlouhodobá HRV. Zachycuje pomalejší kolísání a trend variability.';

  @override
  String get tipSd2Sd1Ratio =>
      'Poměr dlouhodobé/krátkodobé variability. Vyšší poměr může ukazovat na převahu dlouhodobých oscilací nebo zvýšený stres.';

  @override
  String get tipLf =>
      'Low Frequency složka (0.04–0.15 Hz) – směs sympatické i parasympatické aktivity. Uvádíme jako procento z (LF+HF).';

  @override
  String get tipHf =>
      'High Frequency složka (0.15–0.40 Hz) – převážně parasympatická aktivita (dýchací sinusová arytmie). Uvádíme jako procento z (LF+HF).';

  @override
  String get tipLfHfRatio =>
      'Poměr LF/HF – orientační ukazatel rovnováhy sympatikus/parasympatikus. Interpretace musí brát v úvahu kontext a délku záznamu.';

  @override
  String get tipRespiratoryRate =>
      'Dechová frekvence (dechů/min). Odvozeno ze změn amplitudy PPG, typicky 6–20 dechů/min v klidu.';

  @override
  String get tipBaevsky =>
      'Baevského index – orientační míra stresové zátěže. Vyšší hodnoty mohou ukazovat na vyšší napětí, interpretuj s ohledem na podmínky měření.';

  @override
  String get tipGenericHrv =>
      'Metrika HRV. Hodnoť v kontextu délky záznamu, artefaktů a podmínek měření.';

  @override
  String get tipHr0 =>
      'Průměrná tepová frekvence v prvních 10 sekundách zotavení. Slouží jako výchozí hodnota pro porovnání poklesu.';

  @override
  String get tipHr60 =>
      'Tepová frekvence kolem 60. sekundy po ukončení zátěže. Porovnává se s počáteční HR pro HRR60.';

  @override
  String get tipHrr60 =>
      'Heart Rate Recovery za 60 s: rozdíl HR mezi 0–10 s a 50–60 s. Vyšší = rychlejší zotavení.';

  @override
  String get tipHrSlope =>
      'Lineární sklon poklesu HR v prvních 60 s, vyjádřený v bpm/min. Více záporný = rychlejší pokles.';

  @override
  String get tipHr120 =>
      'Tepová frekvence kolem 120. sekundy. Vhodné pro delší zotavení a výpočet HRR120.';

  @override
  String get tipHrr120 =>
      'Heart Rate Recovery za 120 s: rozdíl HR mezi 0–10 s a 110–120 s. Vyšší = lepší kondice.';

  @override
  String get tipHrTau =>
      'Odhad časové konstanty exponenciálního poklesu HR k bazální hodnotě (nižší znamená rychlejší zotavení).';

  @override
  String get recordsTitle => 'Historie měření';

  @override
  String get recordsSearchHint => 'Hledat poznámku, datum, čas, BPM';

  @override
  String get recordsFilterAll => 'Vše';

  @override
  String get recordsSelectMultiple => 'Výběr více záznamů';

  @override
  String get recordsSort => 'Třídit';

  @override
  String get recordsSortDateNewest => 'Datum: nejnovější';

  @override
  String get recordsSortDateOldest => 'Datum: nejstarší';

  @override
  String get recordsSortBpmHighest => 'Tep: nejvyšší';

  @override
  String get recordsSortBpmLowest => 'Tep: nejnižší';

  @override
  String get recordsEmpty => 'Nebyly nalezeny žádné záznamy.';

  @override
  String recordsDeleteSelected(int count) {
    return 'Smazat vybrané ($count)';
  }

  @override
  String get recordsConfirmDeleteTitle => 'Potvrdit smazání';

  @override
  String get recordsConfirmDeleteBody => 'Opravdu chcete tento záznam smazat?';

  @override
  String get recordsDeleted => 'Záznam smazán';

  @override
  String recordsDeletedCount(int count) {
    return 'Smazáno $count záznamů';
  }

  @override
  String get recordsLongTermTrends => 'Dlouhodobé trendy';

  @override
  String recordsTrendSummary(int total, String mean) {
    return '$total měření • průměr $mean bpm';
  }

  @override
  String get recordsDownloadPdf => 'Stáhnout PDF';

  @override
  String get recordsExportTxt => 'Export TXT';

  @override
  String get settingsTitle => 'Nastavení';

  @override
  String get settingsAccessibilitySection => 'Dostupnost a čitelnost';

  @override
  String get settingsDisplayMode => 'Režim zobrazení';

  @override
  String get settingsDisplayModeHint =>
      'Zvolte: Pacient (zjednodušené) nebo Lékař (detailní)';

  @override
  String get settingsPatientMode => 'Režim pacienta';

  @override
  String get settingsPatientModeHint => 'Jednoduché zobrazení – semafor';

  @override
  String get settingsDoctorMode => 'Režim lékaře';

  @override
  String get settingsDoctorModeHint => 'Detailní metriky HRV, zotavení';

  @override
  String get settingsSeniorMode => 'Senior mód';

  @override
  String get settingsSeniorModeHint => 'Větší prvky a lepší čitelnost';

  @override
  String get settingsHighContrast => 'Vysoký kontrast';

  @override
  String get settingsHighContrastHint => 'Černý text na bílém pozadí';

  @override
  String get settingsAppleHealth => 'Propojení s Apple Health';

  @override
  String get settingsAppleHealthBody =>
      'Po dokončení měření můžete tepovou frekvenci uložit do aplikace Zdraví. U měření od 60 sekund s dobrým signálem se uloží i variabilita srdečního rytmu (HRV, SDNN). Žádná další data se neodesílají ani nečtou.';

  @override
  String get settingsManagePermissions => 'Spravovat oprávnění';

  @override
  String get settingsManagePermissionsHint =>
      'Otevřete Nastavení → Soukromí → Zdraví → Tepovka';

  @override
  String get settingsGeneralSection => 'Obecné';

  @override
  String get settingsTestVoiceHint => 'Přehraje krátkou hlášku pro ověření';

  @override
  String get settingsPlayingTestVoice => 'Přehrávám testovací hlášku...';

  @override
  String get settingsHaptics => 'Haptická odezva';

  @override
  String get settingsHapticsHint => 'Vibrace při akcích v aplikaci';

  @override
  String get settingsResearchSection => 'Výzkumný režim';

  @override
  String get settingsResearchMode => 'Režim pro výzkum';

  @override
  String get settingsResearchModeHint =>
      'Před měřením se vyplní údaje k záznamu a export je podrobnější';

  @override
  String get settingsResearchFields => 'Údaje vyplňované před měřením';

  @override
  String get settingsExportFormat => 'Formát exportu';

  @override
  String get settingsPreMeasurementFields => 'Údaje před měřením';

  @override
  String get settingsPreMeasurementFieldsHint =>
      'Každý řádek je jedno pole formuláře.';

  @override
  String get settingsComingSoon => 'Připravujeme';

  @override
  String get settingsLocalCount => 'Počet měření uložených lokálně';

  @override
  String get settingsLastMeasurement => 'Poslední měření';

  @override
  String get settingsOpenLog => 'Otevřít log';

  @override
  String get settingsShareLog => 'Sdílet log';

  @override
  String get settingsLogCleared => 'Log vymazán';

  @override
  String settingsLogOpenError(String error) {
    return 'Chyba při otevírání logu: $error';
  }

  @override
  String settingsLogShareError(String error) {
    return 'Chyba při sdílení logu: $error';
  }

  @override
  String settingsLogDeleteError(String error) {
    return 'Chyba při mazání logu: $error';
  }

  @override
  String get settingsLanguage => 'Jazyk';

  @override
  String get settingsLanguageSystem => 'Podle systému';

  @override
  String get settingsLanguageCzech => 'Čeština';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get exportFormatTxt => 'TXT (původní formát)';

  @override
  String get exportFormatJson => 'JSON (vše v jednom objektu)';

  @override
  String get loginMyQr => 'Můj QR kód';

  @override
  String get loginQrHint =>
      'Lékař na svém mobilu otevře kameru nebo QR skener a naskenuje tento kód. Pokud skener není dostupný, může ručně zadat vaše ID.';

  @override
  String get loginFullscreen => 'Na celé obrazovce';

  @override
  String get loginIdCopied => 'ID zkopírováno do schránky';

  @override
  String get loginCopyId => 'Kopírovat ID';

  @override
  String get loginShare => 'Sdílet';

  @override
  String get loginLocalProfile => 'Lokální profil';

  @override
  String get loginName => 'Jméno';

  @override
  String get loginNameHint => 'Zadejte vaše jméno';

  @override
  String get loginPin => 'PIN (volitelné)';

  @override
  String get loginPinHint => '4–6 číslic pro zámek profilu';

  @override
  String get loginSignInFirst => 'Nejprve se prosím přihlašte.';

  @override
  String get consentTitle => 'Souhlas se zpracováním dat';

  @override
  String get consentBody =>
      'Provoz aplikace vyžaduje zpracování obrazových snímků z fotoaparátu k výpočtu srdeční frekvence a souvisejících metrik.\n\nAplikace neodesílá vaše snímky na servery a data ukládá pouze lokálně, pokud s tím výslovně souhlasíte.\n\nDůležité: tato aplikace není lékařský přístroj. Hodnoty jako SpO2 jsou orientační a nemusí být ihned dostupné nebo přesné. Nepoužívejte aplikaci jako náhradu lékařského zařízení — při obavách vyhledejte odbornou lékařskou pomoc.';

  @override
  String get consentWhatItDoesTitle => 'Co aplikace dělá:';

  @override
  String get consentBullet1 =>
      '- Zpracování snímků z fotoaparátu pro PPG analýzu.';

  @override
  String get consentBullet2 => '- Ukládání souhrnných výsledků lokálně.';

  @override
  String get consentBullet3 =>
      '- Neodesílání surových obrazových dat bez souhlasu.';

  @override
  String get consentQuestion =>
      'Souhlasíte se zpracováním dat potřebných pro měření?';

  @override
  String get consentAgree => 'Souhlasím';

  @override
  String get researchDialogTitle => 'Údaje k měření';

  @override
  String researchDialogAutoStamp(String stamp) {
    return 'Datum a čas se doplní automaticky ($stamp).';
  }

  @override
  String get researchDialogStart => 'Začít měření';

  @override
  String get pdfTitle => 'Měření tepové frekvence a HRV';

  @override
  String pdfTime(String time) {
    return 'Čas: $time';
  }

  @override
  String pdfAverageBpm(String bpm) {
    return 'Průměrný BPM: $bpm';
  }

  @override
  String pdfDuration(String duration) {
    return 'Délka měření: $duration sekund';
  }

  @override
  String pdfNotes(String notes) {
    return 'Poznámky: $notes';
  }

  @override
  String get pdfSignalChart => 'Graf signálu:';

  @override
  String get aboutHowPpgTitle => 'Jak funguje PPG měření?';

  @override
  String get aboutHowPpgBody =>
      'Fotopletysmografie (PPG) měří změny objemu krve v cévách pod pokožkou. S každým tepem projde prstem víc krve, ta pohltí víc světla a snímek z kamery na okamžik potemní. Aplikace z každého snímku spočítá průměrný jas v ploše pod prstem a z toho, jak se v čase mění, odečte tep.';

  @override
  String get aboutFingerTitle => 'Jak správně přiložit prst?';

  @override
  String get aboutFingerBody =>
      '1. Ujistěte se, že máte čistý prst bez nečistot.\n2. Jemně přiložte prst na kameru tak, aby ji zcela zakrýval.\n3. Nepřikládejte prst příliš silně, aby nedošlo ke zkreslení signálu.\n4. Svítilna se zapne sama během odpočtu — nechte prst v klidu, než měření začne.';

  @override
  String get aboutBeforeStartTitle => 'Co se děje před začátkem měření';

  @override
  String get aboutBeforeStartBody =>
      'Během odpočtu 3–2–1 aplikace rozsvítí svítilnu, počká, až se ustálí automatika kamery, a zamkne expozici i zaostření. Bez zámku by automatika kompenzovala právě ty změny jasu, které tep tvoří. Teprve pak začne samotný záznam, aby jeho začátek nebyl zatížený rozsvěcením a rozjezdem filtrů.';

  @override
  String get aboutProcessingTitle => 'Jak se signál zpracovává';

  @override
  String get aboutProcessingBody =>
      '1. Z každého snímku se vezme průměr zeleného kanálu v ploše pod prstem; když je zelená příliš tmavá, použije se červený kanál.\n2. Adaptivní filtr s údaji z akcelerometru potlačí vliv pohybu ruky.\n3. Následuje mediánový filtr proti ojedinělým výkyvům, odečtení pomalu se měnící složky (dýchání, prokrvení) a jemné vyhlazení.\n4. Kamera nedodává snímky přesně pravidelně, proto se pracuje se skutečnou snímkovací frekvencí měřenou z časových značek snímků — v praxi bývá kolem 24 snímků za sekundu, ne 30.';

  @override
  String get aboutHeartRateTitle => 'Jak se vypočítá tepová frekvence?';

  @override
  String get aboutHeartRateBody =>
      'Během měření se tep odhaduje ze spektra signálu a z autokorelace v posledních sekundách; když je odhad málo spolehlivý, aplikace raději nic nezobrazí, než aby ukázala nepodložené číslo.\nVe výsledku a v historii se pak tep počítá z detekovaných vrcholů: najdou se špičky odpovídající jednotlivým tepům, změří se intervaly mezi nimi a tep vyjde jako 60 ÷ průměrný interval v sekundách. Poloha každé špičky se dopočítává i mezi snímky, aby intervaly nebyly omezené krokem snímání.';

  @override
  String get aboutGreenChannelTitle => 'Proč zelený kanál?';

  @override
  String get aboutGreenChannelBody =>
      'Zelené světlo pohlcuje hemoglobin nejsilněji, takže se v něm změny prokrvení projeví nejvýrazněji. Červený kanál se přes prst přesvítí snáz, a slouží proto jako záloha, když je zelená příliš tmavá.';

  @override
  String get aboutAccuracyTitle => 'Jak přesné to je';

  @override
  String get aboutAccuracyBody =>
      'Zpracování jsme v srpnu 2026 ověřovali proti EKG holteru Bittium Faros 180 a pulznímu oxymetru na měřeních s 13 účastníky. Na uložených záznamech přepočtených stejným detektorem, jaký používá aplikace, se tep shodoval s EKG s průměrnou odchylkou pod 2 bpm — srovnatelně s tím, jak si odpovídají oba referenční přístroje navzájem.\nPřesnost ale závisí na kvalitě signálu: při pohybu, slabém prokrvení nebo špatně přiloženém prstu je odhad výrazně horší. U každého měření proto najdete i hodnocení kvality — měření označené jako špatné neberte vážně.\nParametry variability (SDNN, RMSSD) berte jen orientačně; na ně je snímkovací frekvence kamery hrubá. Aplikace není zdravotnický prostředek a neslouží k diagnostice.';

  @override
  String get infoTitle => 'O nás';

  @override
  String get infoIntro =>
      'Ahoj!\nS radostí Vám představujeme naši aplikaci s názvem Tepovka, která vzniká v rámci soutěže organizované Fakultou elektrotechniky a komunikačních technologií na Vysokém učení technickém v Brně. Tento projekt je výsledkem naší spolupráce v týmu, který spojuje nadšení pro biomedicínské inženýrství a snahu přinášet inovativní řešení do každodenního života.\n\nNaším cílem je vytvořit aplikaci, která umožní měření srdeční frekvence jednoduše pomocí smartphonu s kamerou a bleskem. Tato funkce je pouhým začátkem. V budoucnu plánujeme rozšířit aplikaci o pokročilejší funkce, jako je měření saturace kyslíku v krvi (oximetrie), detekce srdečních arytmií nebo dokonce měření krevního tlaku – pokud výzkumy ukáží, že je tato technologie proveditelná.\n\nAplikace vzniká za podpory VUT, které poskytuje nejen technologické zázemí, ale také odborné vedení, díky kterému můžeme naše nápady realizovat.';

  @override
  String get infoTeamTitle => 'Náš tým';

  @override
  String get infoTeamBody =>
      'Jsme studenti biomedicínského inženýrství a spojuje nás vášeň pro vývoj zdravotnických technologií. Náš tým tvoří:\n- Štěpán Zelníček\n- David Vavroušek\n- Jakub Kovář\n- Jakub Kaša\n\nKaždý z nás přispívá svými specifickými dovednostmi – od programování, přes design aplikací až po analýzu biologických dat. Naším hlavním cílem je vytvořit uživatelsky přívětivou a zároveň technologicky pokročilou aplikaci, která bude sloužit široké veřejnosti.';

  @override
  String get infoFollowTitle => 'Sledujte a podpořte nás';

  @override
  String get infoFollowBody =>
      'Jsme nadšeni z možnosti sdílet naši cestu s Vámi a budeme rádi, když nás podpoříte a budete sledovat naše pokroky. Těšíme se na společné objevování nových možností v oblasti digitálního zdravotnictví!';

  @override
  String get infoSupportedBy => 'Za podpory VUT. Děkujeme';

  @override
  String get commonDelete => 'Smazat';

  @override
  String get metricsStressIndex => 'Index stresu';

  @override
  String get settingsAppLanguage => 'Jazyk aplikace';

  @override
  String get settingsTextSize => 'Velikost textu';

  @override
  String get settingsTestVoice => 'Otestovat hlas (TTS)';

  @override
  String get settingsLogSection => 'Logy a diagnostika';

  @override
  String get settingsLogNotFound => 'Log soubor nenalezen';

  @override
  String get settingsClearLog => 'Vymazat log';

  @override
  String get consentDecline => 'Nechci';

  @override
  String get infoWeb => 'Web';

  @override
  String recordsBpmRange(String min, String max) {
    return 'Rozsah BPM: $min–$max';
  }

  @override
  String get pdfHrvMetrics => 'HRV Metriky:';

  @override
  String pdfDate(String date) {
    return 'Datum: $date';
  }

  @override
  String get summarySaveFailed => 'Záznam se nepodařilo uložit.';

  @override
  String a11yHeartRateValue(String bpm) {
    return 'Tepová frekvence $bpm úderů za minutu';
  }

  @override
  String get a11yHeartRateUnknown => 'Tepová frekvence zatím není k dispozici';

  @override
  String a11ySignalQuality(String quality) {
    return 'Kvalita signálu: $quality';
  }

  @override
  String get a11yLiveChart => 'Živý graf pulzní vlny';

  @override
  String get a11yOpenSettings => 'Otevřít nastavení';

  @override
  String get a11yOpenWebsite => 'Otevřít web';

  @override
  String get guideTitle => 'Jak správně měřit';

  @override
  String get guideSkip => 'Přeskočit';

  @override
  String get guideNext => 'Další';

  @override
  String get guideDone => 'Rozumím, měřit';

  @override
  String guideStepOf(int step, int total) {
    return 'Krok $step z $total';
  }

  @override
  String get guideRestTitle => 'Najděte si klid';

  @override
  String get guideRestBody =>
      'Měřte vsedě po minutě odpočinku. Během měření nemluvte a dýchejte normálně.';

  @override
  String get guideCoverTitle => 'Zakryjte fotoaparát i blesk';

  @override
  String get guideCoverBody =>
      'Bříškem ukazováčku zakryjte zadní fotoaparát i blesk vedle něj. Blesk se rozsvítí sám.';

  @override
  String get guidePreviewTitle => 'Náhled musí být celý červený';

  @override
  String get guidePreviewBody =>
      'Když prst sedí správně, kruh s náhledem je rovnoměrně červený a po chvíli mu zezelená okraj. Pokud ne, posuňte prst. U telefonu s více fotoaparáty můžete kameru přepnout.';

  @override
  String get guideStillTitle => 'Lehce a v klidu';

  @override
  String get guideStillBody =>
      'Prst jen lehce položte, silný tlak vytlačí krev z bříška a signál zeslábne. Ruku opřete o stůl a nehýbejte se. Studené prsty si nejdřív zahřejte.';

  @override
  String get guideResultTitle => 'Měření a výsledek';

  @override
  String get guideResultBody =>
      'Po stisku tlačítka běží odpočet 3–2–1 a pak měření. Na tep stačí 30 sekund, pro variabilitu tepu (HRV) měřte aspoň 60 sekund. Když je kvalita signálu špatná, měření zopakujte.';

  @override
  String get guideDisclaimer => 'Tepovka není zdravotnický prostředek.';

  @override
  String get homeHelp => 'Jak měřit';

  @override
  String get hintPlaceFinger => 'Přiložte prst na zadní fotoaparát i blesk.';

  @override
  String get hintPoorContact =>
      'Prst kryje čočku jen zčásti. Posuňte ho, ať je náhled celý červený.';

  @override
  String get hintWeakSignal =>
      'Signál je slabý. Netlačte tolik a držte ruku v klidu.';

  @override
  String get hintGood => 'Výborně, takhle vydržte.';

  @override
  String get aboutPageTitle => 'Jak to funguje';

  @override
  String get aboutGuideSubtitle => 'Pět kroků ke spolehlivému měření';

  @override
  String get introAboutApp => 'O aplikaci';

  @override
  String get infoProjectTitle => 'O projektu Tepovka';

  @override
  String get howSectionPrinciple => 'Jak měření funguje';

  @override
  String get howStepLight => 'Světlo prosvítí prst';

  @override
  String get howStepCamera => 'Kamera zachytí změny barvy';

  @override
  String get howStepPulse => 'Z rytmu se spočítá tep';

  @override
  String get howSectionFinger => 'Správné přiložení prstu';

  @override
  String get howTipCover => 'Zakryjte kameru i blesk';

  @override
  String get howTipLight => 'Přiložte lehce, netlačte';

  @override
  String get howTipStill => 'Vydržte v klidu';

  @override
  String get howAccuracyLabel => 'Odchylka od EKG';

  @override
  String get howAccuracyValue => '< 2 bpm';

  @override
  String get howAccuracyNote =>
      'Ověřeno na 13 účastnících proti EKG holteru Bittium Faros 180. Aplikace není zdravotnický prostředek.';

  @override
  String get howSectionDetails => 'Pro zvídavé';

  @override
  String get infoProjectSummary =>
      'Měření tepu jen telefonem s kamerou a bleskem. Aplikace vzniká v rámci soutěže FEKT VUT v Brně.';

  @override
  String get infoReadMore => 'Číst víc';

  @override
  String get infoReadLess => 'Méně';

  @override
  String infoVersion(String version) {
    return 'Verze $version';
  }

  @override
  String get infoTeamIntro => 'Jsme studenti biomedicínského inženýrství.';

  @override
  String get homeMeasureTitle => 'Změřit tep';

  @override
  String get homeMeasureSubtitle => 'Přiložte prst na kameru a blesk';

  @override
  String get homeLastMeasurement => 'Poslední měření';

  @override
  String homeToday(String time) {
    return 'Dnes $time';
  }

  @override
  String homeYesterday(String time) {
    return 'Včera $time';
  }

  @override
  String homeTrendCaption(int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Posledních $count měření · průměr $avg bpm',
      few: 'Poslední $count měření · průměr $avg bpm',
    );
    return '$_temp0';
  }

  @override
  String get homeNoMeasurementsTitle => 'Zatím žádné měření';

  @override
  String get homeNoMeasurementsBody =>
      'Průvodce vám ukáže, jak správně přiložit prst.';

  @override
  String get homeOpenGuide => 'Otevřít průvodce';

  @override
  String get homeTileHistory => 'Historie';

  @override
  String get homeTileHowItWorks => 'Jak to funguje';

  @override
  String get homeTileAbout => 'O aplikaci';

  @override
  String get homeSectionMore => 'Další';

  @override
  String get homeTileHistoryHint => 'Všechna uložená měření';

  @override
  String get homeTileHowItWorksHint => 'Princip a tipy pro přesné měření';

  @override
  String get homeTileAboutHint => 'Projekt, tým a kontakty';

  @override
  String get commonDone => 'Hotovo';

  @override
  String get measureTitle => 'Měření';

  @override
  String measureRunning(int seconds) {
    return 'Měří se · zbývá $seconds s';
  }

  @override
  String get measureSignalGood => 'Dobrý signál';

  @override
  String get measureSignalWeak => 'Slabý signál';

  @override
  String get measureSignalNoFinger => 'Přiložte prst';

  @override
  String get measurePulseWave => 'Pulzní křivka';

  @override
  String get measureDurationOther => 'Jiná';

  @override
  String get measureDurationHrvShort => 'Pro analýzu HRV zvolte aspoň 60 s';

  @override
  String get measureDurationHrvOk => 'Dost dlouhé i pro analýzu HRV';

  @override
  String get recordsToday => 'Dnes';

  @override
  String get recordsYesterday => 'Včera';

  @override
  String get recordsAverageLabel => 'Průměr';

  @override
  String get recordsRangeLabel => 'Rozsah';

  @override
  String recordsMeasurementsCount(int count) {
    return '$count měření';
  }

  @override
  String get recordsHrvTrends => 'Trendy HRV';

  @override
  String get recordsFilters => 'Filtry';

  @override
  String get recordsSignalQuality => 'Kvalita signálu';

  @override
  String get recordsDateRange => 'Období';

  @override
  String get recordsAnyDate => 'Kdykoli';

  @override
  String get recordsClearFilters => 'Zrušit filtry';

  @override
  String get recordsNoMatch => 'Filtrům neodpovídá žádné měření.';

  @override
  String recordsSelectedCount(int count) {
    return 'Vybráno: $count';
  }

  @override
  String get recordsNoWaveform => 'Záznam neobsahuje pulzní křivku.';

  @override
  String get recordsSearch => 'Hledat';

  @override
  String get recordsMore => 'Další možnosti';

  @override
  String recordsConfirmDeleteSelectedBody(int count) {
    return 'Opravdu chcete smazat vybrané záznamy ($count)?';
  }

  @override
  String get settingsReminderSection => 'Připomínka';

  @override
  String get settingsReminder => 'Denní připomínka měření';

  @override
  String get settingsReminderHint =>
      'Ve zvolený čas připomene měření. Když už jste ten den měřili, nepřijde.';

  @override
  String get settingsReminderTime => 'Čas připomínky';

  @override
  String get settingsReminderDenied =>
      'Oznámení jsou pro Tepovku vypnutá. Povolte je v Nastavení iOS.';

  @override
  String get settingsReminderOpenSettings => 'Otevřít Nastavení';

  @override
  String get reminderTitle => 'Čas na měření';

  @override
  String get reminderBody => 'Změřte si tep, stačí půl minuty.';

  @override
  String get metricHr0 => 'HR (0–10 s)';

  @override
  String get metricHr60 => 'HR v 60. s';

  @override
  String get metricHrr60 => 'Pokles 0–60 s';

  @override
  String get metricSlope60 => 'Sklon (0–60 s)';

  @override
  String get metricHr120 => 'HR v 120. s';

  @override
  String get metricHrr120 => 'Pokles 0–120 s';

  @override
  String get metricTau => 'Tau (odhad)';

  @override
  String get settingsProfileUnnamed => 'Uživatel';

  @override
  String get summaryDiscardTitle => 'Zahodit měření?';

  @override
  String get summaryDiscardBody => 'Výsledek se neuloží do historie.';

  @override
  String get summaryDiscard => 'Zahodit';

  @override
  String get summaryKeep => 'Ponechat';

  @override
  String get summaryWeakSignal =>
      'Signál byl slabý, výsledek nemusí být přesný.';

  @override
  String get summaryMeasureAgain => 'Změřit znovu';

  @override
  String get summarySpo2ComingSoon => 'Funkce SpO2 bude brzy k dispozici.';

  @override
  String get summarySpo2Disclaimer =>
      'SpO2 je orientační hodnota a nenahrazuje lékařský přístroj. Při hodnotách pod 95 % vyhledejte lékaře.';

  @override
  String get settingsSectionMeasurement => 'Měření';

  @override
  String get settingsSectionDisplay => 'Zobrazení';

  @override
  String get settingsSectionSound => 'Zvuk a vibrace';

  @override
  String get settingsSectionData => 'Data a soukromí';

  @override
  String get settingsSectionProfile => 'Profil';

  @override
  String get settingsSectionSupport => 'Podpora';

  @override
  String get settingsPatientModeShort => 'Pacient';

  @override
  String get settingsDoctorModeShort => 'Lékař';

  @override
  String get settingsVoiceGuidance => 'Hlasové pokyny';

  @override
  String get settingsVoiceSample => 'Přehrát ukázku';

  @override
  String get settingsHealthShort => 'Apple Zdraví';

  @override
  String get settingsHealthShortHint => 'Ukládá tep a HRV';

  @override
  String get settingsDataLocal => 'Data zůstávají v telefonu';

  @override
  String get settingsDataLocalHint => 'Tepovka nic neodesílá na server';

  @override
  String get settingsDiagnostics => 'Diagnostika a logy';

  @override
  String get settingsDiagnosticsHint => 'Pro řešení potíží s aplikací';

  @override
  String get settingsMyProfile => 'Můj profil';

  @override
  String get settingsMyProfileHint => 'Jméno a QR kód pro lékaře';

  @override
  String settingsMyProfileSummary(String name, String id) {
    return '$name · ID $id';
  }

  @override
  String get profileCreate => 'Vytvořit profil';

  @override
  String get profileLocalHint =>
      'Profil zůstává jen v tomto telefonu. Lékař podle QR kódu rychle najde vaše záznamy.';

  @override
  String get profileRemove => 'Odebrat profil';

  @override
  String get profileRemoveTitle => 'Odebrat profil?';

  @override
  String get profileRemoveBody =>
      'Jméno a QR kód zmizí z aplikace. Měření v historii zůstanou.';

  @override
  String get profileRemoveConfirm => 'Odebrat';

  @override
  String get profileRemoved => 'Profil odebrán';

  @override
  String get settingsClearLogTitle => 'Vymazat log?';

  @override
  String get settingsClearLogBody =>
      'Záznam událostí pro podporu se smaže. Měření zůstanou.';

  @override
  String get settingsClearLogConfirm => 'Vymazat';

  @override
  String get recordsSelectAll => 'Vybrat vše';

  @override
  String get recordsSelectNone => 'Zrušit výběr';

  @override
  String recordsExportSelected(int count) {
    return 'Exportovat ($count)';
  }

  @override
  String recordsExportTitle(int count) {
    return 'Exportovat $count měření';
  }

  @override
  String get recordsExportPdf => 'Zpráva pro lékaře (PDF)';

  @override
  String get recordsExportPdfHint => 'Souhrn, graf a tabulka měření';

  @override
  String get recordsExportTable => 'Tabulka (CSV)';

  @override
  String get recordsExportTableHint => 'Jeden řádek na měření, pro Excel';

  @override
  String get recordsExportRaw => 'Kompletní data';

  @override
  String recordsExportRawHint(String format) {
    return 'Průběh signálu ve formátu $format, soubor na měření';
  }

  @override
  String get recordsExportFailed => 'Export se nepodařil';

  @override
  String get recordsWeeklyTitle => 'Tep po týdnech';

  @override
  String recordsWeeklyLower(int n) {
    return 'o $n méně než týden předtím';
  }

  @override
  String recordsWeeklyHigher(int n) {
    return 'o $n více než týden předtím';
  }

  @override
  String get recordsWeeklySame => 'stejně jako týden předtím';

  @override
  String get recordsWeeklyCaption =>
      'Průměr za týden, posledních 8 týdnů, bez měření se špatným signálem';

  @override
  String get reportTitle => 'Přehled měření tepu';

  @override
  String reportPatient(String name, String id) {
    return 'Pacient: $name · ID $id';
  }

  @override
  String reportPeriod(String period) {
    return 'Období: $period';
  }

  @override
  String reportCreated(String date) {
    return 'Vytvořeno v aplikaci Tepovka $date';
  }

  @override
  String get reportMeasurements => 'Měření';

  @override
  String get reportAverage => 'Průměrný tep';

  @override
  String get reportRange => 'Rozmezí';

  @override
  String get reportSdnn => 'Průměr SDNN';

  @override
  String get reportChartTitle => 'Tep v jednotlivých měřeních';

  @override
  String get reportTableTitle => 'Seznam měření';

  @override
  String get reportColDate => 'Datum';

  @override
  String get reportColTime => 'Čas';

  @override
  String get reportColDuration => 'Délka';

  @override
  String get reportColBpm => 'Tep';

  @override
  String get reportColQuality => 'Signál';

  @override
  String get reportColNote => 'Poznámka';

  @override
  String get reportDisclaimer =>
      'Tepovka měří tep kamerou telefonu (fotopletysmografie). Hodnoty jsou orientační; aplikace není zdravotnický prostředek a neslouží k diagnostice. HRV (SDNN, RMSSD) je uvedena jen u měření od 60 s, která neměla špatný signál.';

  @override
  String reportPage(int page, int pages) {
    return 'Strana $page z $pages';
  }

  @override
  String get summarySavedToHealthWithHrv => 'Tep a HRV uloženy do Apple Zdraví';

  @override
  String get reportQualityUnknown => 'Bez hodnocení';
}
