// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPCanvasView.h"
#import <CoreImage/CoreImage.h>

@interface CPCanvasView () <NSTextFieldDelegate>
@property (nonatomic, strong) NSImage *baseImage;
@property (nonatomic, strong) NSImage *pixelatedImage; // lazy
@property (nonatomic, strong) NSImage *blurredImage;   // lazy
@property (nonatomic, strong) NSMutableArray<CPMarkup *> *annotations;
@property (nonatomic, strong) CPMarkup *inProgress;   // being drawn (not yet committed)
@property (nonatomic, strong) CPMarkup *selected;     // Select-tool target
@property (nonatomic) NSPoint lastDragPoint;
@property (nonatomic) BOOL didSnapshotForMove;
@property (nonatomic) NSInteger stepCounter;
@property (nonatomic, strong) NSTextField *editingField;
@property (nonatomic, strong) CPMarkup *editingAnnotation;
@property (nonatomic) BOOL editingIsNew;              // new text vs existing (step label)
@property (nonatomic, copy) NSString *currentFontName; // nil = system; for new text
@property (nonatomic) CGFloat currentTextSize;
@property (nonatomic, strong) NSUndoManager *ownUndo;
@end

@implementation CPCanvasView

- (instancetype)initWithCGImage:(CGImageRef)image logicalSize:(NSSize)logicalSize {
    if ((self = [super initWithFrame:NSMakeRect(0, 0, logicalSize.width, logicalSize.height)])) {
        _imagePixelSize = NSMakeSize(CGImageGetWidth(image), CGImageGetHeight(image));
        _baseImage = [[NSImage alloc] initWithCGImage:image size:logicalSize];
        _annotations = [NSMutableArray array];
        _currentTool = CPToolArrow;
        _strokeColor = [NSColor systemRedColor];
        _strokeWidth = 3.0;
        _stepCounter = 1;
        _currentTextSize = 18.0;
    }
    return self;
}

- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)wantsUpdateLayer { return NO; }

// Own the undo manager explicitly instead of relying on the responder chain,
// so annotation edits and the editor's Undo/Redo buttons share one instance.
- (NSUndoManager *)undoManager {
    if (!_ownUndo) _ownUndo = [[NSUndoManager alloc] init];
    return _ownUndo;
}

#pragma mark - Rendering

- (void)drawContentInRect:(NSRect)rect {
    [self.baseImage drawInRect:rect fromRect:NSZeroRect
                     operation:NSCompositingOperationCopy fraction:1.0
                respectFlipped:YES hints:nil];
    for (CPMarkup *a in self.annotations) {
        [a drawWithBase:self.baseImage pixelated:[self pixelatedImage]
                blurred:[self blurredImage] canvasRect:rect];
    }
    if (self.inProgress) {
        [self.inProgress drawWithBase:self.baseImage pixelated:[self pixelatedImage]
                              blurred:[self blurredImage] canvasRect:rect];
    }
}

- (void)drawRect:(NSRect)dirtyRect {
    [self drawContentInRect:self.bounds];
    if (self.selected) {
        NSRect r = [self.selected boundingRect];
        [[NSColor colorWithCalibratedRed:0.20 green:0.55 blue:1.0 alpha:0.9] setStroke];
        NSBezierPath *p = [NSBezierPath bezierPathWithRect:r];
        p.lineWidth = 1.0;
        CGFloat dash[] = {4, 3}; [p setLineDash:dash count:2 phase:0];
        [p stroke];
    }
}

#pragma mark - Lazy processed images

- (NSImage *)pixelatedImage {
    if (_pixelatedImage) return _pixelatedImage;
    // Downsample hard, then it's drawn back up with nearest-neighbor = blocks.
    NSSize small = NSMakeSize(MAX(self.bounds.size.width / 14.0, 1),
                              MAX(self.bounds.size.height / 14.0, 1));
    NSImage *img = [[NSImage alloc] initWithSize:small];
    [img lockFocus];
    [NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationNone;
    [self.baseImage drawInRect:NSMakeRect(0, 0, small.width, small.height)
                      fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    [img unlockFocus];
    _pixelatedImage = img;
    return _pixelatedImage;
}

- (NSImage *)blurredImage {
    if (_blurredImage) return _blurredImage;
    CIImage *ci = [[CIImage alloc] initWithData:[self.baseImage TIFFRepresentation]];
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blur setValue:ci forKey:kCIInputImageKey];
    [blur setValue:@8.0 forKey:kCIInputRadiusKey];
    CIImage *out = blur.outputImage;
    NSRect extent = ci.extent; // clamp to original extent (blur grows it)
    NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:[out imageByCroppingToRect:extent]];
    NSImage *img = [[NSImage alloc] initWithSize:self.bounds.size];
    [img addRepresentation:rep];
    _blurredImage = img;
    return _blurredImage;
}

#pragma mark - Tool / style setters

- (void)setCurrentTool:(CPTool)currentTool {
    _currentTool = currentTool;
    [self commitTextEditingIfNeeded];
    if (currentTool != CPToolSelect) { self.selected = nil; [self setNeedsDisplay:YES]; }
    [[self window] invalidateCursorRectsForView:self];
}

