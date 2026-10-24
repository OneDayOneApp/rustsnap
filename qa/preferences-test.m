#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
static void ShowMessage(NSString *title,NSString *detail){NSLog(@"%@: %@",title,detail);}
#include "../native/preferences.m"
int main(){@autoreleasepool{
    [NSApplication sharedApplication];NSMutableArray *checks=[NSMutableArray array];
    void(^check)(NSString*,BOOL)=^(NSString *name,BOOL ok){[checks addObject:@{@"name":name,@"passed":@(ok)}];};
    NSString *suite=[@"dev.local.rustsnip.tests." stringByAppendingString:NSUUID.UUID.UUIDString];
    NSUserDefaults *d=[[NSUserDefaults alloc]initWithSuiteName:suite];RegisterPreferenceDefaults(d);
    check(@"default shortcut is Control Command S",[d integerForKey:PrefShortcutCode]==kVK_ANSI_S&&[d integerForKey:PrefShortcutModifiers]==(NSEventModifierFlagCommand|NSEventModifierFlagControl)&&[[d stringForKey:PrefShortcutCharacter]isEqual:@"s"]);
    check(@"default output is clipboard only with native resolution",[d boolForKey:@"captureOnlyClipboard"]&&![d boolForKey:@"captureOneX"]);
    [d setBool:NO forKey:@"captureSound"];[d setBool:YES forKey:@"captureOneX"];[d setObject:@"/tmp/选择的图片目录" forKey:@"captureSaveFolder"];[d setObject:@"x" forKey:PrefShortcutCharacter];[d synchronize];
    NSUserDefaults *loaded=[[NSUserDefaults alloc]initWithSuiteName:suite];
    check(@"settings persist in an isolated defaults domain",![loaded boolForKey:@"captureSound"]&&[loaded boolForKey:@"captureOneX"]&&[[loaded stringForKey:@"captureSaveFolder"]isEqual:@"/tmp/选择的图片目录"]&&[[loaded stringForKey:PrefShortcutCharacter]isEqual:@"x"]);
    check(@"shortcut hint uses native modifier symbols",[ShortcutDescription(@"s",NSEventModifierFlagControl|NSEventModifierFlagCommand)isEqual:@"⌃⌘S"]&&[ShortcutDescription(@"",0)isEqual:@"未设置"]);
    NSBitmapImageRep *source=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:80 pixelsHigh:40 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    for(NSInteger y=0;y<40;y++)for(NSInteger x=0;x<80;x++){NSUInteger pixel[4]={y<20?255:0,0,y<20?0:255,255};[source setPixel:pixel atX:x y:y];}
    NSImage *retina=[[NSImage alloc]initWithSize:NSMakeSize(40,20)];[retina addRepresentation:source];
    NSImage *one=PreferenceOneXImage(retina);NSBitmapImageRep *rep=[[NSBitmapImageRep alloc]initWithData:one.TIFFRepresentation];
    check(@"Retina 1x halves pixel dimensions",rep.pixelsWide==40&&rep.pixelsHigh==20);
    NSUInteger top[4]={0},bottom[4]={0};[rep getPixel:top atX:10 y:2];[rep getPixel:bottom atX:10 y:17];
    check(@"Retina downsample preserves image orientation",top[0]>240&&top[2]<10&&bottom[2]>240&&bottom[0]<10);
    NSString *folder=[NSTemporaryDirectory()stringByAppendingPathComponent:[@"rustsnip-pref-test-" stringByAppendingString:NSUUID.UUID.UUIDString]];NSError *error=nil;
    NSURL *first=PreferenceWritePNG(one,folder,&error),*second=PreferenceWritePNG(one,folder,&error);
    check(@"auto-save creates valid unique PNG files",first&&second&&![first isEqual:second]&&[[NSBitmapImageRep alloc]initWithData:[NSData dataWithContentsOfURL:first]].pixelsWide==40);
    NSString *block=[folder stringByAppendingPathComponent:@"not-a-folder"];[@"occupied" writeToFile:block atomically:YES encoding:NSUTF8StringEncoding error:nil];error=nil;
    check(@"save failure returns actionable error",PreferenceWritePNG(one,block,&error)==nil&&error!=nil);
    NSDictionary *login=LoginAgentConfiguration(@"/Applications/RustSnip.app/Contents/MacOS/RustSnip");
    check(@"login launch uses background mode without keep-alive",[login[@"RunAtLoad"]boolValue]&&[login[@"ProgramArguments"]isEqual:@[@"/Applications/RustSnip.app/Contents/MacOS/RustSnip",@"--background"]]&&login[@"KeepAlive"]==nil);
    [d removePersistentDomainForName:suite];[NSFileManager.defaultManager removeItemAtPath:folder error:nil];
    BOOL passed=YES;for(NSDictionary *c in checks)if(![c[@"passed"]boolValue])passed=NO;
    NSData *report=[NSJSONSerialization dataWithJSONObject:@{@"passed":@(passed),@"checks":checks,@"scope":@"Production preferences helpers with isolated defaults and temporary files; no user settings, clipboard or login items changed."} options:NSJSONWritingPrettyPrinted error:nil];
    [report writeToFile:@"qa/preferences-results.json" atomically:YES];puts([[NSString alloc]initWithData:report encoding:NSUTF8StringEncoding].UTF8String);return passed?0:1;
}}
