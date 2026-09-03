#import <Foundation/Foundation.h>
#import "ShotResultSnapshot.h"

NS_ASSUME_NONNULL_BEGIN
@interface LiveDataAdapter : NSObject
+ (instancetype)sharedAdapter;
- (BOOL)configureWithDictionary:(NSDictionary *)dictionary error:(NSError * _Nullable * _Nullable)error;
- (void)startReading;
- (void)stopReading;
- (ShotResultSnapshot *)getLatestSnapshot;
- (BOOL)isLiveDataAvailable;
@end
NS_ASSUME_NONNULL_END
