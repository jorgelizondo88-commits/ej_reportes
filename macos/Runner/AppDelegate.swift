import Cocoa
import FlutterMacOS
import GoogleSignIn

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
       let image = NSImage(contentsOfFile: iconPath) {
      NSApp.applicationIconImage = image
    } else if let namedImage = NSImage(named: "AppIcon") {
      NSApp.applicationIconImage = namedImage
    }
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      GIDSignIn.sharedInstance.handle(url)
    }
  }
}
