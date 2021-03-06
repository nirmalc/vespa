// Copyright 2017 Yahoo Holdings. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

#pragma once

#include <vespa/vespalib/net/state_api.h>
#include <vespa/vespalib/net/simple_metrics_producer.h>
#include <vespa/vespalib/net/simple_health_producer.h>
#include <vespa/vespalib/net/simple_component_config_producer.h>

namespace config {
namespace sentinel {

struct StateApi {
    vespalib::string host_and_port;
    vespalib::SimpleHealthProducer myHealth;
    vespalib::SimpleMetricsProducer myMetrics;
    vespalib::SimpleComponentConfigProducer myComponents;
    vespalib::StateApi myStateApi;

    StateApi() : myStateApi(myHealth, myMetrics, myComponents) {}

    vespalib::string get(const char *path) const;
    void bound(int port);
};

} // namespace config::sentinel
} // namespace config
