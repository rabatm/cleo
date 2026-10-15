import AppKit

// Point d'entrée explicite : @main sur NSObject ne posait pas le délégué
// (applicationDidFinishLaunching n'était jamais appelé). Ce main.swift
// classique est la voie garantie.
let app = NSApplication.shared
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
