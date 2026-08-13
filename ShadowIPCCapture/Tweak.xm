#import <Foundation/Foundation.h>
#import <fcntl.h>
#import <sys/stat.h>
#import <unistd.h>

static void Capture(id center, NSString *name, NSDictionary *info) {
    @autoreleasepool {
        NSString *centerDesc = @"unknown";
        @try {
            centerDesc = [center valueForKey:@"_centerName"] ?: [center description];
        } @catch (__unused NSException *e) {
            centerDesc = [center description];
        }
        NSDictionary *entry = @{
            @"time": @([[NSDate date] timeIntervalSince1970]),
            @"center": centerDesc ?: @"",
            @"message": name ?: @"",
            @"userInfo": info ?: @{}
        };
        NSData *data = [NSJSONSerialization dataWithJSONObject:entry options:0 error:nil];
        if (!data) data = [[entry description] dataUsingEncoding:NSUTF8StringEncoding];
        const char *path = "/var/mobile/Media/1ferver/shadow_ipc_capture.jsonl";
        int fd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0666);
        if (fd >= 0) {
            write(fd, data.bytes, data.length);
            write(fd, "\n", 1);
            close(fd);
            chmod(path, 0666);
        }
    }
}

%hook CPDistributedMessagingCenter
- (id)sendMessageAndReceiveReplyName:(NSString *)name userInfo:(NSDictionary *)info {
    Capture(self, name, info);
    return %orig;
}
- (BOOL)sendMessageName:(NSString *)name userInfo:(NSDictionary *)info {
    Capture(self, name, info);
    return %orig;
}
%end
