// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPHistoryPanelController.h"
#import "CPClipboardHistory.h"

static const CGFloat kPanelW = 380, kPanelH = 480, kRowH = 76, kFooterH = 30;

#pragma mark - Key-handling table

@protocol CPHistoryTableKeys <NSObject>
- (void)historyTableCopySelected;
- (void)historyTableDeleteSelected;
- (void)historyTableCancel;
@end

@interface CPHistoryTableView : NSTableView
@property (nonatomic, weak) id<CPHistoryTableKeys> keyHandler;
@end

@implementation CPHistoryTableView
- (void)keyDown:(NSEvent *)event {
    switch (event.keyCode) {
        case 36: case 76:  [self.keyHandler historyTableCopySelected]; return;   // Return / Enter
        case 51: case 117: [self.keyHandler historyTableDeleteSelected]; return; // Delete / Fwd-delete
        case 53:           [self.keyHandler historyTableCancel]; return;         // Esc
        default: [super keyDown:event];
    }
}
@end

#pragma mark - Controller

@interface CPHistoryPanelController () <NSTableViewDataSource, NSTableViewDelegate, NSWindowDelegate, CPHistoryTableKeys>
@property (nonatomic, strong) CPHistoryTableView *table;
@property (nonatomic, strong) NSTextField *emptyLabel;
@property (nonatomic, strong) NSArray<CPClipboardEntry *> *entries;
@property (nonatomic, strong) NSRunningApplication *previousApp;
@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@end

@implementation CPHistoryPanelController

- (instancetype)init {
    NSPanel *panel = [[NSPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, kPanelW, kPanelH)
                  styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable)
                    backing:NSBackingStoreBuffered defer:NO];
    panel.title = @"Clipboard History";
    panel.level = NSFloatingWindowLevel;
    panel.hidesOnDeactivate = YES;
    panel.releasedWhenClosed = NO;
    panel.minSize = NSMakeSize(280, 240);

    if ((self = [super initWithWindow:panel])) {
        panel.delegate = self;
        _timeFormatter = [[NSDateFormatter alloc] init];
        _timeFormatter.dateStyle = NSDateFormatterNoStyle;
        _timeFormatter.timeStyle = NSDateFormatterMediumStyle;
        [self buildUIInto:panel.contentView];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload)
                                                     name:CPClipboardHistoryDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc { [[NSNotificationCenter defaultCenter] removeObserver:self]; }

- (void)buildUIInto:(NSView *)content {
    NSRect bounds = content.bounds;

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, kFooterH, bounds.size.width,
                                                                          bounds.size.height - kFooterH)];
    scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scroll.hasVerticalScroller = YES;
    scroll.drawsBackground = NO;

    CPHistoryTableView *table = [[CPHistoryTableView alloc] initWithFrame:scroll.bounds];
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"entry"];
    col.resizingMask = NSTableColumnAutoresizingMask;
    [table addTableColumn:col];
    table.headerView = nil;
    table.rowHeight = kRowH;
    table.style = NSTableViewStyleInset;
    table.columnAutoresizingStyle = NSTableViewUniformColumnAutoresizingStyle;
    table.dataSource = self;
    table.delegate = self;
    table.keyHandler = self;
    table.target = self;
    table.doubleAction = @selector(rowDoubleClicked:);
    scroll.documentView = table;
    [content addSubview:scroll];
    self.table = table;

    self.emptyLabel = [NSTextField labelWithString:@"No images copied yet.\nCopy a screenshot from Captr and it shows up here."];
    self.emptyLabel.alignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [NSColor secondaryLabelColor];
    self.emptyLabel.frame = NSMakeRect(20, bounds.size.height / 2 - 20, bounds.size.width - 40, 40);
    self.emptyLabel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin | NSViewMaxYMargin;
    [content addSubview:self.emptyLabel];

    NSTextField *hint = [NSTextField labelWithString:@"↩ Copy   ⌫ Delete   esc Close"];
    hint.font = [NSFont systemFontOfSize:11];
    hint.textColor = [NSColor tertiaryLabelColor];
    hint.alignment = NSTextAlignmentCenter;
    hint.frame = NSMakeRect(0, 8, bounds.size.width, 16);
    hint.autoresizingMask = NSViewWidthSizable;
    [content addSubview:hint];
}

#pragma mark Showing

- (void)toggle {
    if (self.window.isVisible) { [self dismissAndRestoreFocus]; return; }

    NSRunningApplication *front = [NSWorkspace sharedWorkspace].frontmostApplication;
    self.previousApp = [front isEqual:[NSRunningApplication currentApplication]] ? nil : front;

    [self reload];
    [self centerOnScreenUnderCursor];
    [NSApp activateIgnoringOtherApps:YES];
    [self showWindow:nil];
    [self.window makeKeyAndOrderFront:nil];
    [self.window makeFirstResponder:self.table];
    if (self.entries.count) {
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        [self.table scrollRowToVisible:0];
    }
}

