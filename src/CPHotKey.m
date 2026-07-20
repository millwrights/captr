// Captr — SPDX-License-Identifier: MIT OR Apache-2.0
#import "CPHotKey.h"
#import <Carbon/Carbon.h>

static UInt32 gNextHotKeyID = 1;
static NSMapTable<NSNumber *, CPHotKey *> *gRegistry = nil;
static EventHandlerRef gHandlerRef = NULL;

@interface CPHotKey ()
@property (nonatomic, copy) void (^handler)(void);
@property (nonatomic) EventHotKeyRef hotKeyRef;
@property (nonatomic) UInt32 hotKeyID;
@property (nonatomic, readwrite) BOOL registered;
@end

static OSStatus CPHotKeyEventHandler(EventHandlerCallRef nextHandler,
                                     EventRef event, void *userData) {
    (void)nextHandler; (void)userData;
    EventHotKeyID hkID;
    OSStatus status = GetEventParameter(event, kEventParamDirectObject, typeEventHotKeyID,
                                        NULL, sizeof(hkID), NULL, &hkID);
    if (status != noErr) return status;

    CPHotKey *hk = [gRegistry objectForKey:@(hkID.id)];
    if (hk.handler) {
        dispatch_async(dispatch_get_main_queue(), ^{ hk.handler(); });
    }
    return noErr;
}

@implementation CPHotKey

+ (void)initialize {
    if (self == [CPHotKey class]) {
        gRegistry = [NSMapTable strongToWeakObjectsMapTable];
    }
}

- (instancetype)initWithKeyCode:(uint32_t)keyCode
                      modifiers:(uint32_t)modifiers
                        handler:(void (^)(void))handler {
    if ((self = [super init])) {
        _handler = [handler copy];
        _hotKeyID = gNextHotKeyID++;

        // Install the shared Carbon event handler once.
        if (gHandlerRef == NULL) {
            EventTypeSpec spec = { kEventClassKeyboard, kEventHotKeyPressed };
            InstallApplicationEventHandler(&CPHotKeyEventHandler, 1, &spec, NULL, &gHandlerRef);
        }

        EventHotKeyID hkID;
        hkID.signature = 'CAPR';
        hkID.id = _hotKeyID;

        OSStatus status = RegisterEventHotKey(keyCode, modifiers, hkID,
                                              GetApplicationEventTarget(), 0, &_hotKeyRef);
        if (status != noErr) {
            NSLog(@"[Captr] Failed to register hotkey (status %d). "
                  @"Another app may already own this shortcut.", (int)status);
            return self;
        }
        _registered = YES;
        [gRegistry setObject:self forKey:@(_hotKeyID)];
    }
    return self;
}

+ (BOOL)canRegisterKeyCode:(uint32_t)keyCode modifiers:(uint32_t)modifiers {
    EventHotKeyID probe = { .signature = 'CApr', .id = 0xFFFF };
    EventHotKeyRef ref = NULL;
    OSStatus status = RegisterEventHotKey(keyCode, modifiers, probe,
                                          GetApplicationEventTarget(), 0, &ref);
    if (status == noErr && ref) {
        UnregisterEventHotKey(ref);
        return YES;
    }
    return NO;
}

- (void)unregister {
    if (_hotKeyRef) {
        UnregisterEventHotKey(_hotKeyRef);
        _hotKeyRef = NULL;
    }
    [gRegistry removeObjectForKey:@(_hotKeyID)];
}

- (void)dealloc {
    [self unregister];
}

@end
