ruleset wovyn_base {
  meta {
    use module sensor_profile
    use module io.picolabs.subscription alias Subscriptions
    use module temperature_store
  }
  global {
    alert_destination = 18019999
    alert_origin = 18011111
    createRumorEvent = function() {
      data = getFurthestBehind()
      return { "eci": meta:eci, "eid": "gossip_rumor",
        "domain": "gossip", "type": "rumor",
        "attrs": { "picoId": meta:picoId,
                   "rumor": data["rumor"],
                   "Rx_role": "node",
                   "Tx_role": "node",
                   "channel_type": "subscription",
                   "wellKnown_Tx": ent:submap[data["node"]] } } 
    }
    createSeenEvent = function() {
      subscribed = Subscriptions:established("Tx_role","node").length() - 1
      rand = random:integer(subscribed).klog("RANDOM")
      sibling = Subscriptions:established("Tx_role","node")[rand].klog("SIBLING")
      return { "eci": meta:eci, "eid": "gossip_seen",
        "domain": "gossip", "type": "seen",
        "attrs": { "picoId": meta:picoId,
                   "seen": getMySeen(),
                   "Rx_role": "node",
                   "Tx_role": "node",
                   "channel_type": "subscription",
                   "wellKnown_Tx": sibling{"Tx"},
                   "saveRx": sibling{"Rx"}} }
    }
    findSeenDifference = function(siblingSeen) {
      difference = ent:seen.map(function(v,k) { v + 1 - ((siblingSeen[k].defaultsTo(0) + 1))  })
      needToShare = difference.filter(function(v,k) { v > 0 })
      needToShareKeys = needToShare.map(function(v,k) {k})
      rumors = needToShareKeys.length() > 0 => ent:knownRumors{needToShareKeys[0]} | null
      return rumors
    }
    getMaxConsecutive = function(array) {
      sorted = array.map(function(i) { i.as("Number")} ).sort()
      numbers = 0.range(array.length()-1)
      consecutive = numbers.reduce(function(a,i) {
          a.append(sorted[i] == i  => i | 0)
        }, [])
      consecutive.reduce(function(a,i) { a = i > a => i | a return a}, 0)
    }
    getMySeen = function() {
      ent:knownRumors.map(function(v,k) { getMaxConsecutive(v.keys()) }).klog("MINE")
    }
    getFurthestBehind = function() {
      subscribed = ent:submap.keys().klog("!!!!!!")
      test = ent:siblingSeen
      test2 = subscribed.reduce(function(a,x) { a = a + x return a },"").klog("WHY BOT WORKING")
      highest = subscribed.reduce(function(a,i) { a.put(largestDifference(ent:siblingSeen[i.klog("IIIII")], i)) }, {})
      max = highest.keys().reduce(function(a,i) { a = i > a => i | a return a}, 0)
      highest[max]
    }
    largestDifference = function(rumors, node) {
      difference = getMySeen().map(function(v,k){ (v + 1) - (rumors[k.klog("??????")].klog("WHAT") == null => 0 | rumors[k] + 1)}).klog("HERRRE")
      max = difference.values().reduce(function(a,i) { a = i > a => i | a return a}, 0)
      highest = difference.filter(function(v,k) {v == max})
      return {}.put([max], {"target": node, "next": highest.keys()[0]}).klog("EUUFEDF")
    }
  }
  
  rule intialization {
    select when wovyn initialize
    pre {
      test = getFurthestBehind().klog("AAAAAND")
    }
    //event:send(createSeenEvent())
    fired {
      
      //ent:knownRumors := Subscriptions:established("Tx_role","node").map(function(v) { return [] })
      ent:knownRumors := {"id1" : {"1": "stuff", "0":"hello"}, "id2": {"0":"hello"}, "id7":{"1": "stuff", "0":"hello", "2":"sup"}}
      ent:mySeen := {}
      ent:siblingSeen := {"id1" : {"id1" : 1, "id2": 0, "id7":24}, "id2": {"id2": 0}}
      ent:rumorsSent := 0
      ent:submap := {"id1":"hello", "id2":"hello"} 
    }
}

rule gossip_seen {
  select when gossip seen
  pre {
    id = event:attrs["picoId"]
    eci = Subscriptions:established("Tx_role","node").filter(function (v,k) { v{"id"} == id})[0]
    seen = event:attrs["seen"]
    test= event:attrs.klog("MY ONLY HOPE")
    rx = event:attrs["saveRx"]
    
    //rumors = findSeenDifference(seen).klog("DIFFERENCE")
   
  }
  // if (rumors != null) then
  //   event:send({ "eci": meta:eci, "eid": "subscription",
  //       "domain": "wrangler", "type": "subscription",
  //       "attrs": {
  //                 "rumors": rumors,
  //                 "Rx_role": "node",
  //                 "Tx_role": "node",
  //                 "channel_type": "subscription",
  //                 "wellKnown_Tx": eci } } )
  always {
    ent:submap{id} := rx
    ent:siblingSeen{id} := ent:siblingSeen.put([id], seen).klog("BOOOYAH")
  }
  
}

rule gossip_rumor {
  select when gossip rumor
  foreach event:attrs["rumors"] setting (x, i)
  always {
    ent:rumors := ent:rumors[event:attrs["id"]].put(x)
  }
}
  
  rule schedule_gossip_heartbeat {
    select when wovyn schedule_gossip
    if (event:attrs["seconds"] > 0) then
      send_directive("gossip frequency changed")
    fired {
      ent:gossip_frequency := event:attrs["seconds"]
      schedule wovyn event "gossip_heartbeat" at time:add(
        time:now(), { "seconds": event:attrs["seconds"] })
    } else {
      ent:gossip_frequency := 0
    }
  }
  
rule gossip_heartbeat {
  select when wovyn gossip_heartbeat
  pre {
    process = true
    //event = random:integer(1) > 0 => getGossipEvent() | shareSeen()
    log1 = ent:myRumors.klog("myRumors: ")
    log2 = ent:siblingRumors.klog("siblingRumors: ")
    log3 = ent:mySeen.klog("mySeen: ")
    log4 = ent:siblingSeen.klog("siblingSeen: ")
  }
  if (process) then
    send_directive("hello")
    //event:send(event)
  fired {
    ent:siblingRumors := Subscriptions:established("Tx_role","node").map(function(v, k) { return {}.put([v{"Tx"}], v) })
  }
  finally {
    raise wovyn event "schedule_gossip" attributes {"seconds": ent:gossip_frequency }
  }
  
}

  rule add_subscription {
    select when wovyn add_sibling
    pre {
      sensor_id = event:attr("sensor_id").klog("HERE")
      eci = event:attr("eci").klog("HERE")
    }
    event:send(
      { "eci": meta:eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": "Sensor" + sensor_id,
                   "Rx_role": "node",
                   "Tx_role": "node",
                   "channel_type": "subscription",
                   "wellKnown_Tx": eci } } )
  }
   
  rule process_heartbeat {
    select when wovyn heartbeat
    if event:attrs["genericThing"] then
      send_directive("body", event:attrs)
    fired {
      atrs = event:attrs
        .put({"temperature": event:attrs["genericThing"]["data"]["temperature"][0]["temperatureF"]})
        .put({"time": time:now()})
        .klog("Heartbeat Attributes: ")
      raise wovyn event "new_temperature_reading"
      attributes atrs
    }
  }
  
  rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attrs["temperature"].klog("Temperature: ") 
    }
    send_directive("high_temps", {"Threshold Reached": event:attrs["temperature"] > sensor_profile:getThreshold()} )
      
    fired {
      raise wovyn event "threshold_violation"
      attributes event:attrs if (event:attrs["temperature"] > sensor_profile:getThreshold())
    } 
  }
  
  rule threshold_notification {
    select when wovyn threshold_violation
    foreach Subscriptions:established("Tx_role","sensor_manager") setting (v, i)
    pre {
      log = "<- Sent SMS to this number".klog(sensor_profile:getContactNumber())
      contact = sensor_profile:getContactNumber
      eci = v{"Tx"}.klog("IS THIS IT???")
    }
    
    event:send(
      { "eci": v{"Tx"}, "eid": "threshold_violated",
        "domain": "sensor", "type": "threshold_violated" }
    )
  }
  
  rule report_requested {
    select when wovyn report_async
    pre { 
      role = event:attrs["Rx_role"]
      eci = event:attrs["eci"]
      correlation_id = event:attrs["correlation_id"].klog("REQUEST RECEIVED WITH CORRELATION ID ")
    }
    if (role == "sensor_manager") then
    event:send(
      { "eci": eci, "eid": "gather_report",
        "domain": "sensor", "type": "reporting", 
        "attrs": {
          "correlation_id": correlation_id,
          "eci": meta:eci,
          "latest_temperature": temperature_store:temperatures()[temperature_store:temperatures().length()-1]
        }
      })
  }
}
