// click on a ruleset name to see its source here
ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias Wrangler
    use module io.picolabs.subscription alias Subscriptions
    shares
      sensors,
      all_temps
  }
  global {
    nameFromID = function(sensor_id) {
      "Sensor " + sensor_id + " Pico"
    }
    sensors = function() {
      return ent:sensors
    }
    all_temps = function() {
      test = Subscriptions:established("Tx_role","subscribed_sensor").klog("I NEED THIS:")
      return Subscriptions:established("Tx_role","subscribed_sensor").map(function(v) { Wrangler:skyQuery(v{"Tx"},"temperature_store","temperatures",args) })
    }
    defaultThreshold = 95
  }
  rule create_sensor {
    select when sensor new_sensor
    pre {
      sensor_id = event:attr("sensor_id")
      exists = ent:sensors[sensor_id]
      eci = meta:eci
    }
    if exists != null then
      send_directive("sensor_ready", {"sensor_id":sensor_id})
    notfired {
      
      raise wrangler event "child_creation"
      attributes { "sensor_id": sensor_id, "name": nameFromID(sensor_id), "color": "#ffff00", "rids": ["auto_accept_subscriptions","temperature_store", "wovyn_base", "sensor_profile"] }
    }
  }
  
  rule store_new_section {
    select when wrangler child_initialized
    pre {
      sensor_id = event:attr("sensor_id")
    }
    if sensor_id.klog("found sensor_id")
    then
      event:send({ 
          "eci": event:attr("eci"), "eid": "update-profile",
          "domain": "sensor", "type": "profile_updated",
          "attrs": {
            "name": event:attr("name"),
            "location": "hello",
            "contactNumber": "88888888",
            "threshold": defaultThreshold
          }
      })
      
    fired {
      ent:sensors := ent:sensors.defaultsTo({}).put(event:attr("sensor_id"), event:attr("eci")).klog("HHH");
      //ent:sensors{[sensor_id]} := sensor
    }
  }
  
  rule initialize_subscription {
    select when wrangler child_initialized
    pre
    {
      sensor_id = event:attr("sensor_id").klog("Found sensor id in subscription rule")
      waht = event:attrs.klog("!!!!!")
    }
    event:send(
      { "eci": meta:eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": "Sensor" + sensor_id,
                   "Rx_role": "sensor_manager",
                   "Tx_role": "subscribed_sensor",
                   "channel_type": "subscription",
                   "wellKnown_Tx": event:attr("eci") } } )
  }
  
  rule add_subscription {
    select when subscribe add_sensor
    pre {
      sensor_id = event:attr("sensor_id").klog("HERE")
      eci = event:attr("eci").klog("HERE")
    }
    event:send(
      { "eci": meta:eci, "eid": "subscription",
        "domain": "wrangler", "type": "subscription",
        "attrs": { "name": "Sensor" + sensor_id,
                   "Rx_role": "sensor_manager",
                   "Tx_role": "subscribed_sensor",
                   "channel_type": "subscription",
                   "wellKnown_Tx": eci } } )
  }
  
  rule unneeded_sensor {
    select when sensor delete
    pre {
      sensor_id = event:attr("sensor_id")
      exists = ent:sensors.get([sensor_id])
      child_to_delete = nameFromID(sensor_id)
    }
    if exists then
      send_directive("deleting_section", {"sensor_id":sensor_id})
    fired {
      raise wrangler event "child_deletion"
        attributes {"name": child_to_delete};
      ent:sensors := ent:sensors.delete(sensor_id).klog("WHATE")
    }
  }
}
