ruleset registry {
  meta {
    logging on
    shares registered_drivers, __testing
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias Subscriptions
  }
  global {
    __testing = {"queries": [
                  {"name": "registered_drivers"}],
                "events": [
                  {"domain": "registry", "type": "driver_registration", "attrs":
                    ["driver_Rx", "driver_wellKnown_Rx"]},
                  {"domain": "registry", "type": "driver_disconnection", "attrs":
                    ["driver_Rx"]}]}
    registered_drivers = function() {
      drivers = ent:registered_drivers.defaultsTo({})
      drivers
    }
  }
  /*
  // one-time scheduled health check event dependent on continued activity
  */
  // raised by drivers
  rule driver_registered {
    select when registry driver_registration
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
      driver_wellKnown_Rx = event:attrs.get("driver_wellKnown_Rx")
      // time = time:strftime(time:now(), "%c")
    }
    noop()
    fired{
      ent:registered_drivers := registered_drivers().put(driver_Rx, driver_wellKnown_Rx)
      // update other registries
      schedule wrangler event "send_event_on_subs" at time:add(time:now(), {"seconds": 3}) attributes {
        "domain": "registry",
        "type": "add_update",
        "Rx_role": "registry",
        "attrs": {"driver_Rx": driver_Rx, "driver_wellKnown_Rx": driver_wellKnown_Rx}
      }
      /*
      // schedule first one-time scheduled health check event
      */
      // send driver_Rx peers to connect to
      raise registry event "registration_response" attributes {"driver_Rx": driver_Rx}
      raise registry event "color_updated"
    }
  }
  rule registration_responded {
    select when registry registration_response
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
      all_other_drivers = (registered_drivers().delete(driver_Rx))
        // .klog("Map of Possible First Peers: ")
      find_one = (all_other_drivers.length() > 0)
        // .klog("Find One Peer?: ")
      find_exactly_one = (all_other_drivers.length() == 1)
        // .klog("Find Exactly One Peer?: ")
      first_random_integer = find_one => random:integer(all_other_drivers.length() - 1) | 0
      first_peer = (find_one =>
        (find_exactly_one =>
          all_other_drivers |
          all_other_drivers.filter(function(v,k) {k == (all_other_drivers.keys()[first_random_integer]).klog("Random Key: ")}).klog("Filtered Map: ")) |
        {})
         // .klog("First Peer Map: ")
      final_drivers = (find_one =>
        all_other_drivers.delete(first_peer.keys().head()) | {})
        // .klog("Map of Possible Second Peers: ")
      find_two = (final_drivers.length() > 0)
        // .klog("Find Two Peers?: ")
      find_exactly_two = (final_drivers.length() == 1)
        // .klog("Find Exactly Two Peers?: ")
      second_random_integer = find_two => random:integer(final_drivers.length() - 1) | 0
      second_peer = (find_two =>
        (find_exactly_two =>
          final_drivers |
          final_drivers.filter(function(v,k) {k == (final_drivers.keys()[second_random_integer]).klog("Random Key: ")}).klog("Filtered Map: ")) |
        {})
        // .klog("Second Peer Map: ")
      all_peers = (first_peer.put(second_peer))
        // .klog("Map of All Peers: ")
      at_least_one_peer = (all_peers.length() > 0)
        // .klog("Find at Least One Peer?: ")
      two_peers = (all_peers.length() == 2)
        // .klog("Find Two Peers?: ")
    }
    noop()
    fired {
      raise registry event "send_peer" attributes
        {"eci": driver_Rx, "eid": "connect_peer", "domain": "gossip",
        "type": "subscription_requested", "attrs":
          {"wellKnown_Tx": first_peer.values().head()}}
        if at_least_one_peer
      raise registry event "send_peer" attributes
        {"eci": driver_Rx, "eid": "connect_peer", "domain": "gossip",
        "type": "subscription_requested", "attrs":
          {"wellKnown_Tx": second_peer.values().head()}}
        if two_peers
    }
  }
  rule gateway_request {
    select when registry request_gateway
    pre {
      store_Rx = event:attrs.get("store_Rx")
      // all_other_drivers = (registered_drivers().delete(driver_Rx))
        // .klog("Map of Possible First Peers: ")
      all_other_drivers = registered_drivers()
      find_one = (all_other_drivers.length() > 0)
        // .klog("Find One Peer?: ")
      find_exactly_one = (all_other_drivers.length() == 1)
        // .klog("Find Exactly One Peer?: ")
      first_random_integer = find_one => random:integer(all_other_drivers.length() - 1) | 0
      first_peer = (find_one =>
        (find_exactly_one =>
          all_other_drivers |
          all_other_drivers.filter(function(v,k) {k == (all_other_drivers.keys()[first_random_integer]).klog("Random Key: ")}).klog("Filtered Map: ")) |
        {})
         .klog("Gateway Map: ")
       first_peer_Rx = (find_one => first_peer.keys().head() | "No peer_Rx")
        .klog("Gateway Rx:")
      send_peer_attrs = {"eci": store_Rx, "eid": "gateway_response",
        "domain": "order", "type": "gateway_response", "attrs":
          {"orderID": event:attrs.get("orderID"), "gateway_Rx": first_peer_Rx}}
    }
    noop()
    fired {
      raise registry event "send_peer" attributes send_peer_attrs if find_one
    }
  }
  rule peer_send {
    select when registry send_peer
    pre {
      attrs = event:attrs
    }
    event:send(attrs)
  }
  //raised by other registries
  rule driver_added {
    select when registry add_update
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
      driver_wellKnown_Rx = event:attrs.get("driver_wellKnown_Rx")
      // time = event:attrs.get("time")
    }
    noop()
    fired {
      ent:registered_drivers := registered_drivers().put(driver_Rx, driver_wellKnown_Rx)
      raise registry event "color_updated"
    }
  }
  // raised by drivers
  rule driver_disconnected {
    select when registry driver_disconnection
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
    }
    noop()
    fired {
      ent:registered_drivers := registered_drivers().delete(driver_Rx)
      // update other registries
      schedule wrangler event "send_event_on_subs" at time:add(time:now(), {"seconds": 3}) attributes {
        "domain": "registry",
        "type": "remove_update",
        "Rx_role": "registry",
        "attrs": {"driver_Rx": driver_Rx}
      }
      raise registry event "color_updated"
    }
  }
  //raised by other registries
  rule driver_removed {
    select when registry remove_update
    pre {
      driver_Rx = event:attrs.get("driver_Rx")
    }
    noop()
    fired {
      ent:registered_drivers := registered_drivers().delete(driver_Rx)
      raise registry event "color_updated"
    }
  }
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    noop()
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  rule update_color {
    select when registry color_updated
    pre {
      node_Tx = wrangler:myself().get("eci")
      registered_drivers_string = registered_drivers().encode()
      info_hash = math:hash("sha256", registered_drivers_string)
      color = "#" + info_hash.substr(0,6).defaultsTo("87cefa")
      dname = wrangler:myself(){"name"}
      attrs = {"color": color, "dname": dname}
    }
    send_directive("Update color", {"node_Tx": node_Tx, "color": color})
    fired {
      raise visual event "update" attributes attrs
    }
  }
}
