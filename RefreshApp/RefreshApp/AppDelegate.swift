import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        AppDelegate.orientationLock
    }
}

enum OrientationManager {
    static func lockLandscape() {
        AppDelegate.orientationLock = .landscape
        rotate(to: .landscapeRight)
    }

    static func lockPortrait() {
        AppDelegate.orientationLock = .portrait
        rotate(to: .portrait)
    }

    private static func rotate(to orientation: UIInterfaceOrientation) {
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            let mask: UIInterfaceOrientationMask = orientation == .portrait ? .portrait : .landscape
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(orientation.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
}
