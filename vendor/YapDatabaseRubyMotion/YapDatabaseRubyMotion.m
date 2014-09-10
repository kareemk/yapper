#import "YapDatabaseRubyMotion.h"
 
#if ! __has_feature(objc_arc)
#error This file must be compiled with ARC. Use the `-fobjc-arc` flag.
#endif
 
@implementation YapDatabaseSecondaryIndex (RubyMotionBlockTypeWrapper)
 
// Here we define the implementation that does nothing else than forward
// the method call to the normal library’s API. You could say we are
// ‘aliasing’ the method (although we do change the interface).
- (id)initWithSetup:(YapDatabaseSecondaryIndexSetup *)setup
        objectBlock:(YapDatabaseSecondaryIndexWithObjectBlock)block
         versionTag:(NSString *)versionTag;
{
  return [self initWithSetup:setup
                       block:block
                   blockType:YapDatabaseSecondaryIndexBlockTypeWithObject
                   versionTag:versionTag];
}
 
@end
