// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPCaptureEngine.h"

CGRect CPFlipRectForCapture(CGRect cocoaRect, CGFloat primaryScreenHeight) {
    // Cocoa: origin bottom-left, y up. CoreGraphics capture: origin top-left,
    // y down. Flip the y origin about the primary screen's height.
    CGFloat cgY = primaryScreenHeight - (cocoaRect.origin.y + cocoaRect.size.height);
    return CGRectMake(cocoaRect.origin.x, cgY, cocoaRect.size.width, cocoaRect.size.height);
}

@implementation CPCaptureEngine

+ (BOOL)hasScreenRecordingPermission {
    return CGPreflightScreenCaptureAccess();
}

+ (BOOL)ensureScreenRecordingPermission {
    // CGPreflightScreenCaptureAccess / CGRequestScreenCaptureAccess are the
    // supported way to check and trigger the TCC prompt on macOS 11+.
    if (CGPreflightScreenCaptureAccess()) {
        return YES;
    }
    BOOL granted = CGRequestScreenCaptureAccess();
    if (!granted) {
        NSLog(@"[Captr] Screen Recording permission not granted yet. Grant it in "
              @"System Settings → Privacy & Security → Screen Recording, then relaunch Captr.");
    }
    return granted;
}

+ (CGImageRef)captureFullScreen {
    return CGDisplayCreateImage([self displayUnderCursor]); // top-left origin already
}

// The display the cursor is currently on (falls back to the primary display).
+ (CGDirectDisplayID)displayUnderCursor {
    NSPoint mouse = [NSEvent mouseLocation]; // Cocoa: y-up from primary bottom-left
    CGFloat primaryHeight = NSHeight([[NSScreen screens] firstObject].frame);
    CGPoint cgPoint = CGPointMake(mouse.x, primaryHeight - mouse.y);

    CGDirectDisplayID display = CGMainDisplayID();
    uint32_t count = 0;
    if (CGGetDisplaysWithPoint(cgPoint, 1, &display, &count) == kCGErrorSuccess && count > 0) {
        return display;
    }
    return CGMainDisplayID();
}

+ (CGImageRef)captureCocoaRect:(CGRect)cocoaRect {
    if (cocoaRect.size.width < 1 || cocoaRect.size.height < 1) return NULL;

    CGFloat primaryHeight = NSHeight([[NSScreen screens] firstObject].frame);
    CGRect cgRect = CPFlipRectForCapture(cocoaRect, primaryHeight);

    // CGWindowListCreateImage takes a rect in CG screen coordinates and returns
    // the on-screen composite for that region.
    CGImageRef image = CGWindowListCreateImage(cgRect,
                                               kCGWindowListOptionOnScreenOnly,
                                               kCGNullWindowID,
                                               kCGWindowImageDefault);
    return image;
}

+ (CGImageRef)captureWindowID:(CGWindowID)windowID {
    // CGRectNull asks for the window's own bounds. Include the shadow for the
    // familiar macOS look; use BestResolution for Retina fidelity.
    CGImageRef image = CGWindowListCreateImage(CGRectNull,
                                               kCGWindowListOptionIncludingWindow,
                                               windowID,
                                               kCGWindowImageBoundsIgnoreFraming |
                                               kCGWindowImageBestResolution);
    return image;
}

@end
