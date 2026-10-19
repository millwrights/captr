// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPAppDelegate.h"
#import "CPDefaults.h"
#import "CPHotKey.h"
#import "CPCaptureEngine.h"
#import "CPExporter.h"
#import "CPOverlayController.h"
#import "CPEditorWindowController.h"
#import "CPPreferencesController.h"
#import "CPHotKeyRecorder.h"
#import "CPClipboardHistory.h"
#import "CPHistoryPanelController.h"
#import <Carbon/Carbon.h>

@interface CPAppDelegate () <NSMenuDelegate>
@property (nonatomic, strong) NSStatusItem *statusItem;
@property (nonatomic, strong) NSMutableArray<CPHotKey *> *hotKeys;
@property (nonatomic, strong) CPOverlayController *overlay;
@property (nonatomic, strong) NSMutableArray<CPEditorWindowController *> *editors;
@property (nonatomic, strong) CPPreferencesController *preferences;
@property (nonatomic, strong) CPHistoryPanelController *historyPanel;
@property (nonatomic, strong) NSMenu *historyMenu;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@end

@implementation CPAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)note {
    CPRegisterDefaults();
    self.editors = [NSMutableArray array];
    [self setupStatusItem];
    [self registerHotKeys];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(registerHotKeys)
                                                 name:CPHotKeysDidChangeNotification object:nil];
    // Prompt for Screen Recording up front so the first capture is smooth.
    [CPCaptureEngine ensureScreenRecordingPermission];
}

#pragma mark - Menu bar

- (void)setupStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
    NSImage *icon = [NSImage imageWithSystemSymbolName:@"camera.viewfinder"
                              accessibilityDescription:@"Captr"];
    icon.template = YES;
    self.statusItem.button.image = icon;

    NSMenu *menu = [[NSMenu alloc] init];
    // Global shortcuts are shown next to each item; they're editable in Settings
    // and handled by CPHotKey, so no static key-equivalents are set here.
    [self addCaptureItem:menu title:@"Capture Region"      action:@selector(captureRegion:)
                 codeKey:CPDefaultsRegionHotKeyCode modsKey:CPDefaultsRegionHotKeyMods];
    [self addCaptureItem:menu title:@"Capture Window"      action:@selector(captureWindow:)
                 codeKey:CPDefaultsWindowHotKeyCode modsKey:CPDefaultsWindowHotKeyMods];
    [self addCaptureItem:menu title:@"Capture Full Screen" action:@selector(captureFullScreen:)
                 codeKey:CPDefaultsFullScreenHotKeyCode modsKey:CPDefaultsFullScreenHotKeyMods];
    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *historyItem = [[NSMenuItem alloc] initWithTitle:@"Clipboard History" action:nil keyEquivalent:@""];
    self.historyMenu = [[NSMenu alloc] initWithTitle:@"Clipboard History"];
    self.historyMenu.delegate = self; // rebuilt in menuNeedsUpdate:
    historyItem.submenu = self.historyMenu;
    [menu addItem:historyItem];
    [self addItem:menu title:@"Open Screenshots Folder" action:@selector(openFolder:) key:@"" mods:0];
    [self addItem:menu title:@"Settings…" action:@selector(openPreferences:) key:@"," mods:NSEventModifierFlagCommand];
    [menu addItem:[NSMenuItem separatorItem]];
    [self addItem:menu title:@"About Captr" action:@selector(showAbout:) key:@"" mods:0];
    [self addItem:menu title:@"Quit Captr"  action:@selector(quit:) key:@"q" mods:NSEventModifierFlagCommand];
    menu.delegate = self;
    self.statusItem.menu = menu;
}

// A capture menu item whose right-hand text shows the current global shortcut.
- (void)addCaptureItem:(NSMenu *)menu title:(NSString *)title action:(SEL)action
               codeKey:(NSString *)codeKey modsKey:(NSString *)modsKey {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:@""];
    item.target = self;
    item.representedObject = @[codeKey, modsKey];
    [menu addItem:item];
}

// Refresh the displayed shortcut on each capture item before the menu opens.
- (void)menuNeedsUpdate:(NSMenu *)menu {
    if (menu == self.historyMenu) { [self rebuildHistoryMenu]; return; }
    for (NSMenuItem *item in menu.itemArray) {
        NSArray *keys = item.representedObject;
        if (![keys isKindOfClass:[NSArray class]] || keys.count != 2) continue;
        [self showShortcutFromCodeKey:keys[0] modsKey:keys[1] onItem:item];
    }
}

