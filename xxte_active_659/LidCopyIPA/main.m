#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>

static NSString *FindSafariDataPathViaMCM(void) {
    dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
    Class cls = NSClassFromString(@"MCMAppDataContainer");
    if (!cls) cls = NSClassFromString(@"MCMContainer");
    if (!cls) return nil;

    NSArray *selectors = @[
        @"containerWithIdentifier:createIfNecessary:existed:error:",
        @"containerWithIdentifier:createIfNecessary:error:",
        @"containerWithIdentifier:error:"
    ];

    for (NSString *selName in selectors) {
        SEL sel = NSSelectorFromString(selName);
        if (![cls respondsToSelector:sel]) continue;

        id container = nil;
        NSError *err = nil;
        BOOL existed = NO;
        @try {
            if ([selName isEqualToString:@"containerWithIdentifier:createIfNecessary:existed:error:"]) {
                id (*msg)(id, SEL, NSString *, BOOL, BOOL *, NSError **) = (id (*)(id, SEL, NSString *, BOOL, BOOL *, NSError **))objc_msgSend;
                container = msg(cls, sel, @"com.apple.mobilesafari", NO, &existed, &err);
            } else if ([selName isEqualToString:@"containerWithIdentifier:createIfNecessary:error:"]) {
                id (*msg)(id, SEL, NSString *, BOOL, NSError **) = (id (*)(id, SEL, NSString *, BOOL, NSError **))objc_msgSend;
                container = msg(cls, sel, @"com.apple.mobilesafari", NO, &err);
            } else {
                id (*msg)(id, SEL, NSString *, NSError **) = (id (*)(id, SEL, NSString *, NSError **))objc_msgSend;
                container = msg(cls, sel, @"com.apple.mobilesafari", &err);
            }
        } @catch (NSException *e) {
            container = nil;
        }

        if (!container) continue;
        for (NSString *urlSelName in @[@"url", @"containerURL"]) {
            SEL urlSel = NSSelectorFromString(urlSelName);
            if ([container respondsToSelector:urlSel]) {
                NSURL *url = ((NSURL *(*)(id, SEL))objc_msgSend)(container, urlSel);
                if (url.path.length > 0) return url.path;
            }
        }
    }
    return nil;
}

static NSString *FindSafariDataPathByScan(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *bases = @[
        @"/private/var/mobile/Containers/Data/Application",
        @"/var/mobile/Containers/Data/Application"
    ];
    for (NSString *base in bases) {
        NSArray *dirs = [fm contentsOfDirectoryAtPath:base error:nil];
        for (NSString *uuid in dirs) {
            NSString *appPath = [base stringByAppendingPathComponent:uuid];
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:appPath isDirectory:&isDir] || !isDir) continue;

            NSString *meta = [appPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *md = [NSDictionary dictionaryWithContentsOfFile:meta];
            NSString *bid = md[@"MCMMetadataIdentifier"];
            if ([bid isEqualToString:@"com.apple.mobilesafari"]) return appPath;

            NSString *prefs = [appPath stringByAppendingPathComponent:@"Library/Preferences/com.apple.mobilesafari.plist"];
            NSString *safariDir = [appPath stringByAppendingPathComponent:@"Library/Safari"];
            NSString *cookiesDir = [appPath stringByAppendingPathComponent:@"Library/Cookies"];
            if ([fm fileExistsAtPath:prefs] || ([fm fileExistsAtPath:safariDir] && [fm fileExistsAtPath:cookiesDir])) {
                return appPath;
            }
        }
    }
    return nil;
}

static NSString *FindSafariDataPath(void) {
    NSString *p = FindSafariDataPathViaMCM();
    if (p.length > 0) return p;
    return FindSafariDataPathByScan();
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

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSString *msg = [self runCopy];
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Lid Copy v5.1" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:a animated:YES completion:nil];
    });
    return YES;
}

- (NSString *)runCopy {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *src = @"/var/mobile/Media/1ferver/ipa/Cookies.binarycookies";
    if (![fm fileExistsAtPath:src]) {
        src = @"/private/var/mobile/Media/1ferver/ipa/Cookies.binarycookies";
    }
    if (![fm fileExistsAtPath:src]) {
        return [NSString stringWithFormat:@"FAIL: khong tim thay nguon:\n%@", src];
    }

    NSString *safariPath = FindSafariDataPath();
    if (safariPath.length == 0) {
        return @"FAIL: khong tim thay Safari data container";
    }

    NSString *cookieDir = [safariPath stringByAppendingPathComponent:@"Library/Cookies"];
    NSString *dst = [cookieDir stringByAppendingPathComponent:@"Cookies.binarycookies"];
    NSString *bak = [cookieDir stringByAppendingPathComponent:@"Cookies.binarycookies_backup"];

    NSError *err = nil;
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:cookieDir isDirectory:&isDir] || !isDir) {
        return [NSString stringWithFormat:@"FAIL: khong thay Cookies dir:\n%@", cookieDir];
    }

    if ([fm fileExistsAtPath:dst]) {
        [fm removeItemAtPath:bak error:nil];
        [fm copyItemAtPath:dst toPath:bak error:nil];
    }

    NSData *data = [NSData dataWithContentsOfFile:src options:0 error:&err];
    if (!data) {
        return [NSString stringWithFormat:@"FAIL read src:\n%@\nNguon:%@", err.localizedDescription ?: @"unknown", src];
    }

    err = nil;
    if (![data writeToFile:dst options:NSDataWritingAtomic error:&err]) {
        return [NSString stringWithFormat:@"FAIL write:\n%@\nNguon:%@\nDich:%@", err.localizedDescription ?: @"unknown", src, dst];
    }

    return [NSString stringWithFormat:@"OK standalone\nNguon:%@\nDich:%@\nBackup:%@", src, dst, bak];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
