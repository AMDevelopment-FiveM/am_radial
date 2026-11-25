local root, menus, history = {}, {}, {}
local opened, disabled, current, job = false, false, nil, nil
local visible, signature, revision = {}, nil, 0
local function allowed(item)
    if item.jobs then
        local found = false
        for _, name in ipairs(item.jobs) do if job == name then found = true end end
        if not found then return false end
    end
    if item.zone then
        local z = item.zone
        if not z.coords or type(z.radius) ~= "number" then return false end
        if #(GetEntityCoords(PlayerPedId()) - z.coords) > z.radius then return false end
    end
    if item.canInteract then local ok, result = pcall(item.canInteract); if not ok or not result then return false end end
    return true
end
local function hide()
    if not opened then return end
    opened = false; current = nil; history = {}; signature = nil
    SetNuiFocusKeepInput(false); SetNuiFocus(false,false); SendNUIMessage({action='hide'})
end
local function refresh(force)
    if not opened then return end
    if current and not menus[current] then hide(); return end
    for _, link in ipairs(history) do
        local parent = link.menu and menus[link.menu] and menus[link.menu].items or root
        local exists = false
        for _, candidate in ipairs(parent) do
            if candidate == link.item then exists = true; break end
        end
        if not exists or not allowed(link.item) then hide(); return end
    end
    local source = current and menus[current] and menus[current].items or root
    local data, nextVisible = {}, {}
    for i,item in ipairs(source) do
        if allowed(item) then
            nextVisible[#nextVisible+1] = {item=item,index=i}
            data[#data+1] = {id=item.id or tostring(i),label=item.label,icon=type(item.icon)=='table' and item.icon[2] or item.icon,menu=item.menu,iconWidth=item.iconWidth,iconHeight=item.iconHeight}
        end
    end
    if #data == 0 then hide(); return end
    visible = nextVisible
    local payload = {action='show',items=data,back=#history>0,title=current and menus[current] and (menus[current].label or current) or 'Menu', menuId=current or false,key=Config.Key,width=Config.MenuWidth,accent=Config.Accent}
    local s = json.encode(payload)
    if force or s ~= signature then signature=s; revision=revision+1; payload.revision=revision; SendNUIMessage(payload) end
end
local function target(parent)
    if not parent then return root end
    assert(menus[parent], 'Unknown radial menu: ' .. tostring(parent))
    return menus[parent].items
end
local function add(items,parent,owner)
    local t=target(parent); if items.label then items={items} end
    for _,item in ipairs(items) do
        assert(type(item.id)=='string' and type(item.label)=='string','Item needs id and label')
        item.owner=owner or GetCurrentResourceName(); local replaced=false
        for i,v in ipairs(t) do if v.id==item.id then t[i]=item; replaced=true; break end end
        if not replaced then t[#t+1]=item end
    end
    refresh(true)
end
local function register(radial,owner)
    assert(type(radial.id)=='string' and type(radial.items)=='table')
    radial.owner=owner or GetCurrentResourceName()
    for _,item in ipairs(radial.items) do item.owner=radial.owner end
    menus[radial.id]=radial; refresh(true)
end
local function show(id)
    if disabled or (id and not menus[id]) then return end
    if opened then
        current = id
        history = {}
        refresh(true)
        return
    end
    if IsEntityDead(PlayerPedId()) or IsPauseMenuActive() or IsNuiFocused() then return end
    current=id; history={}; opened=true; SetNuiFocus(true,true); SetNuiFocusKeepInput(false); SetCursorLocation(.5,.5); refresh(true)
end
exports('addRadialItem',function(items,parent) add(items,parent,GetInvokingResource()) end)
exports('registerRadial',function(radial) register(radial,GetInvokingResource()) end)
exports('removeRadialItem',function(id,parent) local t=target(parent); for i=#t,1,-1 do if t[i].id==id then table.remove(t,i) end end; refresh(true) end)
exports('clearRadialItems',function() root={}; refresh(true) end)
exports('showRadialMenu',show)
exports('showRadial',show)
exports('hideRadial',hide)
exports('disableRadial',function(state) disabled=state; if state then hide() end end)
exports('getCurrentRadialId',function() return current end)
exports('setJob',function(name) job=name; refresh(true) end)
RegisterCommand('amradial',function() if opened then hide() else show() end end,false)
RegisterKeyMapping('amradial','Radial menu','keyboard',Config.Key)
RegisterNUICallback('close',function(_,cb) hide(); cb(true) end)
RegisterNUICallback('back', function(_, cb)
    cb(true)
    if not opened then return end
    local previous = table.remove(history)
    if previous then
        current = previous.menu
        refresh(true)
    else
        hide()
    end
end)
RegisterNUICallback('select',function(data,cb)
    cb(true); if not opened or type(data) ~= "table" then return end
    if data.revision ~= revision then refresh(true); return end
    local entry=visible[tonumber(data.index) or 0]; if not entry or not allowed(entry.item) then refresh(true); return end
    local item,menu=entry.item,current
    if item.menu then if menus[item.menu] then history[#history+1]={menu=current,item=item}; current=item.menu; refresh(true) end; return end
    if not item.keepOpen then hide() else revision=revision+1; refresh(true) end
    if type(item.onSelect)=='function' then local ok,err=pcall(item.onSelect,menu,entry.index); if not ok then print(err) end
    elseif type(item.onSelect)=='string' then local ok,err=pcall(function() exports[item.owner][item.onSelect](exports[item.owner],menu,entry.index) end); if not ok then print(err) end
    elseif item.event then TriggerEvent(item.event,item.args) elseif item.command then ExecuteCommand(item.command) end
end)
CreateThread(function() while true do if opened then DisablePlayerFiring(PlayerId(),true); Wait(0) else Wait(200) end end end)
CreateThread(function() while true do Wait(250); if opened then if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then hide() else refresh(false) end end end end)
AddEventHandler('onClientResourceStop',function(resource)
    if resource==GetCurrentResourceName() then if opened then hide() end; return end
    for i=#root,1,-1 do if root[i].owner==resource then table.remove(root,i) end end
    for id,m in pairs(menus) do if m.owner==resource then menus[id]=nil; if current==id then hide() end else for i=#m.items,1,-1 do if m.items[i].owner==resource then table.remove(m.items,i) end end end end
    refresh(true)
end)
if not Config.EnableBuiltins then return end

local function vehicle() return GetVehiclePedIsIn(PlayerPedId(),false) end
local function driver() local v=vehicle(); return v~=0 and GetPedInVehicleSeat(v,-1)==PlayerPedId() end
local function anim(dict,name,flag)
    RequestAnimDict(dict); local timeout=GetGameTimer()+3000
    while not HasAnimDictLoaded(dict) and GetGameTimer()<timeout do Wait(10) end
    if HasAnimDictLoaded(dict) then TaskPlayAnim(PlayerPedId(),dict,name,8.0,-8.0,-1,flag or 49,0,false,false,false); RemoveAnimDict(dict) end
end
register({id='animations',label='Animationer',items={
    {label='Vink',icon='hand',onSelect=function() anim('friends@frj@ig_1','wave_a',49) end},
    {label='Hænder op',icon='hands',onSelect=function() anim('missminuteman_1ig_2','handsup_base',49) end},
    {label='Sid ned',icon='chair',onSelect=function() TaskStartScenarioInPlace(PlayerPedId(),'WORLD_HUMAN_PICNIC',0,true) end},
    {label='Klap',icon='hands',onSelect=function() anim('amb@world_human_cheering@male_a','base',49) end},
    {label='Peg',icon='hand',onSelect=function() anim('gestures@m@standing@casual','gesture_point',49) end},
    {label='Læn dig',icon='user',onSelect=function() TaskStartScenarioInPlace(PlayerPedId(),'WORLD_HUMAN_LEANING',0,true) end},
    {label='Noter',icon='receipt',onSelect=function() TaskStartScenarioInPlace(PlayerPedId(),'WORLD_HUMAN_CLIPBOARD',0,true) end},
    {label='Stop',icon='xmark',onSelect=function() ClearPedTasks(PlayerPedId()) end}
}})
register({id='vehicle',label='Køretøj',items={
    {label='Motor',icon='power-off',canInteract=driver,onSelect=function() local v=vehicle(); if driver() then SetVehicleEngineOn(v,not GetIsVehicleEngineRunning(v),false,true) end end},
    {label='Døre',icon='car',canInteract=driver,onSelect=function() local v=vehicle(); if driver() then for i=0,3 do if GetVehicleDoorAngleRatio(v,i)>0 then SetVehicleDoorShut(v,i,false) else SetVehicleDoorOpen(v,i,false,false) end end end end},
    {label='Motorhjelm',icon='car',canInteract=driver,onSelect=function() local v=vehicle(); if driver() then if GetVehicleDoorAngleRatio(v,4)>0 then SetVehicleDoorShut(v,4,false) else SetVehicleDoorOpen(v,4,false,false) end end end},
    {label='Forlad bil',icon='user',onSelect=function() local v=vehicle(); if v~=0 then TaskLeaveVehicle(PlayerPedId(),v,0) end end},
    {label='Bagagerum',icon='box',canInteract=driver,onSelect=function() local v=vehicle(); if driver() then if GetVehicleDoorAngleRatio(v,5)>0 then SetVehicleDoorShut(v,5,false) else SetVehicleDoorOpen(v,5,false,false) end end end}
}})
add({{id='animations',label='Animationer',icon='face-smile',menu='animations'},{id='vehicle',label='Køretøj',icon='car',menu='vehicle',canInteract=function() return vehicle()~=0 end}})
local personal={
    {label='Spiller ID',icon='id-card',onSelect=function() TriggerEvent('chat:addMessage',{args={'ID',tostring(GetPlayerServerId(PlayerId()))}}) end},
    {label='Stop animation',icon='xmark',onSelect=function() ClearPedTasks(PlayerPedId()) end}
}
register({id='general',label='Generelt',items={
    {label='Kort',icon='map',onSelect=function() ActivateFrontendMenu(GetHashKey('FE_MENU_VERSION_MP_PAUSE'),false,-1) end},
    {label='Gem våben',icon='shield',onSelect=function() SetCurrentPedWeapon(PlayerPedId(),GetHashKey('WEAPON_UNARMED'),true) end},
    {label='Ragdoll',icon='user',onSelect=function() SetPedToRagdoll(PlayerPedId(),2500,2500,0,false,false,false) end}
}})
add({id='general',label='Generelt',icon='gear',menu='general'})
for _,entry in ipairs({{'inventory','Inventar','box'},{'identity','ID-kort','id-card'},{'invoices','Fakturaer','receipt'}}) do
    local event=Config.Events[entry[1]]; if event and event~='' then personal[#personal+1]={label=entry[2],icon=entry[3],event=event} end
end
if #personal>0 then register({id='personal',label='Personligt',items=personal}); add({id='personal',label='Personligt',icon='user',menu='personal'}) end
if Config.Events.garage~='' then for _,g in ipairs(Config.Garages) do add({id='garage_'..g.id,label='Åbn garage',icon='warehouse',zone=g,event=Config.Events.garage,args=g.id}) end end
for name,items in pairs(Config.JobItems) do if #items>0 then register({id='job_'..name,label='Arbejde',items=items}); add({id='job_'..name,label='Arbejde',icon='briefcase',jobs={name},menu='job_'..name}) end end
