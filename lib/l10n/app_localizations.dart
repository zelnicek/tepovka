import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L10n
/// returned by `L10n.of(context)`.
///
/// Applications need to include `L10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L10n.localizationsDelegates,
///   supportedLocales: L10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L10n.supportedLocales
/// property.
abstract class L10n {
  L10n(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L10n of(BuildContext context) {
    return Localizations.of<L10n>(context, L10n)!;
  }

  static const LocalizationsDelegate<L10n> delegate = _L10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('en')
  ];

  /// Dialog dismiss button
  ///
  /// In cs, this message translates to:
  /// **'Zrušit'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In cs, this message translates to:
  /// **'Uložit'**
  String get commonSave;

  /// No description provided for @commonClose.
  ///
  /// In cs, this message translates to:
  /// **'Zavřít'**
  String get commonClose;

  /// No description provided for @commonNote.
  ///
  /// In cs, this message translates to:
  /// **'Poznámka'**
  String get commonNote;

  /// Hint on metric cards that open an explanation
  ///
  /// In cs, this message translates to:
  /// **'Tip: klepni pro vysvětlení'**
  String get commonTapForExplanation;

  /// No description provided for @navMenu.
  ///
  /// In cs, this message translates to:
  /// **'MENU'**
  String get navMenu;

  /// No description provided for @navMeasure.
  ///
  /// In cs, this message translates to:
  /// **'MĚŘENÍ'**
  String get navMeasure;

  /// No description provided for @navInfo.
  ///
  /// In cs, this message translates to:
  /// **'INFO'**
  String get navInfo;

  /// App bar title before a measurement starts
  ///
  /// In cs, this message translates to:
  /// **'PŘIPRAVENO K MĚŘENÍ'**
  String get homeReady;

  /// No description provided for @homeMeasuring.
  ///
  /// In cs, this message translates to:
  /// **'PROBÍHÁ MĚŘENÍ...'**
  String get homeMeasuring;

  /// No description provided for @homeGetReady.
  ///
  /// In cs, this message translates to:
  /// **'PŘIPRAVTE SE...'**
  String get homeGetReady;

  /// No description provided for @homeStartButton.
  ///
  /// In cs, this message translates to:
  /// **'ZAHÁJIT MĚŘENÍ'**
  String get homeStartButton;

  /// No description provided for @homeStopButton.
  ///
  /// In cs, this message translates to:
  /// **'ZASTAVIT MĚŘENÍ'**
  String get homeStopButton;

  /// No description provided for @homeDurationLabel.
  ///
  /// In cs, this message translates to:
  /// **'Doba měření (sekundy)'**
  String get homeDurationLabel;

  /// No description provided for @homeSwitchCamera.
  ///
  /// In cs, this message translates to:
  /// **'Přepnout kameru'**
  String get homeSwitchCamera;

  /// No description provided for @homeChangeCamera.
  ///
  /// In cs, this message translates to:
  /// **'Změnit kameru'**
  String get homeChangeCamera;

  /// No description provided for @homeTorchOn.
  ///
  /// In cs, this message translates to:
  /// **'Zapnout blesk'**
  String get homeTorchOn;

  /// No description provided for @homeTorchOff.
  ///
  /// In cs, this message translates to:
  /// **'Vypnout blesk'**
  String get homeTorchOff;

  /// No description provided for @homeQualityLabel.
  ///
  /// In cs, this message translates to:
  /// **'Kvalita'**
  String get homeQualityLabel;

  /// No description provided for @homeBpmUnit.
  ///
  /// In cs, this message translates to:
  /// **'bpm'**
  String get homeBpmUnit;

  /// Countdown remaining, e.g. '24 s'
  ///
  /// In cs, this message translates to:
  /// **'{seconds} s'**
  String homeSecondsSuffix(int seconds);

  /// Shown instead of a BPM number when no reliable estimate exists yet
  ///
  /// In cs, this message translates to:
  /// **'--'**
  String get homeNoReading;

  /// No description provided for @homeCameraSwitchFailed.
  ///
  /// In cs, this message translates to:
  /// **'Nepodařilo se přepnout kameru. Zkuste to znovu.'**
  String get homeCameraSwitchFailed;

  /// No description provided for @homeDurationOutOfRange.
  ///
  /// In cs, this message translates to:
  /// **'Zadejte dobu trvání mezi 10 a 300 sekundami'**
  String get homeDurationOutOfRange;

  /// No description provided for @homeHrvDurationHint.
  ///
  /// In cs, this message translates to:
  /// **'Pro HRV analýzu doporučujeme délku měření alespoň 60 sekund.'**
  String get homeHrvDurationHint;

  /// No description provided for @homeAdjustingCamera.
  ///
  /// In cs, this message translates to:
  /// **'Nastavuji kameru…'**
  String get homeAdjustingCamera;

  /// No description provided for @homeCameraSettingsChanged.
  ///
  /// In cs, this message translates to:
  /// **'Nastavení kamery se během měření změnilo. Záznam není vhodný pro výpočet saturace — zopakujte ho.'**
  String get homeCameraSettingsChanged;

  /// No description provided for @homeRedChannelClipped.
  ///
  /// In cs, this message translates to:
  /// **'Červený kanál byl přepálený. Upravte přiložení prstu a měření zopakujte.'**
  String get homeRedChannelClipped;

  /// Signal quality label. Also used as a filter value in records.
  ///
  /// In cs, this message translates to:
  /// **'Dobrá'**
  String get qualityGood;

  /// No description provided for @qualityMedium.
  ///
  /// In cs, this message translates to:
  /// **'Střední'**
  String get qualityMedium;

  /// No description provided for @qualityBad.
  ///
  /// In cs, this message translates to:
  /// **'Špatná'**
  String get qualityBad;

  /// No description provided for @qualityNoFinger.
  ///
  /// In cs, this message translates to:
  /// **'Žádný prst'**
  String get qualityNoFinger;

  /// No description provided for @qualityPoorContact.
  ///
  /// In cs, this message translates to:
  /// **'Špatný kontakt'**
  String get qualityPoorContact;

