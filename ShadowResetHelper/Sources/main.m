#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#import <dlfcn.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(strong,nonatomic) UIWindow *window;
@property(strong,nonatomic) UITextView *log;
@end

@implementation AppDelegate
- (void)add:(NSString *)s { self.log.text=[NSString stringWithFormat:@"%@\n%@",self.log.text?:@"",s?:@""]; }
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
 self.window=[[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
 UIViewController *vc=[UIViewController new]; vc.view.backgroundColor=UIColor.blackColor;
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; b.frame=CGRectMake(20,80,vc.view.bounds.size.width-40,60);
 [b setTitle:@"RESET SHADOW DATA" forState:UIControlStateNormal]; b.backgroundColor=UIColor.systemRedColor; [b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
 [b addTarget:self action:@selector(resetNow) forControlEvents:UIControlEventTouchUpInside]; [vc.view addSubview:b];
 self.log=[[UITextView alloc] initWithFrame:CGRectMake(20,160,vc.view.bounds.size.width-40,300)]; self.log.editable=NO; self.log.text=@"Ready. Sends ios.shadowteam.zsd / cmd / {cmd:reset}."; [vc.view addSubview:self.log];
 self.window.rootViewController=vc; [self.window makeKeyAndVisible]; return YES;
}
- (void)resetNow {
 void *appSupport=dlopen("/System/Library/PrivateFrameworks/AppSupport.framework/AppSupport",RTLD_NOW|RTLD_GLOBAL);
 [self add:[NSString stringWithFormat:@"AppSupport: %s",appSupport?"loaded":(dlerror()?:"failed")]];
 void *rocket=dlopen("/usr/lib/librocketbootstrap.dylib",RTLD_NOW|RTLD_GLOBAL);
 if(!rocket) rocket=dlopen("/var/jb/usr/lib/librocketbootstrap.dylib",RTLD_NOW|RTLD_GLOBAL);
 [self add:[NSString stringWithFormat:@"RocketBootstrap: %s",rocket?"loaded":"absent"]];
 Class C=NSClassFromString(@"CPDistributedMessagingCenter");
 if(!C){ [self add:@"ERROR: CPDistributedMessagingCenter unavailable"]; return; }
 id center=((id(*)(id,SEL,id))objc_msgSend)(C,sel_registerName("centerNamed:"),@"ios.shadowteam.zsd");
 if(!center){ [self add:@"ERROR: center unavailable"]; return; }
 SEL apply=sel_registerName("applyRocketBootstrap");
 [self add:[NSString stringWithFormat:@"applyRocketBootstrap: %@",[center respondsToSelector:apply]?@"YES":@"NO"]];
 if([center respondsToSelector:apply]) ((void(*)(id,SEL))objc_msgSend)(center,apply);
 NSDictionary *payload=@{@"cmd":@"reset"};
 [self add:@"Sending ios.shadowteam.zsd / cmd / reset..."];
 id reply=((id(*)(id,SEL,id,id))objc_msgSend)(center,sel_registerName("sendMessageAndReceiveReplyName:userInfo:"),@"cmd",payload);
 [self add:[NSString stringWithFormat:@"Reply: %@",reply?:@"(nil)"]];
}
@end

int main(int argc,char **argv){ @autoreleasepool { return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class)); } }
