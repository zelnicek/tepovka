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
  String get summarySpo2Pending =>
      'Note: the SpO2 value is still being prepared and may not be up to date yet.';

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
  String get recordsTitle => 'Measurement history';

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
      'After a measurement you can save your heart rate to the Health app. Tepovka writes only the “Heart rate” type. No other data is sent or read.';

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
  String get settingsLogin => 'Sign-in';

  @override
  String get settingsNotLoggedIn => 'Not signed in';

  @override
  String get settingsLogout => 'Sign out';

  @override
  String get settingsLogoutHint => 'Removes the active sign-in on this device';

  @override
  String get settingsLoggedOut => 'Signed out';

  @override
  String get settingsMyQrForDoctor => 'My QR code for clinicians';

  @override
  String get settingsMyQrForDoctorHint => 'Allows records to be found quickly';

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
  String get loginLogout => 'Sign out';

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
  String get loginSaveProfile => 'Save profile and show QR';

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
  String settingsProfile(String name, String id) {
    return 'Profile: $name ($id…)';
  }

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
  String get summaryMeasureAgain => 'Measure again';

  @override
  String get summarySpo2ComingSoon => 'SpO2 is coming soon.';

  @override
  String get summarySpo2Disclaimer =>
      'SpO2 is an estimate, not a substitute for a medical device. See a doctor if it reads below 95 %.';

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
  String get settingsHealthShortHint => 'Saves heart rate only';

  @override
  String get settingsDataLocal => 'Your data stays on this phone';

  @override
  String get settingsDataLocalHint => 'Tepovka sends nothing to a server';

  @override
  String get settingsDiagnostics => 'Diagnostics and logs';

  @override
  String get settingsDiagnosticsHint => 'For troubleshooting the app';
}