- (void)centerOnScreenUnderCursor {
    NSPoint mouse = [NSEvent mouseLocation];
    NSScreen *screen = [NSScreen mainScreen];
    for (NSScreen *s in [NSScreen screens]) {
        if (NSPointInRect(mouse, s.frame)) { screen = s; break; }
    }
    NSRect vis = screen.visibleFrame, f = self.window.frame;
    [self.window setFrameOrigin:NSMakePoint(round(NSMidX(vis) - f.size.width / 2),
                                            round(NSMidY(vis) - f.size.height / 2))];
}

- (void)dismissAndRestoreFocus {
    [self.window orderOut:nil];
    [self.previousApp activateWithOptions:0];
    self.previousApp = nil;
}

- (void)reload {
    NSInteger sel = self.table.selectedRow;
    self.entries = [CPClipboardHistory sharedHistory].entries;
    [self.table reloadData];
    self.emptyLabel.hidden = self.entries.count > 0;
    if (self.entries.count && sel >= 0) {
        NSInteger row = MIN(sel, (NSInteger)self.entries.count - 1);
        [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
    }
}

#pragma mark Actions

- (CPClipboardEntry *)selectedEntry {
    NSInteger row = self.table.selectedRow;
    return (row >= 0 && row < (NSInteger)self.entries.count) ? self.entries[row] : nil;
}

- (void)historyTableCopySelected {
    CPClipboardEntry *entry = [self selectedEntry];
    if (!entry) { NSBeep(); return; }
    [[CPClipboardHistory sharedHistory] copyEntryToPasteboard:entry];
    [self dismissAndRestoreFocus];
}

- (void)historyTableDeleteSelected {
    CPClipboardEntry *entry = [self selectedEntry];
    if (entry) [[CPClipboardHistory sharedHistory] removeEntry:entry]; else NSBeep();
}

- (void)historyTableCancel { [self dismissAndRestoreFocus]; }

- (void)rowDoubleClicked:(id)sender {
    if (self.table.clickedRow < 0) return;
    [self.table selectRowIndexes:[NSIndexSet indexSetWithIndex:self.table.clickedRow] byExtendingSelection:NO];
    [self historyTableCopySelected];
}

// The close button: also hand focus back.
- (BOOL)windowShouldClose:(NSWindow *)sender {
    [self dismissAndRestoreFocus];
    return NO;
}

#pragma mark Table

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView { return (NSInteger)self.entries.count; }

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)col row:(NSInteger)row {
    NSTableCellView *cell = [tableView makeViewWithIdentifier:@"HistoryCell" owner:self];
    if (!cell) {
        cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, kPanelW, kRowH)];
        cell.identifier = @"HistoryCell";

        NSImageView *thumb = [[NSImageView alloc] initWithFrame:NSMakeRect(6, 6, 104, kRowH - 12)];
        thumb.imageScaling = NSImageScaleProportionallyDown;
        thumb.wantsLayer = YES;
        thumb.layer.cornerRadius = 4;
        thumb.layer.masksToBounds = YES;
        [cell addSubview:thumb];
        cell.imageView = thumb;

        NSTextField *title = [NSTextField labelWithString:@""];
        title.font = [NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightMedium];
        title.frame = NSMakeRect(122, kRowH / 2, kPanelW - 140, 18);
        title.autoresizingMask = NSViewWidthSizable;
        [cell addSubview:title];
        cell.textField = title;

        NSTextField *sub = [NSTextField labelWithString:@""];
        sub.font = [NSFont systemFontOfSize:11];
        sub.textColor = [NSColor secondaryLabelColor];
        sub.frame = NSMakeRect(122, kRowH / 2 - 20, kPanelW - 140, 16);
        sub.autoresizingMask = NSViewWidthSizable;
        sub.identifier = @"subtitle";
        [cell addSubview:sub];
    }
    CPClipboardEntry *e = self.entries[row];
    cell.imageView.image = e.thumbnail;
    cell.textField.stringValue = [NSString stringWithFormat:@"%d × %d",
                                  (int)e.pixelSize.width, (int)e.pixelSize.height];
    for (NSView *v in cell.subviews) {
        if ([v.identifier isEqualToString:@"subtitle"]) {
            ((NSTextField *)v).stringValue = [NSString stringWithFormat:@"Copied at %@",
                                              [self.timeFormatter stringFromDate:e.date]];
        }
    }
    return cell;
}

@end
