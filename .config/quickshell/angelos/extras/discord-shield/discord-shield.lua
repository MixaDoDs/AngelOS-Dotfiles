-- angelOS: Discord's Go Live with sound records every program's playback stream on its own and
-- now and then crashes (SIGTRAP in its Voice thread) when one of them goes away. With a mixer
-- set up like a RØDECaster's (the default output is a virtual mix sink, a PipeWire loopback to
-- the device), everything that plays already reaches Discord through the mixes' loopback
-- streams, which live as long as PipeWire does. Then Discord's PipeWire clients don't see single
-- programs' playback streams at all, only those loopbacks: what Discord streams sounds the same,
-- but nothing in it comes and goes. Without such a mixer nothing changes.
--
-- Hiding a stream once it is there is too late (Discord hears of it first), so a shielded
-- Discord client sees nothing new by default and every new object is let through here, all but
-- those streams (and their ports).

log = Log.open_topic ("s-angelos")

all_om = ObjectManager {
  Interest { type = "core" },
  Interest { type = "client" },
  Interest { type = "factory" },
  Interest { type = "device" },
  Interest { type = "node" },
  Interest { type = "port" },
  Interest { type = "link" },
  Interest { type = "metadata" },
}

metadata_om = ObjectManager {
  Interest {
    type = "metadata",
    Constraint { "metadata.name", "=", "default" },
  }
}

-- Shielded Discord clients, by bound id
discord = {}
-- Hidden playback streams, bound id → true
hidden = {}

function isDiscord (props)
  local bin = (props["application.process.binary"] or ""):lower ()
  return props["pipewire.access.portal.app_id"] == "com.discordapp.Discord"
      or bin:find ("discord", 1, true) ~= nil
end

function isLoopback (props)
  return (props["node.link-group"] or ""):find ("^loopback%-") ~= nil
end

-- Whether the default output is a virtual mix sink (a loopback's capture side)
function mixerSetUp ()
  local metadata = metadata_om:lookup ()
  local value = metadata and metadata:find (0, "default.audio.sink")
  local name = value and (Json.Raw (value):parse () or {}).name
  if not name then
    return false
  end
  for obj in all_om:iterate () do
    local p = obj.properties or {}
    if p["node.name"] == name and p["media.class"] == "Audio/Sink" then
      return isLoopback (p)
    end
  end
  return false
end

-- Whether `obj` is a single program's playback stream (or one of its ports), not to be seen
function isHidden (obj)
  local p = obj.properties or {}
  if p["port.id"] ~= nil or p["port.direction"] ~= nil then
    return hidden[tonumber (p["node.id"])] == true
  end
  local class = p["media.class"] or ""
  return class:find ("^Stream/Output/Audio") ~= nil and not isLoopback (p)
end

-- The permissions `client` (Discord's) gets on `obj`
function permsFor (obj, client)
  local p = obj.properties or {}
  local own = p["client.id"] == tostring (client["bound-id"])
  if not own and isHidden (obj) then
    return "-"
  end
  return "all"
end

function shield (client)
  local perms = { ["any"] = "-", [0] = "all" }
  local n = 0
  for obj in all_om:iterate () do
    local perm = permsFor (obj, client)
    perms[obj["bound-id"]] = perm
    if perm == "-" and ((obj.properties or {})["media.class"] or "") ~= "" then
      n = n + 1
    end
  end
  client:update_permissions (perms)
  log:notice (client, string.format ("Discord client: %d playback streams hidden", n))
end

all_om:connect ("object-added", function (_, obj)
  local p = obj.properties or {}
  if (p["media.class"] or ""):find ("^Stream/Output/Audio") and isHidden (obj) then
    hidden[obj["bound-id"]] = true
  end

  if p["application.process.binary"] ~= nil and p["pipewire.protocol"] ~= nil
      and not p["wireplumber.daemon"] and isDiscord (p) then
    if mixerSetUp () then
      discord[obj["bound-id"]] = obj
      shield (obj)
    else
      log:notice (obj, "Discord client: no mixer (the default output is no loopback), not shielded")
    end
    return
  end

  for _, client in pairs (discord) do
    client:update_permissions { [obj["bound-id"]] = permsFor (obj, client) }
  end
end)

all_om:connect ("object-removed", function (_, obj)
  local id = obj["bound-id"]
  discord[id] = nil
  hidden[id] = nil
end)

metadata_om:activate ()
all_om:activate ()
