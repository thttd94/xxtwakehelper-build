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
 Query(proxy,@"dataContainerURL",nil,NO,NSURL.class,@"data",r);
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
 char buf[2049]={0};ssize_t used=0;while(used<2048){ssize_t z=recv(c,buf+used,2048-used,0);if(z<=0)break;used+=z;buf[used]=0;if(strstr(buf,"\r\n\r\n"))break;}
 const char *line="GET /did603/startup/4b2dfc11a1ccbf2ce8bb9ef5e0dd9eef HTTP/1.1\r\n";
 if(used>0 && !strncmp(buf,line,strlen(line)) && strstr(buf,"\r\n\r\n") && !strstr(buf,"Transfer-Encoding:") && !strstr(buf,"Content-Length:")){
 NSData *body=Snapshot();if(body && body.length<=16384){NSString *h=[NSString stringWithFormat:@"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nCache-Control: no-store\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",(unsigned long)body.length];NSMutableData *out=[[h dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];[out appendData:body];NSUInteger off=0;while(off<out.length){ssize_t z=send(c,(const char*)out.bytes+off,out.length-off,0);if(z<=0)break;off+=z;}}
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
 NSData *pin=[[NSData alloc]initWithBase64EncodedString:@"MIIC6TCCAdGgAwIBAgIUD5FrLTon8dfHVbIrQPp9ZWc12bswDQYJKoZIhvcNAQELBQAwJDEiMCAGA1UEAwwZRElENjAzIHN0YXJ0dXAgZGlhZ25vc3RpYzAeFw0yNjA5MTAwMTA5MzJaFw0yNjA5MTAwMTQ0MzJaMCQxIjAgBgNVBAMMGURJRDYwMyBzdGFydHVwIGRpYWdub3N0aWMwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDiAPNOUKfTHkVU+LDQciFeJrLHLN8memOA2ZehAtNhfEbnYmYR0qyGKm2DF+pzV6nOG5jmkbz92W4HZAqefsLWaw0tLZVYsY8r8SS7vw2t/MEVsHv5mzqeDHvuGweHuhmVSoCyoW2mHxsLdHGMt5dbhgM/Cd3AfCojrkFremTOemzkx/32JapnptMREWyBspemZtyCuwiE4tjNHlERrJMdXnUhx28tmnwttntAC7u7cr7CkdMY3PLLBUOiq6dI7515puQPhadWee8Jj0SrkYQ2KZ9DeyCQSGaAMS/2rxwjkiAqo6qmiEXq9souFw2/DzLF7V9k7UAYL0Gx+ahpPpZPAgMBAAGjEzARMA8GA1UdEQQIMAaHBMARAQowDQYJKoZIhvcNAQELBQADggEBAHXnY1nxEiF7v/QvOqhCAmb6R2O+HR7Y6schoj1Wk2jfyj8hMpEiIg8QjQd9Gqe3fRVXkjc7sWd6Pk19UPQTfGnGcKYLxX6nZSBwA+TNXdkXbg5llU4K0xoMS9rWP4Ke/x+5zdQ6fJiAFBUDSlUO3jqb8vCk8LJvIoyFDMNhI//9SUVGpq90UJrfK+tMdEOJUkKuT9GUMutDTb4enHAnseIIVsIYKU1/XdtCeyqEJ/4gaHcbmtDW4Ij7kcwlLwkyXr762W+tXU8ixVS0vNt3vNTSmIUJCfwQAzsotrqKTvLMG7IUeBzhA3lV034H72/icDvlVdUhOVUfKpsGcG+bARQ=" options:0];BOOL equal=actual && [actual isEqualToData:pin];Mark(@"trust_pin",@(equal));if(!equal){done(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}
 SecPolicyRef policy=SecPolicyCreateSSL(true,CFSTR("192.17.1.10"));OSStatus a=SecTrustSetPolicies(trust,policy);CFRelease(policy);Mark(@"policy_status",@(a));
 OSStatus b=SecTrustSetAnchorCertificates(trust,(__bridge CFArrayRef)@[(__bridge id)leaf]);Mark(@"anchor_status",@(b));OSStatus c=SecTrustSetAnchorCertificatesOnly(trust,true);Mark(@"anchor_only_status",@(c));
 CFErrorRef error=NULL;BOOL ok=SecTrustEvaluateWithError(trust,&error);Mark(@"trust_evaluated",@YES);Mark(@"trust_ok",@(ok));if(error){Mark(@"trust_error_code",@(CFErrorGetCode(error)));CFRelease(error);}
 if(a || b || c || !ok){done(NSURLSessionAuthChallengeCancelAuthenticationChallenge,nil);return;}done(NSURLSessionAuthChallengeUseCredential,[NSURLCredential credentialForTrust:trust]);
}
-(void)URLSession:(NSURLSession*)session task:(NSURLSessionTask*)task willPerformHTTPRedirection:(NSHTTPURLResponse*)response newRequest:(NSURLRequest*)request completionHandler:(void(^)(NSURLRequest*))done {done(nil);}
-(void)startDiagnostic {
 if(self.started)return;self.started=YES;
 NSURLSessionConfiguration *config=[NSURLSessionConfiguration ephemeralSessionConfiguration];config.HTTPCookieStorage=nil;config.HTTPShouldSetCookies=NO;config.URLCredentialStorage=nil;config.URLCache=nil;config.connectionProxyDictionary=@{};config.timeoutIntervalForRequest=12;config.timeoutIntervalForResource=18;
 self.session=[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];NSMutableURLRequest *req=[NSMutableURLRequest requestWithURL:[NSURL URLWithString:@"https://192.17.1.10:59701/did603/startup/4b2dfc11a1ccbf2ce8bb9ef5e0dd9eef"]];req.HTTPMethod=@"POST";req.HTTPBody=[@"{\"schema\":5,\"stage0\":true}" dataUsingEncoding:NSUTF8StringEncoding];[req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
 NSURLSessionDataTask *task=[self.session dataTaskWithRequest:req completionHandler:^(NSData *body,NSURLResponse *response,NSError *error){
 Mark(@"error_domain",@(!error?0:[error.domain isEqualToString:NSURLErrorDomain]?1:[error.domain isEqualToString:NSPOSIXErrorDomain]?2:[error.domain isEqualToString:NSCocoaErrorDomain]?3:4));Mark(@"error_code",@(error.code));Mark(@"http_status",@([response isKindOfClass:NSHTTPURLResponse.class]?[(NSHTTPURLResponse*)response statusCode]:0));Mark(@"completion",@YES);[self.session finishTasksAndInvalidate];}];
 Mark(@"task_created",@((BOOL)(task!=nil)));[task resume];Mark(@"task_resume",@YES);
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0),^{@autoreleasepool{Mark(@"collect_before",@YES);@try{NSDictionary *r=Collect();Mark(@"lookup_returned",@((BOOL)([r[@"lookup_outcome"] integerValue]==5)));Mark(@"identifier_match",@((BOOL)[r[@"identifier_match"] boolValue]));Mark(@"collect_after",@YES);}@catch(NSException *e){Mark(@"collect_exception",@YES);}}});
}
-(BOOL)application:(UIApplication*)application didFinishLaunchingWithOptions:(NSDictionary*)options {
 State=[NSMutableDictionary new];for(NSString *k in @[@"did_finish",@"active",@"collect_before",@"collect_after",@"collect_exception",@"lookup_returned",@"identifier_match",@"task_created",@"task_resume",@"trust_entry",@"trust_guard",@"trust_pin",@"trust_evaluated",@"trust_ok",@"completion",@"persistence_ok",@"server_bound",@"server_closed"])State[k]=@NO; for(NSString *k in @[@"schema",@"build",@"server_errno",@"error_domain",@"error_code",@"http_status",@"policy_status",@"anchor_status",@"anchor_only_status",@"trust_error_code"])State[k]=@0; State[@"schema"]=@5;State[@"build"]=@5;State[@"did_finish"]=@YES;
 NSURL *own=[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] firstObject];ReportURL=[own URLByAppendingPathComponent:@"did603-startup-status.json" isDirectory:NO];Persist();Serve();
 self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];UIViewController *vc=[UIViewController new];self.window.rootViewController=vc;[self.window makeKeyAndVisible];return YES;
}
-(void)applicationDidBecomeActive:(UIApplication*)application{Mark(@"active",@YES);[self startDiagnostic];}
@end
int main(int argc,char **argv){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