- (void)showShortcutFromCodeKey:(NSString *)codeKey modsKey:(NSString *)modsKey onItem:(NSMenuItem *)item {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    uint32_t code = (uint32_t)[ud integerForKey:codeKey];
    uint32_t mods = (uint32_t)[ud integerForKey:modsKey];
    item.keyEquivalent = mods ? [[CPHotKeyRecorder keyStringForKeyCode:code] lowercaseString] : @"";
    item.keyEquivalentModifierMask = [self nsModifiersFromCarbon:mods];
}

// "Show Clipboard History…", then the copied images (newest first), then Clear.
- (void)rebuildHistoryMenu {
    NSMenu *menu = self.historyMenu;
    [menu removeAllItems];

    NSMenuItem *show = [[NSMenuItem alloc] initWithTitle:@"Show Clipboard History…"
                                                  action:@selector(showClipboardHistory:) keyEquivalent:@""];
    show.target = self;
    [self showShortcutFromCodeKey:CPDefaultsHistoryHotKeyCode modsKey:CPDefaultsHistoryHotKeyMods onItem:show];
    [menu addItem:show];
    [menu addItem:[NSMenuItem separatorItem]];

    NSArray<CPClipboardEntry *> *entries = [CPClipboardHistory sharedHistory].entries;
    if (entries.count == 0) {
        NSMenuItem *none = [[NSMenuItem alloc] initWithTitle:@"No images copied yet" action:nil keyEquivalent:@""];
        none.enabled = NO;
        [menu addItem:none];
    }
    if (!self.timeFormatter) {
        self.timeFormatter = [[NSDateFormatter alloc] init];
        self.timeFormatter.dateStyle = NSDateFormatterNoStyle;
        self.timeFormatter.timeStyle = NSDateFormatterMediumStyle;
    }
    for (CPClipboardEntry *e in entries) {
        NSString *title = [NSString stringWithFormat:@"%d × %d — %@", (int)e.pixelSize.width,
                           (int)e.pixelSize.height, [self.timeFormatter stringFromDate:e.date]];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:@selector(copyHistoryEntry:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = e;
        NSImage *icon = [e.thumbnail copy];
        CGFloat scale = MIN(48.0 / icon.size.width, 32.0 / icon.size.height);
        icon.size = NSMakeSize(round(icon.size.width * scale), round(icon.size.height * scale));
        item.image = icon;
        [menu addItem:item];
    }

    [menu addItem:[NSMenuItem separatorItem]];
    NSMenuItem *clear = [[NSMenuItem alloc] initWithTitle:@"Clear History"
                                                   action:(entries.count ? @selector(clearClipboardHistory:) : nil)
                                            keyEquivalent:@""];
    clear.target = self;
    [menu addItem:clear];
}

- (NSEventModifierFlags)nsModifiersFromCarbon:(uint32_t)mods {
    NSEventModifierFlags f = 0;
    if (mods & cmdKey)     f |= NSEventModifierFlagCommand;
    if (mods & shiftKey)   f |= NSEventModifierFlagShift;
    if (mods & optionKey)  f |= NSEventModifierFlagOption;
    if (mods & controlKey) f |= NSEventModifierFlagControl;
    return f;
}

- (void)addItem:(NSMenu *)menu title:(NSString *)title action:(SEL)action
            key:(NSString *)key mods:(NSEventModifierFlags)mods {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.keyEquivalentModifierMask = mods;
    item.target = self;
    [menu addItem:item];
}

#pragma mark - Hotkeys

// (Re)registers all capture hotkeys from user defaults. Safe to call repeatedly
// — existing registrations are torn down first.
- (void)registerHotKeys {
    for (CPHotKey *hk in self.hotKeys) [hk unregister];
    self.hotKeys = [NSMutableArray array];
    __weak typeof(self) ws = self;
    [self registerHotKeyCodeKey:CPDefaultsRegionHotKeyCode modsKey:CPDefaultsRegionHotKeyMods
                        handler:^{ [ws captureRegion:nil]; }];
    [self registerHotKeyCodeKey:CPDefaultsWindowHotKeyCode modsKey:CPDefaultsWindowHotKeyMods
                        handler:^{ [ws captureWindow:nil]; }];
    [self registerHotKeyCodeKey:CPDefaultsFullScreenHotKeyCode modsKey:CPDefaultsFullScreenHotKeyMods
                        handler:^{ [ws captureFullScreen:nil]; }];
    [self registerHotKeyCodeKey:CPDefaultsHistoryHotKeyCode modsKey:CPDefaultsHistoryHotKeyMods
                        handler:^{ [ws showClipboardHistory:nil]; }];
}

- (void)registerHotKeyCodeKey:(NSString *)codeKey modsKey:(NSString *)modsKey handler:(void (^)(void))handler {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    uint32_t code = (uint32_t)[ud integerForKey:codeKey];
    uint32_t mods = (uint32_t)[ud integerForKey:modsKey];
    if (mods == 0) return; // unset / invalid — skip
    [self.hotKeys addObject:[[CPHotKey alloc] initWithKeyCode:code modifiers:mods handler:handler]];
}

#pragma mark - Capture actions

- (void)captureRegion:(id)sender { [self beginOverlayCaptureWithMode:CPOverlayModeRegion]; }
- (void)captureWindow:(id)sender { [self beginOverlayCaptureWithMode:CPOverlayModeWindow]; }

// Returns YES if screenshots can be taken right now. If not, it explains what
// to do (enable Screen Recording, then relaunch) instead of silently no-op'ing.
- (BOOL)requireScreenRecording {
    if ([CPCaptureEngine hasScreenRecordingPermission]) return YES;

    // Register Captr with TCC (adds it to the Screen Recording list and shows
    // the system prompt on first request), then guide the user.
    [CPCaptureEngine ensureScreenRecordingPermission];

    [NSApp activateIgnoringOtherApps:YES];
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Captr needs Screen Recording permission";
    alert.informativeText = @"Enable Captr under System Settings → Privacy & Security → "
        @"Screen Recording, then quit and reopen Captr.\n\nmacOS only applies the permission "
        @"after a relaunch, so screenshots won't work until you reopen the app.";
    [alert addButtonWithTitle:@"Open Settings"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSURL *url = [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"];
        [[NSWorkspace sharedWorkspace] openURL:url];
    }
    return NO;
}

- (void)captureFullScreen:(id)sender {
    if (![self requireScreenRecording]) return;
    CGImageRef img = [CPCaptureEngine captureFullScreen];
    [self handleCapturedImage:img];
}

- (void)beginOverlayCaptureWithMode:(CPOverlayMode)mode {
    if (![self requireScreenRecording]) return;
    if (self.overlay) return; // one at a time
    self.overlay = [[CPOverlayController alloc] init];
    __weak typeof(self) ws = self;
    [self.overlay beginWithMode:mode completion:^(CGImageRef image) {
        ws.overlay = nil;
        [ws handleCapturedImage:image];
    }];
}

// Takes ownership of `image` and releases it.
- (void)handleCapturedImage:(CGImageRef)image {
    if (!image) return;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    // Route into the annotation editor (default). The editor handles copy/save
    // via its own toolbar; it retains the image, so we release our reference.
    if ([ud boolForKey:CPDefaultsOpenEditor]) {
        __block __weak CPEditorWindowController *weakEd = nil;
        __weak typeof(self) ws = self;
        CPEditorWindowController *ed = [[CPEditorWindowController alloc]
            initWithCGImage:image onClose:^{ [ws.editors removeObject:weakEd]; }];
        weakEd = ed;
        [self.editors addObject:ed];
        [ed present];
        CGImageRelease(image);
        return;
    }

    if ([ud boolForKey:CPDefaultsCopyToClipboard]) {
        [CPExporter copyImageToPasteboard:image];
    }
    if ([ud boolForKey:CPDefaultsSaveToFile]) {
        NSString *dir = [ud stringForKey:CPDefaultsSaveDirectory];
        NSString *fmt = [ud stringForKey:CPDefaultsImageFormat];
        NSError *err = nil;
        NSURL *url = [CPExporter saveImage:image toDirectory:dir format:fmt error:&err];
        if (url) {
            NSLog(@"[Captr] Saved %@", url.path);
        } else {
            NSLog(@"[Captr] Save failed: %@", err.localizedDescription);
        }
    }
    if ([ud boolForKey:CPDefaultsPlaySound]) {
        [[NSSound soundNamed:@"Glass"] play];
    }
    CGImageRelease(image);
}

#pragma mark - Clipboard history

- (void)showClipboardHistory:(id)sender {
    if (!self.historyPanel) self.historyPanel = [[CPHistoryPanelController alloc] init];
    [self.historyPanel toggle];
}

- (void)copyHistoryEntry:(NSMenuItem *)sender {
    CPClipboardEntry *entry = sender.representedObject;
    if ([entry isKindOfClass:[CPClipboardEntry class]]) {
        [[CPClipboardHistory sharedHistory] copyEntryToPasteboard:entry];
    }
}

- (void)clearClipboardHistory:(id)sender { [[CPClipboardHistory sharedHistory] clear]; }

#pragma mark - Other menu actions

- (void)openFolder:(id)sender {
    NSString *dir = [[NSUserDefaults standardUserDefaults] stringForKey:CPDefaultsSaveDirectory];
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:dir]];
}

- (void)openPreferences:(id)sender {
    if (!self.preferences) self.preferences = [[CPPreferencesController alloc] init];
    [self.preferences present];
}

- (void)showAbout:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [NSApp orderFrontStandardAboutPanel:nil];
}

- (void)quit:(id)sender { [NSApp terminate:nil]; }

@end
