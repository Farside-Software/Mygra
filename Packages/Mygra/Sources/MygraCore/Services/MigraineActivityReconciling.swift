//
//  MigraineActivityReconciling.swift
//  MygraCore
//
//  An optional capability of the Live Activity controller: end every activity that does
//  not belong to the ongoing migraine. This is what stops an activity lingering after the
//  app was killed and the migraine ended somewhere else (the watch, another device).
//

import Foundation

@MainActor
public protocol MigraineActivityReconciling {
    /// Ends every migraine activity whose migraine is not `migraineID`; with nil, all of them.
    func endAll(except migraineID: UUID?)
}
