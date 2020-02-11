// click on a ruleset name to see its source here
ruleset temperature_store {
  meta {
    provides
      temperatures,
      violations,
      inrange_temperatures
    shares
      temperatures,
      violations,
      inrange_temperatures
  }
  global {
   temperatures = function() {
     return ent:temperatures
   }
   violations = function() {
     return ent:violations
   }
   inrange_temperatures = function() {
     return ent:temperatures.difference(ent:violations)
   }
  }
   
  rule collect_temperature {
    select when wovyn new_temperature_reading
    pre {
      x = ent:temperatures
    }
    always {
      ent:temperatures := ent:temperatures || []
      ent:temperatures := ent:temperatures.append({"time":<<#{event:attrs["time"]}>>, "temperature":<<#{event:attrs["temperature"]}>>}).klog("YEAH")
    }
  }
  
  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      x = ent:violations
    }
    always {
      ent:violations := ent:violations || []
      ent:violations := ent:violations.append({"time":<<#{event:attrs["time"]}>>, "temperature":<<#{event:attrs["temperature"]}>>}).klog("YEAH")
    }
  }
  
  rule clear_temperaturee {
    select when sensor reading_reset
    always {
      clear ent:temperatures
      clear ent:violations
    }
  }
}
