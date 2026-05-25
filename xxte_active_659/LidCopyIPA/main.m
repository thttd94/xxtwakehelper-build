#import <UIKit/UIKit.h>

static NSString *FindSafariDataPath(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *bases = @[
        @"/var/mobile/Containers/Data/Application",
        @"/private/var/mobile/Containers/Data/Application"
    ];

    for (NSString *base in bases) {
        NSArray *dirs = [fm contentsOfDirectoryAtPath:base error:nil];
        for (NSString *d in dirs) {
            NSString *appPath = [base stringByAppendingPathComponent:d];
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:appPath isDirectory:&isDir] || !isDir) continue;

            NSString *meta = [appPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *md = [NSDictionary dictionaryWithContentsOfFile:meta];
            NSString *bid = md[@"MCMMetadataIdentifier"] ?: md[@"MCMMetadataIdentifier"];
            if ([bid isEqualToString:@"com.apple.mobilesafari"]) return appPath;

            NSString *prefs1 = [appPath stringByAppendingPathComponent:@"Library/Preferences/com.apple.mobilesafari.plist"];
            NSString *prefs2 = [appPath stringByAppendingPathComponent:@"Library/Safari"];
            NSString *cookies = [appPath stringByAppendingPathComponent:@"Library/Cookies"];
            if ([fm fileExistsAtPath:prefs1] || ([fm fileExistsAtPath:prefs2] && [fm fileExistsAtPath:cookies])) {
                return appPath;
            }
        }
    }
    return nil;
}

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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *msg = [self runCopy];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Lid Copy" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:a animated:YES completion:nil];
    });
    return YES;
}

- (NSString *)runCopy {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *src = @"/var/mobile/Media/1ferver/ipa/Cookies.binarycookies";
    if (![fm fileExistsAtPath:src]) {
        NSString *bundled = [[NSBundle mainBundle] pathForResource:@"lid" ofType:@"png"];
        if (bundled) src = bundled;
    }
    if (![fm fileExistsAtPath:src]) return [NSString stringWithFormat:@"Khong tim thay nguon:\n%@\nhoac bundled Cookies.binarycookies", src];

    NSString *safariPath = FindSafariDataPath();
    if (!safariPath) return @"Khong tim thay Safari data container. Co the app chua co quyen doc /var/mobile/Containers/Data/Application.";

    NSString *cookieDir = [safariPath stringByAppendingPathComponent:@"Library/Cookies"];
    NSString *dst = [cookieDir stringByAppendingPathComponent:@"Cookies.binarycookies"];
    NSString *bak = [cookieDir stringByAppendingPathComponent:@"Cookies.binarycookies_bu"];

    NSError *err = nil;
    [fm createDirectoryAtPath:cookieDir withIntermediateDirectories:YES attributes:nil error:nil];

    if ([fm fileExistsAtPath:dst]) {
        [fm removeItemAtPath:bak error:nil];
        if (![fm copyItemAtPath:dst toPath:bak error:&err]) {
            return [NSString stringWithFormat:@"Backup loi:\n%@", err.localizedDescription ?: @"unknown"];
        }
    }

    [fm removeItemAtPath:dst error:nil];
    err = nil;
    if (![fm copyItemAtPath:src toPath:dst error:&err]) {
        return [NSString stringWithFormat:@"Copy loi:\n%@\nNguon:%@\nDich:%@", err.localizedDescription ?: @"unknown", src, dst];
    }

    return [NSString stringWithFormat:@"Copy xong\nNguon:%@\nDich:%@\nBackup:%@", src, dst, bak];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