  /// No description provided for @ttsCountdown.
  ///
  /// In cs, this message translates to:
  /// **'Nahrávání začne za tři, dva, jedna.'**
  String get ttsCountdown;

  /// No description provided for @ttsMeasurementEnd.
  ///
  /// In cs, this message translates to:
  /// **'Měření ukončeno.'**
  String get ttsMeasurementEnd;

  /// No description provided for @ttsSignalGood.
  ///
  /// In cs, this message translates to:
  /// **'Signál je dobrý.'**
  String get ttsSignalGood;

  /// No description provided for @ttsSignalWorse.
  ///
  /// In cs, this message translates to:
  /// **'Signál je horší, nehýbejte se.'**
  String get ttsSignalWorse;

  /// No description provided for @ttsPoorContact.
  ///
  /// In cs, this message translates to:
  /// **'Špatný kontakt s kamerou.'**
  String get ttsPoorContact;

  /// No description provided for @ttsPlaceFinger.
  ///
  /// In cs, this message translates to:
  /// **'Přiložte prst na kameru.'**
  String get ttsPlaceFinger;

  /// No description provided for @ttsTestVoice.
  ///
  /// In cs, this message translates to:
  /// **'Testovací hlas funguje.'**
  String get ttsTestVoice;

  /// No description provided for @introTitle.
  ///
  /// In cs, this message translates to:
  /// **'DOMOVSKÁ STRÁNKA'**
  String get introTitle;

  /// No description provided for @introStartMeasurement.
  ///
  /// In cs, this message translates to:
  /// **'ZAČÍT MĚŘENÍ'**
  String get introStartMeasurement;

  /// No description provided for @introRecords.
  ///
  /// In cs, this message translates to:
  /// **'ZÁZNAMY'**
  String get introRecords;

  /// No description provided for @summaryTitle.
  ///
  /// In cs, this message translates to:
  /// **'VÝSLEDEK'**
  String get summaryTitle;

  /// No description provided for @summaryAverageHeartRate.
  ///
  /// In cs, this message translates to:
  /// **'Průměrná tepová frekvence:'**
  String get summaryAverageHeartRate;

  /// No description provided for @summaryNotesHint.
  ///
  /// In cs, this message translates to:
  /// **'Zadejte své poznámky k měření...'**
  String get summaryNotesHint;

  /// No description provided for @summaryTabSignal.
  ///
  /// In cs, this message translates to:
  /// **'Signál'**
  String get summaryTabSignal;

  /// No description provided for @summaryTabRecovery.
  ///
  /// In cs, this message translates to:
  /// **'Zotavení'**
  String get summaryTabRecovery;

  /// No description provided for @summarySaveToHealth.
  ///
  /// In cs, this message translates to:
  /// **'Uložit (zapíše do Apple Health)'**
  String get summarySaveToHealth;

  /// No description provided for @summaryInNorm.
  ///
  /// In cs, this message translates to:
  /// **'Jste v normě'**
  String get summaryInNorm;

  /// No description provided for @summaryRest.
  ///
  /// In cs, this message translates to:
  /// **'Odpočívejte'**
  String get summaryRest;

  /// No description provided for @summaryContinueActivity.
  ///
  /// In cs, this message translates to:
  /// **'Pokračujte v běžné aktivitě'**
  String get summaryContinueActivity;

  /// No description provided for @summaryShortRest.
  ///
  /// In cs, this message translates to:
  /// **'Doporučujeme krátký odpočinek'**
  String get summaryShortRest;

  /// No description provided for @summarySpo2Pending.
  ///
  /// In cs, this message translates to:
  /// **'Poznámka: Hodnota SpO2 se právě připravuje a nemusí být okamžitě aktuální.'**
  String get summarySpo2Pending;

  /// No description provided for @summaryInvalidHeartRate.
  ///
  /// In cs, this message translates to:
  /// **'Neplatná tepová frekvence (≤ 0). Záznam nebyl uložen.'**
  String get summaryInvalidHeartRate;

  /// No description provided for @summarySavedToHealth.
  ///
  /// In cs, this message translates to:
  /// **'Úspěšně uloženo do Apple Health'**
  String get summarySavedToHealth;

  /// No description provided for @summaryHealthSaveError.
  ///
  /// In cs, this message translates to:
  /// **'Chyba při ukládání do Apple Health'**
  String get summaryHealthSaveError;

  /// No description provided for @metricsHrvAnalysis.
  ///
  /// In cs, this message translates to:
  /// **'HRV Analýza'**
  String get metricsHrvAnalysis;

  /// No description provided for @metricsAverageRr.
  ///
  /// In cs, this message translates to:
  /// **'Průměrný RR'**
  String get metricsAverageRr;

  /// No description provided for @metricsRespiratoryRate.
  ///
  /// In cs, this message translates to:
  /// **'Dechová frekvence'**
  String get metricsRespiratoryRate;

  /// Respiratory rate with unit
  ///
  /// In cs, this message translates to:
  /// **'{value} dechů/min'**
  String metricsBreathsPerMinute(String value);

  /// No description provided for @metricsHeartRateRecovery.
  ///
  /// In cs, this message translates to:
  /// **'Zotavení srdeční frekvence'**
  String get metricsHeartRateRecovery;

  /// No description provided for @metricsHeartRate.
  ///
  /// In cs, this message translates to:
  /// **'Tepová frekvence'**
  String get metricsHeartRate;

  /// No description provided for @metricsRecoveryIntro.
  ///
  /// In cs, this message translates to:
  /// **'Měří pokles tepové frekvence po zátěži. Vyšší pokles za 60–120 s obvykle značí lepší kardiovaskulární kondici a rychlejší zotavení.'**
  String get metricsRecoveryIntro;

  /// No description provided for @tipRmssd.
  ///
  /// In cs, this message translates to:
  /// **'Root Mean Square of Successive Differences – citlivé na krátkodobou, parasympatickou aktivitu. Vyšší hodnoty obvykle znamenají lepší regeneraci a nižší stres.'**
  String get tipRmssd;