- (void)setStrokeColor:(NSColor *)strokeColor {
    _strokeColor = strokeColor;
    if (self.selected) {
        [self snapshotForAction:@"Change Color"];
        self.selected.color = strokeColor;
        [self setNeedsDisplay:YES];
    }
}

- (void)setStrokeWidth:(CGFloat)strokeWidth {
    _strokeWidth = strokeWidth;
    if (self.selected) {
        [self snapshotForAction:@"Change Thickness"];
        self.selected.strokeWidth = strokeWidth;
        [self setNeedsDisplay:YES];
    }
}

#pragma mark - Cursor

- (void)resetCursorRects {
    NSCursor *cursor = (self.currentTool == CPToolSelect) ? [NSCursor arrowCursor] : [NSCursor crosshairCursor];
    [self addCursorRect:self.bounds cursor:cursor];
}

#pragma mark - Undo

- (void)snapshotForAction:(NSString *)name {
    NSArray<CPMarkup *> *snapshot = [[NSArray alloc] initWithArray:self.annotations copyItems:YES];
    [[self.undoManager prepareWithInvocationTarget:self] restoreAnnotations:snapshot name:name];
    [self.undoManager setActionName:name];
}

- (void)restoreAnnotations:(NSArray<CPMarkup *> *)snapshot name:(NSString *)name {
    // Register the inverse so redo works, then swap in the snapshot.
    NSArray<CPMarkup *> *current = [[NSArray alloc] initWithArray:self.annotations copyItems:YES];
    [[self.undoManager prepareWithInvocationTarget:self] restoreAnnotations:current name:name];
    [self.undoManager setActionName:name];
    self.annotations = [snapshot mutableCopy];
    self.selected = nil;
    [self setNeedsDisplay:YES];
}

#pragma mark - Mouse

- (void)mouseDown:(NSEvent *)event {
    [self commitTextEditingIfNeeded];
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];

    if (self.currentTool == CPToolSelect) {
        self.selected = [self annotationAtPoint:p];
        self.lastDragPoint = p;
        self.didSnapshotForMove = NO;
        [self setNeedsDisplay:YES];
        return;
    }
    if (self.currentTool == CPToolStep) {
        [self snapshotForAction:@"Add Step"];
        CGFloat rad = self.strokeWidth * 4 + 8;
        CPMarkup *a = [CPMarkup annotationWithTool:CPToolStep color:self.strokeColor stroke:self.strokeWidth];
        a.startPoint = p; a.number = self.stepCounter++;
        a.fontName = self.currentFontName;
        a.fontSize = rad * 0.9;          // label height ≈ badge
        [self.annotations addObject:a];
        [self setNeedsDisplay:YES];
        // Immediately let the user type an explanation to the right of the badge.
        CGFloat lh = a.fontSize + 8;
        NSRect frame = NSMakeRect(p.x + rad + 6, p.y - lh / 2, 220, lh);
        [self beginTextEditingForAnnotation:a fieldFrame:frame isNew:NO];
        return;
    }
    if (self.currentTool == CPToolText) {
        CPMarkup *a = [CPMarkup annotationWithTool:CPToolText color:self.strokeColor stroke:self.strokeWidth];
        a.startPoint = p;
        a.fontName = self.currentFontName;
        a.fontSize = self.currentTextSize;
        [self beginTextEditingForAnnotation:a
                                 fieldFrame:NSMakeRect(p.x, p.y, 220, a.fontSize + 8) isNew:YES];
        return;
    }
    // Drawing tools: build an in-progress annotation.
    CPMarkup *a = [CPMarkup annotationWithTool:self.currentTool color:self.strokeColor stroke:self.strokeWidth];
    a.startPoint = p; a.endPoint = p;
    if (self.currentTool == CPToolPen || self.currentTool == CPToolHighlighter) {
        [a.points removeAllObjects]; [a addPoint:p];
    }
    self.inProgress = a;
}

- (void)mouseDragged:(NSEvent *)event {
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    if (self.currentTool == CPToolSelect) {
        if (!self.selected) return;
        if (!self.didSnapshotForMove) { [self snapshotForAction:@"Move"]; self.didSnapshotForMove = YES; }
        [self.selected translateBy:NSMakeSize(p.x - self.lastDragPoint.x, p.y - self.lastDragPoint.y)];
        self.lastDragPoint = p;
        [self setNeedsDisplay:YES];
        return;
    }
    if (!self.inProgress) return;
    if (self.currentTool == CPToolPen || self.currentTool == CPToolHighlighter) {
        [self.inProgress addPoint:p];
    } else {
        self.inProgress.endPoint = p;
    }
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (self.currentTool == CPToolSelect) return;
    if (!self.inProgress) return;
    CPMarkup *a = self.inProgress;
    self.inProgress = nil;
    if ([a isCommittable]) {
        [self snapshotForAction:@"Add Annotation"];
        [self.annotations addObject:a];
    }
    [self setNeedsDisplay:YES];
}

