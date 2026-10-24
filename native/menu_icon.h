// Compact vector interpretation of the selected double-corner brand mark.
static NSImage *RustSnapMenuIcon(void) {
    NSImage *image=[NSImage imageWithSize:NSMakeSize(18,18) flipped:YES drawingHandler:^BOOL(NSRect rect){
        [NSColor.blackColor setFill];
        for(int side=0;side<2;side++){
            NSBezierPath *p=[NSBezierPath bezierPath];
            NSPoint points[]={ {2,2},{11,2},{11,5},{5.5,5},{5.5,8},{7.5,8},{3.5,12},{2,12} };
            for(int i=0;i<8;i++){NSPoint q=points[i];if(side){q.x=18-q.x;q.y=18-q.y;}if(i==0)[p moveToPoint:q];else[p lineToPoint:q];}
            [p closePath];[p fill];
        }
        return YES;
    }];image.template=YES;image.accessibilityDescription=@"RustSnap 截图与标注";return image;
}
