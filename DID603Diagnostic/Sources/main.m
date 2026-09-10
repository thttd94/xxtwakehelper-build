#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#include <string.h>
#import <Security/Security.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <errno.h>
#include <sys/select.h>

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
  if(validError){NSError *e=error;r[@"mcm_error_code"]=@(e.code);r[@"mcm_error_category"]=@([e.domain isEqualToString:NSPOSIXErrorDomain]?1:[e.domain isEqualToString:NSCocoaErrorDomain]?2:[e.domain isEqualToString:@"MCMErrorDomain"]?3:4);r[@"mcm_error_posix"]=@((BOOL)[e.domain isEqualToString:NSPOSIXErrorDomain]);r[@"mcm_error_cocoa"]=@((BOOL)[e.domain isEqualToString:NSCocoaErrorDomain]);r[@"mcm_error_mcm"]=@((BOOL)[e.domain isEqualToString:@"MCMErrorDomain"]);r[@"mcm_error_other"]=@((BOOL)(![r[@"mcm_error_posix"] boolValue] && ![r[@"mcm_error_cocoa"] boolValue] && ![r[@"mcm_error_mcm"] boolValue]));}
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
 if(!valid)return r;
 id identifier=Query(proxy,@"applicationIdentifier",nil,NO,NSString.class,@"identifier",r);
 BOOL match=[identifier isKindOfClass:NSString.class] && [identifier isEqualToString:@"com.ss.iphone.ugc.Ame"];
 r[@"identifier_match"]=@(match);if(!match)return r;
 Query(proxy,@"bundleURL",nil,NO,NSURL.class,@"bundle",r);
 if([r[@"bundle_outcome"] integerValue]==3)return r;
 Query(proxy,@"dataContainerURL",nil,NO,NSURL.class,@"data",r);
 if([r[@"data_outcome"] integerValue]==3)return r;
 Query(proxy,@"groupContainerURLs",nil,NO,NSDictionary.class,@"groups",r);
 return r;
}

static NSMutableDictionary *State; static NSURL *ReportURL;
static void Persist(void) {
 NSData *b=[NSJSONSerialization dataWithJSONObject:State options:0 error:nil];
 if(ReportURL && b && b.length<=16384){BOOL ok=[b writeToURL:ReportURL options:NSDataWritingAtomic error:nil];State[@"persistence_ok"]=@(ok);}
}
static void Mark(NSString *k,NSNumber *v){@synchronized(State){State[k]=v;Persist();}}
static NSData *Snapshot(void){@synchronized(State){return [NSJSONSerialization dataWithJSONObject:State options:0 error:nil];}}
static void Serve(void){dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@autoreleasepool{
 int fd=socket(AF_INET,SOCK_STREAM,0);if(fd<0){Mark(@"server_errno",@(errno));return;}
 int one=1;setsockopt(fd,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
 struct sockaddr_in addr={0};addr.sin_len=sizeof(addr);addr.sin_family=AF_INET;addr.sin_port=htons(59702);inet_pton(AF_INET,"192.17.4.1",&addr.sin_addr);
 if(bind(fd,(struct sockaddr*)&addr,sizeof(addr)) || listen(fd,2)){Mark(@"server_errno",@(errno));close(fd);return;}
 Mark(@"server_bound",@YES);NSDate *end=[NSDate dateWithTimeIntervalSinceNow:180];
 for(int n=0;n<90 && [end timeIntervalSinceNow]>0;n++){@autoreleasepool{
 fd_set set;FD_ZERO(&set);FD_SET(fd,&set);struct timeval tv={2,0};if(select(fd+1,&set,NULL,NULL,&tv)<=0)continue;
 struct sockaddr_in peer={0};socklen_t len=sizeof(peer);int c=accept(fd,(struct sockaddr*)&peer,&len);if(c<0)continue;
 struct in_addr expected;inet_pton(AF_INET,"192.17.1.10",&expected);if(peer.sin_addr.s_addr!=expected.s_addr){close(c);continue;}
 setsockopt(c,SOL_SOCKET,SO_NOSIGPIPE,&one,sizeof(one));struct timeval timeout={2,0};setsockopt(c,SOL_SOCKET,SO_RCVTIMEO,&timeout,sizeof(timeout));setsockopt(c,SOL_SOCKET,SO_SNDTIMEO,&timeout,sizeof(timeout));
 NSDate *clientEnd=[NSDate dateWithTimeIntervalSinceNow:3];char buf[2049]={0};ssize_t used=0;while(used<2048 && [clientEnd timeIntervalSinceNow]>0 && [end timeIntervalSinceNow]>0){ssize_t z=recv(c,buf+used,2048-used,0);if(z<=0)break;used+=z;buf[used]=0;if(strstr(buf,"\r\n\r\n"))break;}
 const char *line="GET /did603/eku/c6894f4cb52779a1033487e12c0d3dfe HTTP/1.1\r\n";
 if(used>0 && !strncmp(buf,line,strlen(line)) && strstr(buf,"\r\n\r\n") && !strstr(buf,"Transfer-Encoding:") && !strstr(buf,"Content-Length:")){
 NSData *body=Snapshot();if(body && body.length<=16384){NSString *h=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",(unsigned long)body.length];NSMutableData *out=[[h dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];[out appendData:body];NSUInteger off=0;while(off<out.length && [clientEnd timeIntervalSinceNow]>0 && [end timeIntervalSinceNow]>0){ssize_t z=send(c,(const char*)out.bytes+off,out.length-off,0);if(z<=0)break;off+=z;}}
 }close(c);
 }}close(fd);Mark(@"server_closed",@YES);
 }});}
