//
//  MygraWidgetsIntentsPackage.swift
//  MygraWidgets
//
//  Lets the widget extension use the Live Activity button intents from MygraServices.
//

import AppIntents
import MygraServices

struct MygraWidgetsAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MygraServicesIntentsPackage.self]
    }
}