  /// No description provided for @tipSdnn.
  ///
  /// In cs, this message translates to:
  /// **'Standardní odchylka NN intervalů – celková variabilita srdeční frekvence za celé měření. Odráží kombinaci krátkodobých i dlouhodobých vlivů.'**
  String get tipSdnn;

  /// No description provided for @tipPnn50.
  ///
  /// In cs, this message translates to:
  /// **'Podíl po sobě jdoucích NN intervalů, které se liší o více než 50 ms. Vyšší procento obvykle ukazuje na silnější parasympatickou aktivitu.'**
  String get tipPnn50;

  /// No description provided for @tipMeanRr.
  ///
  /// In cs, this message translates to:
  /// **'Průměrná délka NN (RR) intervalu v milisekundách. Nepřímo souvisí s klidovou tepovou frekvencí (delší RR = nižší BPM).'**
  String get tipMeanRr;

  /// No description provided for @tipSd1.
  ///
  /// In cs, this message translates to:
  /// **'SD1 (Poincaré) – krátkodobá HRV (beat-to-beat variabilita). Blízce souvisí s RMSSD a parasympatikem.'**
  String get tipSd1;

  /// No description provided for @tipSd2.
  ///
  /// In cs, this message translates to:
  /// **'SD2 (Poincaré) – dlouhodobá HRV. Zachycuje pomalejší kolísání a trend variability.'**
  String get tipSd2;

  /// No description provided for @tipSd2Sd1Ratio.
  ///
  /// In cs, this message translates to:
  /// **'Poměr dlouhodobé/krátkodobé variability. Vyšší poměr může ukazovat na převahu dlouhodobých oscilací nebo zvýšený stres.'**
  String get tipSd2Sd1Ratio;

  /// No description provided for @tipLf.
  ///
  /// In cs, this message translates to:
  /// **'Low Frequency složka (0.04–0.15 Hz) – směs sympatické i parasympatické aktivity. Uvádíme jako procento z (LF+HF).'**
  String get tipLf;

  /// No description provided for @tipHf.
  ///
  /// In cs, this message translates to:
  /// **'High Frequency složka (0.15–0.40 Hz) – převážně parasympatická aktivita (dýchací sinusová arytmie). Uvádíme jako procento z (LF+HF).'**
  String get tipHf;

  /// No description provided for @tipLfHfRatio.
  ///
  /// In cs, this message translates to:
  /// **'Poměr LF/HF – orientační ukazatel rovnováhy sympatikus/parasympatikus. Interpretace musí brát v úvahu kontext a délku záznamu.'**
  String get tipLfHfRatio;

  /// No description provided for @tipRespiratoryRate.
  ///
  /// In cs, this message translates to:
  /// **'Dechová frekvence (dechů/min). Odvozeno ze změn amplitudy PPG, typicky 6–20 dechů/min v klidu.'**
  String get tipRespiratoryRate;

  /// No description provided for @tipBaevsky.
  ///
  /// In cs, this message translates to:
  /// **'Baevského index – orientační míra stresové zátěže. Vyšší hodnoty mohou ukazovat na vyšší napětí, interpretuj s ohledem na podmínky měření.'**
  String get tipBaevsky;

  /// No description provided for @tipGenericHrv.
  ///
  /// In cs, this message translates to:
  /// **'Metrika HRV. Hodnoť v kontextu délky záznamu, artefaktů a podmínek měření.'**
  String get tipGenericHrv;

  /// No description provided for @tipHr0.
  ///
  /// In cs, this message translates to:
  /// **'Průměrná tepová frekvence v prvních 10 sekundách zotavení. Slouží jako výchozí hodnota pro porovnání poklesu.'**
  String get tipHr0;

  /// No description provided for @tipHr60.
  ///
  /// In cs, this message translates to:
  /// **'Tepová frekvence kolem 60. sekundy po ukončení zátěže. Porovnává se s počáteční HR pro HRR60.'**
  String get tipHr60;

  /// No description provided for @tipHrr60.
  ///
  /// In cs, this message translates to:
  /// **'Heart Rate Recovery za 60 s: rozdíl HR mezi 0–10 s a 50–60 s. Vyšší = rychlejší zotavení.'**
  String get tipHrr60;

  /// No description provided for @tipHrSlope.
  ///
  /// In cs, this message translates to:
  /// **'Lineární sklon poklesu HR v prvních 60 s, vyjádřený v bpm/min. Více záporný = rychlejší pokles.'**
  String get tipHrSlope;

  /// No description provided for @tipHr120.
  ///
  /// In cs, this message translates to:
  /// **'Tepová frekvence kolem 120. sekundy. Vhodné pro delší zotavení a výpočet HRR120.'**
  String get tipHr120;

  /// No description provided for @tipHrr120.
  ///
  /// In cs, this message translates to:
  /// **'Heart Rate Recovery za 120 s: rozdíl HR mezi 0–10 s a 110–120 s. Vyšší = lepší kondice.'**
  String get tipHrr120;

  /// No description provided for @tipHrTau.
  ///
  /// In cs, this message translates to:
  /// **'Odhad časové konstanty exponenciálního poklesu HR k bazální hodnotě (nižší znamená rychlejší zotavení).'**
  String get tipHrTau;

  /// No description provided for @recordsTitle.
  ///
  /// In cs, this message translates to:
  /// **'HISTORIE MĚŘENÍ'**
  String get recordsTitle;

  /// No description provided for @recordsSearchHint.
  ///
  /// In cs, this message translates to:
  /// **'Hledat poznámku, datum, čas, BPM'**
  String get recordsSearchHint;

  /// No description provided for @recordsFilterAll.
  ///
  /// In cs, this message translates to:
  /// **'Vše'**
  String get recordsFilterAll;

  /// No description provided for @recordsSelectMultiple.
  ///
  /// In cs, this message translates to:
  /// **'Výběr více záznamů'**
  String get recordsSelectMultiple;

  /// No description provided for @recordsSort.
  ///
  /// In cs, this message translates to:
  /// **'Třídit'**
  String get recordsSort;

