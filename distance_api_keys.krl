ruleset distance_api_keys {
  meta {
    logging on
    key distance {
    	"auth_token": "****REDACTED****"
    }
    provides keys distance to store_ruleset, driver
  }
}
