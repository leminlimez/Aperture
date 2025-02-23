//
//  Alert++.swift
//  Da Moon
//
//  Created by lemin on 2/21/25.
//

import UIKit

var currentUIAlertController: UIAlertController?

fileprivate let errorString = NSLocalizedString("Error", comment: "")
fileprivate let dismissString = NSLocalizedString("Okay", comment: "")

// create alerts without being attached to a view
extension UIApplication {
    func alert(title: String = errorString, body: String) {
        DispatchQueue.main.async {
            currentUIAlertController = UIAlertController(title: title, message: body, preferredStyle: .alert)
            currentUIAlertController?.addAction(.init(title: dismissString, style: .cancel))
            self.present(alert: currentUIAlertController!)
        }
    }
    
    func present(alert: UIAlertController) {
        if var topController = self.windows[0].rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            topController.present(alert, animated: true)
        }
    }
}
