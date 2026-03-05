import Flutter
import Photos
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var mediaChangesHandler: MediaChangesStreamHandler?
  private var mediaChangesChannel: FlutterEventChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MediaChangesStreamPlugin")
    mediaChangesHandler = MediaChangesStreamHandler()
    mediaChangesChannel = FlutterEventChannel(
      name: "app.mediaChanges",
      binaryMessenger: registrar.messenger()
    )
    mediaChangesChannel?.setStreamHandler(mediaChangesHandler)
  }
}

final class MediaChangesStreamHandler: NSObject, FlutterStreamHandler, PHPhotoLibraryChangeObserver {
  private var eventSink: FlutterEventSink?
  private var isRegistered = false

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    guard status == .authorized || status == .limited else {
      // Keep stream open. Observer will be registered on next listen after permission is granted.
      return nil
    }

    if !isRegistered {
      PHPhotoLibrary.shared().register(self)
      isRegistered = true
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    unregisterIfNeeded()
    eventSink = nil
    return nil
  }

  func photoLibraryDidChange(_ changeInstance: PHChange) {
    DispatchQueue.main.async { [weak self] in
      guard let self = self, let sink = self.eventSink else { return }
      let nowMs = Int(Date().timeIntervalSince1970 * 1000)
      sink([
        "type": "libraryChanged",
        "reason": "unknown",
        "changedAfterMs": nowMs - 2000,
        "timestampMs": nowMs,
      ])
    }
  }

  deinit {
    unregisterIfNeeded()
  }

  private func unregisterIfNeeded() {
    if isRegistered {
      PHPhotoLibrary.shared().unregisterChangeObserver(self)
      isRegistered = false
    }
  }
}
