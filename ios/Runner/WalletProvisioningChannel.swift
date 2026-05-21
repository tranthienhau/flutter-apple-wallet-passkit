import Flutter
import Foundation
import PassKit
import UIKit

/// Bridges Flutter <-> PassKit in-app provisioning.
///
/// The real PassKit flow:
///   1. App calls `PKAddPaymentPassViewController(requestConfiguration:delegate:)`
///   2. iOS asks the delegate `generateRequestWithCertificateChain:`
///   3. App forwards (certificates, nonce, nonceSignature) to the issuer/TSP
///   4. Issuer returns encrypted PAN data + activation data
///   5. App completes the controller with a `PKAddPaymentPassRequest`
///
/// This file implements that flow faithfully but talks to a mocked
/// in-process "issuer" so the POC is self-contained.
final class WalletProvisioningChannel: NSObject {
  static let channelName = "poc.wallet/provisioning"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let instance = WalletProvisioningChannel()
    channel.setMethodCallHandler(instance.handle)
  }

  // Strong refs so PassKit can call the delegate after `present`.
  private var pendingCompletion: ((PKAddPaymentPassRequest?) -> Void)?
  private var pendingFlutterResult: FlutterResult?
  private weak var presentedController: PKAddPaymentPassViewController?

  private let mockIssuer = MockIssuerService()

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(PKAddPaymentPassViewController.canAddPaymentPass())

    case "hasEntitlement":
      // MOCK: real apps check via Apple's provisioned entitlement.
      // For the POC we hard-code `false` so the UI shows "pending Apple review".
      result(false)

    case "addPaymentPass":
      guard let args = call.arguments as? [String: Any],
            let cardholderName = args["cardholderName"] as? String,
            let suffix = args["primaryAccountSuffix"] as? String else {
        result(FlutterError(code: "BAD_ARGS", message: "Missing args", details: nil))
        return
      }
      presentAddPaymentPass(
        cardholderName: cardholderName,
        primaryAccountSuffix: suffix,
        result: result
      )

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func presentAddPaymentPass(
    cardholderName: String,
    primaryAccountSuffix: String,
    result: @escaping FlutterResult
  ) {
    guard PKAddPaymentPassViewController.canAddPaymentPass() else {
      result(["ok": false, "error": "Device cannot add payment pass"])
      return
    }

    let config = PKAddPaymentPassRequestConfiguration(encryptionScheme: .ECC_V2)
    config?.cardholderName = cardholderName
    config?.primaryAccountSuffix = primaryAccountSuffix
    config?.localizedDescription = "Bank Visa"
    config?.paymentNetwork = .visa
    config?.style = .payment

    guard let cfg = config,
          let controller = PKAddPaymentPassViewController(requestConfiguration: cfg, delegate: self) else {
      result(["ok": false, "error": "Failed to build PKAddPaymentPassViewController"])
      return
    }

    presentedController = controller
    pendingFlutterResult = result

    DispatchQueue.main.async {
      let root = UIApplication.shared
        .connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first(where: { $0.isKeyWindow })?
        .rootViewController
      root?.present(controller, animated: true)
    }
  }
}

extension WalletProvisioningChannel: PKAddPaymentPassViewControllerDelegate {
  func addPaymentPassViewController(
    _ controller: PKAddPaymentPassViewController,
    generateRequestWithCertificateChain certificates: [Data],
    nonce: Data,
    nonceSignature: Data,
    completionHandler handler: @escaping (PKAddPaymentPassRequest) -> Void
  ) {
    pendingCompletion = handler

    // MOCK: forward the issuer payload to a fake issuer that returns
    // encrypted PAN data + activation data. Real apps POST to their TSP.
    mockIssuer.requestProvisioningPayload(
      certificates: certificates,
      nonce: nonce,
      nonceSignature: nonceSignature
    ) { payload in
      let request = PKAddPaymentPassRequest()
      request.encryptedPassData = payload.encryptedPassData
      request.activationData = payload.activationData
      request.ephemeralPublicKey = payload.ephemeralPublicKey
      handler(request)
    }
  }

  func addPaymentPassViewController(
    _ controller: PKAddPaymentPassViewController,
    didFinishAdding pass: PKPaymentPass?,
    error: Error?
  ) {
    controller.dismiss(animated: true)
    let completion = pendingFlutterResult
    pendingFlutterResult = nil

    if let error = error {
      completion?([
        "ok": false,
        "error": error.localizedDescription
      ])
      return
    }
    let passId = pass?.primaryAccountIdentifier ?? UUID().uuidString
    completion?([
      "ok": true,
      "passId": passId
    ])
  }
}

/// MOCK issuer / TSP. In production this is your bank's HTTPS service.
private final class MockIssuerService {
  struct ProvisioningPayload {
    let encryptedPassData: Data
    let activationData: Data
    let ephemeralPublicKey: Data
  }

  func requestProvisioningPayload(
    certificates: [Data],
    nonce: Data,
    nonceSignature: Data,
    completion: @escaping (ProvisioningPayload) -> Void
  ) {
    // MOCK: pretend we POSTed to the issuer and got the three blobs back.
    DispatchQueue.global().asyncAfter(deadline: .now() + 0.6) {
      let payload = ProvisioningPayload(
        encryptedPassData: Data(repeating: 0xA1, count: 64),
        activationData: Data(repeating: 0xB2, count: 32),
        ephemeralPublicKey: Data(repeating: 0xC3, count: 65)
      )
      completion(payload)
    }
  }
}
