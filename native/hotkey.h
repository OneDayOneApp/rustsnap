#pragma once
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

// Carbon delivers only the registered chord; no event tap or Accessibility
// authorization is needed. Registration and invalidation run on the main thread.
@interface RustSnapHotKey : NSObject {
    EventHotKeyRef _hotKey;
    EventHandlerRef _handler;
}
@property(nonatomic, weak) id target;
@property(nonatomic) SEL action;
@property(nonatomic, readonly) BOOL registered;
-(BOOL)registerCaptureWithTarget:(id)target action:(SEL)action error:(NSError **)error;
-(BOOL)registerKeyCode:(UInt32)keyCode modifiers:(NSEventModifierFlags)modifiers target:(id)target action:(SEL)action error:(NSError **)error;
-(void)invalidate;
@end

static const UInt32 RustSnapHotKeySignature = 0x52534e50; // RSNP
static OSStatus RustSnapHandleHotKey(EventHandlerCallRef next, EventRef event, void *context) {
    EventHotKeyID key = {0};
    OSStatus status = GetEventParameter(event, kEventParamDirectObject,
        typeEventHotKeyID, NULL, sizeof(key), NULL, &key);
    if (status != noErr) return status;
    if (key.signature != RustSnapHotKeySignature || key.id != 1) return eventNotHandledErr;
    RustSnapHotKey *binding = (__bridge RustSnapHotKey *)context;
    [NSApp sendAction:binding.action to:binding.target from:binding];
    return noErr;
}

@implementation RustSnapHotKey
-(BOOL)registered { return _hotKey != NULL; }
-(BOOL)registerCaptureWithTarget:(id)target action:(SEL)action error:(NSError **)error {
    return [self registerKeyCode:kVK_ANSI_S modifiers:NSEventModifierFlagControl|NSEventModifierFlagCommand target:target action:action error:error];
}
-(BOOL)registerKeyCode:(UInt32)keyCode modifiers:(NSEventModifierFlags)modifiers target:(id)target action:(SEL)action error:(NSError **)error {
    NSAssert(NSThread.isMainThread, @"Hot keys must be registered on the main thread");
    [self invalidate];
    self.target = target;
    self.action = action;
    EventTypeSpec type = {kEventClassKeyboard, kEventHotKeyPressed};
    OSStatus status = InstallEventHandler(GetApplicationEventTarget(),
        RustSnapHandleHotKey, 1, &type, (__bridge void *)self, &_handler);
    if (status == noErr) {
        EventHotKeyID identifier = {RustSnapHotKeySignature, 1};
        UInt32 carbon=0;
        if(modifiers&NSEventModifierFlagControl)carbon|=controlKey;
        if(modifiers&NSEventModifierFlagCommand)carbon|=cmdKey;
        if(modifiers&NSEventModifierFlagOption)carbon|=optionKey;
        if(modifiers&NSEventModifierFlagShift)carbon|=shiftKey;
        status = RegisterEventHotKey(keyCode, carbon,
            identifier, GetApplicationEventTarget(), kEventHotKeyExclusive, &_hotKey);
    }
    if (status == noErr) return YES;
    [self invalidate];
    NSString *message = status == eventHotKeyExistsErr
        ? @"该快捷键已被其他应用占用。请换一个组合；原快捷键会保留。"
        : [NSString stringWithFormat:@"无法注册该快捷键（系统错误 %d）。仍可从菜单栏点击“截屏”。", (int)status];
    if (error) *error = [NSError errorWithDomain:@"dev.local.rustsnip.hotkey"
        code:status userInfo:@{NSLocalizedDescriptionKey:message}];
    return NO;
}
-(void)invalidate {
    if (_hotKey) { UnregisterEventHotKey(_hotKey); _hotKey = NULL; }
    if (_handler) { RemoveEventHandler(_handler); _handler = NULL; }
    self.target = nil;
    self.action = NULL;
}
-(void)dealloc { [self invalidate]; }
@end
