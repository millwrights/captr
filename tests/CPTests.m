// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
// Minimal unit tests for Captr's pure helpers. Run with `make test`.
#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "CPCaptureEngine.h"
#import "CPExporter.h"
#import "CPMarkup.h"
#import "CPCanvasView.h"
#import "CPClipboardHistory.h"

static int gFailures = 0;

#define CHECK(cond, msg) do { \
    if (!(cond)) { fprintf(stderr, "  ✗ %s\n", (msg)); gFailures++; } \
    else { fprintf(stderr, "  ✓ %s\n", (msg)); } \
} while (0)

static void testFlipRect(void) {
    fprintf(stderr, "CPFlipRectForCapture:\n");
    // A rect at the bottom-left of a 1000-tall screen maps to the top-left in CG.
    CGRect in = CGRectMake(0, 0, 100, 50);
    CGRect out = CPFlipRectForCapture(in, 1000);
    CHECK(out.origin.x == 0 && out.origin.y == 950, "bottom-left flips to y=950");
    CHECK(out.size.width == 100 && out.size.height == 50, "size preserved");

    // A rect at the top of the screen maps to y=0 in CG.
    CGRect top = CGRectMake(10, 900, 200, 100); // top edge at y=1000
    CGRect topOut = CPFlipRectForCapture(top, 1000);
    CHECK(topOut.origin.y == 0, "top-aligned rect flips to y=0");
    CHECK(topOut.origin.x == 10, "x is unchanged");
}

static void testFileName(void) {
    fprintf(stderr, "CPScreenshotFileName:\n");
    // 2026-07-20 14:53:09 UTC-agnostic via components in local tz.
    NSDateComponents *c = [[NSDateComponents alloc] init];
    c.year = 2026; c.month = 7; c.day = 20; c.hour = 14; c.minute = 53; c.second = 9;
    NSCalendar *cal = [NSCalendar calendarWithIdentifier:NSCalendarIdentifierGregorian];
    NSDate *d = [cal dateFromComponents:c];
    NSString *name = CPScreenshotFileName(d, @"png");
    CHECK([name isEqualToString:@"Captr 2026-07-20 at 14.53.09.png"], "formats name like macOS");
    CHECK([name hasSuffix:@".png"], "honors extension");

    NSString *jpg = CPScreenshotFileName(d, @"jpg");
    CHECK([jpg hasSuffix:@".jpg"], "jpg extension");
}

static void testAnnotation(void) {
    fprintf(stderr, "CPMarkup:\n");
    CPMarkup *rect = [CPMarkup annotationWithTool:CPToolRectangle color:nil stroke:3];
    rect.startPoint = NSMakePoint(10, 10);
    rect.endPoint = NSMakePoint(50, 40);
    CHECK([rect isCommittable], "40x30 rectangle is committable");
    CHECK([rect containsPoint:NSMakePoint(30, 25)], "point inside rect hit-tests");
    CHECK(![rect containsPoint:NSMakePoint(300, 300)], "far point misses");

    [rect translateBy:NSMakeSize(5, -5)];
    CHECK(rect.startPoint.x == 15 && rect.startPoint.y == 5, "translate moves start point");

    CPMarkup *tiny = [CPMarkup annotationWithTool:CPToolEllipse color:nil stroke:2];
    tiny.startPoint = NSMakePoint(0, 0);
    tiny.endPoint = NSMakePoint(1, 1);
    CHECK(![tiny isCommittable], "1x1 shape is discarded");

    CPMarkup *pen = [CPMarkup annotationWithTool:CPToolPen color:nil stroke:2];
    [pen.points removeAllObjects];
    [pen addPoint:NSMakePoint(0, 0)];
    CHECK(![pen isCommittable], "single-point pen stroke is discarded");
    [pen addPoint:NSMakePoint(5, 5)];
    CHECK([pen isCommittable], "two-point pen stroke is kept");

    CPMarkup *copy = [rect copy];
    copy.startPoint = NSMakePoint(999, 999);
    CHECK(rect.startPoint.x == 15, "copy is independent of original");
}

// Builds an 8x8 image with four solid-color quadrants; row 0 is the TOP.
static CGImageRef makeQuadrantImage(void) {
    static uint8_t px[8 * 8 * 4];
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
            uint8_t *p = &px[(y * 8 + x) * 4];
            uint8_t r = 0, g = 0, b = 0;
            if (y < 4 && x < 4)      { r = 255; }                 // top-left  red
            else if (y < 4)          { g = 255; }                 // top-right green
            else if (x < 4)          { b = 255; }                 // bot-left  blue
            else                     { r = g = b = 255; }         // bot-right white
            p[0] = r; p[1] = g; p[2] = b; p[3] = 255;
        }
    }
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef prov = CGDataProviderCreateWithData(NULL, px, sizeof(px), NULL);
    CGImageRef img = CGImageCreate(8, 8, 8, 32, 8 * 4, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big, prov, NULL, false, kCGRenderingIntentDefault);
    CGColorSpaceRelease(cs); CGDataProviderRelease(prov);
    return img;
}