  /// No description provided for @recordsSortDateNewest.
  ///
  /// In cs, this message translates to:
  /// **'Datum: nejnovější'**
  String get recordsSortDateNewest;

  /// No description provided for @recordsSortDateOldest.
  ///
  /// In cs, this message translates to:
  /// **'Datum: nejstarší'**
  String get recordsSortDateOldest;

  /// No description provided for @recordsSortBpmHighest.
  ///
  /// In cs, this message translates to:
  /// **'Tep: nejvyšší'**
  String get recordsSortBpmHighest;

  /// No description provided for @recordsSortBpmLowest.
  ///
  /// In cs, this message translates to:
  /// **'Tep: nejnižší'**
  String get recordsSortBpmLowest;

  /// No description provided for @recordsEmpty.
  ///
  /// In cs, this message translates to:
  /// **'Nebyly nalezeny žádné záznamy.'**
  String get recordsEmpty;

  /// No description provided for @recordsDeleteSelected.
  ///
  /// In cs, this message translates to:
  /// **'Smazat vybrané ({count})'**
  String recordsDeleteSelected(int count);

  /// No description provided for @recordsConfirmDeleteTitle.
  ///
  /// In cs, this message translates to:
  /// **'Potvrdit smazání'**
  String get recordsConfirmDeleteTitle;

  /// No description provided for @recordsConfirmDeleteBody.
  ///
  /// In cs, this message translates to:
  /// **'Opravdu chcete tento záznam smazat?'**
  String get recordsConfirmDeleteBody;

  /// No description provided for @recordsDeleted.
  ///
  /// In cs, this message translates to:
  /// **'Záznam smazán'**
  String get recordsDeleted;

  /// No description provided for @recordsDeletedCount.
  ///
  /// In cs, this message translates to:
  /// **'Smazáno {count} záznamů'**
  String recordsDeletedCount(int count);

  /// No description provided for @recordsLongTermTrends.
  ///
  /// In cs, this message translates to:
  /// **'Dlouhodobé trendy'**
  String get recordsLongTermTrends;

  /// No description provided for @recordsTrendSummary.
  ///
  /// In cs, this message translates to:
  /// **'{total} měření • průměr {mean} bpm'**
  String recordsTrendSummary(int total, String mean);

  /// No description provided for @recordsDownloadPdf.
  ///
  /// In cs, this message translates to:
  /// **'Stáhnout PDF'**
  String get recordsDownloadPdf;

  /// No description provided for @recordsExportTxt.
  ///
  /// In cs, this message translates to:
  /// **'Export TXT'**
  String get recordsExportTxt;

  /// No description provided for @settingsTitle.
  ///
  /// In cs, this message translates to:
  /// **'NASTAVENÍ'**
  String get settingsTitle;

  /// No description provided for @settingsAccessibilitySection.
  ///
  /// In cs, this message translates to:
  /// **'Dostupnost a čitelnost'**
  String get settingsAccessibilitySection;

  /// No description provided for @settingsDisplayMode.
  ///
  /// In cs, this message translates to:
  /// **'Režim zobrazení'**
  String get settingsDisplayMode;

  /// No description provided for @settingsDisplayModeHint.
  ///
  /// In cs, this message translates to:
  /// **'Zvolte: Pacient (zjednodušené) nebo Lékař (detailní)'**
  String get settingsDisplayModeHint;

  /// No description provided for @settingsPatientMode.
  ///
  /// In cs, this message translates to:
  /// **'Režim pacienta'**
  String get settingsPatientMode;

  /// No description provided for @settingsPatientModeHint.
  ///
  /// In cs, this message translates to:
  /// **'Jednoduché zobrazení – semafor'**
  String get settingsPatientModeHint;

  /// No description provided for @settingsDoctorMode.
  ///
  /// In cs, this message translates to:
  /// **'Režim lékaře'**
  String get settingsDoctorMode;

  /// No description provided for @settingsDoctorModeHint.
  ///
  /// In cs, this message translates to:
  /// **'Detailní metriky HRV, zotavení'**
  String get settingsDoctorModeHint;

  /// No description provided for @settingsSeniorMode.
  ///
  /// In cs, this message translates to:
  /// **'Senior mód'**
  String get settingsSeniorMode;

  /// No description provided for @settingsSeniorModeHint.
  ///
  /// In cs, this message translates to:
  /// **'Větší prvky a lepší čitelnost'**
  String get settingsSeniorModeHint;

  /// No description provided for @settingsHighContrast.
  ///
  /// In cs, this message translates to:
  /// **'Vysoký kontrast'**
  String get settingsHighContrast;

  /// No description provided for @settingsHighContrastHint.
  ///
  /// In cs, this message translates to:
  /// **'Černý text na bílém pozadí'**
  String get settingsHighContrastHint;

  /// No description provided for @settingsAppleHealth.
  ///
  /// In cs, this message translates to:
  /// **'Propojení s Apple Health'**
  String get settingsAppleHealth;

  /// No description provided for @settingsAppleHealthBody.
  ///
  /// In cs, this message translates to:
  /// **'Po dokončení měření můžete tepovou frekvenci uložit do aplikace Zdraví. Aplikace zapisuje pouze typ „Tepová frekvence\". Žádná další data se neodesílají ani nečtou.'**
  String get settingsAppleHealthBody;

  /// No description provided for @settingsManagePermissions.
  ///
  /// In cs, this message translates to:
  /// **'Spravovat oprávnění'**
  String get settingsManagePermissions;

  /// No description provided for @settingsManagePermissionsHint.
  ///
  /// In cs, this message translates to:
  /// **'Otevřete Nastavení → Soukromí → Zdraví → Tepovka'**
  String get settingsManagePermissionsHint;

  /// No description provided for @settingsGeneralSection.
  ///
  /// In cs, this message translates to:
  /// **'Obecné'**
  String get settingsGeneralSection;

  /// No description provided for @settingsTestVoiceHint.
  ///
  /// In cs, this message translates to:
  /// **'Přehraje krátkou hlášku pro ověření'**
  String get settingsTestVoiceHint;

