// click on a ruleset name to see its source here
ruleset driver {
  
  meta {
    use module distance
  }
  
  rule intialization {
    select when driver initialize
    send_directive("initialize")
    fired {
      ent:gossiped := []
      ent:contract := { }
      ent:location := { "lat": 0, "lon": 0 }
      ent:underContract := false
    }
  }
  
  rule register {
    select when driver register 
    pre {
      eci = event:attr("registry_eci") // Must be sent in when raising this event (Body of POST request)
    }
    event:send({ 
        // make sure this event is actually being sent to a real rule
        // (check the eid, domain and type values in registry ruleset)
        "eci": eci, "eid": "register_driver", "domain": "register", 
        "type": "add_driver","attrs": {"eci":meta:eci}
      } )
      // Any more contact info I need to pass?
      // make sure registry calls add_siblings rule after receiving this registration
  }
  
  rule add_siblings {
    select when driver add_siblings 
    // make sure registry is actually sending "drivers": [ ... list of drivers ]
    foreach event:attr("drivers") setting (sibling, i)
    event:send(
      { "eci": meta:eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": "Registry/Driver Subscription",
                   "Rx_role": "node",
                   "Tx_role": "node",
                   "channel_type": "subscription",
                   "wellKnown_Tx": sibling["eci"] } 
      } )
  }
  
  rule receive_bid {
    select when driver receive_bid
    pre {
      bid_id = event:attrs["id"] // make sure store is sending this, needs to be unique (generate uuid)
      eci = event:attrs["store_eci"] // make sure store is sending this
    }
    if (ent:gossiped.index(bid_id) < 0) then
    event:send({ 
          // make sure this event is actually being sent to a real rule
          // (check the eid, domain and type values in store ruleset)
          "eci": event:attr("eci"), "eid": "send_bid", 
          "domain": "store", "type": "send_bid",
          "attrs": {
            // bid attrs.
            // { "eci": meta:eci,
            //   "distance": distance.getDistance(ent:location["lat"]
            //                                    ent:location["long"]
            //                                    event:attrs["lat"]
            //                                    event:attrs["long"])
          }
      })
    fired {
      ent:gossiped := ent:gossiped.append(bid_id)
      raise driver event "gossip_bid" attributes event:attrs
    }
  }
  
  rule gossip_bid {
    select when driver gossip_bid
    foreach Subscriptions:established("Tx_role","node") setting (sibling, i)
      event:send({ 
        "eci": sibling{"Tx"}, "eid": "receive_bid", "domain": "driver", 
        "type": "receive_bid","attrs": event:attrs
      }
    )
  }
  
  // rule accept_contract {
  //   if (ent:underContract) then
    
  // }
  
  rule update_location {
    select when driver update_location
    pre {
      lat = event:attr{"lat"}
      long = event:attr{"long"}
    }
    always {
      ent:location := {"lat":lat, "long":long}
    }
  }
  
}
