// Native preferences UI and OS services. Defaults are injected for isolated tests.
static NSString *const PrefShortcutCode=@"captureShortcutCode", *const PrefShortcutModifiers=@"captureShortcutModifiers", *const PrefShortcutCharacter=@"captureShortcutCharacter", *const PrefShortcutEnabled=@"captureShortcutEnabled";
static void RegisterPreferenceDefaults(NSUserDefaults *defaults){
    [defaults registerDefaults:@{PrefShortcutCode:@(kVK_ANSI_S),PrefShortcutModifiers:@(NSEventModifierFlagControl|NSEventModifierFlagCommand),PrefShortcutCharacter:@"s",PrefShortcutEnabled:@YES,@"captureSound":@YES,@"captureOneX":@NO,@"captureOnlyClipboard":@YES,@"captureAlsoClipboard":@YES,@"captureSaveFolder":[NSHomeDirectory()stringByAppendingPathComponent:@"Pictures/RustSnip"]}];
}
static NSString *ShortcutDescription(NSString *key,NSEventModifierFlags flags){
    if(!key.length)return @"未设置";NSMutableString *s=[NSMutableString string];
    if(flags&NSEventModifierFlagControl)[s appendString:@"⌃"];if(flags&NSEventModifierFlagOption)[s appendString:@"⌥"];
    if(flags&NSEventModifierFlagShift)[s appendString:@"⇧"];if(flags&NSEventModifierFlagCommand)[s appendString:@"⌘"];
    [s appendString:key.uppercaseString];return s;
}
static NSImage *PreferenceOneXImage(NSImage *image){
    NSInteger w=MAX(1,lround(image.size.width)),h=MAX(1,lround(image.size.height));
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:w pixelsHigh:h bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    NSGraphicsContext *context=[NSGraphicsContext graphicsContextWithBitmapImageRep:rep];[NSGraphicsContext saveGraphicsState];[NSGraphicsContext setCurrentContext:context];CGContextClearRect(context.CGContext,CGRectMake(0,0,w,h));
    [image drawInRect:NSMakeRect(0,0,w,h) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:NO hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
    [NSGraphicsContext restoreGraphicsState];NSImage *out=[[NSImage alloc]initWithSize:NSMakeSize(w,h)];[out addRepresentation:rep];return out;
}
static NSURL *PreferenceWritePNG(NSImage *image,NSString *folder,NSError **error){
    if(![[NSFileManager defaultManager]createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:error])return nil;
    NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];f.dateFormat=@"yyyy-MM-dd_HH-mm-ss-SSS";
    NSString *name=[NSString stringWithFormat:@"RustSnap_%@_%@.png",[f stringFromDate:NSDate.date],[NSUUID.UUID.UUIDString substringToIndex:8]];
    NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithData:image.TIFFRepresentation];NSData *data=[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if(!data){if(error)*error=[NSError errorWithDomain:@"dev.local.rustsnip" code:1 userInfo:@{NSLocalizedDescriptionKey:@"图片无法编码为 PNG。"}];return nil;}
    NSURL *url=[NSURL fileURLWithPath:[folder stringByAppendingPathComponent:name]];return [data writeToURL:url options:NSDataWritingAtomic error:error]?url:nil;
}
static NSString *LoginAgentPath(void){return [NSHomeDirectory()stringByAppendingPathComponent:@"Library/LaunchAgents/dev.local.rustsnip.plist"];}
static NSDictionary *LoginAgentConfiguration(NSString *executable){
    return @{@"Label":@"dev.local.rustsnip",@"ProgramArguments":@[executable,@"--background"],@"RunAtLoad":@YES,@"LimitLoadToSessionType":@"Aqua"};
}
static BOOL SetLoginAgent(BOOL enabled,NSError **error){
    NSString *path=LoginAgentPath();NSFileManager *fm=NSFileManager.defaultManager;
    if(!enabled)return ![fm fileExistsAtPath:path]||[fm removeItemAtPath:path error:error];
    if(![fm createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:error])return NO;
    NSString *executable=NSBundle.mainBundle.executablePath;
    NSDictionary *config=LoginAgentConfiguration(executable);
    NSData *data=[NSPropertyListSerialization dataWithPropertyList:config format:NSPropertyListXMLFormat_v1_0 options:0 error:error];return data&&[data writeToFile:path options:NSDataWritingAtomic error:error];
}
@interface ShortcutRecorder:NSButton
@property BOOL recording;
@property NSString *savedTitle;
@property(copy) void(^recordingChanged)(BOOL);
@property(copy) BOOL(^changed)(UInt32,NSEventModifierFlags,NSString*,NSError**);
@end
@implementation ShortcutRecorder
-(BOOL)acceptsFirstResponder{return YES;}
-(void)mouseDown:(NSEvent*)event{
    if(self.recording)return;self.recording=YES;self.savedTitle=self.title;self.title=@"请按快捷键（Esc 取消，Delete 清除）";
    if(self.recordingChanged)self.recordingChanged(YES);[self.window makeFirstResponder:self];
}
-(void)stopRecording{if(!self.recording)return;self.recording=NO;if(self.recordingChanged)self.recordingChanged(NO);}
-(BOOL)resignFirstResponder{if(self.recording){self.title=self.savedTitle;[self stopRecording];}return YES;}
-(BOOL)performKeyEquivalent:(NSEvent*)event{if(self.recording){[self keyDown:event];return YES;}return [super performKeyEquivalent:event];}
-(void)keyDown:(NSEvent*)event{
    if(!self.recording){[super keyDown:event];return;}
    if(event.keyCode==53){self.title=self.savedTitle;[self stopRecording];return;}
    BOOL clear=event.keyCode==51||event.keyCode==117;
    NSEventModifierFlags flags=event.modifierFlags&(NSEventModifierFlagControl|NSEventModifierFlagOption|NSEventModifierFlagShift|NSEventModifierFlagCommand);
    NSString *key=clear?@"":event.charactersIgnoringModifiers.lowercaseString;
    if(!clear&&(!(flags&(NSEventModifierFlagControl|NSEventModifierFlagCommand|NSEventModifierFlagOption))||key.length!=1||![[NSCharacterSet alphanumericCharacterSet]characterIsMember:[key characterAtIndex:0]])){
        self.title=@"请使用 ⌃、⌥ 或 ⌘ 加字母/数字";return;
    }
    if(!clear&&flags==NSEventModifierFlagCommand&&[key isEqual:@"q"]){
        self.title=self.savedTitle;[self stopRecording];[NSApp sendAction:@selector(quitApplication:) to:NSApp.delegate from:self];return;
    }
    if(!clear&&flags==NSEventModifierFlagCommand&&[@[@"q",@"w",@"c",@"v",@"z",@","]containsObject:key]){self.title=@"该组合用于应用操作，请换一个";return;}
    NSError *error=nil;
    if(self.changed&&!self.changed(clear?UINT32_MAX:event.keyCode,clear?0:flags,key,&error)){self.title=self.savedTitle;[self stopRecording];ShowMessage(@"快捷键未更改",error.localizedDescription);return;}
    self.title=ShortcutDescription(key,flags);[self stopRecording];
}
@end
@interface PreferencesController:NSObject<NSWindowDelegate>
@property NSWindow *window;
@property NSUserDefaults *defaults;
@property ShortcutRecorder *recorder;
@property NSButton *alsoClipboard;
@property NSButton *onlyClipboard;
@property NSButton *login;
@property NSPopUpButton *folders;
@property(copy) BOOL(^shortcutChanged)(UInt32,NSEventModifierFlags,NSString*,NSError**);
@property(copy) void(^recordingChanged)(BOOL);
-(void)show;
@end
@implementation PreferencesController
-(NSTextField*)label:(NSString*)text frame:(NSRect)frame font:(CGFloat)size parent:(NSView*)parent{
    NSTextField *label=[NSTextField labelWithString:text];label.frame=frame;label.font=[NSFont systemFontOfSize:size];[parent addSubview:label];return label;
}
-(NSButton*)check:(NSString*)text key:(NSString*)key y:(CGFloat)y parent:(NSView*)parent{
    NSButton *button=[NSButton checkboxWithTitle:text target:self action:@selector(toggle:)];button.frame=NSMakeRect(180,y,350,25);button.identifier=key;button.state=[self.defaults boolForKey:key]?NSControlStateValueOn:NSControlStateValueOff;[parent addSubview:button];return button;
}
-(void)show{
    if(!self.window){
        NSView *root=[[NSView alloc]initWithFrame:NSMakeRect(0,0,560,530)];
        self.window=[[NSWindow alloc]initWithContentRect:root.bounds styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable backing:NSBackingStoreBuffered defer:NO];
        self.window.title=@"RustSnap 偏好设置";self.window.releasedWhenClosed=NO;self.window.delegate=self;self.window.contentView=root;[self.window center];
        NSView *header=[[NSView alloc]initWithFrame:NSMakeRect(0,426,560,104)];header.wantsLayer=YES;header.layer.backgroundColor=[NSColor colorWithWhite:.06 alpha:1].CGColor;[root addSubview:header];
        NSImageView *icon=[[NSImageView alloc]initWithFrame:NSMakeRect(22,16,72,72)];icon.image=[NSImage imageNamed:NSImageNameApplicationIcon];[header addSubview:icon];
        NSTextField *title=[self label:@"偏好设置" frame:NSMakeRect(112,48,380,40) font:30 parent:header];title.textColor=NSColor.whiteColor;
        NSTextField *subtitle=[self label:@"按你的习惯设置截图与保存方式" frame:NSMakeRect(114,20,380,23) font:13 parent:header];subtitle.textColor=[NSColor colorWithWhite:.85 alpha:1];
        NSArray *labels=@[@"截屏快捷键：",@"截屏时：",@"图片大小：",@"图片保存位置："];
        CGFloat labelY[]={371,321,262,202};for(int i=0;i<4;i++){NSTextField *label=[self label:labels[i] frame:NSMakeRect(14,labelY[i],150,25) font:14 parent:root];label.alignment=NSTextAlignmentRight;}
        self.recorder=[[ShortcutRecorder alloc]initWithFrame:NSMakeRect(180,371,314,30)];self.recorder.bezelStyle=NSBezelStyleRounded;
        self.recorder.title=[self.defaults boolForKey:PrefShortcutEnabled]?ShortcutDescription([self.defaults stringForKey:PrefShortcutCharacter],[self.defaults integerForKey:PrefShortcutModifiers]):@"未设置";
        self.recorder.toolTip=@"点击后按下新的截图快捷键；Delete 清除";
        __weak PreferencesController *weakSelf=self;
        self.recorder.changed=^BOOL(UInt32 code,NSEventModifierFlags flags,NSString *key,NSError **error){return weakSelf.shortcutChanged?weakSelf.shortcutChanged(code,flags,key,error):NO;};
        self.recorder.recordingChanged=^(BOOL active){if(weakSelf.recordingChanged)weakSelf.recordingChanged(active);};[root addSubview:self.recorder];
        NSButton *clear=[NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"xmark.circle.fill" accessibilityDescription:@"清除截图快捷键"] target:self action:@selector(clearShortcut:)];clear.bordered=NO;clear.frame=NSMakeRect(498,372,28,28);clear.toolTip=@"清除截图快捷键";[root addSubview:clear];
        [self check:@"截图完成后播放声音" key:@"captureSound" y:321 parent:root];
        [self check:@"Retina 屏幕下输出 1× 大小图片" key:@"captureOneX" y:262 parent:root];
        self.folders=[[NSPopUpButton alloc]initWithFrame:NSMakeRect(180,202,348,29)];self.folders.target=self;self.folders.action=@selector(folderChanged:);[root addSubview:self.folders];[self refreshFolders];
        self.alsoClipboard=[self check:@"同时保存到剪贴板" key:@"captureAlsoClipboard" y:163 parent:root];
        self.onlyClipboard=[self check:@"只保存到剪贴板" key:@"captureOnlyClipboard" y:130 parent:root];[self syncClipboard];
        self.login=[NSButton checkboxWithTitle:@"开机自动启动" target:self action:@selector(loginChanged:)];self.login.frame=NSMakeRect(180,70,340,25);self.login.state=[NSFileManager.defaultManager fileExistsAtPath:LoginAgentPath()]?NSControlStateValueOn:NSControlStateValueOff;[root addSubview:self.login];
        [self label:@"登录当前用户时在菜单栏启动，不弹出标注窗口" frame:NSMakeRect(181,49,350,18) font:11 parent:root];
        for(NSNumber *y in @[@306,@247,@116]){NSBox *line=[[NSBox alloc]initWithFrame:NSMakeRect(24,y.doubleValue,512,1)];line.boxType=NSBoxSeparator;[root addSubview:line];}
        NSButton *privacy=[NSButton buttonWithTitle:@"屏幕录制权限…" target:self action:@selector(openPrivacy:)];privacy.frame=NSMakeRect(24,10,150,28);[root addSubview:privacy];
        NSTextField *foot=[self label:@"设置会立即保存" frame:NSMakeRect(374,14,150,20) font:11 parent:root];foot.alignment=NSTextAlignmentRight;foot.textColor=NSColor.secondaryLabelColor;
    }
    [self.window makeKeyAndOrderFront:nil];[NSApp activateIgnoringOtherApps:YES];
}
-(void)clearShortcut:(id)sender{
    if(self.recorder.recording){self.recorder.title=self.recorder.savedTitle;[self.recorder stopRecording];}
    NSError *error=nil;if(self.shortcutChanged&&self.shortcutChanged(UINT32_MAX,0,@"",&error))self.recorder.title=@"未设置";
    else if(error)ShowMessage(@"快捷键未更改",error.localizedDescription);
}
-(void)syncClipboard{self.alsoClipboard.enabled=![self.defaults boolForKey:@"captureOnlyClipboard"];}
-(void)toggle:(NSButton*)sender{[self.defaults setBool:sender.state==NSControlStateValueOn forKey:sender.identifier];[self syncClipboard];}
-(void)refreshFolders{
    [self.folders removeAllItems];NSString *path=[self.defaults stringForKey:@"captureSaveFolder"];
    [self.folders addItemWithTitle:path.stringByAbbreviatingWithTildeInPath];[self.folders.menu addItem:NSMenuItem.separatorItem];[self.folders addItemsWithTitles:@[@"桌面",@"图片",@"选择其他文件夹…"]];[self.folders selectItemAtIndex:0];self.folders.toolTip=path;
}
-(void)folderChanged:(NSPopUpButton*)sender{
    NSInteger index=sender.indexOfSelectedItem;NSString *path=nil;
    if(index==2)path=[NSHomeDirectory()stringByAppendingPathComponent:@"Desktop"];
    else if(index==3)path=[NSHomeDirectory()stringByAppendingPathComponent:@"Pictures"];
    else if(index==4){NSOpenPanel *panel=[NSOpenPanel openPanel];panel.canChooseFiles=NO;panel.canChooseDirectories=YES;panel.canCreateDirectories=YES;panel.prompt=@"选择保存位置";if([panel runModal]==NSModalResponseOK)path=panel.URL.path;}
    if(path)[self.defaults setObject:path forKey:@"captureSaveFolder"];[self refreshFolders];
}
-(void)loginChanged:(NSButton*)sender{
    BOOL enabled=sender.state==NSControlStateValueOn;NSError *error=nil;
    if(!SetLoginAgent(enabled,&error)){sender.state=enabled?NSControlStateValueOff:NSControlStateValueOn;ShowMessage(@"无法更改开机启动",error.localizedDescription);}
}
-(void)openPrivacy:(id)sender{[NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];}
-(void)windowWillClose:(NSNotification*)note{if(self.recorder.recording){self.recorder.title=self.recorder.savedTitle;[self.recorder stopRecording];}}
@end
