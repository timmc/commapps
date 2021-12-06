VirtualHost "brainonfire.net"

ssl = {
  key = "/srv/commdata/jabber/tls/brainonfire.net.key";
  certificate = "/srv/commdata/jabber/tls/brainonfire.net.chain.pem";
  -- `openssl dhparam -out dhparam.pem 4096` on another machine
  -- Does not seem to enable forward secrecy? Anyway, ECDHE is better.
  -- dhparam = "/etc/prosody/certs/dh-4096.pem";
  protocol = "tlsv1_2";
}
