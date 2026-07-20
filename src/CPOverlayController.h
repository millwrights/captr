// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CPOverlayMode) {
    CPOverlayModeRegion,  // drag a rectangle
    CPOverlayModeWindow,  // hover + click a window
};

/// Called with the captured image (caller owns it — CGImageRelease when done),
/// or NULL if the user cancelled (Esc / right-click).
typedef void (^CPOverlayCompletion)(CGImageRef _Nullable image);

/// A full-screen overlay for interactively selecting a region or a window,
/// then capturing it. Retains itself for the duration of the interaction.
@interface CPOverlayController : NSObject

- (void)beginWithMode:(CPOverlayMode)mode completion:(CPOverlayCompletion)completion;

@end

NS_ASSUME_NONNULL_END
