#import "../Sources/ErrorChain.h"
@interface SyntheticError:NSError
@property(nonatomic,strong) id next;
@end
@implementation SyntheticError
-(NSDictionary*)userInfo{return self.next?@{NSUnderlyingErrorKey:self.next,@"private":@"DO_NOT_EXPORT"}:@{@"private":@"DO_NOT_EXPORT"};}
@end
static void Check(BOOL ok){if(!ok)abort();}
int main(void){@autoreleasepool{
 NSDictionary *r=ErrorChain(nil);Check(r.count==14 && [r[@"depth"] intValue]==0);
 NSError *p=[NSError errorWithDomain:NSPOSIXErrorDomain code:EACCES userInfo:@{@"secret":@"DO_NOT_EXPORT"}];
 NSError *m=[NSError errorWithDomain:@"MCMErrorDomain" code:55 userInfo:@{NSUnderlyingErrorKey:p}];r=ErrorChain(m);Check(r.count==14 && [r[@"depth"] intValue]==2 && [r[@"d0"] intValue]==1 && [r[@"c0"] intValue]==55 && [r[@"k0"] intValue]==0 && [r[@"k1"] intValue]==1);
 for(NSNumber *n in @[@1,@2,@13,@55]){r=ErrorChain([NSError errorWithDomain:NSPOSIXErrorDomain code:n.integerValue userInfo:nil]);Check([r[@"k0"] intValue]==(n.intValue==1||n.intValue==13?1:n.intValue==2?2:0));}
 r=ErrorChain([NSError errorWithDomain:@"PRIVATE" code:123 userInfo:nil]);Check([r[@"d0"] intValue]==0 && [r[@"c0"] intValue]==0);
 r=ErrorChain([NSError errorWithDomain:NSPOSIXErrorDomain code:NSIntegerMax userInfo:nil]);Check([r[@"invalid"] boolValue] && [r[@"c0"] intValue]==0);
 r=ErrorChain([NSError errorWithDomain:NSPOSIXErrorDomain code:NSIntegerMin userInfo:nil]);Check([r[@"invalid"] boolValue]);
 SyntheticError *a=[[SyntheticError alloc]initWithDomain:@"MCMErrorDomain" code:55 userInfo:nil];a.next=a;r=ErrorChain(a);Check([r[@"cycle"] boolValue] && [r[@"depth"] intValue]==1);a.next=@123;r=ErrorChain(a);Check([r[@"invalid"] boolValue]);a.next=nil;
 NSError *n=p;for(int i=0;i<3;i++)n=[NSError errorWithDomain:@"MCMErrorDomain" code:55 userInfo:@{NSUnderlyingErrorKey:n}];r=ErrorChain(n);Check([r[@"truncated"] boolValue] && [r[@"depth"] intValue]==3);
 NSData *data=[NSJSONSerialization dataWithJSONObject:r options:0 error:nil];Check(data!=nil);NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];Check(![json containsString:@"DO_NOT_EXPORT"]);puts("Foundation ErrorChain synthetic tests PASS");
}return 0;}
