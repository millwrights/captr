// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPOverlayController.h"
#import "CPCaptureEngine.h"

#pragma mark - Key-capable borderless window

@interface CPOverlayWindow : NSWindow
@end

@implementation CPOverlayWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

#pragma mark - Drawing / event view

@class CPOverlayView;

@protocol CPOverlayViewDelegate <NSObject>
- (void)overlayViewDidSelectRegion:(NSRect)rectInScreen;   // Cocoa screen coords
- (void)overlayViewDidSelectWindow:(CGWindowID)windowID;
- (void)overlayViewDidCancel;
@end

@interface CPOverlayView : NSView
@property (nonatomic, weak) id<CPOverlayViewDelegate> delegate;
@property (nonatomic) CPOverlayMode mode;
@property (nonatomic) NSPoint screenOrigin;   // origin of this view's window in screen coords
@property (nonatomic) NSRect selection;       // current drag rect (view coords)
@property (nonatomic) BOOL selecting;
@property (nonatomic) NSRect windowHighlight;  // view coords, for window mode
@property (nonatomic) CGWindowID hoverWindowID;
@end

@implementation CPOverlayView {
    NSPoint _dragAnchor;
}

- (BOOL)isFlipped { return NO; }
- (BOOL)acceptsFirstResponder { return YES; }

- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.28] setFill];
    NSRectFill(self.bounds);

    NSRect hole = NSZeroRect;
    if (self.mode == CPOverlayModeRegion && self.selecting) {
        hole = self.selection;
    } else if (self.mode == CPOverlayModeWindow && self.hoverWindowID != kCGNullWindowID) {
        hole = self.windowHighlight;
    }
    if (NSIsEmptyRect(hole)) return;

    // Punch a clear hole so the live screen shows through the dim.
    [[NSColor clearColor] setFill];
    NSRectFillUsingOperation(hole, NSCompositingOperationClear);

    // Border.
    NSColor *stroke = (self.mode == CPOverlayModeWindow)
        ? [NSColor colorWithCalibratedRed:0.20 green:0.55 blue:1.0 alpha:1.0]
        : [NSColor whiteColor];
    [stroke setStroke];
    NSBezierPath *border = [NSBezierPath bezierPathWithRect:NSInsetRect(hole, 0.5, 0.5)];
    border.lineWidth = 1.0;
    [border stroke];

    // Dimensions label (region mode).
    if (self.mode == CPOverlayModeRegion) {
        NSString *label = [NSString stringWithFormat:@"%d × %d",
                           (int)round(hole.size.width), (int)round(hole.size.height)];
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:12
                                                                weight:NSFontWeightMedium],
            NSForegroundColorAttributeName: [NSColor whiteColor],
        };
        NSSize sz = [label sizeWithAttributes:attrs];
        NSRect chip = NSMakeRect(NSMidX(hole) - sz.width/2 - 6,
                                 NSMinY(hole) - sz.height - 10,
                                 sz.width + 12, sz.height + 6);
        if (NSMinY(chip) < 4) chip.origin.y = NSMaxY(hole) + 6; // flip above if off-screen
        [[NSColor colorWithCalibratedWhite:0.0 alpha:0.75] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:chip xRadius:4 yRadius:4] fill];
        [label drawAtPoint:NSMakePoint(chip.origin.x + 6, chip.origin.y + 3) withAttributes:attrs];
    }
}

#pragma mark Events

