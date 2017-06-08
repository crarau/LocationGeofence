//
//  Error+Extensions.swift
//  LocationGeofence
//
//  Created by Ciprian Rarau on 2017-06-07.
//  Copyright © 2017 Ciprian Rarau. All rights reserved.
//

import Foundation
import UIKit

extension Error {
    static func error(_ message: String) -> NSError{
        let userInfo: [AnyHashable: Any] = [ NSLocalizedDescriptionKey :  message, NSLocalizedFailureReasonErrorKey : message]
        return NSError(domain: "com.chip", code: 401, userInfo: userInfo)
    }
}

extension Error {
    func show() {
        UIAlertController.error(self.localizedDescription)
    }
}

extension UIAlertController {
    static func error(_ message: String) {
        let alert = UIAlertController(title: "Alert", message: message, preferredStyle: UIAlertControllerStyle.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        alert.show()
    }
    
    func show() {
        present(true, completion: nil)
    }
    
    func present(_ animated: Bool, completion: (() -> Void)?) {
        if let rootVC = UIApplication.shared.keyWindow?.rootViewController {
            presentFromController(rootVC, animated: animated, completion: completion)
        }
    }
    
    fileprivate func presentFromController(_ controller: UIViewController, animated: Bool, completion: (() -> Void)?) {
        if  let navVC = controller as? UINavigationController,
            let visibleVC = navVC.visibleViewController {
            presentFromController(visibleVC, animated: animated, completion: completion)
        } else {
            if  let tabVC = controller as? UITabBarController,
                let selectedVC = tabVC.selectedViewController {
                presentFromController(selectedVC, animated: animated, completion: completion)
            } else {
                controller.present(self, animated: animated, completion: completion)
            }
        }
    }
}
