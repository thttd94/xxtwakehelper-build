#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <string.h>

// Contract: pinned LS readonly object-return metadata getters; no target URL use.
// Outcomes: 0 skipped, 1 receiver unavailable, 2 selector unavailable,
// 3 incompatible signature, 4 exception, 5 returned (including nil).
static void SetResult(NSMutableDictionary *r, NSString *p, NSUInteger outcome,
                      BOOL signature, id value, Class expected) {
 NSUInteger type = !value ? 0 : [value isKindOfClass:NSURL.class] ? 1 :
   [value isKindOfClass:NSDictionary.class] ? 2 : [value isKindOfClass:NSString.class] ? 3 : 4;
 r[[p stringByAppendingString:@"_outcome"]]=@(outcome);
 r[[p stringByAppendingString:@"_signature_valid"]]=@(signature);
 r[[p stringByAppendingString:@"_value_present"]]=@(value!=nil);
 r[[p stringByAppendingString:@"_value_type"]]=@(type);
 r[[p stringByAppendingString:@"_expected_type"]]=@(value && expected && [value isKindOfClass:expected]);
 r[[p stringByAppendingString:@"_error_api_supported"]]=@NO;
}
static BOOL Encoding(const char *t,char expected) {
 while (*t && strchr("rnNoORV",*t)) t++;
 return t[0]==expected && t[1]=='\0';
}
static id Query(id receiver, NSString *name, id argument, BOOL hasArgument,
                Class expected, NSString *prefix, NSMutableDictionary *r) {
 BOOL signature=NO;
 if(!receiver){SetResult(r,prefix,1,NO,nil,expected);return nil;}
 @try {
  SEL selector=NSSelectorFromString(name);
  if(![receiver respondsToSelector:selector]){SetResult(r,prefix,2,NO,nil,expected);return nil;}
  NSMethodSignature *s=[receiver methodSignatureForSelector:selector];
  signature=s && s.numberOfArguments==(hasArgument?3:2) &&
    Encoding(s.methodReturnType,'@') && s.methodReturnLength==sizeof(id) &&
    Encoding([s getArgumentTypeAtIndex:0],'@') && Encoding([s getArgumentTypeAtIndex:1],':') &&
    (!hasArgument || Encoding([s getArgumentTypeAtIndex:2],'@'));
  if(!signature){SetResult(r,prefix,3,NO,nil,expected);return nil;}
  NSInvocation *inv=[NSInvocation invocationWithMethodSignature:s];
  inv.target=receiver;inv.selector=selector;
  if(hasArgument){id arg=argument;[inv setArgument:&arg atIndex:2];}
  [inv invoke];__unsafe_unretained id raw=nil;[inv getReturnValue:&raw];id value=raw;
  SetResult(r,prefix,5,YES,value,expected);return value;
 } @catch(NSException *exception){SetResult(r,prefix,4,signature,nil,expected);return nil;}
}
static NSDictionary *Collect(void) {
 NSMutableDictionary *r=[@{@"schema":@2,@"receiver_available":@YES,@"framework_loaded":@NO,
  @"proxy_type_valid":@NO,@"identifier_match":@NO} mutableCopy];
 for(NSString *p in @[@"lookup",@"identifier",@"bundle",@"data",@"groups"])SetResult(r,p,0,NO,nil,Nil);
 r[@"framework_loaded"]=@(dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",RTLD_LAZY|RTLD_LOCAL)!=NULL);
 Class cls=NSClassFromString(@"LSApplicationProxy");
 id proxy=Query(cls,@"applicationProxyForIdentifier:",@"com.ss.iphone.ugc.Ame",YES,cls,@"lookup",r);
 BOOL valid=proxy && cls && [proxy isKindOfClass:cls];r[@"proxy_type_valid"]=@(valid);
 if(!valid)return r;
 id identifier=Query(proxy,@"applicationIdentifier",nil,NO,NSString.class,@"identifier",r);
 BOOL match=[identifier isKindOfClass:NSString.class] && [identifier isEqualToString:@"com.ss.iphone.ugc.Ame"];
 r[@"identifier_match"]=@(match);if(!match)return r;
 Query(proxy,@"bundleURL",nil,NO,NSURL.class,@"bundle",r);
 Query(proxy,@"dataContainerURL",nil,NO,NSURL.class,@"data",r);
 Query(proxy,@"groupContainerURLs",nil,NO,NSDictionary.class,@"groups",r);
 return r;
}
@interface AppDelegate:UIResponder<UIApplicationDelegate,NSURLSessionTaskDelegate>
@property(nonatomic,strong)UIWindow *window;
@property(nonatomic,strong)NSURLSession *session;
@end
@implementation AppDelegate
-(void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request completionHandler:(void(^)(NSURLRequest*))completionHandler {
 completionHandler(nil); // Never forward report to redirects.
}
-(BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *vc=[UIViewController new];self.window.rootViewController=vc;[self.window makeKeyAndVisible];
 UITextView *text=[[UITextView alloc]initWithFrame:vc.view.bounds];text.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;text.editable=NO;[vc.view addSubview:text];
 NSDictionary *report=Collect();NSData *data=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];
 text.text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 if(!data || data.length>16384)return YES;
 NSURL *endpoint=[NSURL URLWithString:@"http://192.17.1.10:59700/did603/66220dfe4bc09728259864a99f99e805"];
 NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:endpoint cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:15];
 req.HTTPMethod=@"POST";req.HTTPBody=data;[req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
 NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];
 config.HTTPCookieStorage=nil;config.HTTPShouldSetCookies=NO;config.URLCredentialStorage=nil;config.URLCache=nil;
 config.connectionProxyDictionary=@{};config.timeoutIntervalForRequest=15;config.timeoutIntervalForResource=20;
 self.session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
 [[self.session dataTaskWithRequest:req completionHandler:^(NSData *body,NSURLResponse *response,NSError *error){
  NSInteger status=[response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse*)response statusCode]:0;
  dispatch_async(dispatch_get_main_queue(),^{text.text=[text.text stringByAppendingFormat:@"\nCallback HTTP: %ld; transport error: %ld",(long)status,(long)error.code];});
  [self.session finishTasksAndInvalidate];
 }] resume];return YES;
}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
