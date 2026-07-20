// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted after a capture hotkey is rebound, so the app re-registers it.
extern NSString *const CPHotKeysDidChangeNotification;

/// The Settings window: rebindable capture shortcuts plus output options.
@interface CPPreferencesController : NSWindowController

- (void)present;

@end

NS_ASSUME_NONNULL_END
