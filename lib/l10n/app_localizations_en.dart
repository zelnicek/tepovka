// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class L10nEn extends L10n {
  L10nEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonClose => 'Close';

  @override
  String get commonNote => 'Note';

  @override
  String get commonTapForExplanation => 'Tip: tap for an explanation';

  @override
  String get navMenu => 'Home';

  @override
  String get navMeasure => 'Measure';

  @override
  String get navInfo => 'Info';

  @override
  String get homeReady => 'Ready to measure';

  @override
  String get homeMeasuring => 'Measuring';

  @override
  String get homeGetReady => 'Get ready…';

  @override
  String get homeStartButton => 'Start measuring';

  @override
  String get homeStopButton => 'Stop measuring';

  @override
  String get homeDurationLabel => 'Duration';

  @override
  String get homeSwitchCamera => 'Switch camera';

  @override
  String get homeChangeCamera => 'Change camera';

  @override
  String get homeTorchOn => 'Turn on torch';

  @override
  String get homeTorchOff => 'Turn off torch';

  @override
  String get homeQualityLabel => 'Quality';

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
      'Could not switch camera. Please try again.';

  @override
  String get homeDurationOutOfRange =>
      'Enter a duration between 10 and 300 seconds';

  @override
  String get homeAdjustingCamera => 'Adjusting the camera…';

  @override
  String get homeCameraSettingsChanged =>
      'Camera settings changed during the measurement. The recording is not suitable for SpO₂ analysis — please repeat it.';

  @override
  String get homeRedChannelClipped =>
      'The red channel was saturated. Reposition your finger and repeat the measurement.';

  @override
  String get qualityGood => 'Good';

  @override
  String get qualityMedium => 'Fair';

  @override
  String get qualityBad => 'Poor';

  @override
  String get qualityNoFinger => 'No finger';

  @override
  String get qualityPoorContact => 'Poor contact';

  @override
  String get ttsCountdown => 'Recording starts in three, two, one.';

  @override
  String get ttsMeasurementEnd => 'Measurement complete.';

  @override
  String get ttsSignalGood => 'The signal is good.';

  @override
  String get ttsSignalWorse =>
      'The signal is getting worse, please hold still.';

  @override
  String get ttsPoorContact => 'Poor contact with the camera.';

  @override
  String get ttsPlaceFinger => 'Place your finger on the camera.';

  @override
  String get ttsTestVoice => 'The test voice is working.';

  @override
  String get introTitle => 'Home';

  @override
  String get introStartMeasurement => 'Start measurement';

  @override
  String get introRecords => 'Records';

  @override
  String get summaryTitle => 'Result';

  @override
  String get summaryAverageHeartRate => 'Average heart rate:';

  @override
  String get summaryNotesHint => 'Add your notes about this measurement...';

  @override
  String get summaryTabSignal => 'Signal';

  @override
  String get summaryTabRecovery => 'Recovery';

  @override
  String get summarySaveToHealth => 'Save (writes to Apple Health)';

  @override
  String get summaryInNorm => 'Within range';

  @override
  String get summaryRest => 'Take a rest';

  @override
  String get summaryContinueActivity => 'Carry on as normal';

  @override
  String get summaryShortRest => 'A short rest is recommended';

  @override
  String get summaryInvalidHeartRate =>
      'Invalid heart rate (≤ 0). The record was not saved.';

  @override
  String get summarySavedToHealth => 'Successfully saved to Apple Health';

  @override
  String get summaryHealthSaveError => 'Error saving to Apple Health';

  @override
  String get metricsHrvAnalysis => 'HRV analysis';

  @override
  String get metricsAverageRr => 'Mean RR';

  @override
  String get metricsRespiratoryRate => 'Respiratory rate';

  @override
  String metricsBreathsPerMinute(String value) {
    return '$value breaths/min';
  }

  @override
  String get metricsHeartRateRecovery => 'Heart rate recovery';

  @override
  String get metricsHeartRate => 'Heart rate';

  @override
  String get metricsRecoveryIntro =>
      'Measures how far your heart rate drops after exertion. A larger drop over 60–120 s usually indicates better cardiovascular fitness and faster recovery.';

  @override
  String get tipRmssd =>
      'Root Mean Square of Successive Differences – sensitive to short-term, parasympathetic activity. Higher values usually mean better recovery and lower stress.';

  @override
  String get tipSdnn =>
      'Standard deviation of NN intervals – overall heart rate variability across the whole measurement. Reflects both short- and long-term influences.';

  @override
  String get tipPnn50 =>
      'Proportion of successive NN intervals differing by more than 50 ms. A higher percentage usually indicates stronger parasympathetic activity.';

  @override
  String get tipMeanRr =>
      'Mean NN (RR) interval length in milliseconds. Inversely related to resting heart rate (longer RR = lower BPM).';

  @override
  String get tipSd1 =>
      'SD1 (Poincaré) – short-term HRV (beat-to-beat variability). Closely related to RMSSD and parasympathetic tone.';

  @override
  String get tipSd2 =>
      'SD2 (Poincaré) – long-term HRV. Captures slower fluctuations and the overall variability trend.';

  @override
  String get tipSd2Sd1Ratio =>
      'Ratio of long-term to short-term variability. A higher ratio may indicate dominant slow oscillations or elevated stress.';

  @override
  String get tipLf =>
      'Low Frequency component (0.04–0.15 Hz) – a mix of sympathetic and parasympathetic activity. Shown as a percentage of (LF+HF).';

  @override
  String get tipHf =>
      'High Frequency component (0.15–0.40 Hz) – predominantly parasympathetic activity (respiratory sinus arrhythmia). Shown as a percentage of (LF+HF).';

  @override
  String get tipLfHfRatio =>
      'LF/HF ratio – an indicative measure of sympathetic/parasympathetic balance. Interpret it in the context of recording length and conditions.';

  @override
  String get tipRespiratoryRate =>
      'Respiratory rate (breaths per minute). Derived from PPG amplitude changes, typically 6–20 breaths/min at rest.';

  @override
  String get tipBaevsky =>
      'Baevsky stress index – an indicative measure of stress load. Higher values may point to greater strain; interpret with the measurement conditions in mind.';

  @override
  String get tipGenericHrv =>
      'HRV metric. Interpret it in the context of recording length, artefacts and measurement conditions.';

  @override
  String get tipHr0 =>
      'Average heart rate over the first 10 seconds of recovery. Used as the baseline for assessing the drop.';

  @override
  String get tipHr60 =>
      'Heart rate around the 60th second after exertion. Compared with the initial HR to compute HRR60.';

  @override
  String get tipHrr60 =>
      'Heart Rate Recovery over 60 s: the difference between 0–10 s and 50–60 s. Higher = faster recovery.';

  @override
  String get tipHrSlope =>
      'Linear slope of the heart rate decline over the first 60 s, in bpm/min. More negative = faster decline.';

  @override
  String get tipHr120 =>
      'Heart rate around the 120th second. Suitable for longer recovery protocols and HRR120.';

  @override
  String get tipHrr120 =>
      'Heart Rate Recovery over 120 s: the difference between 0–10 s and 110–120 s. Higher = better fitness.';

  @override
  String get tipHrTau =>
      'Estimated time constant of the exponential heart rate decay toward baseline (lower means faster recovery).';

  @override
  String get recordsTitle => 'History';

  @override
  String get recordsSearchHint => 'Search notes, date, time, BPM';

  @override
  String get recordsFilterAll => 'All';

  @override
  String get recordsSelectMultiple => 'Select multiple';

  @override
  String get recordsSort => 'Sort';

  @override
  String get recordsSortDateNewest => 'Date: newest';

  @override
  String get recordsSortDateOldest => 'Date: oldest';

  @override
  String get recordsSortBpmHighest => 'Heart rate: highest';

  @override
  String get recordsSortBpmLowest => 'Heart rate: lowest';

  @override
  String get recordsEmpty => 'No records found.';

  @override
  String recordsDeleteSelected(int count) {
    return 'Delete selected ($count)';
  }

  @override
  String get recordsConfirmDeleteTitle => 'Confirm deletion';

  @override
  String get recordsConfirmDeleteBody =>
      'Are you sure you want to delete this record?';

  @override
  String get recordsDeleted => 'Record deleted';

  @override
  String recordsDeletedCount(int count) {
    return '$count records deleted';
  }

  @override
  String get recordsLongTermTrends => 'Long-term trends';

  @override
  String recordsTrendSummary(int total, String mean) {
    return '$total measurements • average $mean bpm';
  }

  @override
  String get recordsDownloadPdf => 'Download PDF';

  @override
  String get recordsExportTxt => 'Export TXT';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccessibilitySection => 'Accessibility and readability';

  @override
  String get settingsDisplayMode => 'Display mode';

  @override
  String get settingsDisplayModeHint =>
      'Choose: Patient (simplified) or Clinician (detailed)';

  @override
  String get settingsPatientMode => 'Patient mode';

  @override
  String get settingsPatientModeHint => 'Simple view – traffic light';

  @override
  String get settingsDoctorMode => 'Clinician mode';

  @override
  String get settingsDoctorModeHint => 'Detailed HRV and recovery metrics';

  @override
  String get settingsSeniorMode => 'Senior mode';

  @override
  String get settingsSeniorModeHint => 'Larger controls and better readability';

  @override
  String get settingsHighContrast => 'High contrast';

  @override
  String get settingsHighContrastHint => 'Black text on a white background';

  @override
  String get settingsAppleHealth => 'Apple Health integration';

  @override
  String get settingsAppleHealthBody =>
      'After a measurement you can save your heart rate to the Health app. For measurements of 60 seconds or more with a good signal, heart rate variability (HRV, SDNN) is saved too. No other data is sent or read.';

  @override
  String get settingsManagePermissions => 'Manage permissions';

  @override
  String get settingsManagePermissionsHint =>
      'Open Settings → Privacy → Health → Tepovka';

  @override
  String get settingsGeneralSection => 'General';

  @override
  String get settingsTestVoiceHint =>
      'Plays a short prompt so you can check the voice';

  @override
  String get settingsPlayingTestVoice => 'Playing test prompt...';

  @override
  String get settingsHaptics => 'Haptic feedback';

  @override
  String get settingsHapticsHint => 'Vibration on actions in the app';

  @override
  String get settingsResearchSection => 'Research mode';

  @override
  String get settingsResearchMode => 'Research mode';

  @override
  String get settingsResearchModeHint =>
      'Record details are filled in before measuring and the export is more detailed';

  @override
  String get settingsResearchFields => 'Fields filled in before measuring';

  @override
  String get settingsExportFormat => 'Export format';

  @override
  String get settingsPreMeasurementFields => 'Pre-measurement fields';

  @override
  String get settingsPreMeasurementFieldsHint => 'Each line is one form field.';

  @override
  String get settingsComingSoon => 'Coming soon';

  @override
  String get settingsLocalCount => 'Measurements stored locally';

  @override
  String get settingsLastMeasurement => 'Last measurement';

  @override
  String get settingsOpenLog => 'Open log';

  @override
  String get settingsShareLog => 'Share log';

  @override
  String get settingsLogCleared => 'Log cleared';

  @override
  String settingsLogOpenError(String error) {
    return 'Error opening the log: $error';
  }

  @override
  String settingsLogShareError(String error) {
    return 'Error sharing the log: $error';
  }

  @override
  String settingsLogDeleteError(String error) {
    return 'Error deleting the log: $error';
  }

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageCzech => 'Čeština';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get exportFormatTxt => 'TXT (original format)';

  @override
  String get exportFormatJson => 'JSON (everything in one object)';

  @override
  String get loginMyQr => 'My QR code';

  @override
  String get loginQrHint =>
      'Your clinician opens the camera or a QR scanner on their phone and scans this code. If no scanner is available, they can enter your ID manually.';

  @override
  String get loginFullscreen => 'Full screen';

  @override
  String get loginIdCopied => 'ID copied to clipboard';

  @override
  String get loginCopyId => 'Copy ID';

  @override
  String get loginShare => 'Share';

  @override
  String get loginLocalProfile => 'Local profile';

  @override
  String get loginName => 'Name';

  @override
  String get loginNameHint => 'Enter your name';

  @override
  String get loginPin => 'PIN (optional)';

  @override
  String get loginPinHint => '4–6 digits to lock the profile';

  @override
  String get loginSignInFirst => 'Please sign in first.';

  @override
  String get consentTitle => 'Data processing consent';

  @override
  String get consentBody =>
      'The app needs to process camera frames in order to compute your heart rate and related metrics.\n\nThe app does not upload your frames to any server and stores data only on this device, and only if you explicitly agree.\n\nImportant: this app is not a medical device. Values such as SpO2 are indicative and may not be immediately available or accurate. Do not use the app as a substitute for medical equipment — if you have concerns, seek professional medical advice.';

  @override
  String get consentWhatItDoesTitle => 'What the app does:';

  @override
  String get consentBullet1 => '- Processes camera frames for PPG analysis.';

  @override
  String get consentBullet2 => '- Stores summary results locally.';

  @override
  String get consentBullet3 =>
      '- Does not send raw image data without your consent.';

  @override
  String get consentQuestion =>
      'Do you agree to the data processing required for measurement?';

  @override
  String get consentAgree => 'I agree';

  @override
  String get researchDialogTitle => 'Measurement details';

  @override
  String researchDialogAutoStamp(String stamp) {
    return 'Date and time are filled in automatically ($stamp).';
  }

  @override
  String get researchDialogStart => 'Start measurement';

  @override
  String get pdfTitle => 'Heart rate and HRV measurement';

  @override
  String pdfTime(String time) {
    return 'Time: $time';
  }

  @override
  String pdfAverageBpm(String bpm) {
    return 'Average BPM: $bpm';
  }

  @override
  String pdfDuration(String duration) {
    return 'Duration: $duration seconds';
  }

  @override
  String pdfNotes(String notes) {
    return 'Notes: $notes';
  }

  @override
  String get pdfSignalChart => 'Signal chart:';

  @override
  String get aboutHowPpgTitle => 'How does PPG measurement work?';

  @override
  String get aboutHowPpgBody =>
      'Photoplethysmography (PPG) measures changes in blood volume in the vessels beneath your skin. With every heartbeat more blood passes through your finger, absorbing more light, so the camera frame darkens for a moment. The app computes the average brightness of the area under your finger in each frame and derives your pulse from how that changes over time.';

  @override
  String get aboutFingerTitle => 'How should I place my finger?';

  @override
  String get aboutFingerBody =>
      '1. Make sure your finger is clean.\n2. Place your finger gently on the camera so that it covers it completely.\n3. Do not press too hard, as this distorts the signal.\n4. The torch turns on by itself during the countdown — keep your finger still until measuring begins.';

  @override
  String get aboutBeforeStartTitle => 'What happens before measuring starts';

  @override
  String get aboutBeforeStartBody =>
      'During the 3–2–1 countdown the app turns on the torch, waits for the camera\'s automatic adjustments to settle, and then locks exposure and focus. Without that lock, auto-exposure would compensate for exactly the brightness changes your pulse creates. Only then does recording begin, so its start is not affected by the torch switching on or by filters settling.';

  @override
  String get aboutProcessingTitle => 'How the signal is processed';

  @override
  String get aboutProcessingBody =>
      '1. Each frame contributes the average of the green channel in the area under your finger; if green is too dark, the red channel is used instead.\n2. An adaptive filter driven by accelerometer data suppresses the effect of hand movement.\n3. A median filter then removes isolated spikes, the slowly changing component (breathing, perfusion) is subtracted, and the result is gently smoothed.\n4. The camera does not deliver frames at perfectly even intervals, so the app works with the real frame rate measured from frame timestamps — in practice around 24 frames per second, not 30.';

  @override
  String get aboutHeartRateTitle => 'How is heart rate calculated?';

  @override
  String get aboutHeartRateBody =>
      'During measurement the pulse is estimated from the signal spectrum and from autocorrelation over the last few seconds; when the estimate is not reliable enough, the app shows nothing rather than an unfounded number.\nIn the result and in your history the pulse is then computed from detected peaks: the peaks corresponding to individual beats are located, the intervals between them are measured, and the pulse comes out as 60 ÷ the average interval in seconds. Each peak position is interpolated between frames so the intervals are not limited by the frame step.';

  @override
  String get aboutGreenChannelTitle => 'Why the green channel?';

  @override
  String get aboutGreenChannelBody =>
      'Haemoglobin absorbs green light most strongly, so changes in blood perfusion show up most clearly there. Red light passes through a finger more easily, so the red channel serves as a fallback when green is too dark.';

  @override
  String get aboutAccuracyTitle => 'How accurate is it';

  @override
  String get aboutAccuracyBody =>
      'In August 2026 we validated the processing against a Bittium Faros 180 ECG Holter and a pulse oximeter across measurements with 13 participants. On stored recordings reprocessed with the same detector the app uses, the pulse matched the ECG with a mean deviation below 2 bpm — comparable to how closely the two reference devices agree with each other.\nAccuracy does, however, depend on signal quality: with movement, weak perfusion or a poorly placed finger the estimate is considerably worse. Every measurement therefore carries a quality rating — do not rely on measurements marked as poor.\nTreat the variability parameters (SDNN, RMSSD) as indicative only; the camera\'s frame rate is coarse for those. This app is not a medical device and is not intended for diagnosis.';

  @override
  String get infoTitle => 'About us';

  @override
  String get infoIntro =>
      'Hi there!\nWe are delighted to introduce our app, Tepovka, developed as part of a competition organised by the Faculty of Electrical Engineering and Communication at Brno University of Technology. This project is the result of teamwork combining a passion for biomedical engineering with a drive to bring innovative solutions into everyday life.\n\nOur goal is to build an app that makes measuring heart rate simple, using nothing but a smartphone with a camera and a torch. That feature is only the beginning. In the future we plan to extend the app with more advanced capabilities such as blood oxygen saturation (oximetry), cardiac arrhythmia detection or even blood pressure measurement — should research show the technology to be feasible.\n\nThe app is being developed with the support of BUT, which provides not only the technical facilities but also the expert guidance that lets us turn our ideas into reality.';

  @override
  String get infoTeamTitle => 'Our team';

  @override
  String get infoTeamBody =>
      'We are biomedical engineering students united by a passion for developing healthcare technology. Our team:\n- Štěpán Zelníček\n- David Vavroušek\n- Jakub Kovář\n- Jakub Kaša\n\nEach of us contributes specific skills – from programming through app design to biological data analysis. Our main goal is to create an app that is both user-friendly and technologically advanced, and that serves the general public.';

  @override
  String get infoFollowTitle => 'Follow and support us';

  @override
  String get infoFollowBody =>
      'We are excited to share our journey with you, and we would be glad if you supported us and followed our progress. We look forward to exploring new possibilities in digital healthcare together!';

  @override
  String get infoSupportedBy => 'With the support of BUT. Thank you';

  @override
  String get commonDelete => 'Delete';

  @override
  String get metricsStressIndex => 'Stress index';

  @override
  String get settingsAppLanguage => 'App language';

  @override
  String get settingsTextSize => 'Text size';

  @override
  String get settingsTestVoice => 'Test the voice (TTS)';

  @override
  String get settingsLogSection => 'Logs and diagnostics';

  @override
  String get settingsLogNotFound => 'Log file not found';

  @override
  String get settingsClearLog => 'Clear log';

  @override
  String get consentDecline => 'Decline';

  @override
  String get infoWeb => 'Website';

  @override
  String recordsBpmRange(String min, String max) {
    return 'BPM range: $min–$max';
  }

  @override
  String get pdfHrvMetrics => 'HRV metrics:';

  @override
  String pdfDate(String date) {
    return 'Date: $date';
  }

  @override
  String get summarySaveFailed => 'The record could not be saved.';

  @override
  String a11yHeartRateValue(String bpm) {
    return 'Heart rate $bpm beats per minute';
  }

  @override
  String get a11yHeartRateUnknown => 'Heart rate not available yet';

  @override
  String a11ySignalQuality(String quality) {
    return 'Signal quality: $quality';
  }

  @override
  String get a11yLiveChart => 'Live pulse waveform chart';

  @override
  String get a11yOpenSettings => 'Open settings';

  @override
  String get a11yOpenWebsite => 'Open website';

  @override
  String get guideTitle => 'How to measure correctly';

  @override
  String get guideSkip => 'Skip';

  @override
  String get guideNext => 'Next';

  @override
  String get guideDone => 'Got it, let\'s measure';

  @override
  String guideStepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get guideRestTitle => 'Find a calm moment';

  @override
  String get guideRestBody =>
      'Measure sitting down after a minute of rest. Don\'t talk during the measurement and breathe normally.';

  @override
  String get guideCoverTitle => 'Cover the camera and the flash';

  @override
  String get guideCoverBody =>
      'Cover the rear camera and the flash next to it with the pad of your index finger. The flash turns on by itself.';

  @override
  String get guidePreviewTitle => 'The preview must turn fully red';

  @override
  String get guidePreviewBody =>
      'When your finger sits right, the round preview is evenly red and after a moment its border turns green. If not, move your finger. On a phone with several cameras you can switch the camera.';

  @override
  String get guideStillTitle => 'Lightly and still';

  @override
  String get guideStillBody =>
      'Rest your finger lightly: pressing hard squeezes the blood out of the fingertip and weakens the signal. Rest your hand on a table and stay still. Warm up cold fingers first.';

  @override
  String get guideResultTitle => 'Measurement and result';

  @override
  String get guideResultBody =>
      'After you press the button, a 3–2–1 countdown runs, then the measurement. 30 seconds is enough for heart rate; for heart rate variability (HRV), measure at least 60 seconds. If the signal quality is poor, repeat the measurement.';

  @override
  String get guideDisclaimer => 'Tepovka is not a medical device.';

  @override
  String get homeHelp => 'How to measure';

  @override
  String get hintPlaceFinger =>
      'Place your finger over the rear camera and the flash.';

  @override
  String get hintPoorContact =>
      'Your finger only partly covers the lens. Move it until the preview is fully red.';

  @override
  String get hintWeakSignal =>
      'The signal is weak. Press more lightly and keep your hand still.';

  @override
  String get hintGood => 'Great, hold it just like this.';

  @override
  String get aboutPageTitle => 'How it works';

  @override
  String get aboutGuideSubtitle => 'Five steps to a reliable measurement';

  @override
  String get introAboutApp => 'About the app';

  @override
  String get infoProjectTitle => 'About the Tepovka project';

  @override
  String get howSectionPrinciple => 'How measuring works';

  @override
  String get howStepLight => 'Light shines through the finger';

  @override
  String get howStepCamera => 'The camera sees the colour change';

  @override
  String get howStepPulse => 'The rhythm gives your pulse';

  @override
  String get howSectionFinger => 'Placing your finger';

  @override
  String get howTipCover => 'Cover the camera and the flash';

  @override
  String get howTipLight => 'Rest it lightly, don\'t press';

  @override
  String get howTipStill => 'Keep still';

  @override
  String get howAccuracyLabel => 'Deviation from ECG';

  @override
  String get howAccuracyValue => '< 2 bpm';

  @override
  String get howAccuracyNote =>
      'Validated on 13 participants against a Bittium Faros 180 ECG Holter. The app is not a medical device.';

  @override
  String get howSectionDetails => 'For the curious';

  @override
  String get infoProjectSummary =>
      'Heart-rate measurement with nothing but a phone\'s camera and flash, developed for a competition at the Faculty of Electrical Engineering and Communication, Brno University of Technology.';

  @override
  String get infoReadMore => 'Read more';

  @override
  String get infoReadLess => 'Show less';

  @override
  String infoVersion(String version) {
    return 'Version $version';
  }

  @override
  String get infoTeamIntro => 'We are biomedical engineering students.';

  @override
  String get homeMeasureTitle => 'Measure pulse';

  @override
  String get homeMeasureSubtitle => 'Cover the camera and flash with a finger';

  @override
  String get homeLastMeasurement => 'Last measurement';

  @override
  String homeToday(String time) {
    return 'Today $time';
  }

  @override
  String homeYesterday(String time) {
    return 'Yesterday $time';
  }

  @override
  String homeTrendCaption(int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Last $count measurements · average $avg bpm',
    );
    return '$_temp0';
  }

  @override
  String get homeNoMeasurementsTitle => 'No measurements yet';

  @override
  String get homeNoMeasurementsBody =>
      'The guide shows you how to place your finger correctly.';

  @override
  String get homeOpenGuide => 'Open the guide';

  @override
  String get homeTileHistory => 'History';

  @override
  String get homeTileHowItWorks => 'How it works';

  @override
  String get homeTileAbout => 'About';

  @override
  String get homeSectionMore => 'More';

  @override
  String get homeTileHistoryHint => 'All saved measurements';

  @override
  String get homeTileHowItWorksHint => 'Tips for an accurate reading';

  @override
  String get homeTileAboutHint => 'Project, team and links';

  @override
  String get commonDone => 'Done';

  @override
  String get measureTitle => 'Measurement';

  @override
  String measureRunning(int seconds) {
    return 'Measuring · $seconds s left';
  }

  @override
  String get measureSignalGood => 'Good signal';

  @override
  String get measureSignalWeak => 'Weak signal';

  @override
  String get measureSignalNoFinger => 'Place your finger';

  @override
  String get measurePulseWave => 'Pulse wave';

  @override
  String get measureDurationOther => 'Other';

  @override
  String get measureDurationHrvShort => 'Choose at least 60 s for HRV analysis';

  @override
  String get measureDurationHrvOk => 'Long enough for HRV analysis';

  @override
  String get recordsToday => 'Today';

  @override
  String get recordsYesterday => 'Yesterday';

  @override
  String get recordsAverageLabel => 'Average';

  @override
  String get recordsRangeLabel => 'Range';

  @override
  String recordsMeasurementsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count measurements',
      one: '1 measurement',
    );
    return '$_temp0';
  }

  @override
  String get recordsHrvTrends => 'HRV trends';

  @override
  String get recordsFilters => 'Filters';

  @override
  String get recordsSignalQuality => 'Signal quality';

  @override
  String get recordsDateRange => 'Date range';

  @override
  String get recordsAnyDate => 'Any time';

  @override
  String get recordsClearFilters => 'Clear filters';

  @override
  String get recordsNoMatch => 'No measurements match the filters.';

  @override
  String recordsSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get recordsNoWaveform => 'This record has no pulse wave.';

  @override
  String get recordsSearch => 'Search';

  @override
  String get recordsMore => 'More options';

  @override
  String recordsConfirmDeleteSelectedBody(int count) {
    return 'Delete the $count selected measurements?';
  }

  @override
  String get settingsReminderSection => 'Reminder';

  @override
  String get settingsReminder => 'Daily measurement reminder';

  @override
  String get settingsReminderHint =>
      'Reminds you at the chosen time. Skipped on days you have already measured.';

  @override
  String get settingsReminderTime => 'Reminder time';

  @override
  String get settingsReminderDenied =>
      'Notifications are off for Tepovka. Allow them in iOS Settings.';

  @override
  String get settingsReminderOpenSettings => 'Open Settings';

  @override
  String get reminderTitle => 'Time to measure';

  @override
  String get reminderBody => 'Take your pulse, it only takes half a minute.';

  @override
  String get metricHr0 => 'HR (0–10 s)';

  @override
  String get metricHr60 => 'HR at 60 s';

  @override
  String get metricHrr60 => 'Drop 0–60 s';

  @override
  String get metricSlope60 => 'Slope (0–60 s)';

  @override
  String get metricHr120 => 'HR at 120 s';

  @override
  String get metricHrr120 => 'Drop 0–120 s';

  @override
  String get metricTau => 'Tau (estimate)';

  @override
  String get settingsProfileUnnamed => 'User';

  @override
  String get summaryDiscardTitle => 'Discard measurement?';

  @override
  String get summaryDiscardBody =>
      'The result won\'t be saved to your history.';

  @override
  String get summaryDiscard => 'Discard';

  @override
  String get summaryKeep => 'Keep';

  @override
  String get summaryWeakSignal =>
      'The signal was weak, so the result may be off.';

  @override
  String get summaryNoHeartRate =>
      'No heart rate could be found in this recording. Cover the camera and the flash with your whole fingertip, keep still and measure again.';

  @override
  String get summaryMeasureAgain => 'Measure again';

  @override
  String get settingsSectionMeasurement => 'Measurement';

  @override
  String get settingsSectionDisplay => 'Display';

  @override
  String get settingsSectionSound => 'Sound and haptics';

  @override
  String get settingsSectionData => 'Data and privacy';

  @override
  String get settingsSectionProfile => 'Profile';

  @override
  String get settingsSectionSupport => 'Support';

  @override
  String get settingsPatientModeShort => 'Patient';

  @override
  String get settingsDoctorModeShort => 'Doctor';

  @override
  String get settingsVoiceGuidance => 'Voice guidance';

  @override
  String get settingsVoiceSample => 'Play a sample';

  @override
  String get settingsHealthShort => 'Apple Health';

  @override
  String get settingsHealthShortHint => 'Saves heart rate and HRV';

  @override
  String get settingsDataLocal => 'Your data stays on this phone';

  @override
  String get settingsDataLocalHint => 'Tepovka sends nothing to a server';

  @override
  String get settingsDiagnostics => 'Diagnostics and logs';

  @override
  String get settingsDiagnosticsHint => 'For troubleshooting the app';

  @override
  String get settingsMyProfile => 'My profile';

  @override
  String get settingsMyProfileHint => 'Name and QR code for your doctor';

  @override
  String settingsMyProfileSummary(String name, String id) {
    return '$name · ID $id';
  }

  @override
  String get profileCreate => 'Create profile';

  @override
  String get profileLocalHint =>
      'The profile stays on this phone. Your doctor uses the QR code to find your records quickly.';

  @override
  String get profileRemove => 'Remove profile';

  @override
  String get profileRemoveTitle => 'Remove the profile?';

  @override
  String get profileRemoveBody =>
      'Your name and QR code will be removed from the app. Your measurements stay in the history.';

  @override
  String get profileRemoveConfirm => 'Remove';

  @override
  String get profileRemoved => 'Profile removed';

  @override
  String get settingsClearLogTitle => 'Clear the log?';

  @override
  String get settingsClearLogBody =>
      'The event log for support will be deleted. Your measurements stay.';

  @override
  String get settingsClearLogConfirm => 'Clear';

  @override
  String get recordsSelectAll => 'Select all';

  @override
  String get recordsSelectNone => 'Deselect all';

  @override
  String recordsExportSelected(int count) {
    return 'Export ($count)';
  }

  @override
  String recordsExportTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Export $count measurements',
      one: 'Export 1 measurement',
    );
    return '$_temp0';
  }

  @override
  String get recordsExportPdf => 'Report for your doctor (PDF)';

  @override
  String get recordsExportPdfHint =>
      'Summary, chart and table of the measurements';

  @override
  String get recordsExportTable => 'Table (CSV)';

  @override
  String get recordsExportTableHint => 'One row per measurement, for Excel';

  @override
  String get recordsExportRaw => 'Full data';

  @override
  String recordsExportRawHint(String format) {
    return 'Signal waveform as $format, one file per measurement';
  }

  @override
  String get recordsExportFailed => 'Export failed';

  @override
  String get recordsWeeklyTitle => 'Heart rate by week';

  @override
  String recordsWeeklyLower(int n) {
    return '$n lower than the week before';
  }

  @override
  String recordsWeeklyHigher(int n) {
    return '$n higher than the week before';
  }

  @override
  String get recordsWeeklySame => 'same as the week before';

  @override
  String get recordsWeeklyCaption =>
      'Weekly average over the last 8 weeks. Leaves out readings after exercise, after coffee, under stress or with a poor signal.';

  @override
  String get reportTitle => 'Heart rate report';

  @override
  String reportPatient(String name, String id) {
    return 'Patient: $name · ID $id';
  }

  @override
  String reportPeriod(String period) {
    return 'Period: $period';
  }

  @override
  String reportCreated(String date) {
    return 'Created with Tepovka on $date';
  }

  @override
  String get reportMeasurements => 'Measurements';

  @override
  String get reportAverage => 'Average heart rate';

  @override
  String get reportRange => 'Range';

  @override
  String get reportSdnn => 'Average SDNN';

  @override
  String get reportChartTitle => 'Heart rate per measurement';

  @override
  String get reportTableTitle => 'All measurements';

  @override
  String get reportColDate => 'Date';

  @override
  String get reportColTime => 'Time';

  @override
  String get reportColDuration => 'Length';

  @override
  String get reportColBpm => 'HR';

  @override
  String get reportColQuality => 'Signal';

  @override
  String get reportColNote => 'Note';

  @override
  String get reportDisclaimer =>
      'Tepovka measures heart rate with the phone camera (photoplethysmography). The values are indicative; the app is not a medical device and is not meant for diagnosis. HRV (SDNN, RMSSD) is shown only for measurements of 60 s or more without a poor signal.';

  @override
  String reportPage(int page, int pages) {
    return 'Page $page of $pages';
  }

  @override
  String get summarySavedToHealthWithHrv =>
      'Heart rate and HRV saved to Apple Health';

  @override
  String get reportQualityUnknown => 'Not graded';

  @override
  String get tagRest => 'At rest';

  @override
  String get tagMorning => 'After waking up';

  @override
  String get tagExercise => 'After exercise';

  @override
  String get tagCaffeine => 'After coffee';

  @override
  String get tagStress => 'Stressed';

  @override
  String get summaryContextTitle => 'Measurement context';

  @override
  String get recordsTags => 'Tags';

  @override
  String get metricsFrequencyNeedsLonger =>
      'LF, HF and LF/HF are shown only for measurements of 2 minutes or more. A shorter recording cannot give them reliably.';

  @override
  String get metricsHrvNeedsLonger =>
      'Heart rate variability (HRV) is shown only for measurements of 60 seconds or more; from a shorter recording it is too inaccurate.';

  @override
  String get shareCardTitle => 'Share result';

  @override
  String get shareCardShare => 'Share';

  @override
  String get shareCardHeartRate => 'Heart rate';

  @override
  String get shareCardFooter => 'Measured with the phone camera';

  @override
  String get shareCardFailed => 'Could not create the card';

  @override
  String get homeSectionHeart => 'Your heart';

  @override
  String streakDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days in a row',
      one: '1 day in a row',
      zero: 'No streak yet',
    );
    return '$_temp0';
  }

  @override
  String streakBest(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return 'Longest streak: $_temp0';
  }

  @override
  String get streakKeep => 'Measure today to keep it going';

  @override
  String get streakStart => 'Measure today to start a streak';

  @override
  String get beatsTodayLabel => 'So far today, about';

  @override
  String beatsUnit(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'beats',
      one: 'beat',
    );
    return '$_temp0';
  }

  @override
  String beatsSinceFirst(String count) {
    return 'About $count beats since your first measurement';
  }

  @override
  String beatsEstimate(int bpm) {
    return 'Based on a resting rate of $bpm bpm';
  }

  @override
  String daysCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgeNew => 'New badge!';

  @override
  String get badgeAll => 'All badges';

  @override
  String get badgeGreat => 'Great';

  @override
  String badgeProgress(int value, int goal) {
    return '$value of $goal';
  }

  @override
  String get badgeUnlocked => 'Unlocked';

  @override
  String get badgesTotal => 'Measurements';

  @override
  String get badgesCurrent => 'Current streak';

  @override
  String get badgesBest => 'Longest streak';

  @override
  String get badgeFirstBeat => 'First beat';

  @override
  String get badgeFirstBeatHint => 'Your first measurement';

  @override
  String get badgeTen => 'Ten';

  @override
  String get badgeThirty => 'Thirty';

  @override
  String get badgeHundred => 'Century';

  @override
  String badgeMeasurementsHint(int n) {
    return '$n measurements';
  }

  @override
  String get badgeStreak3 => 'Warm-up';

  @override
  String get badgeStreak7 => 'A week in rhythm';

  @override
  String get badgeStreak30 => 'A month in rhythm';

  @override
  String badgeStreakHint(int n) {
    return '$n days in a row';
  }

  @override
  String get badgeEarlyBird => 'Early bird';

  @override
  String badgeEarlyBirdHint(int n) {
    return '$n measurements tagged After waking up';
  }

  @override
  String get recordsYearTitle => 'Your year';

  @override
  String get recordsYearCaption =>
      'Each square is a day, coloured by resting heart rate.';

  @override
  String get recordsYearLow => 'lower';

  @override
  String get recordsYearHigh => 'higher';

  @override
  String get recordsYearHint => 'Tap a day';

  @override
  String recordsYearDay(String date, int bpm, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count measurements',
      one: '1 measurement',
    );
    return '$date: resting $bpm bpm, $_temp0';
  }

  @override
  String recordsYearDayNoRest(String date) {
    return '$date: only readings after exercise, coffee or stress';
  }

  @override
  String recordsYearDayEmpty(String date) {
    return '$date: no measurement';
  }

  @override
  String reminderStreakBody(int n) {
    return 'You are on a $n-day streak. Measure today to keep it going.';
  }

  @override
  String get hintKeepStill => 'Keep still, movement spoils the reading.';

  @override
  String hintMeasuringLonger(int seconds) {
    return 'The signal was unsettled, measuring $seconds s longer.';
  }

  @override
  String get ttsKeepStill => 'Keep still.';

  @override
  String get ttsMeasuringLonger =>
      'Measuring a little longer, keep your finger still.';

  @override
  String get summaryMethodsDisagree =>
      'The two ways of computing the heart rate disagreed on this measurement, so the result may be off. Measure once more to be sure.';

  @override
  String get recoveryTestTitle => 'Recovery test';

  @override
  String get recoveryTestHint =>
      'How fast your heart rate settles after exercise';

  @override
  String get recoveryIntro =>
      'How fast the heart rate falls after exertion says something about fitness: the faster, the better. Comparing your own tests over time tells the most.';

  @override
  String get recoveryStep1 =>
      'Exercise for 1–2 minutes until you are out of breath: squats, jumping jacks or brisk stair climbing. Do the same each time so the tests compare.';

  @override
  String get recoveryStep2 =>
      'Straight after, sit down, cover the camera and the flash with your fingertip and start measuring. It takes 2 minutes.';

  @override
  String get recoveryStep3 =>
      'Keep still and breathe freely while it measures.';

  @override
  String get recoverySafety =>
      'Exercise only as far as your health allows. Stop, and skip the test, if you feel chest pain, dizziness or unusual breathlessness.';

  @override
  String get recoveryStart => 'Done exercising, measure';

  @override
  String get recoveryMyTests => 'Your tests';

  @override
  String get recoveryNoTests =>
      'No tests yet. After the first you will see how far your heart rate fell, and in time how your recovery changes.';

  @override
  String get recoveryResultTitle => 'Recovery after exercise';

  @override
  String get recoveryAfter1Min => 'after 1 minute';

  @override
  String get recoveryAfter2Min => 'after 2 minutes';

  @override
  String get recoveryHowToRead =>
      'How many beats per minute your heart rate fell from the start of the measurement. The more, the faster you recover. Compare mainly your own tests after the same exercise.';

  @override
  String get recoveryTrendTitle => 'Heart rate drop after 1 minute';

  @override
  String get recordsEditContext => 'Edit context and note';

  @override
  String get recordsAddContext => 'Add context or a note';

  @override
  String get recordsContextSaved => 'Saved';

  @override
  String get recordsContextSaveFailed => 'The change could not be saved.';

  @override
  String recordsFrameRate(int fps) {
    return '$fps fps';
  }
}
