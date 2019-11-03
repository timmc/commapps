VirtualHost "appux.com"

ssl = {
  key = "/srv/commdata/jabber/tls/appux.com.key";
  certificate = "/srv/commdata/jabber/tls/appux.com.chain.pem";
  -- `openssl dhparam -out dhparam.pem 4096` on another machine
  -- Does not seem to enable forward secrecy? Anyway, ECDHE is better.
  -- dhparam = "/etc/prosody/certs/dh-4096.pem";
  protocol = "tlsv1_2";
}

c2s_require_encryption = true

Component "muc.appux.com" "muc"
    name = "Appux chatrooms"
    restrict_room_creation = "local"
    max_history_messages = 5
