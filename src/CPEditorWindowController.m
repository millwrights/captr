// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPEditorWindowController.h"
#import "CPCanvasView.h"
#import "CPExporter.h"
#import "CPDefaults.h"

static const CGFloat kBarHeight   = 60.0;   // roomy tool bar
static const CGFloat kMinBarWidth = 1100.0; // fits every control without crowding

@interface CPEditorWindowController () <NSWindowDelegate>
@property (nonatomic, strong) CPCanvasView *canvas;
@property (nonatomic, strong) NSSegmentedControl *toolControl;
@property (nonatomic, strong) NSTextField *sizeLabel;
@property (nonatomic, copy) void (^onClose)(void);
@end

// Tools shown in the bar, in order, with their SF Symbol + tooltip.
static CPTool kBarTools[] = {
    CPToolSelect, CPToolArrow, CPToolLine, CPToolRectangle, CPToolEllipse,
    CPToolPen, CPToolHighlighter, CPToolText, CPToolStep,
    CPToolPixelate, CPToolBlur, CPToolRedact
};
static NSString *kBarSymbols[] = {
    @"cursorarrow", @"arrow.up.right", @"line.diagonal", @"rectangle", @"circle",
    @"scribble.variable", @"highlighter", @"textformat", @"1.circle.fill",
    @"square.grid.3x3.fill", @"drop.fill", @"rectangle.fill"
};
static NSString *kBarTips[] = {
    @"Select / move", @"Arrow", @"Line", @"Rectangle", @"Ellipse",
    @"Pen", @"Highlighter", @"Text", @"Step number",
    @"Pixelate", @"Blur", @"Redact"
};
static const NSInteger kBarToolCount = 12;

@implementation CPEditorWindowController

- (instancetype)initWithCGImage:(CGImageRef)image onClose:(void (^)(void))onClose {
    NSSize pixelSize = NSMakeSize(CGImageGetWidth(image), CGImageGetHeight(image));
    CGFloat backing = [NSScreen mainScreen].backingScaleFactor ?: 2.0;
    NSSize logical = NSMakeSize(pixelSize.width / backing, pixelSize.height / backing);

    // Cap the canvas to 85% of the visible screen; scale down proportionally.
    NSRect vis = [NSScreen mainScreen].visibleFrame;
    CGFloat maxW = vis.size.width * 0.85;
    CGFloat maxH = (vis.size.height - kBarHeight) * 0.85;
    CGFloat fit = MIN(1.0, MIN(maxW / logical.width, maxH / logical.height));
    NSSize canvasSize = NSMakeSize(round(logical.width * fit), round(logical.height * fit));

    CGFloat contentW = MAX(canvasSize.width, kMinBarWidth);
    CGFloat contentH = canvasSize.height + kBarHeight;

    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, contentW, contentH)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                    backing:NSBackingStoreBuffered defer:NO];
    window.title = @"Captr — Edit";
    window.releasedWhenClosed = NO;

    if ((self = [super initWithWindow:window])) {
        _onClose = [onClose copy];
        window.delegate = self;

        NSView *content = window.contentView;
        _canvas = [[CPCanvasView alloc] initWithCGImage:image logicalSize:canvasSize];
        _canvas.frame = NSMakeRect(round((contentW - canvasSize.width) / 2), 0,
                                   canvasSize.width, canvasSize.height);
        _canvas.currentTool = CPToolArrow;
        [content addSubview:_canvas];

        [self buildBarInContent:content width:contentW y:canvasSize.height];
        [self selectToolSegmentForTool:CPToolArrow];
    }
    return self;
}

- (void)present {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window center];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.canvas];
}

- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window { return self.canvas.undoManager; }

#pragma mark - Tool bar

