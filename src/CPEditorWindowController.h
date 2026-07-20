// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// The post-capture annotation editor. Presents the captured image on a canvas
/// with a tool bar, and exports (copy / save) the flattened result.
@interface CPEditorWindowController : NSWindowController

/// `image` is the freshly captured screenshot. `onClose` is called when the
/// editor window closes, so the owner can release this controller.
- (instancetype)initWithCGImage:(CGImageRef)image onClose:(nullable void (^)(void))onClose;

- (void)present;

@end

NS_ASSUME_NONNULL_END
