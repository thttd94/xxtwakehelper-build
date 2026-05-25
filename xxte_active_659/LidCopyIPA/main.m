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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self runLuaViaXXTouch:^(NSString *msg) {
            UIAlertController *a = [UIAlertController alertControllerWithTitle:@"Lid Copy v3.0" message:msg preferredStyle:UIAlertControllerStyleAlert];
            [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            [vc presentViewController:a animated:YES completion:nil];
        }];
    });
    return YES;
}

- (void)runLuaViaXXTouch:(void (^)(NSString *msg))done {
    NSString *lua = @"app = require(\"app\")\n"
                    "file = require(\"file\")\n"
                    "sys = require(\"sys\")\n"
                    "local src = \"/var/mobile/Media/1ferver/ipa/lid.png\"\n"
                    "local safariPath = app.data_path(\"com.apple.mobilesafari\")\n"
                    "local out = \"/var/mobile/Media/1ferver/ipa/lidcopy_result.txt\"\n"
                    "local function log(s) file.writes(out, tostring(s or \"\")) end\n"
                    "if not safariPath or safariPath == \"\" then log(\"FAIL: app.data_path Safari empty\"); return false end\n"
                    "local cookiePath = safariPath .. \"/Library/Cookies/lid.png\"\n"
                    "local backupPath = safariPath .. \"/Library/Cookies/lid_backup.png\"\n"
                    "if file.exists(cookiePath) then local old = file.reads(cookiePath); if old then file.writes(backupPath, old) end end\n"
                    "if file.exists(src) then\n"
                    "  local data = file.reads(src)\n"
                    "  if data then\n"
                    "    file.writes(cookiePath, data)\n"
                    "    log(\"OK\\nNguon: \" .. src .. \"\\nDich: \" .. cookiePath .. \"\\nBackup: \" .. backupPath)\n"
                    "  else log(\"FAIL: khong doc duoc nguon: \" .. src) end\n"
                    "else log(\"FAIL: khong tim thay nguon: \" .. src) end\n"
                    "return true\n";

    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"http://127.0.0.1:46952/spawn"]];
    req.HTTPMethod = @"POST";
    [req setValue:@"text/lua; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"{}" forHTTPHeaderField:@"spawn_args"];
    req.HTTPBody = [lua dataUsingEncoding:NSUTF8StringEncoding];
    req.timeoutInterval = 8;

    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        if (err) {
            dispatch_async(dispatch_get_main_queue(), ^{ done([NSString stringWithFormat:@"Khong goi duoc XXTouch local /spawn.\nLoi: %@\n\nCan dam bao 1ferver/XXTouch dang chay tren port 46952.", err.localizedDescription]); });
            return;
        }
        NSString *body = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self readResultWithSpawnBody:body done:done];
        });
    }];
    [task resume];
}

- (void)readResultWithSpawnBody:(NSString *)spawnBody done:(void (^)(NSString *msg))done {
    NSString *urlStr = @"http://127.0.0.1:46952/download_file?filename=/var/mobile/Media/1ferver/ipa/lidcopy_result.txt";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 8;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSString *msg = nil;
        if (data.length > 0) msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (msg.length == 0) msg = [NSString stringWithFormat:@"Spawn da goi xong nhung khong doc duoc result.\nSpawn response:\n%@\nError:%@", spawnBody, err.localizedDescription ?: @"none"];
        dispatch_async(dispatch_get_main_queue(), ^{ done(msg); });
    }];
    [task resume];
}
@end

int main(int argc, char * argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
