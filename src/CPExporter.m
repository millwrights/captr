// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPExporter.h"
#import "CPClipboardHistory.h"

NSString *CPScreenshotFileName(NSDate *date, NSString *extension) {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    // Mirror macOS's native screenshot naming, e.g. "at 14.53.09".
    fmt.dateFormat = @"yyyy-MM-dd 'at' HH.mm.ss";
    NSString *stamp = [fmt stringFromDate:date];
    return [NSString stringWithFormat:@"Captr %@.%@", stamp, extension];
}

@implementation CPExporter

+ (void)copyImageToPasteboard:(CGImageRef)image {
    if (!image) return;
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSData *tiff = [rep TIFFRepresentation];
    if (!tiff) return;
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb clearContents];
    [pb setData:tiff forType:NSPasteboardTypeTIFF];
    [[CPClipboardHistory sharedHistory] addImage:image];
}

+ (NSData *)dataForImage:(CGImageRef)image format:(NSString *)format {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:image];
    NSString *f = format.lowercaseString;
    if ([f isEqualToString:@"jpg"] || [f isEqualToString:@"jpeg"]) {
        return [rep representationUsingType:NSBitmapImageFileTypeJPEG
                                properties:@{ NSImageCompressionFactor: @0.9 }];
    }
    // Default to PNG.
    return [rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
}

+ (NSURL *)saveImage:(CGImageRef)image
         toDirectory:(NSString *)directory
              format:(NSString *)format
               error:(NSError **)error {
    if (!image) {
        if (error) *error = [NSError errorWithDomain:@"Captr" code:1
            userInfo:@{ NSLocalizedDescriptionKey: @"No image to save." }];
        return nil;
    }
    NSString *ext = [format.lowercaseString isEqualToString:@"jpg"] ? @"jpg" : @"png";
    NSData *data = [self dataForImage:image format:ext];
    if (!data) {
        if (error) *error = [NSError errorWithDomain:@"Captr" code:2
            userInfo:@{ NSLocalizedDescriptionKey: @"Could not encode image." }];
        return nil;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:directory withIntermediateDirectories:YES
                   attributes:nil error:NULL];

    NSString *name = CPScreenshotFileName([NSDate date], ext);
    NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:name]];
    if (![data writeToURL:url options:NSDataWritingAtomic error:error]) {
        return nil;
    }
    return url;
}

@end
