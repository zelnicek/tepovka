import UIKit
import Flutter
import AVFoundation
// Offline-only: remove Google Sign-In integration

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = self.registrar(forPlugin: "TepovkaCameraLock") {
      CameraLockChannel.register(messenger: registrar.messenger())
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // No external URL handlers required for local-only mode
}

/// Zámek nastavení kamery po dobu měření.
///
/// Flutter plugin `camera` umí zamknout expozici a ostření, ale ne vyvážení
/// bílé. To v automatice průběžně přepočítává zesílení jednotlivých kanálů,
/// tedy přímo poměr červené k zelené, ze kterého se odhaduje saturace — a na
/// datech by to nebylo nijak vidět. Kanál se připojí ke stejnému fyzickému
/// zařízení jako plugin (jméno kamery ve Flutteru je `uniqueID` zařízení),
/// zmrazí expozici, ISO, ostření i vyvážení bílé na přesných hodnotách a vrátí
/// je, aby šly zapsat do exportu.
///
/// Každý setter AVFoundation se volá až po kontrole, že ho zařízení podporuje:
/// nepodporovaný režim vyhodí výjimku Objective-C, kterou Swift nezachytí,
/// a aplikace by spadla.
final class CameraLockChannel {
  private enum LockError: Error {
    case unsupported(String)
  }

  private static let queue = DispatchQueue(label: "cz.tepovka.camera-lock")

