#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <objc/message.h>

static NSMutableArray *gDiag;
static void Diag(NSString *fmt, ...) {
    if (!gDiag) gDiag = [NSMutableArray array];
    va_list args; va_start(args, fmt);
    NSString *s = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    [gDiag addObject:s];
}

static NSString *FindSafariDataPathViaMCM(void) {
    void *h = dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager", RTLD_LAZY);
    Diag(@"MCM dlopen: %@", h ? @"OK" : @"FAIL");
    Class cls = NSClassFromString(@"MCMAppDataContainer");
    if (!cls) cls = NSClassFromString(@"MCMContainer");
    Diag(@"MCM class: %@", cls ? NSStringFromClass(cls) : @"nil");
    if (!cls) return nil;

    NSArray *sels = @[
        @"containerWithIdentifier:createIfNecessary:existed:error:",
        @"containerWithIdentifier:createIfNecessary:error:",
        @"containerWithIdentifier:error:"
    ];
    for (NSString *selName in sels) {
        SEL sel = NSSelectorFromString(selName);
        if (![cls respondsToSelector:sel]) { Diag(@"MCM selector no: %@", selName); continue; }
        Diag(@"MCM selector yes: %@", selName);
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
        } @catch (NSException *e) { Diag(@"MCM exception: %@", e.reason); }
        Diag(@"MCM container: %@ err:%@", container ? @"OK" : @"nil", err.localizedDescription ?: @"none");
        if (!container) continue;

        NSURL *url = nil;
        NSArray *urlSels = @[@"url", @"containerURL"];
        for (NSString *u in urlSels) {
            SEL us = NSSelectorFromString(u);
            if ([container respondsToSelector:us]) {
                url = ((NSURL *(*)(id, SEL))objc_msgSend)(container, us);
                Diag(@"MCM %@: %@", u, url.path ?: @"nil");
                if (url.path.length > 0) return url.path;
            }
        }
    }
    return nil;
}

static NSString *ConfiguredSafariPath(void) {
    NSArray *paths = @[
        @"/var/mobile/Media/1ferver/ipa/safari_path.txt",
        @"/private/var/mobile/Media/1ferver/ipa/safari_path.txt"
    ];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *p in paths) {
        if ([fm fileExistsAtPath:p]) {
            NSError *err = nil;
            NSString *raw = [NSString stringWithContentsOfFile:p encoding:NSUTF8StringEncoding error:&err];
            NSString *v = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            Diag(@"config %@: %@ err:%@", p, v.length ? v : @"empty", err.localizedDescription ?: @"none");
            if (v.length > 0) return v;
        } else {
            Diag(@"config missing: %@", p);
        }
    }
    return nil;
}

static NSString *FindSafariDataPath(void) {
    NSString *cfg = ConfiguredSafariPath();
    if (cfg.length > 0) return cfg;

    NSString *mcm = FindSafariDataPathViaMCM();
    if (mcm.length > 0) return mcm;

    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *bases = @[
        @"/var/mobile/Containers/Data/Application",
        @"/private/var/mobile/Containers/Data/Application"
    ];

    for (NSString *base in bases) {
        NSError *listErr = nil;
        NSArray *dirs = [fm contentsOfDirectoryAtPath:base error:&listErr];
        Diag(@"scan %@ count:%lu err:%@", base, (unsigned long)dirs.count, listErr.localizedDescription ?: @"none");
        for (NSString *d in dirs) {
            NSString *appPath = [base stringByAppendingPathComponent:d];
            BOOL isDir = NO;
            if (![fm fileExistsAtPath:appPath isDirectory:&isDir] || !isDir) continue;

            NSString *meta = [appPath stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            NSDictionary *md = [NSDictionary dictionaryWithContentsOfFile:meta];
            NSString *bid = md[@"MCMMetadataIdentifier"];
            if ([bid isEqualToString:@"com.apple.mobilesafari"]) { Diag(@"found by metadata: %@", appPath); return appPath; }

            NSString *prefs1 = [appPath stringByAppendingPathComponent:@"Library/Preferences/com.apple.mobilesafari.plist"];
            NSString *prefs2 = [appPath stringByAppendingPathComponent:@"Library/Safari"];
            NSString *cookies = [appPath stringByAppendingPathComponent:@"Library/Cookies"];
            if ([fm fileExistsAtPath:prefs1] || ([fm fileExistsAtPath:prefs2] && [fm fileExistsAtPath:cookies])) {
                Diag(@"found by files: %@", appPath);
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
        UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Lid Copy v2.3" message:msg preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [vc presentViewController:a animated:YES completion:nil];
    });
    return YES;
}

- (NSString *)runCopy {
    gDiag = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *src = @"/var/mobile/Media/1ferver/ipa/lid.png";
    if (![fm fileExistsAtPath:src]) {
        NSString *bundled = [[NSBundle mainBundle] pathForResource:@"lid" ofType:@"png"];
        if (bundled) src = bundled;
    }
    if (![fm fileExistsAtPath:src]) return [NSString stringWithFormat:@"Khong tim thay nguon:\n%@\nhoac bundled lid.png\n\nDiag:\n%@", src, [gDiag componentsJoinedByString:@"\n"]];

    NSString *safariPath = FindSafariDataPath();
    if (!safariPath) return [NSString stringWithFormat:@"Khong tim thay Safari data container.\n\nDiag:\n%@", [gDiag componentsJoinedByString:@"\n"]];

    NSString *cookieDir = [safariPath stringByAppendingPathComponent:@"Library/Cookies"];
    NSString *dst = [cookieDir stringByAppendingPathComponent:@"lid.png"];
    NSString *bak = [cookieDir stringByAppendingPathComponent:@"lid_backup.png"];

    NSError *err = nil;
    [fm createDirectoryAtPath:cookieDir withIntermediateDirectories:YES attributes:nil error:nil];

    if ([fm fileExistsAtPath:dst]) {
        [fm removeItemAtPath:bak error:nil];
        if (![fm copyItemAtPath:dst toPath:bak error:&err]) {
            return [NSString stringWithFormat:@"Backup loi:\n%@\n\nDiag:\n%@", err.localizedDescription ?: @"unknown", [gDiag componentsJoinedByString:@"\n"]];
        }
    }

    [fm removeItemAtPath:dst error:nil];
    err = nil;
    if (![fm copyItemAtPath:src toPath:dst error:&err]) {
        return [NSString stringWithFormat:@"Copy loi:\n%@\nNguon:%@\nDich:%@\n\nDiag:\n%@", err.localizedDescription ?: @"unknown", src, dst, [gDiag componentsJoinedByString:@"\n"]];
    }

    return [NSString stringWithFormat:@"Copy xong\nNguon:%@\nDich:%@\nBackup:%@", src, dst, bak];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
