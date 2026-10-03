//
//  WhisperServerApp.swift
//  WhisperServer
//
//  Created by Frankov Pavel on 24.03.2025.
//

import SwiftUI

@main
struct WhisperServerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

/// Lightweight application delegate coordinating specialized services
final class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Properties
    
    private struct RuntimeServices {
        let modelManager: ModelManager
        let serverCoordinator: ServerCoordinator
        let menuBarService: MenuBarService
        let modelObserver: ModelObserver

        init() {
            modelManager = ModelManager()
            serverCoordinator = ServerCoordinator(modelManager: modelManager)
            menuBarService = MenuBarService(modelManager: modelManager)
            modelObserver = ModelObserver(modelManager: modelManager)

            menuBarService.setServerCoordinator(serverCoordinator)
            serverCoordinator.setMenuBarService(menuBarService)
            modelObserver.setMenuBarService(menuBarService)
            modelObserver.setServerCoordinator(serverCoordinator)
        }
    }

    private let runtimeServices: RuntimeServices?
    var hasRuntimeServices: Bool { runtimeServices != nil }

    override init() {
        // Hosted unit tests must not construct ModelManager: its initializer downloads models.
        #if DEBUG
        let isUnitTest = ProcessInfo.processInfo.environment["WHISPER_SERVER_UNIT_TESTS"] == "1"
        runtimeServices = isUnitTest ? nil : RuntimeServices()
        #else
        runtimeServices = RuntimeServices()
        #endif
        super.init()
    }

    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let services = runtimeServices else { return }
        // Make app appear only in menu bar (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Check DEBUG flag status
        #if DEBUG
        print("✅ DEBUG mode is ACTIVE")
        #else
        print("❌ DEBUG mode is INACTIVE (Release build)")
        #endif
        
        // Initialize services
        services.menuBarService.setupMenuBar()
        services.modelObserver.updateUIForModelPreparation()
        services.serverCoordinator.startServer()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        runtimeServices?.serverCoordinator.handleApplicationTermination()
    }
}
