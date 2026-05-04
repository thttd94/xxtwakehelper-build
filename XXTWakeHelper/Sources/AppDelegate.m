#import "AppDelegate.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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
    [self startWakeLoopWithReason:@"button"];
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
