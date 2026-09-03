#include "SharedMemoryWriter.h"
#include <algorithm>
#include <cstring>
#include <utility>
#ifdef _WIN32
#include <windows.h>
#else
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#endif
namespace PoolLive {
SharedMemoryWriter::SharedMemoryWriter(std::string n,std::size_t s):name_(std::move(n)),bufferSize_(std::max(s,sizeof(TrajectoryFrame))){}
SharedMemoryWriter::~SharedMemoryWriter(){close();}
bool SharedMemoryWriter::open(){
#ifdef _WIN32
    (void)name_; return false;
#else
    if(isOpen())return true; fd_=shm_open(name_.c_str(),O_CREAT|O_RDWR,0600);if(fd_<0)return false;if(ftruncate(fd_,(off_t)bufferSize_)!=0){::close(fd_);fd_=-1;return false;}mapping_=mmap(nullptr,bufferSize_,PROT_READ|PROT_WRITE,MAP_SHARED,fd_,0);if(mapping_==MAP_FAILED){mapping_=nullptr;::close(fd_);fd_=-1;return false;}std::memset(mapping_,0,bufferSize_);return true;
#endif
}
void SharedMemoryWriter::close(){
#ifdef _WIN32
#else
    if(mapping_){munmap(mapping_,bufferSize_);mapping_=nullptr;}if(fd_>=0){::close(fd_);fd_=-1;}
#endif
}
bool SharedMemoryWriter::isOpen()const{return mapping_!=nullptr;}
bool SharedMemoryWriter::writeFrame(const TrajectoryFrame&input){if(!isOpen()||input.magic!=kMagic||input.version!=kVersion)return false;auto*out=static_cast<TrajectoryFrame*>(mapping_);uint64_t old=__atomic_load_n(&out->sequence,__ATOMIC_ACQUIRE);uint64_t begin=(old%2)?old+1:old+1;__atomic_store_n(&out->sequence,begin,__ATOMIC_RELEASE);TrajectoryFrame copy=input;copy.sequence=begin;std::memcpy(out,&copy,sizeof(copy));__atomic_store_n(&out->sequence,begin+1,__ATOMIC_RELEASE);return true;}
}
