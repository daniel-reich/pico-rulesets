ruleset sensor_profile {
  meta {
    shares
      profile
  }
  global {
    profile = function() {
     return ent:profile
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
