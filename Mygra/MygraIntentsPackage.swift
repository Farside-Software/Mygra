//
//  MygraIntentsPackage.swift
//  Mygra
//
//  Tells App Intents to include the intents that live in the MygraServices package (the
//  Live Activity buttons) in this app's metadata.
//

import AppIntents
import MygraServices

struct MygraAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] {
        [MygraServicesIntentsPackage.self]
    }
}
