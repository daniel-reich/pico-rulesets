ruleset wovyn_base {
  meta {
    use module sensor_profile
    use module io.picolabs.subscription alias Subscriptions
    use module temperature_store
    shares 
      getKnownRumors
  }
  global {
    alert_destination = 18019999
    alert_origin = 18011111
    createRumorEvent = function() {
      data = getFurthestBehind().klog("Furthest behind")
      current_record = ent:siblingSeen[data["target"]][data["next"]].klog("Current_RECORD")
      num = current_record.klog("is null") == null => 0 | getMaxConsecutive(current_record.keys()) + 1
      rumor = ent:knownRumors[data["next"]].klog("cool")[num]
      return ent:submap[data["target"]] == null => null |
      { "eci": ent:submap[data["target"]], "eid": "gossip_rumor",
        "domain": "gossip", "type": "rumor",
        "attrs": { "picoId": data["next"],
                   "rumor": rumor,
                   "Rx_role": "node",
                   "Tx_role": "node",
                   "channel_type": "subscription",
                   "message_origin": data["next"],
                   "message_number": num,
                   "wellKnown_Tx": ent:submap[data["target"]] } } 
    }
    createSeenEvent = function() {
      subscribed = Subscriptions:established("Tx_role","node").length() - 1
      rand = random:integer(subscribed).klog("RANDOM")
      teest =Subscriptions:established("Tx_role","node").length().klog("HOW MANY SUBS")
      sibling = Subscriptions:established("Tx_role","node").klog("ALL SUBS")[rand].klog("SIBLING")
      return { "eci": sibling{"Tx"}, "eid": "gossip_seen",
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
        }, []).klog("HERE")
      consecutive.reduce(function(a,i) { a = i > a => i | a return a}, 0)
    }
    getMySeen = function() {
      ent:knownRumors.map(function(v,k) { getMaxConsecutive(v.keys()) }).klog("MINE")
    }
    getFurthestBehind = function() {
      log = ent:siblingSeen.klog("SIBLING SEEN8")
      subscribed = ent:submap.keys().klog("BEFORE THE MIDDLE")
      highest = subscribed.reduce(function(a,i) { a.put(largestDifference(ent:siblingSeen[i], i)) }, {})
      max = highest.keys().reduce(function(a,i) { a = i > a => i | a return a}, 0)
      highest[max]
    }
    largestDifference = function(rumors, node) {
      difference = getMySeen().map(function(v,k){ (v + 1) - (rumors[k].klog("NOW THIS7") == null => 0 | rumors[k] + 1)}).klog(node + "I THINK ITS THIS ")
      max = difference.values().reduce(function(a,i) { a = i > a => i | a return a}, 0)
      highest = difference.filter(function(v,k) {v == max})
      return {}.put([max], {"target": node, "next": highest.keys()[0]})
    }
    getKnownRumors = function()
    {
      return ent:knownRumors
    }
  }
  
  rule intialization {
    select when wovyn initialize
    send_directive("initialize")
    fired {
      ent:knownRumors := {}
      ent:mySeen := {}
      ent:siblingSeen := {}
      ent:rumorsSent := 0
      ent:submap := {} 
    }
}

rule gossip_seen {
  select when gossip seen
  pre {
    id = event:attrs["picoId"].klog(meta:picoId + " RECEIVED SEEN EVENT FROM ")
    eci = Subscriptions:established("Tx_role","node").filter(function (v,k) { v{"id"} == id})[0]
    seen = event:attrs["seen"]
    rx = event:attrs["saveRx"]
  }
  always {
    ent:submap{id} := rx
    ent:siblingSeen := ent:siblingSeen.put([id], seen).klog("NEW SEEN")
  }
}

rule gossip_rumor {
  select when gossip rumor
  pre {
    from = event:attrs["picoId"].klog(meta:picoId + " received rumor from ")
    number = event:attrs["message_number"].klog("rumor number: ")
    rumor = event:attrs["rumor"]
  }
  always {
    ent:knownRumors := ent:knownRumors.put([from, number], rumor).klog()
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
    event = (random:integer(1) > 0 => createRumorEvent() | createSeenEvent()).klog(meta:picoId +" WILL SEND: ")
  }
  if (process && event != null) then
    event:send(event)
  fired {
    ent:siblingSeen := event["eid"] == "gossip_rimor" 
      => ent:siblingSeen.put([event["attrs"]["targetId"], event["attrs"]["message_origin"]], event["attrs"]["message_number"]) 
      | ent:siblingSeen
      //test = ent:siblingSeen().klog(meta:picoId + " UPDATED SILBLING SEEN")
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
    pre {
      temp = event:attrs["genericThing"]["data"]["temperature"][0]["temperatureF"]
      timestamp = time:now()
      sensor_id = event:attrs["emitterGUID"]
    }
    if event:attrs["genericThing"] then
      send_directive("body", event:attrs)
    fired {
      ent:knownRumors := ent:knownRumors.put([meta:picoId, ent:rumorsSent], { "temperature": temp, "time": timestamp, "sensorId":sensor_id })
      ent:rumorsSent := ent:rumorsSent + 1
        .put({"temperature": temp})
        .put({"time": timestamp})
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
