import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 🔴 EKRANI YATAYA ZORLA (iOS 16 ve Üzeri İçin)
        if #available(iOS 16.0, *) {
            let windowScene = scene as? UIWindowScene
            let geometryUpdate = UIWindowScene.GeometryConstraints.iOS(interfaceOrientations: .landscape)
            windowScene?.requestGeometryUpdate(geometryUpdate) { error in
                print("Hata: \(error.localizedDescription)")
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}
    func sceneDidBecomeActive(_ scene: UIScene) {}
    func sceneWillResignActive(_ scene: UIScene) {}
    func sceneWillEnterForeground(_ scene: UIScene) {}
    func sceneDidEnterBackground(_ scene: UIScene) {}
}
