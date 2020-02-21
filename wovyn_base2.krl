ruleset wovyn_base {
  meta {
    use module io.picolabs.lesson_keys
    use module io.picolabs.twilio_v2 alias twilio
        with account_sid = keys:testing{"account_sid"}
            auth_token =  keys:testing{"auth_token"}
    use module sensor_profile
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
    pre {
      log = "<- Sent SMS to this number".klog(sensor_profile:getContactNumber())
      contact = sensor_profile:getContactNumber
    }
    twilio:send_sms(contact,
                    alert_origin,
                    "THE TEMPERATURE THRESHOLD HAS BEEN EXCEEDED!!"
                  )
  }
}
