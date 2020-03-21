ruleset wovyn_base {
  meta {
    use module sensor_profile
    use module io.picolabs.subscription alias Subscriptions
    use module temperature_store
  }
  global {
    alert_destination = 18019999
    alert_origin = 18011111
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
