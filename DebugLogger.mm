#import <Foundation/Foundation.h>
#import <os/log.h>
#include "DebugLogger.h"

namespace {
os_log_t Logger() { static os_log_t l=os_log_create("com.internal.pool", "overlay"); return l; }
void Write(NSString *level, const std::string& message) {
    NSString *text=[NSString stringWithUTF8String:message.c_str()] ?: @"";
    os_log_with_type(Logger(), OS_LOG_TYPE_DEFAULT, "%{public}@ %{public}@", level, text);
    NSString *dir=NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES).firstObject;
    NSString *path=[dir stringByAppendingPathComponent:@"Logs/pool-overlay.log"];
    NSFileManager *fm=NSFileManager.defaultManager;
    [fm createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
    NSData *data=[[NSString stringWithFormat:@"%@ %@ %@\n", [NSDate date], level, text] dataUsingEncoding:NSUTF8StringEncoding];
    if(![fm fileExistsAtPath:path]) {[data writeToFile:path atomically:YES]; return;}
    NSFileHandle *h=[NSFileHandle fileHandleForWritingAtPath:path]; [h seekToEndOfFile]; [h writeData:data]; [h closeFile];
}
}
namespace PoolDebug { void logInfo(const std::string& m){Write(@"INFO",m);} void logWarning(const std::string& m){Write(@"WARN",m);} void logError(const std::string& m){Write(@"ERROR",m);} }
