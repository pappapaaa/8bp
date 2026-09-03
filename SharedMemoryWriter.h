#pragma once
#include <cstddef>
#include <cstdint>
#include <string>

namespace PoolLive {
constexpr uint32_t kMagic = 0x504F4F4Cu; // POOL
constexpr uint32_t kVersion = 1;
constexpr uint32_t kMaxBalls = 16;
constexpr uint32_t kMaxPositions = 480;
constexpr uint32_t kPocketCount = 6;

#pragma pack(push, 1)
struct TrajectoryFrame {
    uint32_t magic;
    uint32_t version;
    uint64_t sequence; // odd while being written, even when stable
    uint64_t timestampNanoseconds;
    uint32_t ballCount;
    uint32_t positionCounts[kMaxBalls];
    float positions[kMaxBalls][kMaxPositions][2];
    float predictedPositions[kMaxBalls][2];
    uint8_t onTable[kMaxBalls];
    uint8_t pocketStatus[kPocketCount];
    uint8_t shotState;
    uint8_t reserved[7];
};
#pragma pack(pop)

static_assert(sizeof(TrajectoryFrame) <= 65536, "TrajectoryFrame exceeds the default shared buffer");

class SharedMemoryWriter {
public:
    explicit SharedMemoryWriter(std::string name, std::size_t bufferSize = sizeof(TrajectoryFrame));
    ~SharedMemoryWriter();
    bool open();
    void close();
    bool isOpen() const;
    bool writeFrame(const TrajectoryFrame& frame);
private:
    std::string name_;
    std::size_t bufferSize_;
    int fd_ = -1;
    void* mapping_ = nullptr;
};
}
