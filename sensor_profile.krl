ruleset sensor_profile {
  meta {
    provides 
      getThreshold
    shares
      profile
  }
  global {
    profile = function() {
     return ent:profile
   }
   getThreshold = function() {
     return ent:profile["threshold"] || 100
   }
   getContactNumber = function() {
     return ent:contactNumber || "00000000"
   }
  }
   
  rule update {
    select when sensor profile_updated
    pre {
      x = ent:profile.defaultsTo({})
      
    }
    always {
      ent:profile := clear
      ent:profile := {
        "name": event:attrs["name"] || "UNKNOWN",
        "location": event:attrs["location"] || "UNKNOWN",
        "contactNumber": event:attrs["contactNumber"] || "UNKNOWN",
        "threshold": event:attrs["threshold"] || 100
      }
    }
  }
}
