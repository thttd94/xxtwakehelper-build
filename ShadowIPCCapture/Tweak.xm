#import <Foundation/Foundation.h>
#import <fcntl.h>
#import <unistd.h>

static void Capture(id center, NSString *name, NSDictionary *info) {
    @autoreleasepool {
        NSString *centerDesc = @"unknown";
        @try { centerDesc = [center valueForKey:@"_centerName"] ?: [center description]; } @catch (__unused NSException *e) { centerDesc=[center description]; }
        NSDictionary *entry=@{@"time":@([[NSDate date] timeIntervalSince1970]), @"center":centerDesc?:@"", @"message":name?:@"", @"userInfo":info?:@{}};
        NSData *j=[NSJSONSerialization dataWithJSONObject:entry options:0 error:nil];
        if (!j) j=[[entry description] dataUsingEncoding:NSUTF8StringEncoding];
        int fd=open("/var/mobile/Media/1ferver/shadow_ipc_capture.jsonl",O_WRONLY|O_CREAT|O_APPEND,0666);
        if(fd>=0){write(fd,j.bytes,j.length);write(fd,"\n",1);close(fd);chmod("/var/mobile/Media/1ferver/shadow_ipc_capture.jsonl",0666);}
    }
}

%hook CPDistributedMessagingCenter
- (id)sendMessageAndReceiveReplyName:(NSString *)name userInfo:(NSDictionary *)info { Capture(self,name,info); return %orig; }
- (BOOL)sendMessageName:(NSString *)name userInfo:(NSDictionary *)info { Capture(self,name,info); return %orig; }
%end
