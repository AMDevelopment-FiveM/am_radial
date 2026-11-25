-- Load AFTER @ox_lib/init.lua in a consuming resource, if desired.
lib = lib or {}
for _,name in ipairs({'addRadialItem','registerRadial','removeRadialItem','clearRadialItems','showRadialMenu','showRadial','hideRadial','disableRadial','getCurrentRadialId'}) do
    lib[name]=function(...) return exports.am_radial[name](exports.am_radial,...) end
end