  /// No description provided for @settingsPlayingTestVoice.
  ///
  /// In cs, this message translates to:
  /// **'Přehrávám testovací hlášku...'**
  String get settingsPlayingTestVoice;

  /// No description provided for @settingsHaptics.
  ///
  /// In cs, this message translates to:
  /// **'Haptická odezva'**
  String get settingsHaptics;

  /// No description provided for @settingsHapticsHint.
  ///
  /// In cs, this message translates to:
  /// **'Vibrace při akcích v aplikaci'**
  String get settingsHapticsHint;

  /// No description provided for @settingsResearchSection.
  ///
  /// In cs, this message translates to:
  /// **'VÝZKUMNÝ REŽIM'**
  String get settingsResearchSection;

  /// No description provided for @settingsResearchMode.
  ///
  /// In cs, this message translates to:
  /// **'Režim pro výzkum'**
  String get settingsResearchMode;

  /// No description provided for @settingsResearchModeHint.
  ///
  /// In cs, this message translates to:
  /// **'Před měřením se vyplní údaje k záznamu a export je podrobnější'**
  String get settingsResearchModeHint;

  /// No description provided for @settingsResearchFields.
  ///
  /// In cs, this message translates to:
  /// **'Údaje vyplňované před měřením'**
  String get settingsResearchFields;

  /// No description provided for @settingsExportFormat.
  ///
  /// In cs, this message translates to:
  /// **'Formát exportu'**
  String get settingsExportFormat;

  /// No description provided for @settingsPreMeasurementFields.
  ///
  /// In cs, this message translates to:
  /// **'Údaje před měřením'**
  String get settingsPreMeasurementFields;

  /// No description provided for @settingsPreMeasurementFieldsHint.
  ///
  /// In cs, this message translates to:
  /// **'Každý řádek je jedno pole formuláře.'**
  String get settingsPreMeasurementFieldsHint;

  /// No description provided for @settingsLogin.
  ///
  /// In cs, this message translates to:
  /// **'Přihlášení'**
  String get settingsLogin;

  /// No description provided for @settingsNotLoggedIn.
  ///
  /// In cs, this message translates to:
  /// **'Nepřihlášen'**
  String get settingsNotLoggedIn;

  /// No description provided for @settingsLogout.
  ///
  /// In cs, this message translates to:
  /// **'Odhlásit se'**
  String get settingsLogout;

  /// No description provided for @settingsLogoutHint.
  ///
  /// In cs, this message translates to:
  /// **'Odstraní aktivní přihlášení na tomto zařízení'**
  String get settingsLogoutHint;

  /// No description provided for @settingsLoggedOut.
  ///
  /// In cs, this message translates to:
  /// **'Odhlášeno'**
  String get settingsLoggedOut;

  /// No description provided for @settingsMyQrForDoctor.
  ///
  /// In cs, this message translates to:
  /// **'Můj QR kód pro lékaře'**
  String get settingsMyQrForDoctor;

  /// No description provided for @settingsMyQrForDoctorHint.
  ///
  /// In cs, this message translates to:
  /// **'Umožní rychlé vyhledání záznamů'**
  String get settingsMyQrForDoctorHint;

  /// No description provided for @settingsStoreLocally.
  ///
  /// In cs, this message translates to:
  /// **'Ukládat záznamy lokálně'**
  String get settingsStoreLocally;

  /// No description provided for @settingsStoreLocallyHint.
  ///
  /// In cs, this message translates to:
  /// **'Uloží měření do zařízení'**
  String get settingsStoreLocallyHint;

  /// No description provided for @settingsTorchDuring.
  ///
  /// In cs, this message translates to:
  /// **'Blesk během měření'**
  String get settingsTorchDuring;

  /// No description provided for @settingsTorchDuringHint.
  ///
  /// In cs, this message translates to:
  /// **'Zlepšuje průchod světla při PPG'**
  String get settingsTorchDuringHint;

  /// No description provided for @settingsComingSoon.
  ///
  /// In cs, this message translates to:
  /// **'Připravujeme'**
  String get settingsComingSoon;

  /// No description provided for @settingsLocalCount.
  ///
  /// In cs, this message translates to:
  /// **'Počet měření uložených lokálně'**
  String get settingsLocalCount;

  /// No description provided for @settingsLastMeasurement.
  ///
  /// In cs, this message translates to:
  /// **'Poslední měření'**
  String get settingsLastMeasurement;

  /// No description provided for @settingsOpenLog.
  ///
  /// In cs, this message translates to:
  /// **'Otevřít log'**
  String get settingsOpenLog;

  /// No description provided for @settingsShareLog.
  ///
  /// In cs, this message translates to:
  /// **'Sdílet log'**
  String get settingsShareLog;

  /// No description provided for @settingsLogCleared.
  ///
  /// In cs, this message translates to:
  /// **'Log vymazán'**
  String get settingsLogCleared;

  /// No description provided for @settingsLogOpenError.
  ///
  /// In cs, this message translates to:
  /// **'Chyba při otevírání logu: {error}'**
  String settingsLogOpenError(String error);

  /// No description provided for @settingsLogShareError.
  ///
  /// In cs, this message translates to:
  /// **'Chyba při sdílení logu: {error}'**
  String settingsLogShareError(String error);

  /// No description provided for @settingsLogDeleteError.
  ///
  /// In cs, this message translates to:
  /// **'Chyba při mazání logu: {error}'**
  String settingsLogDeleteError(String error);

  /// New setting introduced with localisation
  ///
  /// In cs, this message translates to:
  /// **'Jazyk'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In cs, this message translates to:
  /// **'Podle systému'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageCzech.
  ///
  /// In cs, this message translates to:
  /// **'Čeština'**
  String get settingsLanguageCzech;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In cs, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @exportFormatTxt.
  ///
  /// In cs, this message translates to:
  /// **'TXT (původní formát)'**
  String get exportFormatTxt;

  /// No description provided for @exportFormatJson.
  ///
  /// In cs, this message translates to:
  /// **'JSON (vše v jednom objektu)'**
  String get exportFormatJson;

