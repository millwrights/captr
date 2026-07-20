// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPHotKeyRecorder.h"
#import "CPHotKey.h"
#import <Carbon/Carbon.h>

@interface CPHotKeyRecorder ()
@property (nonatomic) BOOL recording;
@property (nonatomic, strong) id monitor;
@end

@implementation CPHotKeyRecorder

- (instancetype)initWithFrame:(NSRect)frameRect {
    if ((self = [super initWithFrame:frameRect])) {
        self.bezelStyle = NSBezelStyleRounded;
        self.target = self;
        self.action = @selector(toggleRecording:);
        [self updateTitle];
    }
    return self;
}

- (void)setKeyCode:(uint32_t)keyCode { _keyCode = keyCode; [self updateTitle]; }
- (void)setCarbonModifiers:(uint32_t)mods { _carbonModifiers = mods; [self updateTitle]; }

- (void)updateTitle {
    if (self.recording) { self.title = @"Type shortcut…  (esc to cancel)"; return; }
    self.title = [CPHotKeyRecorder stringForKeyCode:self.keyCode carbonModifiers:self.carbonModifiers];
}

- (void)toggleRecording:(id)sender {
    self.recording ? [self endRecording] : [self beginRecording];
}

- (void)beginRecording {
    self.recording = YES;
    [self updateTitle];
    __weak typeof(self) weakSelf = self;
    self.monitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown
                                                         handler:^NSEvent *(NSEvent *event) {
        [weakSelf captureEvent:event];
        return nil; // swallow while recording
    }];
}

- (void)endRecording {
    self.recording = NO;
    if (self.monitor) { [NSEvent removeMonitor:self.monitor]; self.monitor = nil; }
    [self updateTitle];
}

- (void)captureEvent:(NSEvent *)event {
    if (event.keyCode == kVK_Escape) { [self endRecording]; return; }

    uint32_t mods = 0;
    NSEventModifierFlags f = event.modifierFlags;
    if (f & NSEventModifierFlagCommand) mods |= cmdKey;
    if (f & NSEventModifierFlagShift)   mods |= shiftKey;
    if (f & NSEventModifierFlagOption)  mods |= optionKey;
    if (f & NSEventModifierFlagControl) mods |= controlKey;

    if (mods == 0) { NSBeep(); return; } // require at least one modifier

    uint32_t code = event.keyCode;
    [self endRecording];

    // Re-picking the current combo: nothing to do.
    if (code == self.keyCode && mods == self.carbonModifiers) return;

    // macOS Screenshot owns ⌘⇧3/4/5/6 and intercepts them before Captr, so the
    // shortcut would silently never fire. Warn, but let the user override.
    if ([CPHotKeyRecorder isSystemScreenshotCombo:code modifiers:mods]) {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"That's a macOS Screenshot shortcut";
        alert.informativeText = @"macOS uses ⌘⇧3/4/5/6 for its own screenshots and will "
            @"intercept them before Captr, so this shortcut usually won't work. Disable it "
            @"in System Settings → Keyboard → Keyboard Shortcuts → Screenshots first, or pick "
            @"another combo.";
        [alert addButtonWithTitle:@"Choose Another"];
        [alert addButtonWithTitle:@"Use Anyway"];
        if ([alert runModal] != NSAlertSecondButtonReturn) return;
    } else if (![CPHotKey canRegisterKeyCode:code modifiers:mods]) {
        // Already claimed by another Captr action or the same app.
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = @"That shortcut is already in use";
        alert.informativeText = @"Another Captr action or app already uses this combination. "
            @"Pick a different one.";
        [alert runModal];
        return;
    }

    self.keyCode = code;             // setters refresh the displayed title
    self.carbonModifiers = mods;
    if (self.onChange) self.onChange(code, mods);
}

+ (BOOL)isSystemScreenshotCombo:(uint32_t)code modifiers:(uint32_t)mods {
    if (mods != (cmdKey | shiftKey)) return NO;
    return code == kVK_ANSI_3 || code == kVK_ANSI_4 ||
           code == kVK_ANSI_5 || code == kVK_ANSI_6;
}

#pragma mark - Display

+ (NSString *)stringForKeyCode:(uint32_t)keyCode carbonModifiers:(uint32_t)mods {
    NSMutableString *s = [NSMutableString string];
    if (mods & controlKey) [s appendString:@"⌃"];
    if (mods & optionKey)  [s appendString:@"⌥"];
    if (mods & shiftKey)   [s appendString:@"⇧"];
    if (mods & cmdKey)     [s appendString:@"⌘"];
    [s appendString:[self keyStringForKeyCode:keyCode]];
    return s.length ? s : @"(unset)";
}

+ (NSString *)keyStringForKeyCode:(uint32_t)keyCode {
    switch (keyCode) {
        case kVK_Return: return @"↩";
        case kVK_Tab: return @"⇥";
        case kVK_Space: return @"␣";
        case kVK_Delete: return @"⌫";
        case kVK_Escape: return @"⎋";
        case kVK_LeftArrow: return @"←";
        case kVK_RightArrow: return @"→";
        case kVK_UpArrow: return @"↑";
        case kVK_DownArrow: return @"↓";
        default: break;
    }
    // Translate via the current keyboard layout for printable keys.
    TISInputSourceRef source = TISCopyCurrentKeyboardLayoutInputSource();
    NSString *result = nil;
    if (source) {
        CFDataRef layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData);
        if (layoutData) {
            const UCKeyboardLayout *layout = (const UCKeyboardLayout *)CFDataGetBytePtr(layoutData);
            UInt32 deadKeyState = 0;
            UniChar chars[4];
            UniCharCount len = 0;
            OSStatus status = UCKeyTranslate(layout, (UInt16)keyCode, kUCKeyActionDisplay, 0,
                                             LMGetKbdType(), kUCKeyTranslateNoDeadKeysBit,
                                             &deadKeyState, 4, &len, chars);
            if (status == noErr && len > 0) {
                result = [[NSString stringWithCharacters:chars length:len] uppercaseString];
            }
        }
        CFRelease(source);
    }
    return result ?: [NSString stringWithFormat:@"key%u", keyCode];
}

@end