// Reads pixels of `img` into `out` (row 0 = BOTTOM, since CGContextDrawImage is y-up).
static void readPixels(CGImageRef img, uint8_t *out) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef c = CGBitmapContextCreate(out, 8, 8, 8, 8 * 4, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    CGContextDrawImage(c, CGRectMake(0, 0, 8, 8), img);
    CGContextRelease(c);
}

// Color at image coords (x, yFromTop) given a buffer whose row 0 is the bottom.
static uint8_t *pixelAt(uint8_t *buf, int x, int yFromTop) {
    int row = 7 - yFromTop;
    return &buf[(row * 8 + x) * 4];
}

// A corner matches between two buffers if all RGB channels are close.
static BOOL cornerMatches(uint8_t *a, uint8_t *b) {
    return abs(a[0]-b[0]) < 24 && abs(a[1]-b[1]) < 24 && abs(a[2]-b[2]) < 24;
}

static void testExportOrientation(void) {
    fprintf(stderr, "CPCanvasView export orientation:\n");
    CGImageRef base = makeQuadrantImage();
    uint8_t bufBase[8 * 8 * 4];
    readPixels(base, bufBase);

    CPCanvasView *canvas = [[CPCanvasView alloc] initWithCGImage:base logicalSize:NSMakeSize(8, 8)];
    CGImageRef flat = [canvas newFlattenedImage];
    CHECK(flat != NULL, "flatten produced an image");
    if (flat) {
        CHECK(CGImageGetWidth(flat) == 8 && CGImageGetHeight(flat) == 8, "full-resolution 8x8 output");
        uint8_t bufFlat[8 * 8 * 4];
        readPixels(flat, bufFlat);
        // Each quadrant of the flattened image must match the SAME quadrant of the
        // input — a vertical or horizontal mirror would swap these.
        struct { int x, y; const char *name; } corners[] = {
            {1, 1, "top-left"}, {6, 1, "top-right"}, {1, 6, "bottom-left"}, {6, 6, "bottom-right"},
        };
        for (int i = 0; i < 4; i++) {
            BOOL ok = cornerMatches(pixelAt(bufBase, corners[i].x, corners[i].y),
                                    pixelAt(bufFlat, corners[i].x, corners[i].y));
            CHECK(ok, corners[i].name);
        }
        CGImageRelease(flat);
    }
    CGImageRelease(base);
}

static void testUndoManager(void) {
    fprintf(stderr, "CPCanvasView undo manager:\n");
    CGImageRef base = makeQuadrantImage();
    CPCanvasView *canvas = [[CPCanvasView alloc] initWithCGImage:base logicalSize:NSMakeSize(8, 8)];
    NSUndoManager *a = canvas.undoManager;
    NSUndoManager *b = canvas.undoManager;
    CHECK(a != nil, "canvas provides an undo manager");
    CHECK(a == b, "undo manager is one stable shared instance (edits + buttons agree)");
    CGImageRelease(base);
}

static void testClipboardHistory(void) {
    fprintf(stderr, "CPClipboardHistory:\n");
    CPClipboardHistory *h = [[CPClipboardHistory alloc] init];
    h.maxEntries = 3;
    CGImageRef img = makeQuadrantImage();
    CHECK(h.entries.count == 0, "starts empty");
    [h addImage:NULL];
    CHECK(h.entries.count == 0, "ignores NULL images");
    for (int i = 0; i < 5; i++) [h addImage:img];
    CHECK(h.entries.count == 3, "drops oldest entries beyond maxEntries");
    CPClipboardEntry *first = h.entries.firstObject;
    CHECK(NSEqualSizes(first.pixelSize, NSMakeSize(CGImageGetWidth(img), CGImageGetHeight(img))),
          "entry records the image's pixel size");
    CHECK(first.thumbnail.size.width > 0, "entry has a thumbnail");
    [h removeEntry:first];
    CHECK(h.entries.count == 2 && ![h.entries containsObject:first], "removeEntry drops just that entry");
    [h clear];
    CHECK(h.entries.count == 0, "clear empties the history");
    CGImageRelease(img);
}

int main(int argc, const char *argv[]) {
    (void)argc; (void)argv;
    @autoreleasepool {
        [NSApplication sharedApplication]; // AppKit drawing needs an app instance
        testFlipRect();
        testFileName();
        testAnnotation();
        testExportOrientation();
        testUndoManager();
        testClipboardHistory();
        if (gFailures == 0) { fprintf(stderr, "\nAll tests passed.\n"); return 0; }
        fprintf(stderr, "\n%d test(s) failed.\n", gFailures);
        return 1;
    }
}
