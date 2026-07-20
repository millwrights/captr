// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>
#import "CPMarkup.h"

NS_ASSUME_NONNULL_BEGIN

/// The editable drawing surface: a base screenshot with a stack of vector
/// annotations on top. Handles tool interaction, selection/move, undo/redo,
/// inline text editing, and flattening to an image for export.
@interface CPCanvasView : NSView

/// Initialize with the captured image (its pixel size drives export fidelity).
- (instancetype)initWithCGImage:(CGImageRef)image logicalSize:(NSSize)logicalSize;

@property (nonatomic) CPTool currentTool;
@property (nonatomic, strong) NSColor *strokeColor;
@property (nonatomic) CGFloat strokeWidth;

/// Point size of the captured image in device pixels — used for export scaling.
@property (nonatomic, readonly) NSSize imagePixelSize;

- (void)deleteSelection;

/// The font used for new text — seeds the shared Font panel.
- (NSFont *)currentTextFont;

/// Flatten base image + annotations into a new full-resolution CGImage.
/// Caller owns the result (CGImageRelease).
- (nullable CGImageRef)newFlattenedImage CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