  /// No description provided for @loginMyQr.
  ///
  /// In cs, this message translates to:
  /// **'Můj QR kód'**
  String get loginMyQr;

  /// No description provided for @loginQrHint.
  ///
  /// In cs, this message translates to:
  /// **'Lékař na svém mobilu otevře kameru nebo QR skener a naskenuje tento kód. Pokud skener není dostupný, může ručně zadat vaše ID.'**
  String get loginQrHint;

  /// No description provided for @loginFullscreen.
  ///
  /// In cs, this message translates to:
  /// **'Na celé obrazovce'**
  String get loginFullscreen;

  /// No description provided for @loginIdCopied.
  ///
  /// In cs, this message translates to:
  /// **'ID zkopírováno do schránky'**
  String get loginIdCopied;

  /// No description provided for @loginCopyId.
  ///
  /// In cs, this message translates to:
  /// **'Kopírovat ID'**
  String get loginCopyId;

  /// No description provided for @loginShare.
  ///
  /// In cs, this message translates to:
  /// **'Sdílet'**
  String get loginShare;

  /// No description provided for @loginLogout.
  ///
  /// In cs, this message translates to:
  /// **'Odhlásit'**
  String get loginLogout;

  /// No description provided for @loginLocalProfile.
  ///
  /// In cs, this message translates to:
  /// **'Lokální profil'**
  String get loginLocalProfile;

  /// No description provided for @loginName.
  ///
  /// In cs, this message translates to:
  /// **'Jméno'**
  String get loginName;

  /// No description provided for @loginNameHint.
  ///
  /// In cs, this message translates to:
  /// **'Zadejte vaše jméno'**
  String get loginNameHint;

  /// No description provided for @loginPin.
  ///
  /// In cs, this message translates to:
  /// **'PIN (volitelné)'**
  String get loginPin;

  /// No description provided for @loginPinHint.
  ///
  /// In cs, this message translates to:
  /// **'4–6 číslic pro zámek profilu'**
  String get loginPinHint;

  /// No description provided for @loginSaveProfile.
  ///
  /// In cs, this message translates to:
  /// **'Uložit profil a zobrazit QR'**
  String get loginSaveProfile;

  /// No description provided for @loginSignInFirst.
  ///
  /// In cs, this message translates to:
  /// **'Nejprve se prosím přihlašte.'**
  String get loginSignInFirst;

  /// No description provided for @consentTitle.
  ///
  /// In cs, this message translates to:
  /// **'Souhlas se zpracováním dat'**
  String get consentTitle;

  /// No description provided for @consentBody.
  ///
  /// In cs, this message translates to:
  /// **'Provoz aplikace vyžaduje zpracování obrazových snímků z fotoaparátu k výpočtu srdeční frekvence a souvisejících metrik.\n\nAplikace neodesílá vaše snímky na servery a data ukládá pouze lokálně, pokud s tím výslovně souhlasíte.\n\nDůležité: tato aplikace není lékařský přístroj. Hodnoty jako SpO2 jsou orientační a nemusí být ihned dostupné nebo přesné. Nepoužívejte aplikaci jako náhradu lékařského zařízení — při obavách vyhledejte odbornou lékařskou pomoc.'**
  String get consentBody;

  /// No description provided for @consentWhatItDoesTitle.
  ///
  /// In cs, this message translates to:
  /// **'Co aplikace dělá:'**
  String get consentWhatItDoesTitle;

  /// No description provided for @consentBullet1.
  ///
  /// In cs, this message translates to:
  /// **'- Zpracování snímků z fotoaparátu pro PPG analýzu.'**
  String get consentBullet1;

  /// No description provided for @consentBullet2.
  ///
  /// In cs, this message translates to:
  /// **'- Ukládání souhrnných výsledků lokálně.'**
  String get consentBullet2;

  /// No description provided for @consentBullet3.
  ///
  /// In cs, this message translates to:
  /// **'- Neodesílání surových obrazových dat bez souhlasu.'**
  String get consentBullet3;

  /// No description provided for @consentQuestion.
  ///
  /// In cs, this message translates to:
  /// **'Souhlasíte se zpracováním dat potřebných pro měření?'**
  String get consentQuestion;

  /// No description provided for @consentAgree.
  ///
  /// In cs, this message translates to:
  /// **'Souhlasím'**
  String get consentAgree;

  /// No description provided for @researchDialogTitle.
  ///
  /// In cs, this message translates to:
  /// **'Údaje k měření'**
  String get researchDialogTitle;

  /// No description provided for @researchDialogAutoStamp.
  ///
  /// In cs, this message translates to:
  /// **'Datum a čas se doplní automaticky ({stamp}).'**
  String researchDialogAutoStamp(String stamp);

  /// No description provided for @researchDialogStart.
  ///
  /// In cs, this message translates to:
  /// **'Začít měření'**
  String get researchDialogStart;

  /// No description provided for @pdfTitle.
  ///
  /// In cs, this message translates to:
  /// **'Měření tepové frekvence a HRV'**
  String get pdfTitle;

  /// No description provided for @pdfTime.
  ///
  /// In cs, this message translates to:
  /// **'Čas: {time}'**
  String pdfTime(String time);

  /// No description provided for @pdfAverageBpm.
  ///
  /// In cs, this message translates to:
  /// **'Průměrný BPM: {bpm}'**
  String pdfAverageBpm(String bpm);

  /// No description provided for @pdfDuration.
  ///
  /// In cs, this message translates to:
  /// **'Délka měření: {duration} sekund'**
  String pdfDuration(String duration);

  /// No description provided for @pdfNotes.
  ///
  /// In cs, this message translates to:
  /// **'Poznámky: {notes}'**
  String pdfNotes(String notes);

  /// No description provided for @pdfSignalChart.
  ///
  /// In cs, this message translates to:
  /// **'Graf signálu:'**
  String get pdfSignalChart;

  /// No description provided for @aboutHowPpgTitle.
  ///
  /// In cs, this message translates to:
  /// **'Jak funguje PPG měření?'**
  String get aboutHowPpgTitle;

