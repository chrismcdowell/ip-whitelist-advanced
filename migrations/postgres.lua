return {
  {
    name = "ip-whitelist-advanced",
    up = function(_, _, factory)
      local plugins, err = factory.plugins:find_all {name = "ip-whitelist-advanced"}
      if err then
        return err
      end

      for _, plugin in ipairs(plugins) do
        plugin.config._whitelist_cache = nil
        local _, err = factory.plugins:update(plugin, plugin, {full = true})
        if err then
          return err
        end
      end
    end,
    down = function()
      -- Do nothing
    end
  }
}
