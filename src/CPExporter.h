// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// Builds a timestamped file name like "Captr 2026-07-20 at 14.53.09.png".
/// Pure function (given a date) — unit-tested.
NSString *CPScreenshotFileName(NSDate *date, NSString *extension);

@interface CPExporter : NSObject

/// Copy an image onto the general pasteboard as TIFF/PNG.
+ (void)copyImageToPasteboard:(CGImageRef)image;

/// Write an image to `directory` using the given format (@"png"/@"jpg").
/// Returns the file URL on success, or nil (with `error`) on failure.
+ (nullable NSURL *)saveImage:(CGImageRef)image
                  toDirectory:(NSString *)directory
                       format:(NSString *)format
                        error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
