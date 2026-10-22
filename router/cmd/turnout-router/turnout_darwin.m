#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>

extern void TurnoutHandleURL(char *url, int forcePicker);

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