- (void)buildBarInContent:(NSView *)content width:(CGFloat)width y:(CGFloat)y {
    NSView *bar = [[NSView alloc] initWithFrame:NSMakeRect(0, y, width, kBarHeight)];
    bar.wantsLayer = YES;
    bar.layer.backgroundColor = [NSColor controlBackgroundColor].CGColor;
    bar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [content addSubview:bar];

    // Hairline separating the tool bar from the canvas below it.
    NSBox *bottom = [[NSBox alloc] initWithFrame:NSMakeRect(0, 0, width, 1)];
    bottom.boxType = NSBoxSeparator;
    bottom.autoresizingMask = NSViewWidthSizable;
    [bar addSubview:bottom];

    const CGFloat h = 30;                       // control height
    const CGFloat cy = round((kBarHeight - h) / 2);
    CGFloat x = 16;

    // --- Tools ------------------------------------------------------------
    // Larger, medium-weight glyphs render far more legibly than the default
    // (small, thin) symbol size inside a segmented control.
    NSImageSymbolConfiguration *glyph =
        [NSImageSymbolConfiguration configurationWithPointSize:16 weight:NSFontWeightMedium];
    const CGFloat segW = 36;
    NSSegmentedControl *seg = [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(x, cy, segW * kBarToolCount, h)];
    seg.segmentCount = kBarToolCount;
    seg.segmentStyle = NSSegmentStyleSeparated;   // clearer per-tool buttons + selection
    seg.trackingMode = NSSegmentSwitchTrackingSelectOne;
    seg.target = self; seg.action = @selector(toolChanged:);
    for (NSInteger i = 0; i < kBarToolCount; i++) {
        NSImage *img = [[NSImage imageWithSystemSymbolName:kBarSymbols[i] accessibilityDescription:kBarTips[i]]
                        imageWithSymbolConfiguration:glyph];
        [seg setImage:img forSegment:i];
        [seg setWidth:segW forSegment:i];
        [seg setToolTip:kBarTips[i] forSegment:i];
    }
    [bar addSubview:seg];
    self.toolControl = seg;
    x += seg.frame.size.width + 14;
    x = [self addDividerAtX:x inBar:bar];

    // --- Color + thickness ------------------------------------------------
    NSColorWell *well = [[NSColorWell alloc] initWithFrame:NSMakeRect(x, cy, 46, h)];
    well.color = self.canvas.strokeColor;
    well.target = self; well.action = @selector(colorChanged:);
    well.toolTip = @"Color";
    [bar addSubview:well];
    x += 46 + 12;

    NSSlider *slider = [[NSSlider alloc] initWithFrame:NSMakeRect(x, cy, 120, h)];
    slider.minValue = 1; slider.maxValue = 20; slider.doubleValue = self.canvas.strokeWidth;
    slider.target = self; slider.action = @selector(thicknessChanged:);
    slider.toolTip = @"Thickness";
    [bar addSubview:slider];
    x += 120 + 8;

    self.sizeLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(x, cy, 44, h)];
    self.sizeLabel.bezeled = NO; self.sizeLabel.drawsBackground = NO;
    self.sizeLabel.editable = NO; self.sizeLabel.selectable = NO;
    self.sizeLabel.font = [NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightRegular];
    self.sizeLabel.textColor = [NSColor secondaryLabelColor];
    self.sizeLabel.alignment = NSTextAlignmentLeft;
    [self.sizeLabel.cell setLineBreakMode:NSLineBreakByClipping];
    [self.sizeLabel setStringValue:[self sizeString]];
    // Vertically center the single line of text within the control height.
    self.sizeLabel.frame = NSMakeRect(x, cy + (h - 17) / 2, 44, 17);
    [bar addSubview:self.sizeLabel];
    x += 44 + 12;

    // Font picker (opens the system Font panel) for the Text tool & step labels.
    NSButton *fontBtn = [[NSButton alloc] initWithFrame:NSMakeRect(x, cy, 34, h)];
    fontBtn.bezelStyle = NSBezelStyleTexturedRounded;
    fontBtn.image = [[NSImage imageWithSystemSymbolName:@"textformat.size" accessibilityDescription:@"Text font"]
                     imageWithSymbolConfiguration:glyph];
    fontBtn.imagePosition = NSImageOnly;
    fontBtn.toolTip = @"Choose text font & size";
    fontBtn.target = self; fontBtn.action = @selector(chooseFont:);
    [bar addSubview:fontBtn];
    x += 34;

    // --- Actions, right-aligned. Two groups split by a divider:
    //     edit (Undo · Redo · Delete)  |  output (Copy · Copy & Close · Save · Close).
    //     Undo/Redo also bind ⌘Z / ⇧⌘Z (no Edit menu exists in this agent app).
    CGFloat rx = width - 16;
    rx = [self addButton:@"Close" symbol:@"xmark" action:@selector(closeEditor:)
                     key:@"" mask:0 rightEdge:rx inBar:bar cy:cy];
    rx = [self addButton:@"Save" symbol:@"square.and.arrow.down" action:@selector(saveImage:)
                     key:@"" mask:0 rightEdge:rx inBar:bar cy:cy];
    rx = [self addButton:@"Copy & Close" symbol:@"doc.on.clipboard" action:@selector(copyAndClose:)
                     key:@"" mask:0 rightEdge:rx inBar:bar cy:cy];
    rx = [self addButton:@"Copy" symbol:@"doc.on.doc" action:@selector(copyImage:)
                     key:@"" mask:0 rightEdge:rx inBar:bar cy:cy];
    rx = [self addDividerAtRightEdge:rx inBar:bar];
    rx = [self addButton:@"Delete selection" symbol:@"trash" action:@selector(deleteSel:)
                     key:@"" mask:0 rightEdge:rx inBar:bar cy:cy];
    rx = [self addButton:@"Redo  ⇧⌘Z" symbol:@"arrow.uturn.forward" action:@selector(redo:)
                     key:@"z" mask:(NSEventModifierFlagCommand | NSEventModifierFlagShift) rightEdge:rx inBar:bar cy:cy];
    rx = [self addButton:@"Undo  ⌘Z" symbol:@"arrow.uturn.backward" action:@selector(undoEdit:)
                     key:@"z" mask:NSEventModifierFlagCommand rightEdge:rx inBar:bar cy:cy];
}