- (void)mouseDown:(NSEvent *)event {
    if (self.mode == CPOverlayModeWindow) {
        if (self.hoverWindowID != kCGNullWindowID) {
            [self.delegate overlayViewDidSelectWindow:self.hoverWindowID];
        }
        return;
    }
    self.selecting = YES;
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    self.selection = NSMakeRect(p.x, p.y, 0, 0);
    _dragAnchor = p;
    [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event {
    if (self.mode != CPOverlayModeRegion || !self.selecting) return;
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    self.selection = NSMakeRect(MIN(p.x, _dragAnchor.x), MIN(p.y, _dragAnchor.y),
                                fabs(p.x - _dragAnchor.x), fabs(p.y - _dragAnchor.y));
    [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event {
    if (self.mode != CPOverlayModeRegion || !self.selecting) return;
    self.selecting = NO;
    if (self.selection.size.width < 2 || self.selection.size.height < 2) {
        [self.delegate overlayViewDidCancel];
        return;
    }
    NSRect inScreen = self.selection;
    inScreen.origin.x += self.screenOrigin.x;
    inScreen.origin.y += self.screenOrigin.y;
    [self.delegate overlayViewDidSelectRegion:inScreen];
}

- (void)rightMouseDown:(NSEvent *)event {
    [self.delegate overlayViewDidCancel];
}

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 53) { // Esc
        [self.delegate overlayViewDidCancel];
    }
}

@end

#pragma mark - Controller

@interface CPOverlayController () <CPOverlayViewDelegate>
@property (nonatomic, strong) NSArray<CPOverlayWindow *> *windows; // one per display
@property (nonatomic, strong) NSArray<CPOverlayView *> *views;
@property (nonatomic, copy) CPOverlayCompletion completion;
@property (nonatomic, strong) id monitor;         // local event monitor for mouse-moved
@property (nonatomic, strong) CPOverlayController *selfRef; // keep alive during interaction
@end

@implementation CPOverlayController

- (void)beginWithMode:(CPOverlayMode)mode completion:(CPOverlayCompletion)completion {
    self.completion = completion;
    self.selfRef = self;

    // Cover every display with its own overlay so capture starts wherever the
    // cursor is — not on whichever screen happens to hold the key window (e.g. a
    // previously-opened editor). Keyboard focus goes to the screen under the
    // cursor so Esc works and the interaction feels local.
    NSPoint mouse = [NSEvent mouseLocation];
    NSMutableArray<CPOverlayWindow *> *windows = [NSMutableArray array];
    NSMutableArray<CPOverlayView *> *views = [NSMutableArray array];
    CPOverlayView *cursorView = nil;

    for (NSScreen *screen in [NSScreen screens]) {
        NSRect frame = screen.frame;
        CPOverlayWindow *win = [[CPOverlayWindow alloc] initWithContentRect:frame
                                                                 styleMask:NSWindowStyleMaskBorderless
                                                                   backing:NSBackingStoreBuffered
                                                                     defer:NO];
        win.opaque = NO;
        win.backgroundColor = [NSColor clearColor];
        win.level = NSScreenSaverWindowLevel;
        win.ignoresMouseEvents = NO;
        [win setAcceptsMouseMovedEvents:YES];

        CPOverlayView *view = [[CPOverlayView alloc] initWithFrame:(NSRect){NSZeroPoint, frame.size}];
        view.delegate = self;
        view.mode = mode;
        view.screenOrigin = frame.origin;
        win.contentView = view;

        [windows addObject:win];
        [views addObject:view];
        if (NSPointInRect(mouse, frame)) cursorView = view;
    }

    self.windows = windows;
    self.views = views;

    [NSApp activateIgnoringOtherApps:YES];
    for (CPOverlayWindow *win in windows) [win orderFront:nil];

    if (!cursorView) cursorView = views.firstObject;
    [cursorView.window makeKeyAndOrderFront:nil];
    [cursorView.window makeFirstResponder:cursorView];
    [[NSCursor crosshairCursor] push];

    if (mode == CPOverlayModeWindow) {
        [self trackWindowUnderCursor]; // prime highlight
        __weak typeof(self) weakSelf = self;
        self.monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskMouseMoved
            handler:^NSEvent *(NSEvent *e) {
                [weakSelf trackWindowUnderCursor];
                return e;
            }];
    }
}

- (void)hideOverlays {
    for (CPOverlayWindow *win in self.windows) [win orderOut:nil];
}

- (void)tearDown {
    [[NSCursor crosshairCursor] pop];
    if (self.monitor) { [NSEvent removeMonitor:self.monitor]; self.monitor = nil; }
    [self hideOverlays];
    self.windows = nil;
    self.views = nil;
}

- (void)finishWithImage:(CGImageRef)image {
    CPOverlayCompletion done = self.completion;
    self.completion = nil;
    [self tearDown];
    if (done) done(image);
    self.selfRef = nil; // release after callback
}

#pragma mark Window-mode tracking

- (void)trackWindowUnderCursor {
    NSPoint mouse = [NSEvent mouseLocation]; // Cocoa global coords
    CGFloat primaryHeight = NSHeight([[NSScreen screens] firstObject].frame);
    CGPoint cgPoint = CGPointMake(mouse.x, primaryHeight - mouse.y);

    pid_t myPID = [[NSProcessInfo processInfo] processIdentifier];
    CFArrayRef list = CGWindowListCopyWindowInfo(
        kCGWindowListOptionOnScreenOnly | kCGWindowListExcludeDesktopElements, kCGNullWindowID);

    CGWindowID found = kCGNullWindowID;
    CGRect foundBounds = CGRectZero;
    for (NSDictionary *info in (__bridge NSArray *)list) {
        NSNumber *layer = info[(id)kCGWindowLayer];
        if (layer.intValue != 0) continue; // only normal windows
        NSNumber *owner = info[(id)kCGWindowOwnerPID];
        if (owner.intValue == myPID) continue; // skip our overlay
        CGRect bounds;
        CGRectMakeWithDictionaryRepresentation(
            (__bridge CFDictionaryRef)info[(id)kCGWindowBounds], &bounds);
        if (CGRectContainsPoint(bounds, cgPoint)) {
            found = (CGWindowID)[info[(id)kCGWindowNumber] unsignedIntValue];
            foundBounds = bounds;
            break; // list is front-to-back; first hit is topmost
        }
    }
    if (list) CFRelease(list);

    // Global Cocoa rect (y-up) of the hovered window; each per-display view
    // converts it into its own coordinates and draws the portion on its screen.
    NSRect globalHighlight = NSMakeRect(foundBounds.origin.x,
                                        primaryHeight - (foundBounds.origin.y + foundBounds.size.height),
                                        foundBounds.size.width, foundBounds.size.height);
    for (CPOverlayView *view in self.views) {
        view.hoverWindowID = found;
        if (found != kCGNullWindowID) {
            NSRect r = globalHighlight;
            r.origin.x -= view.screenOrigin.x;
            r.origin.y -= view.screenOrigin.y;
            view.windowHighlight = r;
        }
        [view setNeedsDisplay:YES];
    }
}

#pragma mark CPOverlayViewDelegate

- (void)overlayViewDidSelectRegion:(NSRect)rectInScreen {
    // Hide the overlays first, then capture after they're off-screen.
    [self hideOverlays];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        CGImageRef img = [CPCaptureEngine captureCocoaRect:rectInScreen];
        [self finishWithImage:img];
    });
}

- (void)overlayViewDidSelectWindow:(CGWindowID)windowID {
    [self hideOverlays];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        CGImageRef img = [CPCaptureEngine captureWindowID:windowID];
        [self finishWithImage:img];
    });
}

- (void)overlayViewDidCancel {
    [self finishWithImage:NULL];
}

@end
