// click on a ruleset name to see its source here

ruleset io.picolabs.twilio_v2 {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms,
        messages
  }
 
  global {
    
    messages = defaction(pageSize, from, to) {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json>>
      base_url = pageSize == null => base_url + "?PageSize=50" | base_url + <<?PageSize=#{pageSize}>>
      base_url = from == null => base_url | base_url + <<&From=#{from}>>
      base_url = to == null => base_url | base_url + <<&To=#{to}>>
      log = base_url.klog("get; ")
      test = http:get(base_url){"content"}.decode()
      send_directive("results", test)
    }
    
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/Messages.json>>.klog("our passed in name: ")
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }
    
    
  }
}