@interface AppDelegate:UIResponder<UIApplicationDelegate,NSURLSessionTaskDelegate>
@property(nonatomic,strong)UIWindow *window;
@property(nonatomic,strong)NSURLSession *session;
@property(nonatomic,assign)BOOL started;
@end
@implementation AppDelegate
-(void)URLSession:(NSURLSession*)session didReceiveChallenge:(NSURLAuthenticationChallenge*)challenge completionHandler:(void(^)(NSURLSessionAuthChallengeDisposition,NSURLCredential*))done {
 Mark(@"trust_entry",@YES);NSURLProtectionSpace *space=challenge.protectionSpace;
 BOOL guard=session==self.session && [space.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust] && [space.host isEqualToString:@"192.17.1.10"] && space.port==59701 && [space.protocol isEqualToString:@"https"] && space.serverTrust;
 Mark(@"trust_guard",@(guard));if(!guard){done(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}
 SecTrustRef trust=space.serverTrust;SecCertificateRef leaf=SecTrustGetCertificateAtIndex(trust,0);
 NSData *actual=leaf?CFBridgingRelease(SecCertificateCopyData(leaf)):nil;
 NSData *pin=[[NSData alloc]initWithBase64EncodedString:@"MIIDEzCCAfugAwIBAgITZBqqk378Ksd/3fZDGBVWPvTCBzANBgkqhkiG9w0BAQsFADAgMR4wHAYDVQQDDBVESUQ2MDMgRUtVIGRpYWdub3N0aWMwHhcNMjYwOTEwMDEyMDE1WhcNMjYwOTEwMDE1MDE1WjAgMR4wHAYDVQQDDBVESUQ2MDMgRUtVIGRpYWdub3N0aWMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC8n2kG0bVfKkC74LHxZBilctwQVxzRsee6GnNny5Ee9WShK6PrUNCHzG+fNudxOuhgGflDGwm02Z0BW5RaOH9QGGcc3W8Gaa+qzVxFjoRszp0e0x3G0TIV31mIUcgXNW2Q5rqSw1X3EruM1ygokOJPmx00T/Oz50DazcYUKvDlttHQxINf1En0pZbeM76PJM75uF5oDik8k9yvDerv71LzJ4teK7TYtrkNFB+Re089RlU0UytsBdS+w7PxXYh9+l0TmRBD+Fyoa59Tyik6jMUAhcRa4e6cyLKdFcmVKPN2ITs0mt1mfFhXQx4nz8lJ3lXdkPY5Xh6R9v7etzIIk0OnAgMBAAGjRjBEMA8GA1UdEQQIMAaHBMARAQowEwYDVR0lBAwwCgYIKwYBBQUHAwEwDgYDVR0PAQH/BAQDAgWgMAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQELBQADggEBAAQisLA0gUlo9yXL7EKiqjVN98pEgnCohXKWVITFmkTsF5QwARWk2aTKRoFKpBzOB6J0h5gO+bU96u7MhjBKa048pOtz77zaSYOlIKskKipbLWRDnkHNlgm72F0BDGgQUen+mBjq6CH0HyJI8XDk9X+hGO/aI3mrQRVOw62YY9j5THS/MyQl1fKiUXwTB7csku38eEdF7X0rsXgzcAsKw+LM7Qf2QPL2C+uAW3s/QXThkQ2egAIhYoLSXYu3u8VFgeR2kMib5EvAlgNxOuNPdKDOK+cpEhJcExxxpjaIJ5ypa8sLKapErJAplnQPghsZNL7kh06yvBdRv5kL3lSn+Ik=" options:0];BOOL equal=actual && [actual isEqualToData:pin];Mark(@"trust_pin",@(equal));if(!equal){done(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}
 SecPolicyRef policy=SecPolicyCreateSSL(true,CFSTR("192.17.1.10"));OSStatus a=SecTrustSetPolicies(trust,policy);CFRelease(policy);Mark(@"policy_status",@(a));
 OSStatus b=SecTrustSetAnchorCertificates(trust,(__bridge CFArrayRef)@[(__bridge id)leaf]);Mark(@"anchor_status",@(b));OSStatus c=SecTrustSetAnchorCertificatesOnly(trust,true);Mark(@"anchor_only_status",@(c));
 CFErrorRef error=NULL;BOOL ok=SecTrustEvaluateWithError(trust,&error);Mark(@"trust_evaluated",@YES);Mark(@"trust_ok",@(ok));if(error){Mark(@"trust_error_code",@(CFErrorGetCode(error)));CFRelease(error);}
 if(a || b || c || !ok){done(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}done(NSURLSessionAuthChallengeUseCredential,[NSURLCredential credentialForTrust:trust]);
}
-(void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request completionHandler:(void(^)(NSURLRequest*))done {done(nil);}
-(void)startDiagnostic {
 if(self.started)return;self.started=YES;
 NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];config.HTTPCookieStorage=nil;config.HTTPShouldSetCookies=NO;config.URLCredentialStorage=nil;config.URLCache=nil;config.connectionProxyDictionary=@{};config.timeoutIntervalForRequest=12;config.timeoutIntervalForResource=18;
 self.session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://192.17.1.10:59701/did603/eku/c6894f4cb52779a1033487e12c0d3dfe"]];req.HTTPMethod=@"POST";req.HTTPBody=[@"{\"schema\":6,\"stage0\":true}" dataUsingEncoding:NSUTF8StringEncoding];[req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
 NSURLSessionDataTask *task=[self.session dataTaskWithRequest:req completionHandler:^(NSData *body,NSURLResponse *response,NSError *error){
 Mark(@"error_domain",@(!error?0:[error.domain isEqualToString:NSURLErrorDomain]?1:[error.domain isEqualToString:NSPOSIXErrorDomain]?2:[error.domain isEqualToString:NSCocoaErrorDomain]?3:4));Mark(@"error_code",@(error.code));Mark(@"http_status",@([response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse*)response statusCode]:0));Mark(@"completion",@YES);
 if(error || ![State[@"trust_ok"] boolValue] || ![State[@"trust_pin"] boolValue] || ![response isKindOfClass:NSHTTPURLResponse.class] || [(NSHTTPURLResponse*)response statusCode]!=204){[self.session finishTasksAndInvalidate];return;}
 Mark(@"tls204",@YES);Mark(@"stage",@1);
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@autoreleasepool{
 Mark(@"collect_before",@YES);@try{NSMutableDictionary *r=[Collect() mutableCopy];
 for(NSString *k in r){if(![k isEqualToString:@"schema"])Mark(k,r[k]);}
 Mark(@"lookup_returned",@((BOOL)([r[@"lookup_outcome"] integerValue]==5)));Mark(@"collect_after",@YES);
 BOOL bad=NO;for(NSString *p in @[@"lookup",@"identifier",@"bundle",@"data",@"groups"]){if([r[[p stringByAppendingString:@"_outcome"]] integerValue]==3)bad=YES;}
 if(bad)Mark(@"abi_stop",@YES);
 else if([r[@"identifier_match"] boolValue]){Mark(@"mcm_before",@YES);MCM(r);for(NSString *k in r){if([k hasPrefix:@"mcm_"])Mark(k,r[k]);}Mark(@"mcm_after",@YES);if([r[@"mcm_outcome"] integerValue]==3)Mark(@"abi_stop",@YES);}
 }@catch(NSException *e){Mark(@"collect_exception",@YES);}
 Mark(@"stage",@2);NSMutableURLRequest *finalReq=[req mutableCopy];finalReq.HTTPBody=Snapshot();
 [[self.session dataTaskWithRequest:finalReq completionHandler:^(NSData *b,NSURLResponse *v,NSError *e){NSInteger status=[v isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse*)v statusCode]:0;Mark(@"final_http_status",@(status));Mark(@"final_error_code",@(e.code));Mark(@"final_error_category",@(!e?0:[e.domain isEqualToString:NSURLErrorDomain]?1:4));Mark(@"final_ok",@((BOOL)(!e && status==204)));Mark(@"final_completion",@YES);[self.session finishTasksAndInvalidate];}] resume];
 }});}];
 Mark(@"task_created",@((BOOL)(task!=nil)));[task resume];Mark(@"task_resume",@YES);

}
-(BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
 State=[NSMutableDictionary new];for(NSString *k in @[@"did_finish",@"active",@"collect_before",@"collect_after",@"collect_exception",@"lookup_returned",@"identifier_match",@"task_created",@"task_resume",@"trust_entry",@"trust_guard",@"trust_pin",@"trust_evaluated",@"trust_ok",@"completion",@"persistence_ok",@"server_bound",@"server_closed"])State[k]=@NO; for(NSString *k in @[@"schema",@"build",@"server_errno",@"error_domain",@"error_code",@"http_status",@"policy_status",@"anchor_status",@"anchor_only_status",@"trust_error_code"])State[k]=@0; for(NSString *k in @[@"tls204",@"abi_stop",@"mcm_before",@"mcm_after",@"final_completion",@"final_ok",@"receiver_available",@"framework_loaded",@"proxy_type_valid",@"mcm_framework_loaded",@"mcm_class_valid",@"mcm_signature_valid",@"mcm_existed",@"mcm_value_present",@"mcm_value_expected_type",@"mcm_error_present",@"mcm_error_is_nserror",@"mcm_error_posix",@"mcm_error_cocoa",@"mcm_error_mcm",@"mcm_error_other",@"lookup_signature_valid",@"lookup_value_present",@"lookup_expected_type",@"lookup_error_api_supported",@"identifier_signature_valid",@"identifier_value_present",@"identifier_expected_type",@"identifier_error_api_supported",@"bundle_signature_valid",@"bundle_value_present",@"bundle_expected_type",@"bundle_error_api_supported",@"data_signature_valid",@"data_value_present",@"data_expected_type",@"data_error_api_supported",@"groups_signature_valid",@"groups_value_present",@"groups_expected_type",@"groups_error_api_supported"])State[k]=@NO;for(NSString *k in @[@"stage",@"mcm_outcome",@"mcm_value_type",@"mcm_error_code",@"mcm_error_category",@"final_error_code",@"final_error_category",@"final_http_status",@"lookup_outcome",@"lookup_value_type",@"identifier_outcome",@"identifier_value_type",@"bundle_outcome",@"bundle_value_type",@"data_outcome",@"data_value_type",@"groups_outcome",@"groups_value_type"])State[k]=@0;State[@"schema"]=@6;State[@"build"]=@6;State[@"did_finish"]=@YES;
 NSURL *own=[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];ReportURL=[own URLByAppendingPathComponent:@"did603-startup-status.json" isDirectory:NO];Persist();Serve();
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *vc=[UIViewController new];self.window.rootViewController=vc;[self.window makeKeyAndVisible];return YES;
}
-(void)applicationDidBecomeActive:(UIApplication*)application{Mark(@"active",@YES);[self startDiagnostic];}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
