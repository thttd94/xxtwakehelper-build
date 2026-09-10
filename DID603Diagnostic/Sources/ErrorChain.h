#import <Foundation/Foundation.h>
#include <stdint.h>
#include <errno.h>
static NSDictionary *ErrorChain(id root) {
 NSMutableDictionary *r=[@{@"schema":@1,@"depth":@0,@"cycle":@NO,@"truncated":@NO,@"invalid":@NO,@"d0":@0,@"c0":@0,@"k0":@0,@"d1":@0,@"c1":@0,@"k1":@0,@"d2":@0,@"c2":@0,@"k2":@0} mutableCopy];
 id seen[3]={nil,nil,nil};id cur=root;
 for(NSUInteger i=0;i<3 && cur;i++) {
  if(![cur isKindOfClass:NSError.class]){r[@"invalid"]=@YES;break;}
  BOOL cycle=NO;for(NSUInteger j=0;j<i;j++)if(cur==seen[j])cycle=YES;
  if(cycle){r[@"cycle"]=@YES;break;}seen[i]=cur;
  NSError *e=cur;NSString *domain=e.domain;NSInteger d=0;
  if([domain isEqualToString:@"MCMErrorDomain"])d=1;
  else if([domain isEqualToString:NSPOSIXErrorDomain])d=2;
  else if([domain isEqualToString:NSCocoaErrorDomain])d=3;
  else if([domain isEqualToString:NSOSStatusErrorDomain])d=4;
  else if([domain isEqualToString:NSMachErrorDomain])d=5;
  else if([domain isEqualToString:NSURLErrorDomain])d=6;
  NSInteger c=0,k=0;if(d){NSInteger raw=e.code;if(raw<INT32_MIN || raw>INT32_MAX)r[@"invalid"]=@YES;else c=raw;}
  if(d==2){if(c==EPERM || c==EACCES)k=1;else if(c==ENOENT)k=2;}
  r[ @[@"d0",@"d1",@"d2"][i] ]=@(d);r[ @[@"c0",@"c1",@"c2"][i] ]=@(c);r[ @[@"k0",@"k1",@"k2"][i] ]=@(k);r[@"depth"]=@(i+1);
  id next=e.userInfo[NSUnderlyingErrorKey];
  if(next && ![next isKindOfClass:NSError.class]){r[@"invalid"]=@YES;break;}
  BOOL repeat=NO;for(NSUInteger j=0;j<=i;j++)if(next && next==seen[j])repeat=YES;
  if(repeat){r[@"cycle"]=@YES;break;}
  if(i==2){if(next)r[@"truncated"]=@YES;break;}cur=next;
 }
 return r;
}
