#import "YapDatabaseRubyMotion.h"
 
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Use the `-fobjc-arc` flag.
#endif
 
@implementation YapDatabaseViewTransaction (RubyMotionBlockTypeWrapper)
 
// Here we define the implementation that does nothing else than forward
// the method call to the normal library’s API. You could say we are
// ‘aliasing’ the method (although we do change the interface).
- (NSRange)findRangeInGroup:(NSString *)group
           usingObjectBlock:(YapDatabaseViewFindWithObjectBlock)block;
{
  return [self findRangeInGroup:group
                     usingBlock:block
                      blockType:YapDatabaseViewBlockTypeWithObject];
}
 
@end
