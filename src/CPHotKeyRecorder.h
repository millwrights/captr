// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A button that records a global-hotkey combination. Values are Carbon key
/// codes / modifier masks so they can be handed straight to CPHotKey.
@interface CPHotKeyRecorder : NSButton

@property (nonatomic) uint32_t keyCode;
@property (nonatomic) uint32_t carbonModifiers;
@property (nonatomic, copy, nullable) void (^onChange)(uint32_t keyCode, uint32_t carbonModifiers);

/// Human-readable combo, e.g. "⇧⌘A".
+ (NSString *)stringForKeyCode:(uint32_t)keyCode carbonModifiers:(uint32_t)mods;

/// Just the key glyph/character for `keyCode` (no modifiers), e.g. "A" or "↩".
+ (NSString *)keyStringForKeyCode:(uint32_t)keyCode;

@end

NS_ASSUME_NONNULL_END
