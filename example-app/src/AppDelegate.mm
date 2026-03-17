#import "AppDelegate.h"
#include <pqrs/osx/accessibility.hpp>

namespace {
NSTextField* makeLabel(NSRect frame, CGFloat fontSize, NSColor* color) {
  auto label = [[NSTextField alloc] initWithFrame:frame];
  label.bezeled = NO;
  label.drawsBackground = NO;
  label.editable = NO;
  label.selectable = YES;
  label.font = [NSFont systemFontOfSize:fontSize];
  label.textColor = color;
  label.lineBreakMode = NSLineBreakByTruncatingTail;
  return label;
}

NSString* makeUTF8String(const std::optional<std::string>& value, NSString* fallback = @"") {
  if (!value) {
    return fallback;
  }

  if (auto string = [NSString stringWithUTF8String:value->c_str()]) {
    return string;
  }

  return fallback;
}
} // namespace

@interface AppDelegate ()

@property(strong) NSWindow* window;
@property(strong) NSTextField* permissionLabel;
@property(strong) NSTextField* applicationLabel;
@property(strong) NSTextField* roleLabel;
@property(strong) NSTextField* detailLabel;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification {
  (void)notification;

  [self buildWindow];

  if (!pqrs::osx::accessibility::is_process_trusted()) {
    self.permissionLabel.stringValue = @"Accessibility permission is required. A system prompt will appear.";
    pqrs::osx::accessibility::is_process_trusted_with_prompt();
  } else {
    self.permissionLabel.stringValue = @"Accessibility permission is granted.";
  }

  pqrs::dispatcher::extra::initialize_shared_dispatcher();
  pqrs::osx::accessibility::monitor::initialize_shared_monitor(pqrs::dispatcher::extra::get_shared_dispatcher());

  if (auto monitor = pqrs::osx::accessibility::monitor::get_shared_monitor().lock()) {
    AppDelegate* appDelegate = self;

    monitor->frontmost_application_changed.connect([appDelegate](auto&& application_ptr) {
      NSMutableArray<NSString*>* lines = [NSMutableArray array];

      if (!application_ptr) {
        [lines addObject:@"Application: none"];
      } else {
        NSString* name = makeUTF8String(application_ptr->get_name(), @"(unknown)");
        [lines addObject:[NSString stringWithFormat:@"Application: %@", name]];

        if (auto& bundleIdentifier = application_ptr->get_bundle_identifier()) {
          [lines addObject:[NSString stringWithFormat:@"Bundle ID: %@", makeUTF8String(bundleIdentifier)]];
        }
        if (auto& pid = application_ptr->get_pid()) {
          [lines addObject:[NSString stringWithFormat:@"PID: %d", *pid]];
        }
      }

      NSString* text = [lines componentsJoinedByString:@"\n"];

      dispatch_async(dispatch_get_main_queue(), ^{
        appDelegate.applicationLabel.stringValue = text;
      });
    });

    monitor->focused_ui_element_changed.connect([appDelegate](auto&& focused_ui_element_ptr) {
      NSString* roleText = nil;
      NSString* detailText = @"";

      if (!focused_ui_element_ptr) {
        roleText = @"Focused element: none";
      } else {
        NSString* role = makeUTF8String(focused_ui_element_ptr->get_role(), @"(unknown)");
        NSString* subrole = makeUTF8String(focused_ui_element_ptr->get_subrole());
        roleText = subrole.length > 0
                       ? [NSString stringWithFormat:@"Focused element: %@ / %@", role, subrole]
                       : [NSString stringWithFormat:@"Focused element: %@", role];

        NSMutableArray<NSString*>* lines = [NSMutableArray array];
        if (auto& roleDescription = focused_ui_element_ptr->get_role_description()) {
          [lines addObject:[NSString stringWithFormat:@"Role description: %@", makeUTF8String(roleDescription)]];
        }
        if (auto& title = focused_ui_element_ptr->get_title()) {
          [lines addObject:[NSString stringWithFormat:@"Title: %@", makeUTF8String(title)]];
        }
        if (auto& description = focused_ui_element_ptr->get_description()) {
          [lines addObject:[NSString stringWithFormat:@"Description: %@", makeUTF8String(description)]];
        }
        if (auto& identifier = focused_ui_element_ptr->get_identifier()) {
          [lines addObject:[NSString stringWithFormat:@"Identifier: %@", makeUTF8String(identifier)]];
        }

        detailText = [lines componentsJoinedByString:@"\n"];
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        appDelegate.roleLabel.stringValue = roleText;
        appDelegate.detailLabel.stringValue = detailText;
      });
    });

    monitor->trigger();
  }
}

- (void)applicationWillTerminate:(NSNotification*)notification {
  (void)notification;

  pqrs::osx::accessibility::monitor::terminate_shared_monitor();
  pqrs::dispatcher::extra::terminate_shared_dispatcher();
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender {
  (void)sender;
  return YES;
}

- (void)buildWindow {
  self.window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 680, 320)
                                            styleMask:(NSWindowStyleMaskTitled |
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskMiniaturizable |
                                                       NSWindowStyleMaskResizable)
                                              backing:NSBackingStoreBuffered
                                                defer:NO];
  self.window.title = @"Accessibility Monitor Example";
  self.window.level = NSFloatingWindowLevel;
  self.window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;
  [self.window center];

  auto contentView = self.window.contentView;

  auto headingLabel = makeLabel(NSMakeRect(20, 270, 640, 24), 20, NSColor.labelColor);
  headingLabel.stringValue = @"Frontmost application and focused element";
  [contentView addSubview:headingLabel];

  self.permissionLabel = makeLabel(NSMakeRect(20, 236, 640, 20), 12, NSColor.secondaryLabelColor);
  [contentView addSubview:self.permissionLabel];

  self.applicationLabel = makeLabel(NSMakeRect(20, 156, 640, 64), 13, NSColor.labelColor);
  self.applicationLabel.usesSingleLineMode = NO;
  [contentView addSubview:self.applicationLabel];

  self.roleLabel = makeLabel(NSMakeRect(20, 120, 640, 20), 13, NSColor.labelColor);
  [contentView addSubview:self.roleLabel];

  self.detailLabel = makeLabel(NSMakeRect(20, 24, 640, 84), 13, NSColor.secondaryLabelColor);
  self.detailLabel.usesSingleLineMode = NO;
  [contentView addSubview:self.detailLabel];

  [self.window makeKeyAndOrderFront:nil];
}

@end
