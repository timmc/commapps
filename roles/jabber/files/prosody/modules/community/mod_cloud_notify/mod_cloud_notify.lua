-- XEP-0357: Push (aka: My mobile OS vendor won't let me have persistent TCP connections)
-- Copyright (C) 2015-2016 Kim Alvefur
-- Copyright (C) 2017-2018 Thilo Molitor
--
-- This file is MIT/X11 licensed.

local t_insert = table.insert;
local s_match = string.match;
local s_sub = string.sub;
local os_time = os.time;
local next = next;
local st = require"util.stanza";
local jid = require"util.jid";
local dataform = require"util.dataforms".new;
local filters = require"util.filters";
local hashes = require"util.hashes";

local xmlns_push = "urn:xmpp:push:0";

-- configuration
local include_body = module:get_option_boolean("push_notification_with_body", false);
local include_sender = module:get_option_boolean("push_notification_with_sender", false);
local max_push_errors = module:get_option_number("push_max_errors", 16);
local max_push_devices = module:get_option_number("push_max_devices", 5);
local dummy_body = module:get_option_string("push_notification_important_body", "New Message!");

local host_sessions = prosody.hosts[module.host].sessions;
local push_errors = {};
local id2node = {};

-- ordered table iterator, allow to iterate on the natural order of the keys of a table,
-- see http://lua-users.org/wiki/SortedIteration
local function __genOrderedIndex( t )
	local orderedIndex = {}
	for key in pairs(t) do
		table.insert( orderedIndex, key )
	end
	-- sort in reverse order (newest one first)
	table.sort( orderedIndex, function(a, b)
		if a == nil or t[a] == nil or b == nil or t[b] == nil then return false end
		-- only one timestamp given, this is the newer one
		if t[a].timestamp ~= nil and t[b].timestamp == nil then return true end
		if t[a].timestamp == nil and t[b].timestamp ~= nil then return false end
		-- both timestamps given, sort normally
		if t[a].timestamp ~= nil and t[b].timestamp ~= nil then return t[a].timestamp > t[b].timestamp end
		return false	-- normally not reached
	end)
	return orderedIndex
end
local function orderedNext(t, state)
	-- Equivalent of the next function, but returns the keys in timestamp
	-- order. We use a temporary ordered key table that is stored in the
	-- table being iterated.

	local key = nil
	--print("orderedNext: state = "..tostring(state) )
	if state == nil then
		-- the first time, generate the index
		t.__orderedIndex = __genOrderedIndex( t )
		key = t.__orderedIndex[1]
	else
		-- fetch the next value
		for i = 1, #t.__orderedIndex do
			if t.__orderedIndex[i] == state then
				key = t.__orderedIndex[i+1]
			end
		end
	end

	if key then
		return key, t[key]
	end

	-- no more value to return, cleanup
	t.__orderedIndex = nil
	return
end
local function orderedPairs(t)
	-- Equivalent of the pairs() function on tables. Allows to iterate
	-- in order
	return orderedNext, t, nil
end

-- small helper function to return new table with only "maximum" elements containing only the newest entries
local function reduce_table(table, maximum)
	local count = 0;
	local result = {};
	for key, value in orderedPairs(table) do
		count = count + 1;
		if count > maximum then break end
		result[key] = value;
	end
	return result;
end

-- For keeping state across reloads while caching reads
local push_store = (function()
	local store = module:open_store();
	local push_services = {};
	local api = {};
	function api:get(user)
		if not push_services[user] then
			local err;
			push_services[user], err = store:get(user);
			if not push_services[user] and err then
				module:log("warn", "Error reading push notification storage for user '%s': %s", user, tostring(err));
				push_services[user] = {};
				return push_services[user], false;
			end
		end
		if not push_services[user] then push_services[user] = {} end
		return push_services[user], true;
	end
	function api:set(user, data)
		push_services[user] = reduce_table(data, max_push_devices);
		local ok, err = store:set(user, push_services[user]);
		if not ok then
			module:log("error", "Error writing push notification storage for user '%s': %s", user, tostring(err));
			return false;
		end
		return true;
	end
	function api:set_identifier(user, push_identifier, data)
		local services = self:get(user);
		services[push_identifier] = data;
		return self:set(user, services);
	end
	return api;
end)();


-- Forward declarations, as both functions need to reference each other
local handle_push_success, handle_push_error;

function handle_push_error(event)
	local stanza = event.stanza;
	local error_type, condition = stanza:get_error();
	local node = id2node[stanza.attr.id];
	if node == nil then return false; end		-- unknown stanza? Ignore for now!
	local from = stanza.attr.from;
	local user_push_services = push_store:get(node);
	local changed = false;
	
	for push_identifier, _ in pairs(user_push_services) do
		local stanza_id = hashes.sha256(push_identifier, true);
		if stanza_id == stanza.attr.id then
			if user_push_services[push_identifier] and user_push_services[push_identifier].jid == from and error_type ~= "wait" then
				push_errors[push_identifier] = push_errors[push_identifier] + 1;
				module:log("info", "Got error of type '%s' (%s) for identifier '%s': "
					.."error count for this identifier is now at %s", error_type, condition, push_identifier,
					tostring(push_errors[push_identifier]));
				if push_errors[push_identifier] >= max_push_errors then
					module:log("warn", "Disabling push notifications for identifier '%s'", push_identifier);
					-- remove push settings from sessions
					if host_sessions[node] then
						for _, session in pairs(host_sessions[node].sessions) do
							if session.push_identifier == push_identifier then
								session.push_identifier = nil;
								session.push_settings = nil;
								session.first_hibernated_push = nil;
							end
						end
					end
					-- save changed global config
					changed = true;
					user_push_services[push_identifier] = nil
					push_errors[push_identifier] = nil;
					-- unhook iq handlers for this identifier (if possible)
					if module.unhook then
						module:unhook("iq-error/host/"..stanza_id, handle_push_error);
						module:unhook("iq-result/host/"..stanza_id, handle_push_success);
						id2node[stanza_id] = nil;
					end
				end
			elseif user_push_services[push_identifier] and user_push_services[push_identifier].jid == from and error_type == "wait" then
				module:log("debug", "Got error of type '%s' (%s) for identifier '%s': "
					.."NOT increasing error count for this identifier", error_type, condition, push_identifier);
			end
		end
	end
	if changed then
		push_store:set(node, user_push_services);
	end
	return true;
end

function handle_push_success(event)
	local stanza = event.stanza;
	local node = id2node[stanza.attr.id];
	if node == nil then return false; end		-- unknown stanza? Ignore for now!
	local from = stanza.attr.from;
	local user_push_services = push_store:get(node);
	
	for push_identifier, _ in pairs(user_push_services) do
		if hashes.sha256(push_identifier, true) == stanza.attr.id then
			if user_push_services[push_identifier] and user_push_services[push_identifier].jid == from and push_errors[push_identifier] > 0 then
				push_errors[push_identifier] = 0;
				module:log("debug", "Push succeeded, error count for identifier '%s' is now at %s again", push_identifier, tostring(push_errors[push_identifier]));
			end
		end
	end
	return true;
end

-- http://xmpp.org/extensions/xep-0357.html#disco
local function account_dico_info(event)
	(event.reply or event.stanza):tag("feature", {var=xmlns_push}):up();
end
module:hook("account-disco-info", account_dico_info);

-- http://xmpp.org/extensions/xep-0357.html#enabling
local function push_enable(event)
	local origin, stanza = event.origin, event.stanza;
	local enable = stanza.tags[1];
	origin.log("debug", "Attempting to enable push notifications");
	-- MUST contain a 'jid' attribute of the XMPP Push Service being enabled
	local push_jid = enable.attr.jid;
	-- SHOULD contain a 'node' attribute
	local push_node = enable.attr.node;
	-- CAN contain a 'include_payload' attribute
	local include_payload = enable.attr.include_payload;
	if not push_jid then
		origin.log("debug", "Push notification enable request missing the 'jid' field");
		origin.send(st.error_reply(stanza, "modify", "bad-request", "Missing jid"));
		return true;
	end
	local publish_options = enable:get_child("x", "jabber:x:data");
	if not publish_options then
		-- Could be intentional
		origin.log("debug", "No publish options in request");
	end
	local push_identifier = push_jid .. "<" .. (push_node or "");
	local push_service = {
		jid = push_jid;
		node = push_node;
		include_payload = include_payload;
		options = publish_options and st.preserialize(publish_options);
		timestamp = os_time();
	};
	local ok = push_store:set_identifier(origin.username, push_identifier, push_service);
	if not ok then
		origin.send(st.error_reply(stanza, "wait", "internal-server-error"));
	else
		origin.push_identifier = push_identifier;
		origin.push_settings = push_service;
		origin.first_hibernated_push = nil;
		origin.log("info", "Push notifications enabled for %s (%s)", tostring(stanza.attr.from), tostring(origin.push_identifier));
		origin.send(st.reply(stanza));
	end
	return true;
end
module:hook("iq-set/self/"..xmlns_push..":enable", push_enable);

-- http://xmpp.org/extensions/xep-0357.html#disabling
local function push_disable(event)
	local origin, stanza = event.origin, event.stanza;
	local push_jid = stanza.tags[1].attr.jid; -- MUST include a 'jid' attribute
	local push_node = stanza.tags[1].attr.node; -- A 'node' attribute MAY be included
	if not push_jid then
		origin.send(st.error_reply(stanza, "modify", "bad-request", "Missing jid"));
		return true;
	end
	local user_push_services = push_store:get(origin.username);
	for key, push_info in pairs(user_push_services) do
		if push_info.jid == push_jid and (not push_node or push_info.node == push_node) then
			origin.log("info", "Push notifications disabled (%s)", tostring(key));
			if origin.push_identifier == key then
				origin.push_identifier = nil;
				origin.push_settings = nil;
				origin.first_hibernated_push = nil;
			end
			user_push_services[key] = nil;
			push_errors[key] = nil;
			if module.unhook then
				module:unhook("iq-error/host/"..key, handle_push_error);
				module:unhook("iq-result/host/"..key, handle_push_success);
				id2node[key] = nil;
			end
		end
	end
	local ok = push_store:set(origin.username, user_push_services);
	if not ok then
		origin.send(st.error_reply(stanza, "wait", "internal-server-error"));
	else
		origin.send(st.reply(stanza));
	end
	return true;
end
module:hook("iq-set/self/"..xmlns_push..":disable", push_disable);

-- Patched version of util.stanza:find() that supports giving stanza names
-- without their namespace, allowing for every namespace.
local function find(self, path)
	local pos = 1;
	local len = #path + 1;

	repeat
		local xmlns, name, text;
		local char = s_sub(path, pos, pos);
		if char == "@" then
			return self.attr[s_sub(path, pos + 1)];
		elseif char == "{" then
			xmlns, pos = s_match(path, "^([^}]+)}()", pos + 1);
		end
		name, text, pos = s_match(path, "^([^@/#]*)([/#]?)()", pos);
		name = name ~= "" and name or nil;
		if pos == len then
			if text == "#" then
				local child = xmlns ~= nil and self:get_child(name, xmlns) or self:child_with_name(name);
				return child and child:get_text() or nil;
			end
			return xmlns ~= nil and self:get_child(name, xmlns) or self:child_with_name(name);
		end
		self = xmlns ~= nil and self:get_child(name, xmlns) or self:child_with_name(name);
	until not self
	return nil;
end

-- is this push a high priority one (this is needed for ios apps not using voip pushes)
local function is_important(stanza)
	local st_name = stanza and stanza.name or nil;
	if not st_name then return false; end	-- nonzas are never important here
	if st_name == "presence" then
		return false;						-- same for presences
	elseif st_name == "message" then
		-- unpack carbon copies
		local stanza_direction = "in";
		local carbon;
		local st_type;
		-- support carbon copied message stanzas having an arbitrary message-namespace or no message-namespace at all
		if not carbon then carbon = find(stanza, "{urn:xmpp:carbons:2}/forwarded/message"); end
		if not carbon then carbon = find(stanza, "{urn:xmpp:carbons:1}/forwarded/message"); end
		stanza_direction = carbon and stanza:child_with_name("sent") and "out" or "in";
		if carbon then stanza = carbon; end
		st_type = stanza.attr.type;
		
		-- headline message are always not important
		if st_type == "headline" then return false; end
		
		-- carbon copied outgoing messages are not important
		if carbon and stanza_direction == "out" then return false; end
		
		-- We can't check for body contents in encrypted messages, so let's treat them as important
		-- Some clients don't even set a body or an empty body for encrypted messages
		
		-- check omemo https://xmpp.org/extensions/inbox/omemo.html
		if stanza:get_child("encrypted", "eu.siacs.conversations.axolotl") or stanza:get_child("encrypted", "urn:xmpp:omemo:0") then return true; end
		
		-- check xep27 pgp https://xmpp.org/extensions/xep-0027.html
		if stanza:get_child("x", "jabber:x:encrypted") then return true; end
		
		-- check xep373 pgp (OX) https://xmpp.org/extensions/xep-0373.html
		if stanza:get_child("openpgp", "urn:xmpp:openpgp:0") then return true; end
		
		local body = stanza:get_child_text("body");
		if st_type == "groupchat" and stanza:get_child_text("subject") then return false; end		-- groupchat subjects are not important here
		return body ~= nil and body ~= "";			-- empty bodies are not important
	end
	return false;		-- this stanza wasn't one of the above cases --> it is not important, too
end

local push_form = dataform {
	{ name = "FORM_TYPE"; type = "hidden"; value = "urn:xmpp:push:summary"; };
	{ name = "message-count"; type = "text-single"; };
	{ name = "pending-subscription-count"; type = "text-single"; };
	{ name = "last-message-sender"; type = "jid-single"; };
	{ name = "last-message-body"; type = "text-single"; };
};

-- http://xmpp.org/extensions/xep-0357.html#publishing
local function handle_notify_request(stanza, node, user_push_services, log_push_decline)
	local pushes = 0;
	if not user_push_services or next(user_push_services) == nil then return pushes end
	
	for push_identifier, push_info in pairs(user_push_services) do
		local send_push = true;		-- only send push to this node when not already done for this stanza or if no stanza is given at all
		if stanza then
			if not stanza._push_notify then stanza._push_notify = {}; end
			if stanza._push_notify[push_identifier] then
				if log_push_decline then
					module:log("debug", "Already sent push notification for %s@%s to %s (%s)", node, module.host, push_info.jid, tostring(push_info.node));
				end
				send_push = false;
			end
			stanza._push_notify[push_identifier] = true;
		end
		
		if send_push then
			-- construct push stanza
			local stanza_id = hashes.sha256(push_identifier, true);
			local push_publish = st.iq({ to = push_info.jid, from = module.host, type = "set", id = stanza_id })
				:tag("pubsub", { xmlns = "http://jabber.org/protocol/pubsub" })
					:tag("publish", { node = push_info.node })
						:tag("item")
							:tag("notification", { xmlns = xmlns_push });
			local form_data = {
				-- hardcode to 1 because other numbers are just meaningless (the XEP does not specify *what exactly* to count)
				["message-count"] = "1";
			};
			if stanza and include_sender then
				form_data["last-message-sender"] = stanza.attr.from;
			end
			if stanza and include_body then
				form_data["last-message-body"] = stanza:get_child_text("body");
			elseif stanza and dummy_body and is_important(stanza) then
				form_data["last-message-body"] = tostring(dummy_body);
			end
			push_publish:add_child(push_form:form(form_data));
			push_publish:up(); -- / notification
			push_publish:up(); -- / publish
			push_publish:up(); -- / pubsub
			if push_info.options then
				push_publish:tag("publish-options"):add_child(st.deserialize(push_info.options));
			end
			-- send out push
			module:log("debug", "Sending%s push notification for %s@%s to %s (%s)", form_data["last-message-body"] and " important" or "", node, module.host, push_info.jid, tostring(push_info.node));
			-- module:log("debug", "PUSH STANZA: %s", tostring(push_publish));
			-- handle push errors for this node
			if push_errors[push_identifier] == nil then
				push_errors[push_identifier] = 0;
				module:hook("iq-error/host/"..stanza_id, handle_push_error);
				module:hook("iq-result/host/"..stanza_id, handle_push_success);
				id2node[stanza_id] = node;
			end
			module:send(push_publish);
			pushes = pushes + 1;
		end
	end
	return pushes;
end

-- small helper function to extract relevant push settings
local function get_push_settings(stanza, session)
	local to = stanza.attr.to;
	local node = to and jid.split(to) or session.username;
	local user_push_services = push_store:get(node);
	return node, user_push_services;
end

-- publish on offline message
module:hook("message/offline/handle", function(event)
	local node, user_push_services = get_push_settings(event.stanza, event.origin);
	module:log("debug", "Invoking cloud handle_notify_request() for offline stanza");
	handle_notify_request(event.stanza, node, user_push_services, true);
end, 1);

-- publish on unacked smacks message
local function process_smacks_stanza(stanza, session)
	if session.push_identifier then
		session.log("debug", "Invoking cloud handle_notify_request() for smacks queued stanza");
		local user_push_services = {[session.push_identifier] = session.push_settings};
		local node = get_push_settings(stanza, session);
		if handle_notify_request(stanza, node, user_push_services, true) ~= 0 then
			if session.hibernating and not session.first_hibernated_push then
				-- if important stanzas are treated differently (pushed with last-message-body field set to dummy string)
				-- and the message was important (e.g. had a last-message-body field) OR if we treat all pushes equally,
				-- then record the time of first push in the session for the smack module which will extend its hibernation
				-- timeout based on the value of session.first_hibernated_push
				if not dummy_body or (dummy_body and is_important(stanza)) then
					session.first_hibernated_push = os_time();
				end
			end
		end
	end
	return stanza;
end

local function process_smacks_queue(queue, session)
	if not session.push_identifier then return; end
	local user_push_services = {[session.push_identifier] = session.push_settings};
	local notified = { unimportant = false; important = false }
	for i=1, #queue do
		local stanza = queue[i];
		local node = get_push_settings(stanza, session);
		stanza_type = "unimportant"
		if dummy_body and is_important(stanza) then stanza_type = "important"; end
		if not notified[stanza_type] then		-- only notify if we didn't try to push for this stanza type already
			-- session.log("debug", "Invoking cloud handle_notify_request() for smacks queued stanza: %d", i);
			if handle_notify_request(stanza, node, user_push_services, false) ~= 0 then
				if session.hibernating and not session.first_hibernated_push then
					-- if important stanzas are treated differently (pushed with last-message-body field set to dummy string)
					-- and the message was important (e.g. had a last-message-body field) OR if we treat all pushes equally,
					-- then record the time of first push in the session for the smack module which will extend its hibernation
					-- timeout based on the value of session.first_hibernated_push
					if not dummy_body or (dummy_body and is_important(stanza)) then
						session.first_hibernated_push = os_time();
					end
				end
				session.log("debug", "Cloud handle_notify_request() > 0, not notifying for other queued stanzas of type %s", stanza_type);
				notified[stanza_type] = true
			end
		end
	end
end

-- smacks hibernation is started
local function hibernate_session(event)
	local session = event.origin;
	local queue = event.queue;
	session.first_hibernated_push = nil;
	-- process unacked stanzas
	process_smacks_queue(queue, session);
	-- process future unacked (hibernated) stanzas
	filters.add_filter(session, "stanzas/out", process_smacks_stanza, -990);
end

-- smacks hibernation is ended
local function restore_session(event)
	local session = event.resumed;
	if session then		-- older smacks module versions send only the "intermediate" session in event.session and no session.resumed one
		filters.remove_filter(session, "stanzas/out", process_smacks_stanza);
		session.first_hibernated_push = nil;
	end
end

-- smacks ack is delayed
local function ack_delayed(event)
	local session = event.origin;
	local queue = event.queue;
	-- process unacked stanzas (handle_notify_request() will only send push requests for new stanzas)
	process_smacks_queue(queue, session);
end

-- archive message added
local function archive_message_added(event)
	-- event is: { origin = origin, stanza = stanza, for_user = store_user, id = id }
	-- only notify for new mam messages when at least one device is online
	if not event.for_user or not host_sessions[event.for_user] then return; end
	local stanza = event.stanza;
	local user_session = host_sessions[event.for_user].sessions;
	local to = stanza.attr.to;
	to = to and jid.split(to) or event.origin.username;

	-- only notify if the stanza destination is the mam user we store it for
	if event.for_user == to then
		local user_push_services = push_store:get(to);
		if next(user_push_services) == nil then return end
		
		-- only notify nodes with no active sessions (smacks is counted as active and handled separate)
		local notify_push_services = {};
		for identifier, push_info in pairs(user_push_services) do
			local identifier_found = nil;
			for _, session in pairs(user_session) do
				-- module:log("debug", "searching for '%s': identifier '%s' for session %s", tostring(identifier), tostring(session.push_identifier), tostring(session.full_jid));
				if session.push_identifier == identifier then
					identifier_found = session;
					break;
				end
			end
			if identifier_found then
				identifier_found.log("debug", "Not cloud notifying '%s' of new MAM stanza (session still alive)", identifier);
			else
				notify_push_services[identifier] = push_info;
			end
		end

		handle_notify_request(event.stanza, to, notify_push_services, true);
	end
end

module:hook("smacks-hibernation-start", hibernate_session);
module:hook("smacks-hibernation-end", restore_session);
module:hook("smacks-ack-delayed", ack_delayed);
module:hook("archive-message-added", archive_message_added);

local function send_ping(event)
	local user = event.user;
	local user_push_services = push_store:get(user);
	local push_services = event.push_services or user_push_services;
	handle_notify_request(nil, user, push_services, true);
end
-- can be used by other modules to ping one or more (or all) push endpoints
module:hook("cloud-notify-ping", send_ping);

module:log("info", "Module loaded");
function module.unload()
	if module.unhook then
		module:unhook("account-disco-info", account_dico_info);
		module:unhook("iq-set/self/"..xmlns_push..":enable", push_enable);
		module:unhook("iq-set/self/"..xmlns_push..":disable", push_disable);

		module:unhook("smacks-hibernation-start", hibernate_session);
		module:unhook("smacks-hibernation-end", restore_session);
		module:unhook("smacks-ack-delayed", ack_delayed);
		module:unhook("archive-message-added", archive_message_added);
		module:unhook("cloud-notify-ping", send_ping);

		for push_identifier, _ in pairs(push_errors) do
			local stanza_id = hashes.sha256(push_identifier, true);
			module:unhook("iq-error/host/"..stanza_id, handle_push_error);
			module:unhook("iq-result/host/"..stanza_id, handle_push_success);
			id2node[stanza_id] = nil;
		end
	end

	module:log("info", "Module unloaded");
end