  /// No description provided for @aboutHowPpgBody.
  ///
  /// In cs, this message translates to:
  /// **'Fotopletysmografie (PPG) měří změny objemu krve v cévách pod pokožkou. S každým tepem projde prstem víc krve, ta pohltí víc světla a snímek z kamery na okamžik potemní. Aplikace z každého snímku spočítá průměrný jas v ploše pod prstem a z toho, jak se v čase mění, odečte tep.'**
  String get aboutHowPpgBody;

  /// No description provided for @aboutFingerTitle.
  ///
  /// In cs, this message translates to:
  /// **'Jak správně přiložit prst?'**
  String get aboutFingerTitle;

  /// No description provided for @aboutFingerBody.
  ///
  /// In cs, this message translates to:
  /// **'1. Ujistěte se, že máte čistý prst bez nečistot.\n2. Jemně přiložte prst na kameru tak, aby ji zcela zakrýval.\n3. Nepřikládejte prst příliš silně, aby nedošlo ke zkreslení signálu.\n4. Svítilna se zapne sama během odpočtu — nechte prst v klidu, než měření začne.'**
  String get aboutFingerBody;

  /// No description provided for @aboutBeforeStartTitle.
  ///
  /// In cs, this message translates to:
  /// **'Co se děje před začátkem měření'**
  String get aboutBeforeStartTitle;

  /// No description provided for @aboutBeforeStartBody.
  ///
  /// In cs, this message translates to:
  /// **'Během odpočtu 3–2–1 aplikace rozsvítí svítilnu, počká, až se ustálí automatika kamery, a zamkne expozici i zaostření. Bez zámku by automatika kompenzovala právě ty změny jasu, které tep tvoří. Teprve pak začne samotný záznam, aby jeho začátek nebyl zatížený rozsvěcením a rozjezdem filtrů.'**
  String get aboutBeforeStartBody;

  /// No description provided for @aboutProcessingTitle.
  ///
  /// In cs, this message translates to:
  /// **'Jak se signál zpracovává'**
  String get aboutProcessingTitle;

  /// No description provided for @aboutProcessingBody.
  ///
  /// In cs, this message translates to:
  /// **'1. Z každého snímku se vezme průměr zeleného kanálu v ploše pod prstem; když je zelená příliš tmavá, použije se červený kanál.\n2. Adaptivní filtr s údaji z akcelerometru potlačí vliv pohybu ruky.\n3. Následuje mediánový filtr proti ojedinělým výkyvům, odečtení pomalu se měnící složky (dýchání, prokrvení) a jemné vyhlazení.\n4. Kamera nedodává snímky přesně pravidelně, proto se pracuje se skutečnou snímkovací frekvencí měřenou z časových značek snímků — v praxi bývá kolem 24 snímků za sekundu, ne 30.'**
  String get aboutProcessingBody;

  /// No description provided for @aboutHeartRateTitle.
  ///
  /// In cs, this message translates to:
  /// **'Jak se vypočítá tepová frekvence?'**
  String get aboutHeartRateTitle;

  /// No description provided for @aboutHeartRateBody.
  ///
  /// In cs, this message translates to:
  /// **'Během měření se tep odhaduje ze spektra signálu a z autokorelace v posledních sekundách; když je odhad málo spolehlivý, aplikace raději nic nezobrazí, než aby ukázala nepodložené číslo.\nVe výsledku a v historii se pak tep počítá z detekovaných vrcholů: najdou se špičky odpovídající jednotlivým tepům, změří se intervaly mezi nimi a tep vyjde jako 60 ÷ průměrný interval v sekundách. Poloha každé špičky se dopočítává i mezi snímky, aby intervaly nebyly omezené krokem snímání.'**
  String get aboutHeartRateBody;

  /// No description provided for @aboutGreenChannelTitle.
  ///
  /// In cs, this message translates to:
  /// **'Proč zelený kanál?'**
  String get aboutGreenChannelTitle;

  /// No description provided for @aboutGreenChannelBody.
  ///
  /// In cs, this message translates to:
  /// **'Zelené světlo pohlcuje hemoglobin nejsilněji, takže se v něm změny prokrvení projeví nejvýrazněji. Červený kanál se přes prst přesvítí snáz, a slouží proto jako záloha, když je zelená příliš tmavá.'**
  String get aboutGreenChannelBody;

  /// No description provided for @aboutAccuracyTitle.
  ///
  /// In cs, this message translates to:
  /// **'Jak přesné to je'**
  String get aboutAccuracyTitle;

  /// No description provided for @aboutAccuracyBody.
  ///
  /// In cs, this message translates to:
  /// **'Zpracování jsme v srpnu 2026 ověřovali proti EKG holteru Bittium Faros 180 a pulznímu oxymetru na měřeních s 13 účastníky. Na uložených záznamech přepočtených stejným detektorem, jaký používá aplikace, se tep shodoval s EKG s průměrnou odchylkou pod 2 bpm — srovnatelně s tím, jak si odpovídají oba referenční přístroje navzájem.\nPřesnost ale závisí na kvalitě signálu: při pohybu, slabém prokrvení nebo špatně přiloženém prstu je odhad výrazně horší. U každého měření proto najdete i hodnocení kvality — měření označené jako špatné neberte vážně.\nParametry variability (SDNN, RMSSD) berte jen orientačně; na ně je snímkovací frekvence kamery hrubá. Aplikace není zdravotnický prostředek a neslouží k diagnostice.'**
  String get aboutAccuracyBody;

  /// No description provided for @infoTitle.
  ///
  /// In cs, this message translates to:
  /// **'O NÁS'**
  String get infoTitle;

