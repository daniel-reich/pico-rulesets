ruleset store_ruleset {
    meta {
        use module io.picolabs.subscription alias Subscriptions
        use module io.picolabs.wrangler alias wrangler
        /*
        // use module **this depends on where we have api keys**
        use module twilio_v2_api alias twilio
            with account_sid = keys:twilio{"account_sid"}
            auth_token =  keys:twilio{"auth_token"}
        */
        use module twilio_api_keys
        use module twilio_api alias twilio
          with account_sid = keys:twilio{"account_sid"}
            auth_token = keys:twilio{"auth_token"}
        use module distance_api_keys
        use module distance alias dist
            with auth_token = keys:distance{"auth_token"}
        shares __testing, get_all_orders, get_bids, get_assigned_orders,
          get_completed_orders, getLocation, get_random_location
    }
    global {
        __testing = {
            "queries": [
              {"name": "get_all_orders"},
              {"name": "get_bids"},
              {"name": "get_assigned_orders"},
              {"name": "get_completed_orders"},
              {"name": "getLocation"},
              {"name": "get_random_location"}],
            "events": [
              {"domain": "order", "type": "new"},
              {"domain": "store", "type": "setLocation", "attrs":
                ["latitude", "longitude"]}]}
        getLocation = function() {
            ent:location
        }
        get_random_location = function() {
        location = {"latitude": 40.2968979 + random:number(lower = 0, upper = 1),
            "longitude":-111.69464749999997 + random:number(lower = 0, upper = 1)}
            // .klog("Random Location: ")
        location
        }
        get_assigned_orders = function() {
            ent:orders.filter(function(a) {
                not a{"assigned_driver"}.isnull() && a{"delivered_at"}.isnull();
            });
        }
        get_completed_orders = function() {
            ent:orders.filter(function(a) {
                not a{"delivered_at"}.isnull()
            });
        }
        /*
        get_driver = function() {
            subs = Subscriptions:established("Rx_role","driver").klog("Drivers:");
            // Return a random driver from this list of drivers the store knows about
            rand_sub = random:integer(subs.length() - 1);
            subs[rand_sub]
        }
        */
        order_by_id = function(orderID) {
            ent:orders{orderID}
        }
        get_all_orders = function() {
            ent:orders
        }
        get_bids = function() {
            ent:bids
        }
        getDistance = function(alat, alon, blat, blon) {
            output = dist:get_distance(alat,alon,blat,blon).klog("Store dist calculated:");
            output;
        }
        chooseBidForOrder = function(orderID) {
            filtered = ent:bids.filter(function(a){a{"orderID"} == orderID}).klog("Filtered:");
            sorted = filtered.sort(function(a, b) {
                alat = a{["driverLocation", "latitude"]};
                alon = a{["driverLocation", "longitude"]};
                blat = b{["driverLocation", "latitude"]};
                blon = b{["driverLocation", "longitude"]};
                storelat = ent:location{"latitude"};
                storelon = ent:location{"longitude"};
                a{"rating"} > b{"rating"}  => -1 |
                a{"rating"} == b{"rating"} && (getDistance(alat, alon, storelat, storelon) < getDistance(blat, blon, storelat, storelon)) =>  -1 | 1
            }).klog("Sorted:");
            sorted[0];
        }
        getRejectedBids = function(acceptedBid) {
            filtered = ent:bids.filter(function(a){
                a{"orderID"} == acceptedBid{"orderID"} && a{"driverEci"} != acceptedBid{"driverEci"}
            });
            filtered
        }
        get_registry = function() {
          registry_Rx = ent:registry_Rx.defaultsTo(
            ["HoxSRJwJPnfATNMa6gFESy", "KajeqGfUkRpHWT2VmVR9gN", "9Xebtm27yd3Xp9ZWKfcqDv"]
            [random:integer(2)])
          registry_Rx
        }
    }
    rule ruleset_added {
        select when wrangler ruleset_added where rids >< meta:rid
        always {
            ent:bids := [];
            ent:orders := {};
            // ent:bidWindowTime := 10;
            ent:bidWindowTime := 30;
            ent:storePhoneNumber := "+15034064270";
            ent:location := {"latitude": "40.2968979", "longitude": "-111.69464749999997"};
        }
    }
    // Customer order triggers this rule
    rule new_order {
        select when order new
        pre {
            // Create unique identifier for this new order
            orderID = random:uuid()
            // can't actually send to other phone because of twilio
            // customer_phone = event:attr("phone")
            customer_phone = "+18017848121"
            // let's automate this for efficiency
            // description = event:attr("description")
            description = random:word() + ", " + random:word() + ", " + random:word()
            location = get_random_location()
            store_Rx = wrangler:myself().get("eci")
            new_order = {
                "orderID": orderID,
                "customer_phone": customer_phone,
                "description": description,
                "location": location,
                "store_Rx": store_Rx
            }
            // Message: [MessageID*, DriverID, location, orderID, store_Rx, driver_location],
              // where location: [latitude, latitude]
        }
        always {
            ent:orders := get_all_orders().put(orderID, new_order);
            // raise order event "request_bids" attributes {"orderID": orderID}
            raise order event "request_gateway" attributes {"store_Rx": store_Rx, "orderID": orderID}
        }
    }
    rule collect_bid {
      select when order bidOnOrder
      pre {
          bid = event:attrs.get("distance")
          eci = event:attrs.get("driver_Rx")
          id = event:attrs.get("orderID")
          // order_already_assigned = not order_by_id(id){"assigned_driver"}.isnull()
      }
      /*
      if order_already_assigned then
          event:send(
          { "eci": eci, "eid": "reject_bid",
              "domain": "order", "type": "rejected",
              "attrs": { "id": id} } )
      notfired {
          ent:bids := ent:bids.append(bid)
      }
      */
      send_directive("Received Bid", event:attrs)
      fired {
        ent:bids := ent:bids.append(event:attrs)
      }
    }
    /*
    "eci": store_Rx, "eid": "send_bid",
          "domain": "order", "type": "bidOnOrder",
          "attrs": {
              "driver_Rx": meta:eci,
              "distance": distance.getDistance(driver_lat, driver_long, lat, long),
              "orderId": orderId
          }
    */
    rule gateway_request {
      select when order request_gateway
      pre {
        // {"store_Rx": store_Rx, "orderID": orderID}
        attrs = event:attrs
        registry_Rx = get_registry()
      }
      event:send({"eci": registry_Rx, "eid": "gateway_request", "domain": "registry",
          "type": "request_gateway", "attrs": attrs})
    }
    rule gateway_response {
      select when order gateway_response
      pre {
        orderID = event:attrs.get("orderID")
        Message = order_by_id(orderID)
        gateway_Rx = event:attrs.get("gateway_Rx")
      }
      event:send({"eci": gateway_Rx, "eid": "message_generation", "domain": "gossip",
          "type": "generate_message", "attrs": {"Message": Message}})
      fired {
        // schedule time-out for bid collection
      }
    }
    /*
    send_peer_attrs = {"eci": store_Rx, "eid": "gateway_response",
        "domain": "order", "type": "gateway_response", "attrs":
          {"orderID": event:attrs.get("orderID"), "gateway_Rx": first_peer_Rx}}
    */
    // The flower shop will only ever initiate subscriptions
    /*
    rule auto_accept {
        select when wrangler inbound_pending_subscription_added
        pre {
            attrs = event:attrs.klog("subcription:")
        }
        always {
            raise wrangler event "pending_subscription_approval"
            attributes attrs
        }
    }
    */
    rule update_customer_via_text {
        select when customer sendMessage
        pre {
            message = event:attr("message").defaultsTo("Confirmation of flower delivery")
            orderID = event:attr("orderID")
            // can't deliver to other numbers
            // toNumber = event:attr("phoneNumber").defaultsTo("+18017848121")
            toNumber = order_by_id(orderID).get("customer_phone")
        }
        // send_message=defaction(source, destination, message)
        twilio:send_message(ent:storePhoneNumber, toNumber, message)
    }
    rule set_location {
        select when store setLocation
        pre {
            lat = event:attr("latitude").defaultsTo(ent:location{"latitude"})
            lon = event:attr("longitude").defaultsTo(ent:location{"longitude"})
        }
        always {
            ent:location := {"latitude": lat, "longitude": lon}
        }
    }
}
