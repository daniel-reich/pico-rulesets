ruleset manage_sensors {
  meta {
    use module io.picolabs.wrangler alias Wrangler
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
      return ent:sensors.map(function(v,k) { Wrangler:skyQuery(v,"temperature_store","temperatures",args) })
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
  
  rule unneeded_sensor {
    select when sensor delete
    pre {
      sensor_id = event:attr("sensor_id").klog("HOORAY")
      exists = ent:sensors.get([sensor_id]).klog("HOORAY")
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
