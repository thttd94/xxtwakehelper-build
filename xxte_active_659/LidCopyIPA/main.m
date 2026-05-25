#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    UIViewController *vc = [UIViewController new];
    vc.view.backgroundColor = UIColor.blackColor;
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *msg = [self runCopy];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Lid Copy v4.0" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:a animated:YES completion:nil];
    });
    return YES;
}

- (NSString *)runCopy {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = @"/var/mobile/Media/1ferver/ipa/lid.png";
    if (![fm fileExistsAtPath:src]) {
        NSString *bundled = [[NSBundle mainBundle] pathForResource:@"lid" ofType:@"png"];
        if (bundled) src = bundled;
    }
    if (![fm fileExistsAtPath:src]) {
        return [NSString stringWithFormat:@"FAIL: khong tim thay nguon:\n%@\nhoac bundled lid.png", src];
    }

    NSString *safariPath = @"/private/var/mobile/Containers/Data/Application/979004A5-D273-4274-B4FA-962006E0F9B0";
    NSString *cookieDir = [safariPath stringByAppendingPathComponent:@"Library/Cookies"];
    NSString *dst = [cookieDir stringByAppendingPathComponent:@"lid.png"];
    NSString *bak = [cookieDir stringByAppendingPathComponent:@"lid_backup.png"];

    NSError *err = nil;
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:cookieDir isDirectory:&isDir] || !isDir) {
        return [NSString stringWithFormat:@"FAIL: khong thay Cookies dir:\n%@", cookieDir];
    }

    if ([fm fileExistsAtPath:dst]) {
        [fm removeItemAtPath:bak error:nil];
        err = nil;
        if (![fm copyItemAtPath:dst toPath:bak error:&err]) {
            return [NSString stringWithFormat:@"FAIL backup:\n%@\nPath:%@", err.localizedDescription ?: @"unknown", bak];
        }
    }

    [fm removeItemAtPath:dst error:nil];
    err = nil;
    if (![fm copyItemAtPath:src toPath:dst error:&err]) {
        return [NSString stringWithFormat:@"FAIL copy:\n%@\nNguon:%@\nDich:%@", err.localizedDescription ?: @"unknown", src, dst];
    }

    return [NSString stringWithFormat:@"OK standalone\nNguon:%@\nDich:%@\nBackup:%@", src, dst, bak];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
