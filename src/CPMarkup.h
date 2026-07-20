// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, CPTool) {
    CPToolSelect = 0,
    CPToolArrow,
    CPToolLine,
    CPToolRectangle,
    CPToolEllipse,
    CPToolPen,
    CPToolHighlighter,
    CPToolText,
    CPToolStep,
    CPToolPixelate,
    CPToolBlur,
    CPToolRedact,
    CPToolCount
};

/// One drawable annotation. All geometry is stored in canvas *view* coordinates
/// (top-left origin, since the canvas view is flipped). The same draw code is
/// used on screen and when flattening for export.
@interface CPMarkup : NSObject <NSCopying>

@property (nonatomic) CPTool tool;
@property (nonatomic, strong) NSMutableArray<NSValue *> *points; // NSPoint values
@property (nonatomic, strong) NSColor *color;
@property (nonatomic) CGFloat strokeWidth;
@property (nonatomic, copy) NSString *text;         // text tool + step label
@property (nonatomic) CGFloat fontSize;            // text tool + step label
@property (nonatomic, copy, nullable) NSString *fontName; // nil = system font
@property (nonatomic) NSInteger number;            // step tool

/// The font this annotation draws its text with, at the given size.
- (NSFont *)fontOfSize:(CGFloat)size;

+ (instancetype)annotationWithTool:(CPTool)tool color:(nullable NSColor *)color stroke:(CGFloat)stroke;

// Convenience for two-point shapes.
@property (nonatomic) NSPoint startPoint;
@property (nonatomic) NSPoint endPoint;
- (void)addPoint:(NSPoint)p;

/// Bounding rect in view coordinates (includes a little padding for handles).
- (NSRect)boundingRect;
/// Hit test for the Select tool.
- (BOOL)containsPoint:(NSPoint)p;
- (void)translateBy:(NSSize)delta;

/// Draw into the current graphics context (view coordinates). `base`,
/// `pixelated`, and `blurred` are full-canvas images used by the
/// pixelate/blur tools; `canvasRect` is the full canvas bounds.
- (void)drawWithBase:(NSImage *)base
           pixelated:(nullable NSImage *)pixelated
             blurred:(nullable NSImage *)blurred
          canvasRect:(NSRect)canvasRect;

/// Whether this annotation is complete enough to keep on mouse-up.
- (BOOL)isCommittable;

@end

NS_ASSUME_NONNULL_END
