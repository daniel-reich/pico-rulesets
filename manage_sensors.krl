ruleset manage_sensors {
  
  global {
    nameFromID = function(sensor_id) {
      "Sensor " + sensor_id + " Pico"
    }
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
      attributes { "sensor_id": sensor_id, "name": nameFromID(sensor_id), "color": "#ffff00", "rids": ["temperature_store", "wovyn_base", "sensor_profile"] }
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
            "name": "hi",
            "location": "hello",
            "contactNumber": "88888888",
            "threshold": 50.5
          }
      })
    fired {
      ent:sensors := ent:sensors.defaultsTo({}).put(event:attr("sensor_id"), event:attr("eci")).klog("HHH");
      //ent:sensors := ent:sensors.defaultsTo({});
      //ent:sensors{[sensor_id]} := sensor
    }
}
}
