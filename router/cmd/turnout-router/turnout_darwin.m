#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import <ServiceManagement/ServiceManagement.h>

extern void TurnoutHandleURL(char *url, int forcePicker);
extern void TurnoutPrewarm(void);

@interface TurnoutDelegate : NSObject <NSApplicationDelegate>
@end

@implementation TurnoutDelegate

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [[NSAppleEventManager sharedAppleEventManager]
        setEventHandler:self
            andSelector:@selector(handleGetURLEvent:withReplyEvent:)
          forEventClass:kInternetEventClass
             andEventID:kAEGetURL];
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event
         withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    (void)replyEvent;
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    if (!urlString || urlString.length == 0) {
        return;
    }

    // Holding Option while clicking a link skips handlers/frecency/default and shows the picker.
    BOOL forcePicker = ([NSEvent modifierFlags] & NSEventModifierFlagOption) != 0;

    const char *utf8 = [urlString UTF8String];
    char *copy = strdup(utf8);
    if (!copy) {
        return;
    }
    TurnoutHandleURL(copy, forcePicker ? 1 : 0);
    free(copy);
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    [self registerLoginItemOnce];
    TurnoutPrewarm();
}

// Start at login so neither the router nor the picker pays a cold start on the first link.
// Registered once per install (from /Applications only, never dev builds); if the user later
// turns it off in Login Items, that choice sticks.
- (void)registerLoginItemOnce {
    if (![[[NSBundle mainBundle] bundlePath] hasPrefix:@"/Applications/"]) {
        return;
    }
    NSString *key = @"TurnoutLoginItemRegistered";
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:key]) {
        return;
    }
    if (@available(macOS 13.0, *)) {
        NSError *err = nil;
        if ([[SMAppService mainAppService] registerAndReturnError:&err]) {
            [defaults setBool:YES forKey:key];
        } else {
            NSLog(@"Turnout: login item registration failed: %@", err);
        }
    }
}

@end

void turnout_run_app(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        TurnoutDelegate *delegate = [[TurnoutDelegate alloc] init];
        [NSApp setDelegate:delegate];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [NSApp run];
    }
}
