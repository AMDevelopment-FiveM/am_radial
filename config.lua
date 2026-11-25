Config = {}
Config.Key = 'Z'
Config.EnableBuiltins = true
-- Configure your existing resource events here. Empty events are hidden.
Config.Events = { garage = '', inventory = '', identity = '', invoices = '' }
-- Example: {coords = vector3(215.8,-810.1,30.7), radius = 15.0, id = 'central'}
Config.Garages = {}
-- Jobs are supplied by your framework via exports.am_radial:setJob('police')
Config.JobItems = {
    police = {}, ambulance = {}, mechanic = {}
}

-- UI customization (pixels, capped automatically on smaller screens)
Config.MenuWidth = 390
Config.Accent = '#387ce9'
