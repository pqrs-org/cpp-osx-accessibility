#import "AppDelegate.h"
#import <Cocoa/Cocoa.h>

static void setupMainMenu(void) {
  NSMenu* mainMenu = [[NSMenu alloc] initWithTitle:@""];
  NSMenuItem* appMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  NSMenuItem* fileMenuItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
  [mainMenu addItem:appMenuItem];
  [mainMenu addItem:fileMenuItem];

  NSMenu* appMenu = [[NSMenu alloc] initWithTitle:@""];
  NSString* appName = NSProcessInfo.processInfo.processName;
  NSString* quitTitle = [NSString stringWithFormat:@"Quit %@", appName];

  NSMenuItem* quitItem = [[NSMenuItem alloc] initWithTitle:quitTitle
                                                    action:@selector(terminate:)
                                             keyEquivalent:@"q"];
  [appMenu addItem:quitItem];
  [appMenuItem setSubmenu:appMenu];

  NSMenu* fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
  NSMenuItem* closeItem = [[NSMenuItem alloc] initWithTitle:@"Close Window"
                                                     action:@selector(performClose:)
                                              keyEquivalent:@"w"];
  [fileMenu addItem:closeItem];
  [fileMenuItem setSubmenu:fileMenu];

  [NSApp setMainMenu:mainMenu];
}

int main(int argc, const char* argv[]) {
  @autoreleasepool {
    NSApplication* application = [NSApplication sharedApplication];
    AppDelegate* delegate = [[AppDelegate alloc] init];
    application.delegate = delegate;
    setupMainMenu();
    return NSApplicationMain(argc, argv);
  }
}
