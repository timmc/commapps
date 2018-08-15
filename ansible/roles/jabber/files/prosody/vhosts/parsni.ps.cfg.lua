VirtualHost "parsni.ps"

ssl = {
  key = "/srv/commdata/jabber/tls/parsni.ps.key";
  certificate = "/srv/commdata/jabber/tls/parsni.ps.chain.pem";
  -- `openssl dhparam -out dhparam.pem 4096` on another machine
  -- Does not seem to enable forward secrecy? Anyway, ECDHE is better.
  -- dhparam = "/etc/prosody/certs/dh-4096.pem";
  protocol = "tlsv1_2";
}

c2s_require_encryption = true

Component "muc.parsni.ps" "muc"
    name = "Parsni.ps chatrooms"
    restrict_room_creation = "local"
    max_history_messages = 5
