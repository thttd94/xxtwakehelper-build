#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <sys/stat.h>
#import <unistd.h>

@interface AppDelegate ()
@property (nonatomic, strong) NSTimer *wakeTimer;
@property (nonatomic, assign) NSInteger wakeCount;
@property (nonatomic, strong) UITextView *logView;
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.blackColor;

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(20, 60, vc.view.bounds.size.width - 40, 32)];
    title.text = @"XXTWakeHelper";
    title.textColor = UIColor.whiteColor;
    title.font = [UIFont boldSystemFontOfSize:24];
    [vc.view addSubview:title];

    UILabel *sub = [[UILabel alloc] initWithFrame:CGRectMake(20, 98, vc.view.bounds.size.width - 40, 48)];
    sub.text = @"Wakes XXTouch using xxt:// after launch/boot.";
    sub.textColor = UIColor.lightGrayColor;
    sub.numberOfLines = 2;
    [vc.view addSubview:sub];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(20, 155, vc.view.bounds.size.width - 40, 44);
    [btn setTitle:@"Wake XXTouch Now" forState:UIControlStateNormal];
    [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    btn.backgroundColor = [UIColor colorWithRed:0.10 green:0.35 blue:0.95 alpha:1.0];
    btn.layer.cornerRadius = 8;
    [btn addTarget:self action:@selector(wakeNowButton) forControlEvents:UIControlEventTouchUpInside];
    [vc.view addSubview:btn];

    self.logView = [[UITextView alloc] initWithFrame:CGRectMake(20, 215, vc.view.bounds.size.width - 40, vc.view.bounds.size.height - 235)];
    self.logView.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1];
    self.logView.textColor = UIColor.greenColor;
    self.logView.editable = NO;
    self.logView.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightRegular];
    [vc.view addSubview:self.logView];

    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    [self log:@"launched"];
    [self installBootWakeDaemon];
    [self startWakeLoopWithReason:@"didFinishLaunching"];
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [self log:@"didBecomeActive"];
    [self startWakeLoopWithReason:@"didBecomeActive"];
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [self log:@"didEnterBackground"];
    UIBackgroundTaskIdentifier bg = [application beginBackgroundTaskWithName:@"xxtwake" expirationHandler:^{ }];
    [self startWakeLoopWithReason:@"background"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (bg != UIBackgroundTaskInvalid) [application endBackgroundTask:bg];
    });
}

- (void)wakeNowButton {
    [self installBootWakeDaemon];
    [self startWakeLoopWithReason:@"button"];
}

