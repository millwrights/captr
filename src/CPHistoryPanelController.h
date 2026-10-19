// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A floating panel listing the clipboard history. Arrow keys move, Return
/// (or double-click) copies the image and closes, Delete removes, Esc closes.
/// Focus returns to the previously active app so ⌘V pastes right away.
@interface CPHistoryPanelController : NSWindowController

/// Show the panel, or close it if it's already showing.
- (void)toggle;

@end

NS_ASSUME_NONNULL_END
