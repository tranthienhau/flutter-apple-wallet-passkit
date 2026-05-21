import Flutter
import Foundation

/// Bridges Flutter <-> HID Approve SDK.
///
/// In production this file would import the HID Approve xcframework and
/// call `HIDOTPGenerator.generateOTP(context:)` (exact API differs by
/// SDK version). For the POC we return a deterministic 6-digit number
/// derived from the request id so the demo is reproducible offline.
final class HidApproveChannel: NSObject {
  static let channelName = "poc.hid/approve"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = HidApproveChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "generateOtp":
      guard let args = call.arguments as? [String: Any],
            let requestId = args["requestId"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "requestId missing", details: nil))
        return
      }
      generateMockOtp(requestId: requestId, result: result)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func generateMockOtp(requestId: String, result: @escaping FlutterResult) {
    // MOCK: simulate the HID Approve SDK's ~150 ms signing latency.
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.15) {
      // Deterministic 6-digit OTP from the request id hash.
      var hash: UInt32 = 2_166_136_261
      for byte in requestId.utf8 {
        hash ^= UInt32(byte)
        hash = hash &* 16_777_619
      }
      let otp = String(format: "%06u", hash % 1_000_000)
      DispatchQueue.main.async {
        result(otp)
      }
    }
  }
}
