#import <YapDatabase/YapDatabaseViewTransaction.h>
 
@interface YapDatabaseViewTransaction (RubyMotionBlockTypeWrapper)
 
- (NSRange)findRangeInGroup:(NSString *)group
           usingObjectBlock:(YapDatabaseViewFindWithObjectBlock)block;
@end
