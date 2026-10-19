// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPClipboardHistory.h"

NSString *const CPClipboardHistoryDidChangeNotification = @"CPClipboardHistoryDidChangeNotification";

static const CGFloat kThumbMaxW = 192, kThumbMaxH = 120;

@interface CPClipboardEntry ()
@property (nonatomic, readwrite) NSSize pixelSize;
@property (nonatomic, readwrite) NSDate *date;
@property (nonatomic, readwrite) NSImage *thumbnail;
@property (nonatomic, strong) NSData *pngData;   // set once background encoding finishes
@end

@implementation CPClipboardEntry {
    CGImageRef _image;                           // held until pngData exists
}

- (instancetype)initWithImage:(CGImageRef)image {
    if ((self = [super init])) {
        _image = CGImageRetain(image);
        _pixelSize = NSMakeSize(CGImageGetWidth(image), CGImageGetHeight(image));
        _date = [NSDate date];
        _thumbnail = [CPClipboardEntry thumbnailForImage:image];
    }
    return self;
}

- (void)dealloc { CGImageRelease(_image); }

+ (NSImage *)thumbnailForImage:(CGImageRef)image {
    CGFloat w = CGImageGetWidth(image), h = CGImageGetHeight(image);
    CGFloat fit = MIN(1.0, MIN(kThumbMaxW * 2 / w, kThumbMaxH * 2 / h)); // 2x for Retina
    size_t tw = MAX((size_t)round(w * fit), 1), th = MAX((size_t)round(h * fit), 1);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, tw, th, 8, 0, cs,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) return [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
    CGContextSetInterpolationQuality(ctx, kCGInterpolationHigh);
    CGContextDrawImage(ctx, CGRectMake(0, 0, tw, th), image);
    CGImageRef small = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    NSImage *thumb = [[NSImage alloc] initWithCGImage:small size:NSMakeSize(tw / 2.0, th / 2.0)];
    CGImageRelease(small);
    return thumb;
}

// Compress the full image off the main thread, then drop the raw bitmap.
- (void)encodeInBackground {
    CGImageRef image = CGImageRetain(_image);
    __weak typeof(self) ws = self;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
        NSData *png = [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        CGImageRelease(image);
        if (!png) return;
        dispatch_async(dispatch_get_main_queue(), ^{
            CPClipboardEntry *entry = ws;
            if (!entry) return;
            entry.pngData = png;
            CGImageRelease(entry->_image);
            entry->_image = NULL;
        });
    });
}

- (void)writeToPasteboard:(NSPasteboard *)pb {
    NSBitmapImageRep *rep = self.pngData ? [NSBitmapImageRep imageRepWithData:self.pngData]
                          : _image ? [[NSBitmapImageRep alloc] initWithCGImage:_image] : nil;
    NSData *tiff = rep.TIFFRepresentation;
    if (!tiff) return;
    [pb clearContents];
    [pb setData:tiff forType:NSPasteboardTypeTIFF];
    if (self.pngData) [pb setData:self.pngData forType:NSPasteboardTypePNG];
}

@end

@implementation CPClipboardHistory {
    NSMutableArray<CPClipboardEntry *> *_entries;
}

+ (instancetype)sharedHistory {
    static CPClipboardHistory *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[CPClipboardHistory alloc] init]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _entries = [NSMutableArray array];
        _maxEntries = 20;
    }
    return self;
}

- (NSArray<CPClipboardEntry *> *)entries { return [_entries copy]; }

- (void)addImage:(CGImageRef)image {
    if (!image) return;
    CPClipboardEntry *entry = [[CPClipboardEntry alloc] initWithImage:image];
    [_entries insertObject:entry atIndex:0];
    while (_entries.count > self.maxEntries) [_entries removeLastObject];
    [entry encodeInBackground];
    [self notify];
}

- (void)copyEntryToPasteboard:(CPClipboardEntry *)entry {
    if (![_entries containsObject:entry]) return;
    [entry writeToPasteboard:[NSPasteboard generalPasteboard]];
    [_entries removeObject:entry];
    [_entries insertObject:entry atIndex:0];
    [self notify];
}

- (void)removeEntry:(CPClipboardEntry *)entry {
    [_entries removeObject:entry];
    [self notify];
}

- (void)clear {
    [_entries removeAllObjects];
    [self notify];
}

- (void)notify {
    [[NSNotificationCenter defaultCenter] postNotificationName:CPClipboardHistoryDidChangeNotification
                                                        object:self];
}

@end
