#import "DOUIManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface DOUIManager (Bridge)
- (void)bridgeCaptureLog:(NSString *)line;
@end

extern NSArray<NSString *> *_DopamineBridgePopLogs(void);

NS_ASSUME_NONNULL_END
