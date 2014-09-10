#import <YapDatabase/YapDatabaseSecondaryIndex.h>
 
@interface YapDatabaseSecondaryIndex (RubyMotionBlockTypeWrapper)
 
// Here we define the prototype of our wrapper method that explicitly
// states what the type signature of the block argument will be.
//
// This will give the RubyMotion compiler enough information to ‘do
// the right thing’.
- (id)initWithSetup:(YapDatabaseSecondaryIndexSetup *)setup
        objectBlock:(YapDatabaseSecondaryIndexWithObjectBlock)block
         versionTag:(NSString *)versionTag;
@end