  /// No description provided for @infoIntro.
  ///
  /// In cs, this message translates to:
  /// **'Ahoj!\nS radostí Vám představujeme naši aplikaci s názvem Tepovka, která vzniká v rámci soutěže organizované Fakultou elektrotechniky a komunikačních technologií na Vysokém učení technickém v Brně. Tento projekt je výsledkem naší spolupráce v týmu, který spojuje nadšení pro biomedicínské inženýrství a snahu přinášet inovativní řešení do každodenního života.\n\nNaším cílem je vytvořit aplikaci, která umožní měření srdeční frekvence jednoduše pomocí smartphonu s kamerou a bleskem. Tato funkce je pouhým začátkem. V budoucnu plánujeme rozšířit aplikaci o pokročilejší funkce, jako je měření saturace kyslíku v krvi (oximetrie), detekce srdečních arytmií nebo dokonce měření krevního tlaku – pokud výzkumy ukáží, že je tato technologie proveditelná.\n\nAplikace vzniká za podpory VUT, které poskytuje nejen technologické zázemí, ale také odborné vedení, díky kterému můžeme naše nápady realizovat.'**
  String get infoIntro;

  /// No description provided for @infoTeamTitle.
  ///
  /// In cs, this message translates to:
  /// **'Náš tým'**
  String get infoTeamTitle;

  /// No description provided for @infoTeamBody.
  ///
  /// In cs, this message translates to:
  /// **'Jsme studenti biomedicínského inženýrství a spojuje nás vášeň pro vývoj zdravotnických technologií. Náš tým tvoří:\n- Štěpán Zelníček\n- David Vavroušek\n- Jakub Kovář\n- Jakub Kaša\n\nKaždý z nás přispívá svými specifickými dovednostmi – od programování, přes design aplikací až po analýzu biologických dat. Naším hlavním cílem je vytvořit uživatelsky přívětivou a zároveň technologicky pokročilou aplikaci, která bude sloužit široké veřejnosti.'**
  String get infoTeamBody;

  /// No description provided for @infoFollowTitle.
  ///
  /// In cs, this message translates to:
  /// **'Sledujte a podpořte nás'**
  String get infoFollowTitle;

  /// No description provided for @infoFollowBody.
  ///
  /// In cs, this message translates to:
  /// **'Jsme nadšeni z možnosti sdílet naši cestu s Vámi a budeme rádi, když nás podpoříte a budete sledovat naše pokroky. Těšíme se na společné objevování nových možností v oblasti digitálního zdravotnictví!'**
  String get infoFollowBody;

  /// No description provided for @infoSupportedBy.
  ///
  /// In cs, this message translates to:
  /// **'Za podpory VUT. Děkujeme'**
  String get infoSupportedBy;

  /// No description provided for @commonDelete.
  ///
  /// In cs, this message translates to:
  /// **'Smazat'**
  String get commonDelete;

  /// No description provided for @metricsStressIndex.
  ///
  /// In cs, this message translates to:
  /// **'Index stresu'**
  String get metricsStressIndex;

  /// No description provided for @settingsAppLanguage.
  ///
  /// In cs, this message translates to:
  /// **'Jazyk aplikace'**
  String get settingsAppLanguage;

  /// No description provided for @settingsTextSize.
  ///
  /// In cs, this message translates to:
  /// **'Velikost textu'**
  String get settingsTextSize;

  /// No description provided for @settingsTestVoice.
  ///
  /// In cs, this message translates to:
  /// **'Otestovat hlas (TTS)'**
  String get settingsTestVoice;

  /// No description provided for @settingsLogSection.
  ///
  /// In cs, this message translates to:
  /// **'Logy a diagnostika'**
  String get settingsLogSection;

  /// No description provided for @settingsLogNotFound.
  ///
  /// In cs, this message translates to:
  /// **'Log soubor nenalezen'**
  String get settingsLogNotFound;

  /// No description provided for @settingsClearLog.
  ///
  /// In cs, this message translates to:
  /// **'Vymazat log'**
  String get settingsClearLog;

  /// No description provided for @consentDecline.
  ///
  /// In cs, this message translates to:
  /// **'Nechci'**
  String get consentDecline;

  /// No description provided for @infoWeb.
  ///
  /// In cs, this message translates to:
  /// **'Web'**
  String get infoWeb;

  /// No description provided for @recordsBpmRange.
  ///
  /// In cs, this message translates to:
  /// **'Rozsah BPM: {min}–{max}'**
  String recordsBpmRange(String min, String max);

  /// No description provided for @pdfHrvMetrics.
  ///
  /// In cs, this message translates to:
  /// **'HRV Metriky:'**
  String get pdfHrvMetrics;

  /// No description provided for @pdfDate.
  ///
  /// In cs, this message translates to:
  /// **'Datum: {date}'**
  String pdfDate(String date);

  /// No description provided for @summarySaveFailed.
  ///
  /// In cs, this message translates to:
  /// **'Záznam se nepodařilo uložit.'**
  String get summarySaveFailed;

  /// No description provided for @a11yHeartRateValue.
  ///
  /// In cs, this message translates to:
  /// **'Tepová frekvence {bpm} úderů za minutu'**
  String a11yHeartRateValue(String bpm);

  /// No description provided for @a11yHeartRateUnknown.
  ///
  /// In cs, this message translates to:
  /// **'Tepová frekvence zatím není k dispozici'**
  String get a11yHeartRateUnknown;

  /// No description provided for @a11ySignalQuality.
  ///
  /// In cs, this message translates to:
  /// **'Kvalita signálu: {quality}'**
  String a11ySignalQuality(String quality);

  /// No description provided for @a11yLiveChart.
  ///
  /// In cs, this message translates to:
  /// **'Živý graf pulzní vlny'**
  String get a11yLiveChart;

  /// No description provided for @a11yOpenSettings.
  ///
  /// In cs, this message translates to:
  /// **'Otevřít nastavení'**
  String get a11yOpenSettings;

  /// No description provided for @a11yOpenWebsite.
  ///
  /// In cs, this message translates to:
  /// **'Otevřít web'**
  String get a11yOpenWebsite;
}

class _L10nDelegate extends LocalizationsDelegate<L10n> {
  const _L10nDelegate();

  @override
  Future<L10n> load(Locale locale) {
    return SynchronousFuture<L10n>(lookupL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['cs', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_L10nDelegate old) => false;
}

L10n lookupL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return L10nCs();
    case 'en':
      return L10nEn();
  }

  throw FlutterError(
      'L10n.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