- (void)installBootWakeDaemon {
    NSString *scriptPath = @"/var/mobile/Media/1ferver/xxtwake_boot.sh";
    NSString *logPath = @"/var/mobile/Media/1ferver/xxtwake_boot.log";
    NSString *script = [NSString stringWithFormat:
        @"#!/bin/sh\n"
         "echo \"[$(date)] xxtwake boot start\" >> %@\n"
         "i=0\n"
         "while [ $i -lt 30 ]; do\n"
         "  echo \"[$(date)] wake tick $i\" >> %@\n"
         "  if [ -x /usr/bin/uiopen ]; then /usr/bin/uiopen xxt:// >> %@ 2>&1; fi\n"
         "  if [ -x /var/jb/usr/bin/uiopen ]; then /var/jb/usr/bin/uiopen xxt:// >> %@ 2>&1; fi\n"
         "  if [ -x /usr/bin/open ]; then /usr/bin/open xxt:// >> %@ 2>&1; fi\n"
         "  if [ -x /var/jb/usr/bin/open ]; then /var/jb/usr/bin/open xxt:// >> %@ 2>&1; fi\n"
         "  /bin/launchctl asuser 501 /usr/bin/uiopen xxt:// >> %@ 2>&1\n"
         "  /bin/launchctl asuser 501 /var/jb/usr/bin/uiopen xxt:// >> %@ 2>&1\n"
         "  sleep 10\n"
         "  i=$((i+1))\n"
         "done\n"
         "echo \"[$(date)] xxtwake boot done\" >> %@\n",
        logPath, logPath, logPath, logPath, logPath, logPath, logPath, logPath, logPath];

    NSError *err = nil;
    BOOL wroteScript = [script writeToFile:scriptPath atomically:YES encoding:NSUTF8StringEncoding error:&err];
    if (!wroteScript) {
        [self log:[NSString stringWithFormat:@"boot script write failed: %@", err.localizedDescription ?: @"unknown"]];
        return;
    }
    chmod(scriptPath.UTF8String, 0755);

    NSDictionary *plist = @{
        @"Label": @"com.oc.xxtwake.boot",
        @"ProgramArguments": @[@"/bin/sh", scriptPath],
        @"RunAtLoad": @YES,
        @"StandardOutPath": @"/var/mobile/Media/1ferver/xxtwake_boot.out",
        @"StandardErrorPath": @"/var/mobile/Media/1ferver/xxtwake_boot.err"
    };

    NSArray<NSString *> *plistPaths = @[
        @"/var/jb/Library/LaunchDaemons/com.oc.xxtwake.boot.plist",
        @"/Library/LaunchDaemons/com.oc.xxtwake.boot.plist"
    ];
    BOOL installed = NO;
    for (NSString *plistPath in plistPaths) {
        NSString *dir = [plistPath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:&err];
        if (data && [data writeToFile:plistPath options:NSDataWritingAtomic error:&err]) {
            chmod(plistPath.UTF8String, 0644);
            chown(plistPath.UTF8String, 0, 0);
            installed = YES;
            [self log:[NSString stringWithFormat:@"boot daemon installed: %@", plistPath]];
            NSString *cmd = [NSString stringWithFormat:@"/bin/launchctl unload %@ 2>/dev/null; /bin/launchctl load -w %@ 2>&1", plistPath, plistPath];
            FILE *fp = popen(cmd.UTF8String, "r");
            if (fp) {
                char buf[512]; NSMutableString *out = [NSMutableString string];
                while (fgets(buf, sizeof(buf), fp)) [out appendString:[NSString stringWithUTF8String:buf]];
                pclose(fp);
                if (out.length) [self log:[NSString stringWithFormat:@"launchctl: %@", out]];
            }
            break;
        } else {
            [self log:[NSString stringWithFormat:@"boot plist write failed %@: %@", plistPath, err.localizedDescription ?: @"unknown"]];
        }
    }
    if (!installed) [self log:@"boot daemon install failed all paths"];
}

- (void)startWakeLoopWithReason:(NSString *)reason {
    [self log:[NSString stringWithFormat:@"startWakeLoop: %@", reason]];
    self.wakeCount = 0;
    [self.wakeTimer invalidate];
    self.wakeTimer = [NSTimer scheduledTimerWithTimeInterval:10.0 target:self selector:@selector(wakeTick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.wakeTimer forMode:NSRunLoopCommonModes];
    [self wakeTick];
}

- (void)wakeTick {
    self.wakeCount += 1;
    [self wakeXXTouch];
    if (self.wakeCount >= 30) { // ~5 minutes
        [self log:@"wake loop done"];
        [self.wakeTimer invalidate];
        self.wakeTimer = nil;
    }
}

- (void)wakeXXTouch {
    NSArray<NSString *> *urls = @[@"xxt://", @"xxt://open", @"xxt://script"];
    for (NSString *u in urls) {
        NSURL *url = [NSURL URLWithString:u];
        if (!url) continue;
        [self log:[NSString stringWithFormat:@"openURL %@", u]];
        if (@available(iOS 10.0, *)) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                [self log:[NSString stringWithFormat:@"openURL result %@ = %@", u, success ? @"YES" : @"NO"]];
            }];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            BOOL ok = [[UIApplication sharedApplication] openURL:url];
#pragma clang diagnostic pop
            [self log:[NSString stringWithFormat:@"openURL old result %@ = %@", u, ok ? @"YES" : @"NO"]];
        }
        break;
    }
}

- (void)log:(NSString *)line {
    NSString *stamp = [NSDate date].description;
    NSString *msg = [NSString stringWithFormat:@"[%@] %@\n", stamp, line ?: @""];
    NSLog(@"%@", msg);
    NSString *old = self.logView.text ?: @"";
    self.logView.text = [old stringByAppendingString:msg];
    NSRange bottom = NSMakeRange(self.logView.text.length, 0);
    [self.logView scrollRangeToVisible:bottom];
    NSString *path = @"/var/mobile/Media/1ferver/xxtwakehelper.log";
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:path];
    if (!fh) {
        [msg writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    } else {
        [fh seekToEndOfFile];
        [fh writeData:[msg dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

@end
