#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <objc/message.h>
#include <unistd.h>
#include <errno.h>

typedef CFTypeRef (*TaskCreate)(CFAllocatorRef);
typedef CFTypeRef (*TaskValue)(CFTypeRef,CFStringRef,CFErrorRef*);
static NSDictionary *URLCheck(id value) {
 if (![value isKindOfClass:NSURL.class]) return @{ @"available":@NO };
 NSURL *url=value; if (!url.isFileURL) return @{ @"available":@YES,@"file_url":@NO };
 BOOL dir=NO; BOOL exists=[[NSFileManager defaultManager] fileExistsAtPath:url.path isDirectory:&dir];
 errno=0; int rc=access(url.fileSystemRepresentation,R_OK); int err=rc?errno:0;
 return @{@"available":@YES,@"exists":@(exists),@"directory":@(dir),@"readable":@(rc==0),@"access_errno":@(err)};
}
static id SafeGet(id obj,NSString *name,NSMutableDictionary *errors) {
 SEL sel=NSSelectorFromString(name); if(![obj respondsToSelector:sel]) {errors[name]=@{@"selector_available":@NO};return nil;}
 @try { return ((id(*)(id,SEL))objc_msgSend)(obj,sel); } @catch(NSException *e) {errors[name]=@{@"exception":@YES};return nil;}
}
static NSDictionary *Collect(void) {
 NSMutableDictionary *report=[NSMutableDictionary dictionary];report[@"schema"]=@1;report[@"read_only"]=@YES;
 NSMutableDictionary *ent=[NSMutableDictionary dictionary];
 TaskCreate create=(TaskCreate)dlsym(RTLD_DEFAULT,"SecTaskCreateFromSelf");TaskValue copy=(TaskValue)dlsym(RTLD_DEFAULT,"SecTaskCopyValueForEntitlement");
 report[@"self_entitlement_api_available"]=@(create && copy);
 CFTypeRef task=create?create(kCFAllocatorDefault):NULL;
 for(NSString *key in @[@"platform-application",@"get-task-allow",@"com.apple.private.security.no-container",@"com.apple.private.security.container-required",@"keychain-access-groups",@"com.apple.security.application-groups",@"com.apple.private.MobileContainerManager.allowed",@"com.apple.private.security.storage.AppDataContainers"]) {
  CFErrorRef error=NULL;CFTypeRef v=(task&&copy)?copy(task,(__bridge CFStringRef)key,&error):NULL;
  NSMutableDictionary *entry=[@{@"present":@(v!=NULL)} mutableCopy];
  if(v && CFGetTypeID(v)==CFBooleanGetTypeID()) entry[@"boolean"]=@((BOOL)CFBooleanGetValue((CFBooleanRef)v));
  if(v && CFGetTypeID(v)==CFArrayGetTypeID()) entry[@"count"]=@(CFArrayGetCount((CFArrayRef)v));
  if(error){entry[@"error_code"]=@(CFErrorGetCode(error));CFRelease(error);}if(v)CFRelease(v);ent[key]=entry;
 } if(task)CFRelease(task);report[@"self_entitlements"]=ent;
 NSMutableDictionary *frameworks=[NSMutableDictionary dictionary];
 for(NSString *p in @[@"/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",@"/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager",@"/System/Library/PrivateFrameworks/AppSupport.framework/AppSupport"]) {
  void *h=dlopen(p.UTF8String,RTLD_LAZY|RTLD_LOCAL);frameworks[p.lastPathComponent]=@{@"file_exists":@([[NSFileManager defaultManager] fileExistsAtPath:p]),@"loadable":@(h!=NULL)};
 }
 report[@"frameworks"]=frameworks;
 NSMutableDictionary *classes=[NSMutableDictionary dictionary];for(NSString *s in @[@"LSApplicationProxy",@"LSApplicationWorkspace",@"MCMAppDataContainer",@"MCMSharedDataContainer",@"CPDistributedMessagingCenter"]) classes[s]=@(NSClassFromString(s)!=Nil);report[@"classes"]=classes;
 NSMutableDictionary *ls=[NSMutableDictionary dictionary],*errors=[NSMutableDictionary dictionary];
 Class cls=NSClassFromString(@"LSApplicationProxy");SEL selector=NSSelectorFromString(@"applicationProxyForIdentifier:");id proxy=nil;
 ls[@"lookup_available"]=@([cls respondsToSelector:selector]);
 @try {if([cls respondsToSelector:selector])proxy=((id(*)(id,SEL,id))objc_msgSend)(cls,selector,@"com.ss.iphone.ugc.Ame");} @catch(NSException *e){ls[@"lookup_exception"]=@YES;}
 ls[@"proxy_present"]=@(proxy!=nil);
 if(proxy){
  id identifier=SafeGet(proxy,@"applicationIdentifier",errors);ls[@"intended_identifier_match"]=@([identifier isKindOfClass:NSString.class]&&[identifier isEqualToString:@"com.ss.iphone.ugc.Ame"]);
  for(NSString *field in @[@"bundleURL",@"dataContainerURL"])ls[field]=URLCheck(SafeGet(proxy,field,errors));
  id groups=SafeGet(proxy,@"groupContainerURLs",errors);
  if([groups isKindOfClass:NSDictionary.class]){NSUInteger exists=0,readable=0,failures=0;for(id url in [groups allValues]){NSDictionary *c=URLCheck(url);exists+=[c[@"exists"] boolValue];readable+=[c[@"readable"] boolValue];failures+=![c[@"readable"] boolValue];}ls[@"group_containers"]=@{@"available":@YES,@"count":@([groups count]),@"exists_count":@(exists),@"readable_count":@(readable),@"access_failure_count":@(failures)};}else ls[@"group_containers"]=@{@"available":@NO};
 }ls[@"access_errors"]=errors;report[@"target_registration"]=ls;return report;
}
@interface AppDelegate:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong)UIWindow *window;
@end
@implementation AppDelegate
-(BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *vc=[UIViewController new];self.window.rootViewController=vc;[self.window makeKeyAndVisible];
 UITextView *text=[[UITextView alloc]initWithFrame:vc.view.bounds];text.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;text.editable=NO;[vc.view addSubview:text];
 NSDictionary *report=Collect();NSData *data=[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil];
 NSURL *docs=[[[NSFileManager defaultManager]URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask]firstObject];NSError *error=nil;BOOL saved=[data writeToURL:[docs URLByAppendingPathComponent:@"diagnostic.json"] options:NSDataWritingAtomic error:&error];
 text.text=[NSString stringWithFormat:@"603 READ-ONLY\nReport saved: %@; error: %ld\n%@",saved?@"true":@"false",(long)error.code,[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