- (CPMarkup *)annotationAtPoint:(NSPoint)p {
    for (CPMarkup *a in [self.annotations reverseObjectEnumerator]) {
        if ([a containsPoint:p]) return a;
    }
    return nil;
}

#pragma mark - Keyboard

- (void)keyDown:(NSEvent *)event {
    unichar c = [event.charactersIgnoringModifiers length] ? [event.charactersIgnoringModifiers characterAtIndex:0] : 0;
    if (c == NSDeleteCharacter || c == NSBackspaceCharacter || c == NSDeleteFunctionKey) {
        [self deleteSelection];
    } else {
        [super keyDown:event];
    }
}

- (void)deleteSelection {
    if (!self.selected) return;
    [self snapshotForAction:@"Delete"];
    [self.annotations removeObject:self.selected];
    self.selected = nil;
    [self setNeedsDisplay:YES];
}

#pragma mark - Inline text editing

- (void)beginTextEditingForAnnotation:(CPMarkup *)a fieldFrame:(NSRect)frame isNew:(BOOL)isNew {
    self.editingAnnotation = a;
    self.editingIsNew = isNew;

    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.font = [a fontOfSize:a.fontSize];
    field.textColor = a.color;
    field.backgroundColor = [NSColor colorWithCalibratedWhite:1.0 alpha:0.85];
    field.bordered = YES;
    field.focusRingType = NSFocusRingTypeNone;
    field.delegate = self;
    field.stringValue = a.text ?: @"";
    [self addSubview:field];
    self.editingField = field;
    [self.window makeFirstResponder:field];
}

- (void)controlTextDidEndEditing:(NSNotification *)note {
    [self commitTextEditingIfNeeded];
}

- (void)commitTextEditingIfNeeded {
    if (!self.editingField) return;
    NSString *text = self.editingField.stringValue;
    NSFont *usedFont = self.editingField.font;   // may have been changed via the font panel
    BOOL isNew = self.editingIsNew;
    NSTextField *field = self.editingField;
    CPMarkup *a = self.editingAnnotation;
    self.editingField = nil;
    self.editingAnnotation = nil;
    [field removeFromSuperview];
    if (!a) return;

    if (usedFont) {
        a.fontName = usedFont.fontName;
        a.fontSize = usedFont.pointSize;
        self.currentFontName = usedFont.fontName;
        self.currentTextSize = usedFont.pointSize;
    }

    if (isNew) {
        // New text annotation: keep only if the user typed something.
        if (text.length > 0) {
            a.text = text;
            [self snapshotForAction:@"Add Text"];
            [self.annotations addObject:a];
        }
    } else {
        // Existing annotation (e.g. a step badge): just store its label.
        a.text = text;
    }
    [self setNeedsDisplay:YES];
}

#pragma mark - Font

/// The font used for new text (and the seed for the Font panel).
- (NSFont *)currentTextFont {
    NSFont *f = self.currentFontName ? [NSFont fontWithName:self.currentFontName size:self.currentTextSize] : nil;
    return f ?: [NSFont systemFontOfSize:self.currentTextSize weight:NSFontWeightSemibold];
}

// Sent by the shared Font panel. Applies to the field being edited, the
// selected text/step annotation, and becomes the default for new text.
- (void)changeFont:(id)sender {
    NSFont *newFont = [sender convertFont:[self currentTextFont]];
    if (!newFont) return;
    self.currentFontName = newFont.fontName;
    self.currentTextSize = newFont.pointSize;

    if (self.editingField) {
        self.editingField.font = newFont;
    }
    if (self.selected && (self.selected.tool == CPToolText || self.selected.tool == CPToolStep)) {
        [self snapshotForAction:@"Change Font"];
        self.selected.fontName = newFont.fontName;
        self.selected.fontSize = newFont.pointSize;
        [self setNeedsDisplay:YES];
    }
}

- (BOOL)validateMenuItem:(NSMenuItem *)item { return YES; }

#pragma mark - Export

- (CGImageRef)newFlattenedImage {
    NSSize px = self.imagePixelSize;
    NSSize view = self.bounds.size;
    size_t w = (size_t)px.width, h = (size_t)px.height;
    if (w == 0 || h == 0 || view.width <= 0 || view.height <= 0) return NULL;

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef cg = CGBitmapContextCreate(NULL, w, h, 8, 0, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!cg) return NULL;

    // Map view points -> pixels, with a top-left origin, and wrap it as a
    // *flipped* NSGraphicsContext so AppKit drawing (respectFlipped: images,
    // text) renders identically to the on-screen flipped view — no mirroring.
    CGContextScaleCTM(cg, px.width / view.width, px.height / view.height);
    CGContextTranslateCTM(cg, 0, view.height);
    CGContextScaleCTM(cg, 1, -1);

    NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES];
    [NSGraphicsContext saveGraphicsState];
    [NSGraphicsContext setCurrentContext:ctx];
    [self drawContentInRect:self.bounds];
    [NSGraphicsContext restoreGraphicsState];

    CGImageRef img = CGBitmapContextCreateImage(cg);
    CGContextRelease(cg);
    return img; // caller owns it (CGImageRelease)
}

@end
