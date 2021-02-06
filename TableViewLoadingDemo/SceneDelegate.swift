import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let windowScene = scene as? UIWindowScene {

            let viewController = ViewController()
            let navigationController = UINavigationController(rootViewController: viewController)

            self.window = UIWindow(windowScene: windowScene)
            self.window?.rootViewController = navigationController
            self.window?.makeKeyAndVisible()
        }
    }
}
