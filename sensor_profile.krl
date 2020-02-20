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
        "name": event:attrs["name"],
        "location": event:attrs["location"],
        "contactNumber": event:attrs["contactNumber"],
        "threshold": event:attrs["threshold"]
      }
    }
  }
}
