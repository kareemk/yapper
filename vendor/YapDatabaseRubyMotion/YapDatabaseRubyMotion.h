#import <YapDatabase/YapDatabaseSecondaryIndex.h>
 
@interface YapDatabaseSecondaryIndex (RubyMotionBlockTypeWrapper)
 
- (id)initWithSetup:(YapDatabaseSecondaryIndexSetup *)setup
        objectBlock:(YapDatabaseSecondaryIndexWithObjectBlock)block
         versionTag:(NSString *)versionTag;
@end

#import <YapDatabase/YapDatabaseFullTextSearch.h>

@interface YapDatabaseFullTextSearch (RubyMotionBlockTypeWrapper)

  - (id)initWithColumnNames:(NSArray *)columnNames
                objectBlock:(YapDatabaseFullTextSearchWithObjectBlock)block
                 versionTag:(NSString *)versionTag;
@end
