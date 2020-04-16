ruleset driver_manager {
  meta {
    logging on
    shares child_sensors, __testing
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = {"queries": [ {"name": "__testing"}, {"name": "child_sensors" }],
                "events": [{ "domain": "sensor", "type": "new_sensor", "attrs": ["name"]},
                  {"domain": "sensor", "type": "unneeded_sensor", "attrs": ["name"]},
                  {"domain": "sensor", "type": "set_process", "attrs": ["status"]},
                  {"domain": "sensor", "type": "reset"}]}
    child_sensors = function() {
      sensors = ent:child_sensors.defaultsTo({})
      sensors
    }
    setup_child = defaction(eci) {
      every {
        // start gossip node heartbeat once child has been initialized
        event:send({"eci": eci, "eid": "start_heartbeat", "domain": "gossip",
          "type": "heartbeat"})
        // refer driver to registry
        event:send({"eci": eci, "eid": "refer_registry", "domain": "gossip",
          "type": "registration_referral"})
      }
    }
  }