// A vertical hairline. `addDividerAtX:` advances left→right; the RightEdge
// variant advances right→left. Both return the next cursor position.
- (CGFloat)addDividerAtX:(CGFloat)x inBar:(NSView *)bar {
    CGFloat lineH = 28, ly = round((kBarHeight - lineH) / 2);
    NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(x, ly, 1, lineH)];
    line.boxType = NSBoxSeparator;
    [bar addSubview:line];
    return x + 1 + 14;
}

- (CGFloat)addDividerAtRightEdge:(CGFloat)rx inBar:(NSView *)bar {
    CGFloat lineH = 28, ly = round((kBarHeight - lineH) / 2);
    NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(rx - 1, ly, 1, lineH)];
    line.boxType = NSBoxSeparator;
    line.autoresizingMask = NSViewMinXMargin;
    [bar addSubview:line];
    return rx - 1 - 14;
}

- (CGFloat)addButton:(NSString *)tooltip symbol:(NSString *)symbol action:(SEL)action
                 key:(NSString *)key mask:(NSEventModifierFlags)mask
           rightEdge:(CGFloat)rightEdge inBar:(NSView *)bar cy:(CGFloat)cy {
    const CGFloat bw = 34, h = 30;
    NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(rightEdge - bw, cy, bw, h)];
    b.bezelStyle = NSBezelStyleTexturedRounded;
    b.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:tooltip];
    b.imagePosition = NSImageOnly;
    b.toolTip = tooltip;
    b.target = self; b.action = action;
    b.keyEquivalent = key; b.keyEquivalentModifierMask = mask;
    b.autoresizingMask = NSViewMinXMargin;
    [bar addSubview:b];
    return rightEdge - bw - 8;
}

- (NSString *)sizeString {
    return [NSString stringWithFormat:@"%d pt", (int)round(self.canvas.strokeWidth)];
}

- (void)selectToolSegmentForTool:(CPTool)tool {
    for (NSInteger i = 0; i < kBarToolCount; i++) {
        if (kBarTools[i] == tool) { [self.toolControl setSelectedSegment:i]; return; }
    }
}

#pragma mark - Actions

- (void)toolChanged:(NSSegmentedControl *)sender {
    NSInteger i = sender.selectedSegment;
    if (i >= 0 && i < kBarToolCount) self.canvas.currentTool = kBarTools[i];
    [self.window makeFirstResponder:self.canvas];
}

- (void)colorChanged:(NSColorWell *)sender { self.canvas.strokeColor = sender.color; }

// Open the shared Font panel; its changeFont: is routed to the canvas.
- (void)chooseFont:(id)sender {
    [self.window makeFirstResponder:self.canvas];
    NSFontManager *fm = [NSFontManager sharedFontManager];
    [fm setSelectedFont:[self.canvas currentTextFont] isMultiple:NO];
    [fm orderFrontFontPanel:self];
}

- (void)thicknessChanged:(NSSlider *)sender {
    self.canvas.strokeWidth = sender.doubleValue;
    self.sizeLabel.stringValue = [self sizeString];
}
- (void)deleteSel:(id)sender { [self.canvas deleteSelection]; }
- (void)undoEdit:(id)sender {
    NSUndoManager *um = self.canvas.undoManager;
    if (um.canUndo) [um undo]; else NSBeep();
}
- (void)redo:(id)sender {
    NSUndoManager *um = self.canvas.undoManager;
    if (um.canRedo) [um redo]; else NSBeep();
}

- (void)copyImage:(id)sender {
    CGImageRef img = [self.canvas newFlattenedImage];
    if (img) { [CPExporter copyImageToPasteboard:img]; CGImageRelease(img); }
}

// Copy is the "done" action here — close the editor once it's on the clipboard.
- (void)copyAndClose:(id)sender {
    CGImageRef img = [self.canvas newFlattenedImage];
    if (!img) return;
    [CPExporter copyImageToPasteboard:img];
    CGImageRelease(img);
    [self.window performClose:nil];
}

- (void)saveImage:(id)sender {
    CGImageRef img = [self.canvas newFlattenedImage];
    if (!img) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    NSError *err = nil;
    NSURL *url = [CPExporter saveImage:img
                          toDirectory:[ud stringForKey:CPDefaultsSaveDirectory]
                               format:[ud stringForKey:CPDefaultsImageFormat]
                                error:&err];
    CGImageRelease(img);
    if (url) {
        NSLog(@"[Captr] Saved %@", url.path);
        [self.window performClose:nil];   // save is a "done" action — close the editor
    } else {
        NSLog(@"[Captr] Editor save failed: %@", err.localizedDescription);
    }
}

- (void)closeEditor:(id)sender { [self.window performClose:nil]; }

- (void)windowWillClose:(NSNotification *)note {
    if (self.onClose) { void (^cb)(void) = self.onClose; self.onClose = nil; cb(); }
}

@end
