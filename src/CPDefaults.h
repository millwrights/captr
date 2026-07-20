// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h> // kVK_* key codes and Carbon modifier masks for defaults

// NSUserDefaults keys. Keep string values stable across releases.
static NSString *const CPDefaultsSaveToFile      = @"CPSaveToFile";       // BOOL
static NSString *const CPDefaultsCopyToClipboard = @"CPCopyToClipboard";  // BOOL
static NSString *const CPDefaultsSaveDirectory   = @"CPSaveDirectory";    // path string
static NSString *const CPDefaultsImageFormat     = @"CPImageFormat";      // @"png"/@"jpg"/@"heic"
static NSString *const CPDefaultsPlaySound       = @"CPPlaySound";        // BOOL
static NSString *const CPDefaultsOpenEditor      = @"CPOpenEditor";       // BOOL

// Global capture hotkeys (Carbon key code + Carbon modifier mask).
static NSString *const CPDefaultsRegionHotKeyCode     = @"CPRegionHotKeyCode";
static NSString *const CPDefaultsRegionHotKeyMods     = @"CPRegionHotKeyMods";
static NSString *const CPDefaultsWindowHotKeyCode     = @"CPWindowHotKeyCode";
static NSString *const CPDefaultsWindowHotKeyMods     = @"CPWindowHotKeyMods";
static NSString *const CPDefaultsFullScreenHotKeyCode = @"CPFullScreenHotKeyCode";
static NSString *const CPDefaultsFullScreenHotKeyMods = @"CPFullScreenHotKeyMods";

// Registers factory defaults. Call once at launch before reading any value.
static inline void CPRegisterDefaults(void) {
    NSString *desktop = [NSSearchPathForDirectoriesInDomains(
        NSDesktopDirectory, NSUserDomainMask, YES) firstObject] ?: NSHomeDirectory();
    [[NSUserDefaults standardUserDefaults] registerDefaults:@{
        CPDefaultsSaveToFile:      @YES,
        CPDefaultsCopyToClipboard: @YES,
        CPDefaultsSaveDirectory:   desktop,
        CPDefaultsImageFormat:     @"png",
        CPDefaultsPlaySound:       @YES,
        CPDefaultsOpenEditor:      @YES,
        // Defaults match the original hardcoded shortcuts: ⌃⇧⌘A/W/F.
        CPDefaultsRegionHotKeyCode:     @(kVK_ANSI_A),
        CPDefaultsRegionHotKeyMods:     @(controlKey | shiftKey | cmdKey),
        CPDefaultsWindowHotKeyCode:     @(kVK_ANSI_W),
        CPDefaultsWindowHotKeyMods:     @(controlKey | shiftKey | cmdKey),
        CPDefaultsFullScreenHotKeyCode: @(kVK_ANSI_F),
        CPDefaultsFullScreenHotKeyMods: @(controlKey | shiftKey | cmdKey),
    }];
}
