---
description: HTTP File Upload
labels: 'Stage-Alpha'
---

Introduction
============

This module implements [XEP-0363], versions 0.2 and 0.3, which let
clients upload files over HTTP.

Configuration
=============

mod\_http\_upload relies on Prosodys HTTP server and mod\_http for
serving HTTP requests. See [Prosodys HTTP server documentation][doc:http]
for information about how to configure ports, HTTP Host names etc.

The module can be added as a new Component definition:

``` {.lua}
Component "upload.example.org" "http_upload"
```

Alternatively it can be added to `modules_enabled` like other modules.

Limits
------

### Max size

A maximum file size can be set by:

``` {.lua}
http_upload_file_size_limit = 123 -- bytes
```

Default is 1MB (1024\*1024).

This can not be set over the value of `http_max_content_size` (default 10M).
Consider [mod_http_upload_external] instead of attempting to increase
this limit.

### Max age

Files can be set to be deleted after some time:

``` lua
http_upload_expire_after = 60 * 60 * 24 * 7 -- a week in seconds
```

### User quota

A total maximum size of all uploaded files per user can be set by:

``` lua
http_upload_quota = 1234 -- bytes
```

Path
----

By default, uploaded files are put in a sub-directory of the default
Prosody storage path (usually `/var/lib/prosody`). This can be changed:

``` {.lua}
http_upload_path = "/path/to/uploded/files"
```

Compatibility
=============

Works with Prosody 0.9.x and later.
