-- Based off of default 0.10.0 config

admins = { "cortex@brainonfire.net" }

-- Better perf; requires libevent to be installed
use_libevent = true

-- Load extra modules from here
plugin_paths = { "/opt/commapps/prosody/modules/community" }

-- Modules to load on startup.
-- Documentation for builtin modules: https://prosody.im/doc/modules

modules_enabled = {
  -- Generally required
    "roster"; -- Allow users to have a roster.
    "saslauth"; -- Authentication for clients and servers.
    "tls"; -- Add support for secure TLS on c2s/s2s connections
    "dialback"; -- s2s dialback support
    "disco"; -- Service discovery
    "posix"; -- For prosodyctl

  -- "Conversations" support
    "carbons"; -- Keep multiple clients in sync
    "mam"; -- XEP-0313 message archives
    "privacy_lists"; -- required for mod_blocking
    "blocking"; -- XEP-0191: Simple Communications Blocking support
    "csi"; -- client state indication
    "http_upload";
    -- Disabled until I decide whether this is a terrible idea to enable, privacy-wise:
    -- "cloud_notify"; -- Push notifications
    "omemo_all_access"; -- Allow users to start OMEMO conversations without pre-existing mutual subscription
    "smacks"; -- Fast reconnect
    -- Disabled until I can be sure all users' clients have MAM support:
    -- "smacks_noerror"; -- Suppresses "unacked message" warnings

  -- Not essential, but recommended
    "pep"; -- Enables users to publish their mood/activity/now-playing, etc.
    "private"; -- Private XML storage (for room bookmarks, etc.)
    "vcard"; -- Allow users to set vCards

  -- Nice to have
    "version"; -- Replies to server version requests
    "uptime"; -- Report how long server has been running
    "time"; -- Let others know the time here on this server
    "ping"; -- Replies to XMPP pings with pongs
    -- Not in apt packages anymore:
    -- "server_contact_info"; -- Shows admin contact info

  -- Admin interfaces
    --"admin_adhoc"; -- administration via XMPP client
    "announce"; -- Send announcement to all online users

  -- Other specific functionality
    --"proxy65"; -- Enables a file transfer proxy service for NATed clients
}

modules_disabled = {
  --"offline"; -- to disable message buffering support for offline recipients
}

-- Disable account registration, just in case "register" module is
-- accidentally loaded
allow_registration = false

c2s_require_encryption = true
-- Timeout for unauthed connections
c2s_timeout = 45
s2s_require_encryption = true
-- Force certificate authentication for server-to-server connections?
s2s_secure_auth = false
s2s_insecure_domains = { }
s2s_secure_domains = { "parsni.ps", "brainonfire.net" }

-- Required for init scripts and prosodyctl [default]
pidfile = "/var/run/prosody/prosody.pid"

data_path = "/opt/commdata/jabber/data"

authentication = "internal_hashed"

-- For advanced logging see https://prosody.im/doc/logging
log = {
  -- Change 'info' to 'debug' for verbose logging
  info = "/var/log/prosody/prosody.log";
  error = "/var/log/prosody/prosody.err";
  -- "*syslog"; -- Uncomment this for logging to syslog
  -- "*console"; -- Log to the console, useful for debugging with daemonize=false
}

-- TODO Use this correctly
certificates = "certs"

-- Once the virtual host sections start, you can't set global
-- configuation. Settings under each VirtualHost entry apply *only* to
-- that host, so this line must remain at the end.

Include "/etc/prosody/conf.d/vhosts/*.cfg.lua"


-- No config after vhosts, please!
