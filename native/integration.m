// Integration checks use the production Canvas and Rust document model.
static NSBitmapImageRep *TestBitmap(NSImage *image) {
    return [[NSBitmapImageRep alloc] initWithData:image.TIFFRepresentation];
}
static NSData *TestPixels(NSBitmapImageRep *rep) {
    NSMutableData *bytes=[NSMutableData data];
    for(NSInteger y=0;y<rep.pixelsHigh;y++)for(NSInteger x=0;x<rep.pixelsWide;x++){
        NSUInteger px[4]={0,0,0,255};[rep getPixel:px atX:x y:y];
        unsigned char rgba[4]={(unsigned char)px[0],(unsigned char)px[1],(unsigned char)px[2],(unsigned char)(rep.hasAlpha?px[rep.samplesPerPixel-1]:255)};
        [bytes appendBytes:rgba length:4];
    }
    return bytes;
}
int run_integration(const char *directory){@autoreleasepool{
    [NSApplication sharedApplication];
    NSString *dir=[NSString stringWithUTF8String:directory];
    [[NSFileManager defaultManager]createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableArray *checks=[NSMutableArray array];
    void(^check)(NSString*,BOOL)=^(NSString *name,BOOL passed){[checks addObject:@{@"name":name,@"passed":@(passed)}];};
    NSBitmapImageRep *source=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:256 pixelsHigh:192 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    for(NSInteger y=0;y<192;y++)for(NSInteger x=0;x<256;x++){
        NSUInteger px[4]={255,255,255,255};
        if(x<8&&y<8){px[0]=0;px[1]=0;px[2]=0;px[3]=0;}
        else if(x<16&&y<16){px[0]=0;px[1]=0;px[2]=255;}
        else if(x<16&&y>176){px[0]=0;px[1]=255;px[2]=0;}
        [source setPixel:px atX:x y:y];
    }
    NSString *input=[dir stringByAppendingPathComponent:@"integration-input.png"];
    [[source representationUsingType:NSBitmapImageFileTypePNG properties:@{}]writeToFile:input atomically:YES];
    Canvas *canvas=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,256,192)];
    [canvas load:input];
    NSBitmapImageRep *base=TestBitmap([canvas render]);
    check(@"import retains pixel dimensions",base.pixelsWide==256&&base.pixelsHigh==192);
    check(@"import and render preserve orientation and alpha",[TestPixels(source)isEqual:TestPixels(base)]);
    NSData *last=TestPixels(base);
    for(int tool=0;tool<5;tool++){
        rust_model_set_tool(canvas.model,tool);rust_model_set_width(canvas.model,3);
        rust_model_begin(canvas.model,30+tool*40,40);
        if(tool==4)rust_model_text(canvas.model,"Test");
        else {if(tool==3)rust_model_drag(canvas.model,165,70);rust_model_drag(canvas.model,55+tool*40,100);}
        rust_model_finish(canvas.model);
        NSData *next=TestPixels(TestBitmap([canvas render]));
        check([NSString stringWithFormat:@"tool %d changes rendered pixels",tool],![last isEqual:next]);last=next;
    }
    NSData *all=last;
    rust_model_undo(canvas.model);
    check(@"undo changes rendered pixels",![all isEqual:TestPixels(TestBitmap([canvas render]))]);
    rust_model_redo(canvas.model);
    check(@"redo restores exact rendered pixels",[all isEqual:TestPixels(TestBitmap([canvas render]))]);
    NSImage *out=[canvas render];NSBitmapImageRep *outRep=TestBitmap(out);
    NSString *pngPath=[dir stringByAppendingPathComponent:@"integration-output.png"];
    NSData *png=[outRep representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    BOOL saved=[png writeToFile:pngPath atomically:YES];
    NSBitmapImageRep *decoded=[[NSBitmapImageRep alloc]initWithData:[NSData dataWithContentsOfFile:pngPath]];
    check(@"PNG file roundtrip preserves dimensions and pixels",saved&&decoded.pixelsWide==256&&decoded.pixelsHigh==192&&[all isEqual:TestPixels(decoded)]);
    NSPasteboard *board=[NSPasteboard pasteboardWithName:[@"dev.local.rustsnip.integration." stringByAppendingString:NSUUID.UUID.UUIDString]];
    BOOL written=[board writeObjects:@[out]];
    NSArray *images=[board readObjectsForClasses:@[NSImage.class] options:@{}];
    check(@"isolated pasteboard image roundtrip",written&&images.count==1&&[all isEqual:TestPixels(TestBitmap(images.firstObject))]);
    [board releaseGlobally];
    // Exercise production inline text lifecycle rather than only the model API.
    Canvas *tools=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,256,192)];[tools load:input];
    NSData *empty=TestPixels(TestBitmap([tools render]));
    rust_model_set_tool(tools.model,3);rust_model_set_width(tools.model,6);
    rust_model_begin(tools.model,60,60);rust_model_finish(tools.model);
    NSData *dot=TestPixels(TestBitmap([tools render]));
    check(@"single pen click renders a dot",![empty isEqual:dot]);
    NSColor *dotColor=[TestBitmap([tools render])colorAtX:60 y:60];
    check(@"pen dot is drawn at click location",dotColor.redComponent>.8&&dotColor.greenComponent<.5);
    rust_model_undo(tools.model);check(@"pen dot undo restores image",[empty isEqual:TestPixels(TestBitmap([tools render]))]);
    NSWindow *eventWindow=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,256,192) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    eventWindow.releasedWhenClosed=NO;eventWindow.contentView=tools;
    NSEvent *(^mouse)(NSEventType,NSPoint)=^NSEvent*(NSEventType type,NSPoint point){return [NSEvent mouseEventWithType:type location:[tools convertPoint:point toView:nil] modifierFlags:0 timestamp:0 windowNumber:eventWindow.windowNumber context:nil eventNumber:0 clickCount:1 pressure:1];};
    [tools mouseDown:mouse(NSEventTypeLeftMouseDown,NSMakePoint(40,40))];
    [tools mouseUp:mouse(NSEventTypeLeftMouseUp,NSMakePoint(110,100))];
    RShape stroke=rust_model_shape(tools.model,0);
    check(@"mouse release endpoint is retained without drag events",stroke.count==2&&stroke.points[1].x==110&&stroke.points[1].y==100);
    rust_model_undo(tools.model);
    rust_model_set_tool(tools.model,4);rust_model_set_width(tools.model,3);
    [tools beginTextAtPoint:NSMakePoint(25,30)];tools.textEditor.string=@"中文 Rust\n第二行";
    [tools render];
    check(@"export commits inline Unicode multiline text",tools.textEditor==nil&&rust_model_count(tools.model,NO)==1&&strcmp(rust_model_shape(tools.model,0).text,"中文 Rust\n第二行")==0);
    NSData *textPixels=TestPixels(TestBitmap([tools render]));
    check(@"inline text appears in export",![empty isEqual:textPixels]);
    [tools beginTextAtPoint:NSMakePoint(25,90)];tools.textEditor.string=@"取消";
    [tools textView:tools.textEditor doCommandBySelector:@selector(cancelOperation:)];
    check(@"Escape cancels only pending text",tools.textEditor==nil&&rust_model_count(tools.model,NO)==1&&[textPixels isEqual:TestPixels(TestBitmap([tools render]))]);
    [tools beginTextAtPoint:NSMakePoint(25,90)];tools.textEditor.string=@"   ";[tools commitText];
    check(@"blank text does not add undo entry",rust_model_count(tools.model,NO)==1);
    [tools beginTextAtPoint:NSMakePoint(500,500)];
    check(@"text editor stays inside image at edges",NSContainsRect(tools.bounds,tools.textEditor.frame));[tools cancelText];
    rust_model_undo(tools.model);check(@"inline text undo restores image",[empty isEqual:TestPixels(TestBitmap([tools render]))]);
    rust_model_redo(tools.model);check(@"inline text redo restores exact pixels",[textPixels isEqual:TestPixels(TestBitmap([tools render]))]);
    Canvas *eraser=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,256,192)];[eraser load:input];
    NSData *original=TestPixels(TestBitmap([eraser render]));
    rust_model_set_tool(eraser.model,3);rust_model_set_width(eraser.model,6);
    rust_model_begin(eraser.model,40,60);rust_model_drag(eraser.model,200,60);rust_model_finish(eraser.model);
    NSData *ink=TestPixels(TestBitmap([eraser render]));
    rust_model_set_tool(eraser.model,5);rust_model_set_width(eraser.model,4);
    rust_model_begin(eraser.model,120,30);rust_model_drag(eraser.model,120,90);rust_model_finish(eraser.model);
    NSBitmapImageRep *erased=TestBitmap([eraser render]);NSData *erasedPixels=TestPixels(erased);
    NSColor *center=[erased colorAtX:120 y:60],*remaining=[erased colorAtX:60 y:60];
    check(@"eraser removes crossed ink and reveals screenshot",center.redComponent>.95&&center.greenComponent>.95&&center.alphaComponent>.99&&remaining.greenComponent<.5);
    rust_model_undo(eraser.model);check(@"undo eraser restores exact ink",[ink isEqual:TestPixels(TestBitmap([eraser render]))]);
    rust_model_redo(eraser.model);check(@"redo eraser restores exact erased pixels",[erasedPixels isEqual:TestPixels(TestBitmap([eraser render]))]);
    rust_model_set_tool(eraser.model,3);rust_model_set_width(eraser.model,3);
    rust_model_begin(eraser.model,120,60);rust_model_finish(eraser.model);
    NSColor *newInk=[TestBitmap([eraser render])colorAtX:120 y:60];
    check(@"new ink can be drawn over an erased region",newInk.greenComponent<.5);
    rust_model_reset(eraser.model,256,192);rust_model_set_tool(eraser.model,5);
    rust_model_begin(eraser.model,4,4);rust_model_drag(eraser.model,220,160);rust_model_finish(eraser.model);
    check(@"erasing unmarked screenshot preserves exact pixels and alpha",[original isEqual:TestPixels(TestBitmap([eraser render]))]);
    rust_model_reset(eraser.model,256,192);rust_model_set_tool(eraser.model,3);rust_model_set_width(eraser.model,6);
    rust_model_begin(eraser.model,60,60);rust_model_finish(eraser.model);
    rust_model_set_tool(eraser.model,5);rust_model_begin(eraser.model,60,60);rust_model_finish(eraser.model);
    check(@"single click eraser removes a pen dot",[original isEqual:TestPixels(TestBitmap([eraser render]))]);
    NSBitmapImageRep *texture=[[NSBitmapImageRep alloc]initWithBitmapDataPlanes:NULL pixelsWide:256 pixelsHigh:192 bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0];
    for(NSInteger y=0;y<192;y++)for(NSInteger x=0;x<256;x++){NSUInteger v=(x+y)%2?255:0;NSUInteger px[4]={v,v,v,255};[texture setPixel:px atX:x y:y];}
    NSString *texturePath=[dir stringByAppendingPathComponent:@"mosaic-input.png"];
    [[texture representationUsingType:NSBitmapImageFileTypePNG properties:@{}]writeToFile:texturePath atomically:YES];
    Canvas *mosaic=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,256,192)];[mosaic load:texturePath];NSData *texturePixels=TestPixels(TestBitmap([mosaic render]));
    rust_model_set_tool(mosaic.model,6);rust_model_set_width(mosaic.model,4);
    rust_model_begin(mosaic.model,40,90);rust_model_drag(mosaic.model,100,70);rust_model_drag(mosaic.model,200,90);rust_model_finish(mosaic.model);
    NSBitmapImageRep *obscured=TestBitmap([mosaic render]);NSData *mosaicPixels=TestPixels(obscured);
    check(@"mosaic changes textured screenshot",![texturePixels isEqual:mosaicPixels]);
    NSColor *masked=[obscured colorAtX:100 y:70],*outside=[obscured colorAtX:10 y:10];
    check(@"mosaic masks detail only inside brush path",masked.redComponent>.1&&masked.redComponent<.9&&outside.redComponent<.01);
    NSColor *neighbor=[obscured colorAtX:101 y:70];check(@"mosaic creates flat pixel blocks",fabs(masked.redComponent-neighbor.redComponent)<.01);
    rust_model_undo(mosaic.model);check(@"undo mosaic restores original pixels",[texturePixels isEqual:TestPixels(TestBitmap([mosaic render]))]);
    rust_model_redo(mosaic.model);check(@"redo mosaic restores exact pixels",[mosaicPixels isEqual:TestPixels(TestBitmap([mosaic render]))]);
    NSData *mosaicPNG=[obscured representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    [mosaicPNG writeToFile:[dir stringByAppendingPathComponent:@"mosaic-output.png"] atomically:YES];
    check(@"PNG export retains mosaic",[mosaicPixels isEqual:TestPixels([[NSBitmapImageRep alloc]initWithData:mosaicPNG])]);
    rust_model_set_tool(mosaic.model,5);rust_model_set_width(mosaic.model,6);rust_model_begin(mosaic.model,100,70);rust_model_finish(mosaic.model);
    NSColor *restored=[TestBitmap([mosaic render])colorAtX:100 y:70];check(@"eraser removes mosaic to reveal original image",restored.redComponent<.01);
    CaptureView *toolbarTest=[[CaptureView alloc]initWithFrame:NSMakeRect(0,0,800,600)];
    check(@"capture toolbar has seven distinct tools",toolbarTest.toolButtons.count==7&&toolbarTest.toolButtons[6].tag==6);
    check(@"pen icon has selected and unselected images",toolbarTest.toolButtons[0].tag==3&&toolbarTest.toolButtons[0].image!=nil&&toolbarTest.toolButtons[0].alternateImage!=nil);
    // Measure only preparation work, using synthetic Retina pixels (no desktop permission).
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    CGContextRef largeContext=CGBitmapContextCreate(NULL,3840,2160,8,0,space,kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(largeContext,.12,.34,.56,1);CGContextFillRect(largeContext,CGRectMake(0,0,3840,2160));
    CGImageRef largeCG=CGBitmapContextCreateImage(largeContext);
    NSImage *large=[[NSImage alloc]initWithCGImage:largeCG size:NSMakeSize(1920,1080)];
    NSMutableArray *legacyTimes=[NSMutableArray array],*directTimes=[NSMutableArray array];
    BOOL bitmapOK=YES;
    for(int iteration=0;iteration<5;iteration++){@autoreleasepool{
        CFAbsoluteTime start=CFAbsoluteTimeGetCurrent();
        NSBitmapImageRep *legacy=[[NSBitmapImageRep alloc]initWithData:large.TIFFRepresentation];
        [legacyTimes addObject:@((CFAbsoluteTimeGetCurrent()-start)*1000)];
        start=CFAbsoluteTimeGetCurrent();NSBitmapImageRep *direct=CaptureBitmap(large);
        [directTimes addObject:@((CFAbsoluteTimeGetCurrent()-start)*1000)];
        bitmapOK &= direct.pixelsWide==3840&&direct.pixelsHigh==2160&&legacy.pixelsWide==direct.pixelsWide;
        NSColor *before=[legacy colorAtX:500 y:500],*after=[direct colorAtX:500 y:500];
        bitmapOK &= fabs(before.redComponent-after.redComponent)<.001&&fabs(before.greenComponent-after.greenComponent)<.001&&fabs(before.blueComponent-after.blueComponent)<.001;
    }}
    check(@"direct capture bitmap preserves Retina pixels and colors",bitmapOK);
    check(@"toolbar asset cache reuses images",CaptureAsset(@"ico_rectangle")==CaptureAsset(@"ico_rectangle"));
    NSBitmapImageRep *directSource=CaptureBitmap(large);
    CaptureView *retinaView=[[CaptureView alloc]initWithFrame:NSMakeRect(0,0,1920,1080)];retinaView.background=large;retinaView.backgroundBitmap=directSource;
    NSBitmapImageRep *retinaCrop=TestBitmap([retinaView cropped:NSMakeRect(10,20,100,80)]);
    check(@"direct Retina bitmap crop retains 2x scale",retinaCrop.pixelsWide==200&&retinaCrop.pixelsHigh==160);
    NSArray *oldSorted=[legacyTimes sortedArrayUsingSelector:@selector(compare:)],*newSorted=[directTimes sortedArrayUsingSelector:@selector(compare:)];
    NSDictionary *performance=@{@"scope":@"Synthetic 3840x2160 Retina capture bitmap preparation only; 5 iterations, no real desktop capture or hotkey timing.",@"legacyTIFFMilliseconds":legacyTimes,@"directBitmapMilliseconds":directTimes,@"legacyMedianMs":oldSorted[2],@"directMedianMs":newSorted[2],@"removedFixedDelayMs":@200};
    [[NSJSONSerialization dataWithJSONObject:performance options:NSJSONWritingPrettyPrinted error:nil]writeToFile:[dir stringByAppendingPathComponent:@"capture-performance.json"] atomically:YES];
    CGImageRelease(largeCG);CGContextRelease(largeContext);CGColorSpaceRelease(space);
    Controller *zoomController=[Controller new];
    NSView *editorBar=[[NSView alloc]initWithFrame:NSMakeRect(0,0,1100,50)];[zoomController populateEditorToolbar:editorBar];
    NSScrollView *zoomScroll=[[NSScrollView alloc]initWithFrame:NSMakeRect(0,0,180,130)];
    Canvas *zoomCanvas=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,256,192)];[zoomCanvas load:input];zoomScroll.documentView=zoomCanvas;
    zoomController.canvas=zoomCanvas;[zoomController configureEditorScroll:zoomScroll];
    NSData *beforeZoom=TestPixels(TestBitmap([zoomCanvas render]));
    [zoomController zoomIn:nil];check(@"zoom in changes view magnification",fabs(zoomScroll.magnification-1.25)<.001);
    check(@"zoom percentage label follows magnification",[zoomController.zoomLabel.stringValue isEqual:@"125%"]);
    [zoomController zoomOut:nil];check(@"zoom out reverses magnification",fabs(zoomScroll.magnification-1)<.001);
    [zoomController setEditorZoom:100];check(@"zoom respects upper limit",fabs(zoomScroll.magnification-8)<.001);
    [zoomController setEditorZoom:.001];check(@"zoom respects lower limit",fabs(zoomScroll.magnification-.1)<.001);
    [zoomController zoomToFit:nil];check(@"fit scales entire image into viewport",zoomScroll.magnification<1&&zoomScroll.magnification>=.1);
    [zoomController setEditorZoom:2];
    NSPoint imagePoint=NSMakePoint(60,70);NSPoint viewport=[zoomCanvas convertPoint:imagePoint toView:zoomScroll];NSPoint roundtrip=[zoomCanvas convertPoint:viewport fromView:zoomScroll];
    check(@"zoomed view coordinate conversion retains image positions",fabs(roundtrip.x-60)<.001&&fabs(roundtrip.y-70)<.001);
    check(@"zoom leaves exported pixels and resolution unchanged",[beforeZoom isEqual:TestPixels(TestBitmap([zoomCanvas render]))]);
    [zoomController zoomActual:nil];check(@"actual size restores 100 percent",fabs(zoomScroll.magnification-1)<.001);
    NSURL *noteRoot=[NSURL fileURLWithPath:[dir stringByAppendingPathComponent:[@"pinboard-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    RSPinBoard *pinBoardTest=[[RSPinBoard alloc]initWithStorageURL:noteRoot];NSError *pinError=nil;
    RSPinnedNote *note=[pinBoardTest addImage:out error:&pinError];
    check(@"pin creates a persistent floating image note",note!=nil&&pinBoardTest.notes.count==1&&note.window.level==NSFloatingWindowLevel);
    NSBitmapImageRep *storedNote=[[NSBitmapImageRep alloc]initWithData:[NSData dataWithContentsOfURL:[noteRoot URLByAppendingPathComponent:[note.identifier stringByAppendingString:@".png"]]]];
    check(@"pinned PNG preserves all annotation pixels and dimensions",storedNote.pixelsWide==256&&storedNote.pixelsHigh==192&&[all isEqual:TestPixels(storedNote)]);
    NSRect savedFrame=NSMakeRect(100,100,400,330);[note.window setFrame:savedFrame display:NO];
    [note togglePinned:[NSButton new]];check(@"pin can toggle always on top",!note.pinned&&note.window.level==NSNormalWindowLevel);
    [note.window performClose:nil];[pinBoardTest save:nil];
    check(@"closing a note hides it without deleting screenshot",!note.visible&&!note.window.isVisible&&[NSFileManager.defaultManager fileExistsAtPath:[[noteRoot URLByAppendingPathComponent:[note.identifier stringByAppendingString:@".png"]]path]]);
    RSPinBoard *restoredBoard=[[RSPinBoard alloc]initWithStorageURL:noteRoot];[restoredBoard restore];
    RSPinnedNote *restoredNote=restoredBoard.notes.firstObject;
    check(@"restart restores note identity and pin state",restoredBoard.notes.count==1&&[restoredNote.identifier isEqual:note.identifier]&&!restoredNote.pinned);
    check(@"closed notes remain hidden on restart",!restoredNote.visible&&!restoredNote.window.isVisible);
    check(@"restart restores note size",fabs(restoredNote.window.frame.size.width-400)<1&&fabs(restoredNote.window.frame.size.height-330)<1);
    [restoredBoard showAll];check(@"show all recovers closed notes",restoredNote.visible&&restoredNote.window.isVisible);
    RSPinnedNote *second=[restoredBoard addImage:out error:&pinError];check(@"multiple independent notes can coexist",second!=nil&&restoredBoard.notes.count==2&&![second.identifier isEqual:restoredNote.identifier]);
    for(RSPinnedNote *item in pinBoardTest.notes)[item.window orderOut:nil];
    for(RSPinnedNote *item in restoredBoard.notes){item.visible=NO;[item.window orderOut:nil];}[restoredBoard save:nil];
    NSURL *invalidRoot=[noteRoot URLByAppendingPathComponent:@"not-a-folder"];[@"file" writeToURL:invalidRoot atomically:YES encoding:NSUTF8StringEncoding error:nil];
    RSPinBoard *invalidBoard=[[RSPinBoard alloc]initWithStorageURL:invalidRoot];NSError *writeError=nil;
    check(@"pin reports storage failure without creating a window",[invalidBoard addImage:out error:&writeError]==nil&&writeError!=nil&&invalidBoard.notes.count==0);
    CaptureSession *pinSession=[CaptureSession new];pinSession.windows=[NSMutableArray array];pinSession.views=[NSMutableArray array];
    CaptureView *pinView=[[CaptureView alloc]initWithFrame:NSMakeRect(0,0,256,192)];pinView.background=canvas.image;pinView.backgroundBitmap=CaptureBitmap(canvas.image);pinView.session=pinSession;
    rust_selection_down(pinView.selection,20,20);rust_selection_drag(pinView.selection,100,80);rust_selection_up(pinView.selection);[pinView syncSelection:NO];
    __block BOOL pinDelivered=NO;pinSession.completion=^(NSImage *image,BOOL save,BOOL cancelled){pinDelivered=image!=nil&&!save&&!cancelled&&pinSession.pinOnFinish;};
    [pinView finishPin:nil];check(@"capture toolbar pin finishes selection with the pin flag",pinDelivered&&pinSession.finished);pinSession.completion=nil;
    NSURL *sizeRoot=[noteRoot URLByAppendingPathComponent:@"original-size" isDirectory:YES];RSPinBoard *sizeBoard=[[RSPinBoard alloc]initWithStorageURL:sizeRoot];
    Controller *sizeController=[Controller new];sizeController.canvas=[[Canvas alloc]initWithFrame:NSMakeRect(0,0,256,192)];sizeController.pinBoard=sizeBoard;
    NSImage *retinaNoteImage=[out copy];retinaNoteImage.size=NSMakeSize(128,96);[sizeController loadCaptureImage:retinaNoteImage];[sizeController pinCurrent:nil];
    RSPinnedNote *sizedNote=sizeBoard.notes.firstObject;
    check(@"Retina note preserves selection point size instead of doubling it",NSEqualSizes(sizedNote.image.size,NSMakeSize(128,96)));
    NSView *sizedImage=sizedNote.window.contentView.subviews.firstObject;
    check(@"new note image view uses original screenshot size",fabs(sizedImage.frame.size.width-128)<1&&fabs(sizedImage.frame.size.height-96)<1);
    NSBitmapImageRep *retainedPixels=[[NSBitmapImageRep alloc]initWithData:[NSData dataWithContentsOfURL:[sizeRoot URLByAppendingPathComponent:[sizedNote.identifier stringByAppendingString:@".png"]]]];
    check(@"original display size retains full resolution PNG",retainedPixels.pixelsWide==256&&retainedPixels.pixelsHigh==192);
    RSPinBoard *sizeRestored=[[RSPinBoard alloc]initWithStorageURL:sizeRoot];[sizeRestored restore];
    check(@"restart retains original Retina display size",NSEqualSizes(sizeRestored.notes.firstObject.image.size,NSMakeSize(128,96)));
    for(RSPinnedNote *item in sizeBoard.notes)[item.window orderOut:nil];for(RSPinnedNote *item in sizeRestored.notes)[item.window orderOut:nil];
    BOOL passed=YES;for(NSDictionary *c in checks)if(![c[@"passed"]boolValue])passed=NO;
    NSDictionary *report=@{@"passed":@(passed),@"checks":checks,@"scope":@"Production Canvas load/render, Rust model, PNG file IO, unique named NSPasteboard. No system screenshot or GUI event automation; general clipboard unchanged."};
    NSData *json=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
    [json writeToFile:[dir stringByAppendingPathComponent:@"integration-results.json"] atomically:YES];
    puts([[NSString alloc]initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
    return passed?0:1;
}}
