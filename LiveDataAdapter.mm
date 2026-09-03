#import "LiveDataAdapter.h"
#include "SharedMemoryWriter.h"
#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <fcntl.h>
#include <map>
#include <memory>
#include <mutex>
#include <sys/mman.h>
#include <sys/stat.h>
#include <thread>
#include <unistd.h>

static NSError *LiveError(NSString *s){return [NSError errorWithDomain:@"PoolLiveData" code:1 userInfo:@{NSLocalizedDescriptionKey:s}];}
static uint64_t LiveNowMs(){return (uint64_t)std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count();}
@interface LiveDataAdapter(){std::mutex _mutex;std::thread _thread;std::atomic<bool> _running;std::atomic<bool> _available;std::atomic<uint64_t> _lastReceiveMs;NSString *_name;NSUInteger _bufferSize;NSUInteger _staleAfterMs;void *_mapping;int _fd;ShotResultSnapshot *_latest;}@end
@implementation LiveDataAdapter
+(instancetype)sharedAdapter{static LiveDataAdapter*a;static dispatch_once_t once;dispatch_once(&once,^{a=[LiveDataAdapter new];});return a;}
-(instancetype)init{if((self=[super init])){_running=false;_available=false;_lastReceiveMs=0;_staleAfterMs=1000;_mapping=nullptr;_fd=-1;_bufferSize=sizeof(PoolLive::TrajectoryFrame);}return self;}
-(BOOL)configureWithDictionary:(NSDictionary*)dictionary error:(NSError**)error{NSDictionary*d=dictionary[@"LiveData"];if(![d isKindOfClass:NSDictionary.class]){if(error)*error=LiveError(@"Missing LiveData dictionary");return NO;}NSString*n=d[@"sharedMemoryName"];NSNumber*s=d[@"bufferSize"];if(![n isKindOfClass:NSString.class]||!s){if(error)*error=LiveError(@"LiveData requires sharedMemoryName and bufferSize");return NO;}if(_running)[self stopReading];_name=[n copy];_bufferSize=MAX((NSUInteger)s.unsignedIntegerValue,sizeof(PoolLive::TrajectoryFrame));_staleAfterMs=MAX((NSUInteger)[d[@"staleAfterMilliseconds"] unsignedIntegerValue],(NSUInteger)1);return YES;}
-(void)startReading{if(_running.exchange(true))return;_thread=std::thread([self]{[self readLoop];});}
-(void)stopReading{if(!_running.exchange(false))return;if(_thread.joinable())_thread.join();if(_mapping){munmap(_mapping,_bufferSize);_mapping=nullptr;}if(_fd>=0){close(_fd);_fd=-1;}_available=false;}
-(BOOL)isLiveDataAvailable{return _available.load()&&LiveNowMs()-_lastReceiveMs.load()<=_staleAfterMs;}
-(ShotResultSnapshot*)getLatestSnapshot{if(![self isLiveDataAvailable])return [[ShotResultSnapshot alloc]initWithBalls:@[] pocketedBallIndices:@[] pocketStatus:@[] shotState:NO settled:NO duration:0 collisionCount:0];std::lock_guard<std::mutex>g(_mutex);return _latest?[_latest copy]:[[ShotResultSnapshot alloc]initWithBalls:@[] pocketedBallIndices:@[] pocketStatus:@[] shotState:NO settled:NO duration:0 collisionCount:0];}
-(void)readLoop{while(_running){if(!_mapping){_fd=shm_open(_name.UTF8String,O_RDONLY,0600);if(_fd<0){std::this_thread::sleep_for(std::chrono::milliseconds(100));continue;}_mapping=mmap(nullptr,_bufferSize,PROT_READ,MAP_SHARED,_fd,0);if(_mapping==MAP_FAILED){_mapping=nullptr;close(_fd);_fd=-1;std::this_thread::sleep_for(std::chrono::milliseconds(100));continue;}}
        auto*frame=static_cast<const PoolLive::TrajectoryFrame*>(_mapping);PoolLive::TrajectoryFrame copy{};uint64_t before=__atomic_load_n(&frame->sequence,__ATOMIC_ACQUIRE);if(before&&!(before&1)&&frame->magic==PoolLive::kMagic&&frame->version==PoolLive::kVersion){std::memcpy(&copy,frame,sizeof(copy));uint64_t after=__atomic_load_n(&frame->sequence,__ATOMIC_ACQUIRE);if(before==after&&!(after&1)){NSMutableArray*balls=[NSMutableArray array];uint32_t count=std::min(copy.ballCount,PoolLive::kMaxBalls);for(uint32_t i=0;i<count;++i){uint32_t points=std::min(copy.positionCounts[i],PoolLive::kMaxPositions);NSMutableArray*positions=[NSMutableArray arrayWithCapacity:points];for(uint32_t j=0;j<points;++j)[positions addObject:[NSValue valueWithCGPoint:CGPointMake(copy.positions[i][j][0],copy.positions[i][j][1])]];CGPoint predicted=CGPointMake(copy.predictedPositions[i][0],copy.predictedPositions[i][1]);if(points&&copy.predictedPositions[i][0]==0&&copy.predictedPositions[i][1]==0)predicted=positions.lastObject.CGPointValue;[balls addObject:[[BallTrajectorySnapshot alloc]initWithIndex:i positions:positions predictedPosition:predicted onTable:copy.onTable[i]!=0]];}NSMutableArray*status=[NSMutableArray arrayWithCapacity:6];for(int i=0;i<6;++i)[status addObject:@(copy.pocketStatus[i]!=0)];ShotResultSnapshot*s=[[ShotResultSnapshot alloc]initWithBalls:balls pocketedBallIndices:@[] pocketStatus:status shotState:copy.shotState!=0 settled:YES duration:0 collisionCount:0];{std::lock_guard<std::mutex>g(_mutex);_latest=s;}_lastReceiveMs=LiveNowMs();_available=true;}}std::this_thread::sleep_for(std::chrono::milliseconds(8));}}
-(void)dealloc{[self stopReading];}
@end
