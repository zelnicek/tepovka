import 'dart:math';

/// What spoils a measurement while it runs: the phone moving, and stretches
/// of pulse wave the heart rate cannot be read from.
///
/// On BUT PPG (tool/butppg) motion cut the share of usable recordings from
/// 24 % at rest to 11-16 %, while the heart rate from the usable ones stayed
/// as accurate as at rest. So the help is to say "keep still" when it
/// happens, and to measure on for a few seconds when too much of the
/// recording was unsettled.

/// Tells from the accelerometer, gravity removed, whether the phone moves
/// enough to spoil the pulse wave.
///
/// The thresholds are a first estimate, not yet checked on recorded data: a
/// phone held still reads around 0.05 m/s², walking 1-2 m/s². Each saved
/// record keeps how many of its seconds were moving, so they can be tuned.
class MotionMonitor {
  MotionMonitor({this.samples = 15, this.startRms = 0.5, this.stopRms = 0.3});

  /// Readings the RMS spans: about a second at the 15 Hz the measure screen
  /// asks for.
  final int samples;

  /// RMS acceleration (m/s²) above which the phone counts as moving, and
  /// below which it counts as still again. The gap keeps a reading near the
  /// threshold from flickering.
  final double startRms;
  final double stopRms;

  final List<double> _squares = [];
  double _sum = 0;
  bool _moving = false;
  double _rms = 0;

  bool get moving => _moving;

  /// RMS acceleration over the latest [samples] readings, m/s².
  double get rms => _rms;

  /// Adds one reading in m/s² and returns whether the phone is moving.
  bool add(double x, double y, double z) {
    final double square = x * x + y * y + z * z;
    _squares.add(square);
    _sum += square;
    if (_squares.length > samples) _sum -= _squares.removeAt(0);
    _rms = sqrt(max(0.0, _sum) / _squares.length);
    _moving = _moving ? _rms > stopRms : _rms > startRms;
    return _moving;
  }

  void reset() {
    _squares.clear();
    _sum = 0;
    _moving = false;
    _rms = 0;
  }
}

/// The seconds of a recording, and how many of them were unsettled: the
/// phone moving, or no heart rate in the live window.
class SteadinessLog {
  int seconds = 0;
  int unsettled = 0;
  int moving = 0;

  /// [MotionMonitor.rms] each second, kept in research mode to tune the
  /// motion thresholds on measurements with deliberate movement.
  final List<double> motionRms = [];

  void add({
    required bool movingSecond,
    required bool heartRateFound,
    double? motionRms,
  }) {
    seconds++;
    if (movingSecond) moving++;
    if (movingSecond || !heartRateFound) unsettled++;
    if (motionRms != null) this.motionRms.add(motionRms);
  }

  double get unsettledShare => seconds == 0 ? 0 : unsettled / seconds;

  void reset() {
    seconds = 0;
    unsettled = 0;
    moving = 0;
    motionRms.clear();
  }

  Map<String, Object> toJson(int extendedSeconds, {MotionMonitor? monitor}) => {
        'seconds': seconds,
        'unsettledSeconds': unsettled,
        'movingSeconds': moving,
        'extendedSeconds': extendedSeconds,
        if (motionRms.isNotEmpty) ...{
          'motionRmsPerSecond': [
            for (final double v in motionRms) (v * 1000).round() / 1000
          ],
          if (monitor != null)
            'motionThresholds': [monitor.startRms, monitor.stopRms],
        },
      };
}

/// Seconds a measurement runs on when too much of it was unsettled.
const int kExtensionSeconds = 10;

/// Share of unsettled seconds above which the measurement runs on.
const double kMaxUnsettledShare = 0.3;

/// Whether the measurement should run on for [kExtensionSeconds]. Only
/// once: a recording that stays unsettled does not get better by waiting,
/// and the result screen then says how it went.
bool shouldExtendMeasurement(SteadinessLog log,
        {required bool alreadyExtended}) =>
    !alreadyExtended &&
    log.seconds > 0 &&
    log.unsettledShare > kMaxUnsettledShare;
