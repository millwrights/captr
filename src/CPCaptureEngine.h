// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

/// Converts a rect expressed in Cocoa screen coordinates (origin bottom-left of
/// the primary screen, y up) into CoreGraphics capture coordinates (origin
/// top-left, y down). `primaryScreenHeight` is the height of the primary
/// display in points. Pure function — unit-tested, no side effects.
CGRect CPFlipRectForCapture(CGRect cocoaRect, CGFloat primaryScreenHeight);

/// Still-image capture. All methods return a retained CGImageRef the caller
/// must CGImageRelease, or NULL on failure. They require Screen Recording
/// permission; call +ensureScreenRecordingPermission first.
@interface CPCaptureEngine : NSObject

/// Non-prompting check: YES if Screen Recording permission is currently active
/// for this process. Note macOS only re-reads a newly granted permission on the
/// next launch, so this can stay NO until Captr is relaunched.
+ (BOOL)hasScreenRecordingPermission;

/// Returns YES if Screen Recording permission is already granted. If not, it
/// asks the system to prompt the user (which may require a relaunch) and
/// returns NO for this call.
+ (BOOL)ensureScreenRecordingPermission;

/// Capture the entire primary display.
+ (nullable CGImageRef)captureFullScreen CF_RETURNS_RETAINED;

/// Capture an arbitrary rect given in Cocoa screen coordinates.
+ (nullable CGImageRef)captureCocoaRect:(CGRect)cocoaRect CF_RETURNS_RETAINED;

/// Capture a single on-screen window by its CGWindowID, including its shadow.
+ (nullable CGImageRef)captureWindowID:(CGWindowID)windowID CF_RETURNS_RETAINED;

@end

NS_ASSUME_NONNULL_END