  static func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "tepovka/camera_lock", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      guard let cameraId = args["cameraId"] as? String,
        let device = AVCaptureDevice(uniqueID: cameraId)
      else {
        result(FlutterError(code: "no_device", message: "Camera not found", details: nil))
        return
      }
      // Čekání na doběhnutí automatiky blokuje, takže mimo hlavní vlákno.
      CameraLockChannel.queue.async {
        let reply: Any?
        do {
          switch call.method {
          case "lock":
            let timeoutMs = args["settleTimeoutMs"] as? Int ?? 1500
            reply = try CameraLockChannel.lock(device, settleTimeout: Double(timeoutMs) / 1000.0)
          case "setExposure":
            guard let duration = args["durationS"] as? Double,
              let iso = args["iso"] as? Double,
              duration.isFinite, duration > 0, iso.isFinite, iso > 0
            else {
              throw LockError.unsupported("invalid exposure arguments")
            }
            reply = try CameraLockChannel.setExposure(device, durationS: duration, iso: iso)
          case "unlock":
            try CameraLockChannel.unlock(device)
            reply = nil
          case "snapshot":
            reply = CameraLockChannel.snapshot(device)
          default:
            DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
            return
          }
        } catch {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "camera_lock_failed", message: "\(error)", details: nil))
          }
          return
        }
        DispatchQueue.main.async { result(reply) }
      }
    }
  }

  /// Zmrazí expozici, ostření a vyvážení bílé na aktuálních hodnotách.
  ///
  /// Plugin zamyká expozici i ostření jednorázovým automatickým nastavením,
  /// které po zavolání ještě chvíli běží. Hodnoty se proto čtou a zamykají
  /// až po jeho doběhnutí, jinak by v exportu byla čísla, která neplatí.
  private static func lock(_ d: AVCaptureDevice, settleTimeout: TimeInterval) throws
    -> [String: Any]
  {
    let deadline = Date().addingTimeInterval(settleTimeout)
    while isAdjusting(d) && Date() < deadline {
      Thread.sleep(forTimeInterval: 0.05)
    }
    let settled = !isAdjusting(d)

    let applied = DispatchGroup()
    try d.lockForConfiguration()
    if d.isExposureModeSupported(.custom) {
      applied.enter()
      d.setExposureModeCustom(
        duration: AVCaptureDevice.currentExposureDuration,
        iso: AVCaptureDevice.currentISO
      ) { _ in applied.leave() }
    } else if d.isExposureModeSupported(.locked) {
      d.exposureMode = .locked
    }
    if d.isFocusModeSupported(.locked) {
      if d.isLockingFocusWithCustomLensPositionSupported {
        applied.enter()
        d.setFocusModeLocked(lensPosition: AVCaptureDevice.currentLensPosition) { _ in
          applied.leave()
        }
      } else {
        d.focusMode = .locked
      }
    }
    if d.isLockingWhiteBalanceWithCustomDeviceGainsSupported {
      applied.enter()
      d.setWhiteBalanceModeLocked(with: AVCaptureDevice.currentWhiteBalanceGains) { _ in
        applied.leave()
      }
    } else if d.isWhiteBalanceModeSupported(.locked) {
      d.whiteBalanceMode = .locked
    }
    d.unlockForConfiguration()
    _ = applied.wait(timeout: .now() + 1.0)

    var s = snapshot(d)
    s["settled_before_lock"] = settled
    return s
  }

  /// Nastaví pevnou délku expozice a ISO, oříznuté na rozsah aktivního formátu.
  private static func setExposure(_ d: AVCaptureDevice, durationS: Double, iso: Double) throws
    -> [String: Any]
  {
    guard d.isExposureModeSupported(.custom) else {
      throw LockError.unsupported("custom exposure")
    }
    let format = d.activeFormat
    var duration = CMTime(seconds: durationS, preferredTimescale: 1_000_000_000)
    if duration < format.minExposureDuration { duration = format.minExposureDuration }
    if duration > format.maxExposureDuration { duration = format.maxExposureDuration }
    let clampedIso = min(max(Float(iso), format.minISO), format.maxISO)

    let applied = DispatchGroup()
    applied.enter()
    try d.lockForConfiguration()
    d.setExposureModeCustom(duration: duration, iso: clampedIso) { _ in applied.leave() }
    d.unlockForConfiguration()
    _ = applied.wait(timeout: .now() + 1.0)
    return snapshot(d)
  }

  /// Vrátí expozici, ostření i vyvážení bílé do plynulé automatiky. Zámek
  /// vyvážení bílé by jinak na zařízení přežil i do dalšího měření, protože
  /// plugin ho při otevření kamery nenastavuje.
  private static func unlock(_ d: AVCaptureDevice) throws {
    try d.lockForConfiguration()
    if d.isExposureModeSupported(.continuousAutoExposure) {
      d.exposureMode = .continuousAutoExposure
    }
    if d.isFocusModeSupported(.continuousAutoFocus) {
      d.focusMode = .continuousAutoFocus
    }
    if d.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
      d.whiteBalanceMode = .continuousAutoWhiteBalance
    }
    d.unlockForConfiguration()
  }

  private static func isAdjusting(_ d: AVCaptureDevice) -> Bool {
    d.isAdjustingExposure || d.isAdjustingFocus || d.isAdjustingWhiteBalance
  }

  /// Aktuální nastavení kamery. Jen čte, nic nemění.
  private static func snapshot(_ d: AVCaptureDevice) -> [String: Any] {
    let format = d.activeFormat
    let dims = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
    let gains = d.deviceWhiteBalanceGains
    var s: [String: Any] = [
      "device_model": deviceModel(),
      "camera_type": d.deviceType.rawValue,
      "format": "\(dims.width)x\(dims.height)",
      "frame_duration_min_s": CMTimeGetSeconds(d.activeVideoMinFrameDuration),
      "frame_duration_max_s": CMTimeGetSeconds(d.activeVideoMaxFrameDuration),
      "exposure_mode": name(of: d.exposureMode),
      "exposure_duration_s": CMTimeGetSeconds(d.exposureDuration),
      "iso": Double(d.iso),
      "iso_min": Double(format.minISO),
      "iso_max": Double(format.maxISO),
      "exposure_duration_min_s": CMTimeGetSeconds(format.minExposureDuration),
      "exposure_duration_max_s": CMTimeGetSeconds(format.maxExposureDuration),
      "exposure_target_bias_ev": Double(d.exposureTargetBias),
      "white_balance_mode": name(of: d.whiteBalanceMode),
      "wb_gain_red": Double(gains.redGain),
      "wb_gain_green": Double(gains.greenGain),
      "wb_gain_blue": Double(gains.blueGain),
      "focus_mode": name(of: d.focusMode),
      "lens_position": Double(d.lensPosition),
      "torch_level": Double(d.torchLevel),
    ]
    // Převod na teplotu chromatičnosti vyhodí výjimku, když je některé
    // zesílení mimo povolený rozsah, takže se nejdřív ořízne.
    let maxGain = d.maxWhiteBalanceGain
    func clamp(_ v: Float) -> Float { min(max(v, 1.0), maxGain) }
    let valid = AVCaptureDevice.WhiteBalanceGains(
      redGain: clamp(gains.redGain), greenGain: clamp(gains.greenGain),
      blueGain: clamp(gains.blueGain))
    let tt = d.temperatureAndTintValues(for: valid)
    s["wb_temperature_k"] = Double(tt.temperature)
    s["wb_tint"] = Double(tt.tint)
    return s
  }

  private static func deviceModel() -> String {
    var info = utsname()
    uname(&info)
    return withUnsafePointer(to: &info.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
    }
  }

  private static func name(of mode: AVCaptureDevice.ExposureMode) -> String {
    switch mode {
    case .locked: return "locked"
    case .autoExpose: return "auto_once"
    case .continuousAutoExposure: return "auto"
    case .custom: return "custom"
    @unknown default: return "unknown"
    }
  }

  private static func name(of mode: AVCaptureDevice.FocusMode) -> String {
    switch mode {
    case .locked: return "locked"
    case .autoFocus: return "auto_once"
    case .continuousAutoFocus: return "auto"
    @unknown default: return "unknown"
    }
  }

  private static func name(of mode: AVCaptureDevice.WhiteBalanceMode) -> String {
    switch mode {
    case .locked: return "locked"
    case .autoWhiteBalance: return "auto_once"
    case .continuousAutoWhiteBalance: return "auto"
    @unknown default: return "unknown"
    }
  }
}
