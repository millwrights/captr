// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>
#import "CPAppDelegate.h"

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        CPAppDelegate *delegate = [[CPAppDelegate alloc] init];
        app.delegate = delegate;
        // Menu-bar agent: no Dock icon, no main menu.
        [app setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [app run];
    }
    return 0;
}
