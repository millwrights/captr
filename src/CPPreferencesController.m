// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPPreferencesController.h"
#import "CPHotKeyRecorder.h"
#import "CPDefaults.h"

NSString *const CPHotKeysDidChangeNotification = @"CPHotKeysDidChangeNotification";

static const CGFloat kWidth   = 480;
static const CGFloat kMargin  = 20;
static const CGFloat kLabelW  = 170;
static const CGFloat kCtrlX   = 200;   // kMargin + kLabelW + 10

@interface CPFlippedView : NSView @end
@implementation CPFlippedView
- (BOOL)isFlipped { return YES; }
@end

@interface CPPreferencesController ()
@property (nonatomic, strong) NSTextField *pathLabel;
@end

@implementation CPPreferencesController

- (instancetype)init {
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, kWidth, 372)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
                    backing:NSBackingStoreBuffered defer:NO];
    window.title = @"Captr Settings";
    window.releasedWhenClosed = NO;

    if ((self = [super initWithWindow:window])) {
        CPFlippedView *content = [[CPFlippedView alloc] initWithFrame:NSMakeRect(0, 0, kWidth, 372)];
        window.contentView = content;
        [self buildUIInto:content];
    }
    return self;
}

- (void)present {
    [NSApp activateIgnoringOtherApps:YES];
    [self.window center];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
}

#pragma mark - Build

- (void)buildUIInto:(NSView *)content {
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];

    [self addSectionHeader:@"Shortcuts" y:16 into:content];
    [self addRecorderRow:@"Capture Region" y:44 into:content
                 codeKey:CPDefaultsRegionHotKeyCode modsKey:CPDefaultsRegionHotKeyMods];
    [self addRecorderRow:@"Capture Window" y:76 into:content
                 codeKey:CPDefaultsWindowHotKeyCode modsKey:CPDefaultsWindowHotKeyMods];
    [self addRecorderRow:@"Capture Full Screen" y:108 into:content
                 codeKey:CPDefaultsFullScreenHotKeyCode modsKey:CPDefaultsFullScreenHotKeyMods];

    [self addSectionHeader:@"General" y:150 into:content];
    [self addCheckbox:@"Open editor after capture" y:178 key:CPDefaultsOpenEditor into:content];
    [self addCheckbox:@"Copy to clipboard" y:206 key:CPDefaultsCopyToClipboard into:content];
    [self addCheckbox:@"Save to file" y:234 key:CPDefaultsSaveToFile into:content];

    // Format popup.
    [self addLabel:@"Format:" y:266 into:content];
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(kCtrlX, 264, 100, 26)];
    [popup addItemsWithTitles:@[@"PNG", @"JPG"]];
    [popup selectItemWithTitle:[[ud stringForKey:CPDefaultsImageFormat] uppercaseString] ?: @"PNG"];
    popup.target = self; popup.action = @selector(formatChanged:);
    [content addSubview:popup];

    // Save location.
    [self addLabel:@"Save to:" y:298 into:content];
    self.pathLabel = [self makePlainLabel:[self prettyPath] frame:NSMakeRect(kCtrlX, 300, 170, 20)];
    self.pathLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.pathLabel.toolTip = [ud stringForKey:CPDefaultsSaveDirectory];
    [content addSubview:self.pathLabel];
    NSButton *choose = [[NSButton alloc] initWithFrame:NSMakeRect(kWidth - kMargin - 80, 296, 80, 26)];
    choose.title = @"Choose…"; choose.bezelStyle = NSBezelStyleRounded;
    choose.target = self; choose.action = @selector(chooseFolder:);
    [content addSubview:choose];

    [self addCheckbox:@"Play sound after capture" y:334 key:CPDefaultsPlaySound into:content];
}

- (void)addSectionHeader:(NSString *)title y:(CGFloat)y into:(NSView *)content {
    NSTextField *l = [self makePlainLabel:title frame:NSMakeRect(kMargin, y, kWidth - 2*kMargin, 20)];
    l.font = [NSFont boldSystemFontOfSize:13];
    [content addSubview:l];
}

- (void)addLabel:(NSString *)title y:(CGFloat)y into:(NSView *)content {
    NSTextField *l = [self makePlainLabel:title frame:NSMakeRect(kMargin, y, kLabelW, 20)];
    l.alignment = NSTextAlignmentRight;
    [content addSubview:l];
}

- (void)addRecorderRow:(NSString *)title y:(CGFloat)y into:(NSView *)content
               codeKey:(NSString *)codeKey modsKey:(NSString *)modsKey {
    [self addLabel:title y:y + 4 into:content];
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    CPHotKeyRecorder *rec = [[CPHotKeyRecorder alloc] initWithFrame:NSMakeRect(kCtrlX, y, kWidth - kCtrlX - kMargin, 28)];
    rec.keyCode = (uint32_t)[ud integerForKey:codeKey];
    rec.carbonModifiers = (uint32_t)[ud integerForKey:modsKey];
    rec.onChange = ^(uint32_t keyCode, uint32_t mods) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setInteger:keyCode forKey:codeKey];
        [d setInteger:mods forKey:modsKey];
        [[NSNotificationCenter defaultCenter] postNotificationName:CPHotKeysDidChangeNotification object:nil];
    };
    [content addSubview:rec];
}

- (NSButton *)addCheckbox:(NSString *)title y:(CGFloat)y key:(NSString *)key into:(NSView *)content {
    NSButton *box = [[NSButton alloc] initWithFrame:NSMakeRect(kCtrlX, y, kWidth - kCtrlX - kMargin, 22)];
    [box setButtonType:NSButtonTypeSwitch];
    box.title = title;
    box.state = [[NSUserDefaults standardUserDefaults] boolForKey:key] ? NSControlStateValueOn : NSControlStateValueOff;
    box.identifier = key;
    box.target = self; box.action = @selector(checkboxToggled:);
    [content addSubview:box];
    return box;
}

- (NSTextField *)makePlainLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *l = [[NSTextField alloc] initWithFrame:frame];
    l.stringValue = text ?: @"";
    l.bezeled = NO; l.drawsBackground = NO; l.editable = NO; l.selectable = NO;
    l.font = [NSFont systemFontOfSize:12];
    return l;
}

#pragma mark - Actions

- (void)checkboxToggled:(NSButton *)sender {
    NSString *key = sender.identifier;
    if (key) [[NSUserDefaults standardUserDefaults] setBool:(sender.state == NSControlStateValueOn) forKey:key];
}

- (void)formatChanged:(NSPopUpButton *)sender {
    [[NSUserDefaults standardUserDefaults] setObject:sender.titleOfSelectedItem.lowercaseString
                                              forKey:CPDefaultsImageFormat];
}

- (void)chooseFolder:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.canChooseDirectories = YES;
    panel.canChooseFiles = NO;
    panel.allowsMultipleSelection = NO;
    panel.prompt = @"Choose";
    NSString *cur = [[NSUserDefaults standardUserDefaults] stringForKey:CPDefaultsSaveDirectory];
    if (cur) panel.directoryURL = [NSURL fileURLWithPath:cur];
    if ([panel runModal] == NSModalResponseOK && panel.URL) {
        [[NSUserDefaults standardUserDefaults] setObject:panel.URL.path forKey:CPDefaultsSaveDirectory];
        self.pathLabel.stringValue = [self prettyPath];
        self.pathLabel.toolTip = panel.URL.path;
    }
}

- (NSString *)prettyPath {
    NSString *path = [[NSUserDefaults standardUserDefaults] stringForKey:CPDefaultsSaveDirectory] ?: @"";
    return [path stringByAbbreviatingWithTildeInPath];
}

@end
