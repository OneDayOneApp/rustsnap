#include <Carbon/Carbon.h>
#include <stdio.h>
#include <stdlib.h>
int main(int argc,char **argv){
    if(argc!=3)return 2;
    UInt32 key=(UInt32)strtoul(argv[1],NULL,10),flags=(UInt32)strtoul(argv[2],NULL,10);
    EventHotKeyRef hotkey=NULL;EventHotKeyID identifier={0x52535154,1};
    OSStatus result=RegisterEventHotKey(key,flags,identifier,GetApplicationEventTarget(),kEventHotKeyExclusive,&hotkey);
    if(hotkey)UnregisterEventHotKey(hotkey);
    printf("Exclusive hotkey registration after quit: %d\n",(int)result);return result==noErr?0:1;
}
