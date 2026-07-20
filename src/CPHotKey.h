// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// Registers a single system-wide hotkey via Carbon's RegisterEventHotKey.
/// Carbon hotkeys don't require Accessibility permission to register.
@interface CPHotKey : NSObject

/// `keyCode` is a virtual key code (e.g. kVK_ANSI_A). `modifiers` uses Carbon
/// modifier masks (cmdKey, shiftKey, optionKey, controlKey).
- (instancetype)initWithKeyCode:(uint32_t)keyCode
                      modifiers:(uint32_t)modifiers
                        handler:(void (^)(void))handler;

/// YES if RegisterEventHotKey succeeded for this instance.
@property (nonatomic, readonly) BOOL registered;

/// Test whether a combo can be claimed as a global hotkey right now (catches
/// combos already held by another Captr action or the same app). Does not catch
/// OS-reserved combos, which register but never deliver events.
+ (BOOL)canRegisterKeyCode:(uint32_t)keyCode modifiers:(uint32_t)modifiers;

- (void)unregister;

@end

NS_ASSUME_NONNULL_END
