# AM Radial
Install folder in resources and `ensure am_radial`. Z opens, Esc closes. Standalone; vRP job state can be passed from your existing client bridge with setJob. No server permissions are granted by this menu; validate sensitive actions server-side.

## Garage
In config.lua set Config.Events.garage to your existing garage CLIENT event, then add entries to Config.Garages. The event receives the garage id. The menu is only an interface and does not spawn vehicles itself. Your garage resource must handle the event and validate access.

## API
```lua
exports.am_radial:registerRadial({id='police', label='Politi', items={{label='MDT',icon='shield',event='police:openMDT'}}})
exports.am_radial:addRadialItem({id='police',label='Politi',icon='shield',menu='police',jobs={'police'}})
exports.am_radial:setJob('police')
exports.am_radial:addRadialItem({id='garage',label='Garage',icon='warehouse',zone={coords=vector3(215.8,-810.1,30.7),radius=15},onSelect=function() TriggerEvent('mygarage:open') end})
exports.am_radial:removeRadialItem('garage')
```
Also: clearRadialItems, showRadialMenu (alias showRadial), hideRadial, disableRadial, getCurrentRadialId. add/remove accept optional parent menu ID. Items support canInteract(), keepOpen, command, event, args, jobs, zone. Callbacks receive menu id and original 1-based index. String callbacks call an export of the registering resource. Font Awesome Free solid icons are bundled as SVG data; unknown names use circle-dot; custom HTTPS/NUI image URLs supported. For existing ox_lib scripts, optionally load `@am_radial/bridge.lua` after `@ox_lib/init.lua` in each consuming resource and disable conflicting original Z mapping. This is not a replacement for all of ox_lib. Existing ox_lib calls without this bridge are not intercepted. Test in your server before production.

### Appearance
Set `Config.MenuWidth` and `Config.Accent` in config.lua. The UI uses local Font Awesome Free 6.7.2 SVG icons and system sans-serif typography. No CDN or internet connection is required for built-in icons. Set `Config.EnableBuiltins = false` for an empty menu managed by your own scripts.

### Release validation
Lua 5.4 and JavaScript syntax checks passed. Before publishing, test the following on a FiveM development server:
- Open and close with Z and Escape; verify cursor and camera focus are restored.
- Navigate nested menus and return to root; test pagination with nine or more entries.
- Enter/leave a garage zone and change jobs while the menu is open.
- Restart a resource that registered menu items; verify its items disappear.
- Test death, pause menu, other NUI resources and restarting am_radial while open.
- Connect garage, inventory and vRP job events; verify permissions server-side.

The package is a release candidate, not a certified runtime-tested release. See third-party notices for icon licensing. Set your own commercial distribution terms before selling.
