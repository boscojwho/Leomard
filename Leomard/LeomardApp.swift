//
//  LeomardApp.swift
//  Leomard
//
//  Created by Konrad Figura on 01/07/2023.
//

import SwiftUI
import Nuke

@main
struct LeomardApp: App {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL
    
    @State private var mainWindowNavSplitStatus = NavigationSplitViewVisibility.automatic
    
    @State private var latestRelease: Release? = nil
    
    // Initialize user preferences here, so all subwindows catch it getting updated.
    @ObservedObject var userPreferences: UserPreferences = UserPreferences.getInstance

    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView(columnStatus: $mainWindowNavSplitStatus)
                .frame(
                    minWidth: mainWindowNavSplitStatus == .detailOnly ? 600 : 800,
                    minHeight: 400,
                    idealHeight: 800)
                .onAppear {
                    ImageCache.shared.costLimit = 300 * (1024 * 1024)
                    ImageCache.shared.countLimit = 250
                    
                    DataLoader.sharedUrlCache.diskCapacity = 500 * (1024 * 1024)
                    DataLoader.sharedUrlCache.memoryCapacity = 0
                }
                .onDisappear {
                    
                }
                .task {
                    checkForUpdateOnStart()
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowToolbarStyle(UnifiedWindowToolbarStyle())
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Preferences", action: showPreferences)
                    .keyboardShortcut(",", modifiers: .command)
                Button("Donate", action: { openURL(URL(string: "https://ko-fi.com/athlon")!) })
            }
        }
        
        Window("Preferences", id: "preferences") {
            PreferencesView(checkForUpdateMethod: checkForUpdates)
                .frame(minWidth: 600, maxWidth: 600, maxHeight: 800)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowToolbarStyle(UnifiedWindowToolbarStyle())
        .windowResizability(.contentSize)
        
        Window("Update Available", id: "update_window") {
            UpdateView(release: self.latestRelease)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowToolbarStyle(UnifiedWindowToolbarStyle())
        .windowResizability(.contentSize)
    }
    
    func showPreferences() {
        self.openWindow(id: "preferences")
    }
    
    func checkForUpdateOnStart() {
        if UserPreferences.getInstance.checkForUpdateFrequency == .never {
            print("Did not check for update: Check For Update Frequency = Never")
            return
        }
        
        if UserPreferences.getInstance.checkForUpdateFrequency != .everyLaunch {
            var nextCheckIn = UserPreferences.getInstance.lastUpdateCheckDate
            switch UserPreferences.getInstance.checkForUpdateFrequency {
            case .onceADay:
                nextCheckIn = Calendar.current.date(byAdding: .day, value: 1, to: nextCheckIn)!
            case .onceAWeek:
                nextCheckIn = Calendar.current.date(byAdding: .day, value: 7, to: nextCheckIn)!
            default:
                return
            }
            
            // I know that logically, the current date should be higher than nextCheckIn.
            // But for some reason, if I do it the correct way, the "return" is not hit, if we're not past the time to check for update.
            if Date() < nextCheckIn {
                print("Did not check for update: Check is due for later.")
                return
            }
        }
        
        DispatchQueue.main.async {
            self.checkForUpdates()
        }
    }
    
    func checkForUpdates() {
        let githubService = GithubService(requestHandler: RequestHandler())
        UserPreferences.getInstance.lastUpdateCheckDate = Date()
        
        githubService.getLatestReleases { result in
            switch result {
            case .success(let release):
                if let appVersionString = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, let localVersion = try? TagNameVersion(textVersion: appVersionString) {
                    if release.tagName > localVersion && String(describing: release.tagName) != UserPreferences.getInstance.skippedUpdateVersion {
                        print("Newer version available.")
                        self.latestRelease = release
                        DispatchQueue.main.sync {
                            self.openWindow(id: "update_window")
                        }
                    } else {
                        print("Up-to-date. Your version: \(String(describing: localVersion)). Newest: \(String(describing: release.tagName))")
                    }
                }
            case .failure(let error):
                print(error)
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainWindow = NSApp.windows[0]
        mainWindow.delegate = self
    
        // Register handling of leomard: protocol.
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleCustomURL(event:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.hide(nil)
        return false
    }
    
    @objc func handleCustomURL(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        if let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue {
            if let url = URL(string: urlString) {
                // Send as notification.
                NotificationCenter.default.post(name: NSNotification.Name("CustomURLReceived"), object: url)
            }
        }
    }
}
