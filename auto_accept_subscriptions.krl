ruleset auto_accept_subscriptions {
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre
    {
      log = event:attr("eci").klog("Accepted")
    }
    fired {
      raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }
}
