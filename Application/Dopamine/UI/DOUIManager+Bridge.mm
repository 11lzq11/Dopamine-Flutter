#import "DOUIManager+Bridge.h"

static NSMutableArray<NSString *> *_bridgeLog;
static NSLock *_bridgeLogLock;
static NSUInteger _bridgeRecordConsumed;

@implementation DOUIManager (Bridge)

- (void)bridgeCaptureLog:(NSString *)line
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _bridgeLog = [NSMutableArray new];
        _bridgeLogLock = [NSLock new];
    });

    if (!line.length) return;
    [_bridgeLogLock lock];
    [_bridgeLog addObject:line];
    if (_bridgeLog.count > 1000) [_bridgeLog removeObjectsInRange:NSMakeRange(0, _bridgeLog.count - 1000)];
    [_bridgeLogLock unlock];
}

@end

NSArray<NSString *> *_DopamineBridgePopLogs(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _bridgeLog = [NSMutableArray new];
        _bridgeLogLock = [NSLock new];
        [[DOUIManager sharedInstance] startLogCapture];
    });

    NSArray *logs;
    [_bridgeLogLock lock];
    logs = [_bridgeLog copy] ?: @[];
    [_bridgeLog removeAllObjects];
    [_bridgeLogLock unlock];

    NSArray<NSString *> *record = [[DOUIManager sharedInstance] logRecord] ?: @[];
    if (record.count > _bridgeRecordConsumed) {
        NSRange range = NSMakeRange(_bridgeRecordConsumed, record.count - _bridgeRecordConsumed);
        logs = [logs arrayByAddingObjectsFromArray:[record subarrayWithRange:range]];
        _bridgeRecordConsumed = record.count;
    }

    return logs;
}

