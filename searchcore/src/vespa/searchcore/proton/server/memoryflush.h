// Copyright 2016 Yahoo Inc. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.
#pragma once

#include <boost/utility.hpp>
#include <vespa/searchcore/proton/flushengine/iflushstrategy.h>
#include <vespa/vespalib/util/sync.h>
#include <vespa/vespalib/stllike/string.h>
#include <map>

namespace proton {

class MemoryFlush : public boost::noncopyable,
                    public IFlushStrategy
{
public:
    struct Config
    {
        /// Global maxMemory
        uint64_t          maxGlobalMemory;
        /// Maximum global tls size.
        uint64_t          maxGlobalTlsSize;
        /// Maximum global disk bloat factor. When this limit is reached
        /// flush is forced.
        double            globalDiskBloatFactor;
        /// Maximum memory saved. When this limit is reached flush is forced.
        int64_t           maxMemoryGain;
        /// Maximum disk bloat factor. When this limit is reached
        /// flush is forced.
        double            diskBloatFactor;
        /// Maximum count of what a target can have outstanding in the TLS.
        int64_t           maxSerialGain;
        /// Maximum age of unflushed data.
        fastos::TimeStamp maxTimeGain;
        Config();
        Config(uint64_t maxGlobalMemory_in,
               uint64_t maxGlobalTlsSize_in,
               double globalDiskBloatFactor_in,
               uint64_t maxMemoryGain_in,
               double diskBloatFactor_in,
               uint64_t maxSerialGain_in,
               fastos::TimeStamp maxTimeGain_in);
    };

private:
    /// Needed as flushDone is called in different context from the rest
    vespalib::Lock     _lock;
    Config             _config;
    /// The time when the strategy was started.
    fastos::TimeStamp  _startTime;

    enum OrderType { DEFAULT, MAXAGE, MAXSERIAL, DISKBLOAT, TLSSIZE, MEMORY };
    class CompareTarget
    {
    public:
        CompareTarget(OrderType order,
                      const flushengine::TlsStatsMap &tlsStatsMap)
            : _order(order),
              _tlsStatsMap(tlsStatsMap)
        {
        }

        bool
        operator ()(const FlushContext::SP &lfc,
                    const FlushContext::SP &rfc) const;
    private:

        OrderType     _order;
        const flushengine::TlsStatsMap &_tlsStatsMap;
    };

public:
    using SP = std::shared_ptr<MemoryFlush>;

    MemoryFlush();

    MemoryFlush(const Config &config,
                fastos::TimeStamp startTime = fastos::TimeStamp(fastos::ClockSystem::now()));

    // Implements IFlushStrategy
    virtual FlushContext::List
    getFlushTargets(const FlushContext::List &targetList,
                    const flushengine::TlsStatsMap &
                    tlsStatsMap) const override;

    void setConfig(const Config &config);
    Config getConfig() const;
};

} // namespace proton

