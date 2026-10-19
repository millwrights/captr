// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// Posted on the main thread whenever the history's entries change.
extern NSString *const CPClipboardHistoryDidChangeNotification;

/// One image Captr put on the clipboard.
@interface CPClipboardEntry : NSObject
@property (nonatomic, readonly) NSSize pixelSize;
@property (nonatomic, readonly) NSDate *date;
@property (nonatomic, readonly) NSImage *thumbnail;   // small preview for lists/menus
@end

/// In-memory history of images Captr has copied (newest first). Nothing is
/// written to disk, so the history is cleared when Captr quits. Full images are
/// compressed to PNG in the background to keep memory use down.
@interface CPClipboardHistory : NSObject

+ (instancetype)sharedHistory;

@property (nonatomic, readonly) NSArray<CPClipboardEntry *> *entries;
/// Oldest entries are dropped beyond this count. Default 20.
@property (nonatomic) NSUInteger maxEntries;

/// Record an image that was just copied. Does not touch the pasteboard.
- (void)addImage:(CGImageRef)image;

/// Put `entry` back on the clipboard and move it to the top of the history.
- (void)copyEntryToPasteboard:(CPClipboardEntry *)entry;

- (void)removeEntry:(CPClipboardEntry *)entry;
- (void)clear;

@end

NS_ASSUME_NONNULL_END
