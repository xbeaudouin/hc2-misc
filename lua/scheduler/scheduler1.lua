--[[
%% properties
%% globals
%% autostart
--]]

--[[
LUAScheduler for HC2 v1.2.5
original by robmac
contibutions from jompa68 , A.Socha
 
HISTORY:
1.0.0   original  					                                                        28-07-2013
1.0.1   minor fixes and comments  	                                                                29-07-2013
1.0.2   minor fixes and comments  	                                                                30-07-2013
1.0.3   virtual devices and dimmer	                                                                30-07-2013
1.0.4   reindexed by counter to allow 
		multiple event per device per minute
		to allow multiple virtual device calls                                                30-07-2013
1.0.5	use number rather then strings for a small
		gain and easy translation of day names                                          30-07-2013
1.0.6	added armed for door and window sensors                                     30-07-2013
1.0.7	the scheduler catches up state from 
		last 24 hours at start based on no manual intervention                   31-07-2013
1.0.8	sort the catch up so the items run in schedule order                       31-07-2013
1.0.9	property added for catch up                                                             31-07-2013
1.0.10	prepare multiple items from single add 
		supported for individual days and All only 
		Add basic support for RGB                                                              01-08-2013
1.0.11	Sunrise and Sunset + offset added                                                 01-08-2013
1.0.12	RGB multi + offset added 		                                                01-08-2013
1.0.13	Only execute when schedule not every miunute
		add report and debug code				                                02-08-2013
1.0.14	fixed order of catch up				                                        02-08-2013
1.0.15	clean and split solar in prep for multi solar
		correct any time drift from schedule                                                02-08-2013
1.0.16	prepareSolar bug fix				                                        03-08-2013
1.0.17	catchup flag added				                                                03-08-2013
1.0.18	setTargetLevel added				                                        03-08-2013
1.1.0	runs with thousand + actions so call it a cut	                                03-08-2013
1.1.1	enable scene debug and kill scenes added	 
          [ERROR] ??:??:??: line 337: attempt to index field '?' (a nil value) fix   04-08-2013
1.1.2	add examples enable scene debug and kill scenes added	         04-08-2013
1.1.4	sunrise schedule not refreshed fix		05-08-2013	
1.1.5   setThermostat time and temp at same time    
		getValue and store in  global
		+ as an example of own function
		get remaining time and store in a global and
		a function that stores 4 temperature sensors in globals
		but this could be any function you want to write    06-08-2013
1.1.6   fix spurious bad solar record debug message   08-08-2013
1.2.0   multiple calls from single line to turn of multiple devices or set multiple thermostats for example    26-08-2013
1.2.1   same as 1.2.1    26-08-2013
1.2.2   some type checking in add that should help debug add set adddebug = true to use   19-09-2013
1.2.3   added e-mail and notification  24-09-2013
1.2.5   added e-mail and notification  27-10-2013

KNOWN ISSUES: 
1) Sunrise and sunset events that are not everyday are not caught up correctly.
2) No handling of over/under values when incrementing values on muti schedule items

PURPOSE:
This scene schedules all timed events on a HC2 system. 
It is a more efficient approach than having many 
"if (<day> or <day> ) and <time> then <do this> 
Elseif (<day> or <day> ) and <time>  then <do this> 
...... else  <do this> " statements checking for times and days
in many scenes. It only uses one loop with a sleep for potentially
hundreds of timed events. If additional criteria are required, create a scene 
to check the additional conditions  e.g. turn on a light at 06:00 if it is dark

TO USE:
add your actions after the "add the schedule items" comment at the end of the scene

DISCLAIMER:
The code is offered with no warranty. The user needs to modify 
to use and the code cannot be used as is.

TO DO; 
		value checking when incrementing so limit at min 0 max 100 or 255
		A bit of refactoring and tidy interfaces to reduce lenght and increase efficiency
		Random time variations for security
--]]
-- DO NOT EDIT SECTION START
--only want one schedule running
if (fibaro:countScenes() > 1) then fibaro:abort() end; 
--schedule engine start
local luaDaySchedule = {version = "1.2.5"};
--prints debug messages
local debugadd = false;
local debugcatch = false;
local debug = false; --solar
--prints when it runs to debug
local reportRun = true;
--fixed time schedule
local schedule = {}; 
--time to prepare sunrise sunset for new day
local prepareSunScheduleRise = "00:05";
local prepareSunScheduleSet = "12:05";   
--master schedule for sunrise and sunset
local scheduleSunMaster = {}; 
--holds the sunrise for sunset for today
local scheduleSunLiveRise = {}; 
local scheduleSunLiveSet = {}; 
--would be used to allow pause but no way to achieve yet
local run = false;
--provide unique counter for various table use
local count;
--variables so only loops when schedules due
local currentDayItem = "NOTSET"; --tracks the last schedule run
local daySchedules = {}; --populates every day with the next days schedule times

--table of wrapper functions
fibaroLookup ={
call = function (device,action)
    if type(device) == "table" then 
      for i,v in ipairs(device) do
        	fibaro:call(v,action)
  			if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ",\"" .. action .. "\")" ) end 
      end
    else
  		fibaro:call(device,action)
  		if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ",\"" .. action .. "\")" ) end 
	end
end,
setGlobal = function (variable,value)
    if type(variable) == "table" then 
      for i,v in ipairs(variable) do
        	fibaro:setGlobal(v,value[i])
        	if reportRun then  fibaro:debug( "fibaro:setGlobal(\"" .. v .. "\",\"" .. value[i] .. "\")" ) end 
 		end
    else
        fibaro:setGlobal(variable,value)
        if reportRun then  fibaro:debug( "fibaro:setGlobal(\"" .. variable .. "\",\"" .. value .. "\")" ) end 
    end
end,
startScene = function (scene,values)
    if type(scene) == "table" then 
      	for i,v in ipairs(scene) do
        	fibaro:startScene(v)
    		if reportRun then  fibaro:debug( "fibaro:startScene(" .. v ..  ")" ) end 
		end
    else
         fibaro:startScene(scene)
    	if reportRun then  fibaro:debug( "fibaro:startScene(" .. scene ..  ")" ) end 
	end
 end,
pressButton = function (device,button)
  fibaro:call(device, "pressButton" , button )   
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"pressButton\" ," .. button .. ")" ) end 
end,
setSlider = function (device,btnvalparam)
    fibaro:call(device, "setSlider", btnvalparam[1],btnvalparam[2])
   if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setSlider\" ," ..  btnvalparam[1] .. "," .. btnvalparam[2] .. ")" ) end 
end,
setValue = function (device,value)
    if type(device) == "table" then
      if type(value) == "table" then 
          for i,v in ipairs(device) do
              fibaro:call(v, "setValue", value[i] )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"setValue\" ," .. value[i] .. ")" ) end 
          end
       else  --set them all to a single value
          for i,v in ipairs(device) do
              fibaro:call(v, "setValue", value )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"setValue\" ," .. value .. ")" ) end 
      	  end
       end
    else
    	fibaro:call(device, "setValue", value )
    	if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setValue\" ," .. value .. ")" ) end 
	end
end,
sendEmail = function (user,message)
    fibaro:call(user, 'sendEmail', message[1] , message[2])
   if reportRun then  fibaro:debug( "fibaro:call(" .. user .. ", \'sendEmail\' , \'" .. message[1] .. "\' , \'" .. message[2] .. " \' )" ) end 
end,
sendGlobalPushNotifications = function (device,notification)
    if type(device) == "table" then
      if type(notification) == "table" then 
          for i,v in ipairs(device) do
              fibaro:call(v, "sendGlobalPushNotifications", notification[i] )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendGlobalPushNotifications\" ," .. notification[i] .. ")" ) end 
          end
       else  --set them all to a single value
          for i,v in ipairs(device) do
              fibaro:call(v, "sendGlobalPushNotifications", notification )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendGlobalPushNotifications\" ," .. notification .. ")" ) end 
      	  end
       end
    else
    	fibaro:call(device, "sendGlobalPushNotifications", notification )
    	if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"sendGlobalPushNotifications\" ," .. notification .. ")" ) end 
	end
end,
sendDefinedPushNotification = function (device,notification)
    if type(device) == "table" then
      if type(notification) == "table" then 
          for i,v in ipairs(device) do
              fibaro:call(v, "sendDefinedPushNotification", notification[i] )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendDefinedPushNotification\" ," .. notification[i] .. ")" ) end 
          end
       else  --set them all to a single value
          for i,v in ipairs(device) do
              fibaro:call(v, "sendDefinedPushNotification", notification )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendDefinedPushNotification\" ," .. notification .. ")" ) end 
      	  end
       end
    else
    	fibaro:call(device, "sendDefinedPushNotification", notification )
    	if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"sendDefinedPushNotification\" ," .. notification .. ")" ) end 
	end
end,
sendGlobalEmailNotifications = function (device,notification)
    if type(device) == "table" then
      if type(notification) == "table" then 
          for i,v in ipairs(device) do
              fibaro:call(v, "sendGlobalEmailNotifications", notification[i] )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendGlobalEmailNotifications\" ," .. notification[i] .. ")" ) end 
          end
       else  --set them all to a single value
          for i,v in ipairs(device) do
              fibaro:call(v, "sendGlobalEmailNotifications", notification )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendGlobalEmailNotifications\" ," .. notification .. ")" ) end 
      	  end
       end
    else
    	fibaro:call(device, "sendGlobalEmailNotifications", notification )
    	if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"sendGlobalEmailNotifications\" ," .. notification .. ")" ) end 
	end
end,
sendDefinedEmailNotification = function (device,notification)
    if type(device) == "table" then
      if type(notification) == "table" then 
          for i,v in ipairs(device) do
              fibaro:call(v, "sendDefinedEmailNotification", notification[i] )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendDefinedEmailNotification\" ," .. notification[i] .. ")" ) end 
          end
       else  --set them all to a single value
          for i,v in ipairs(device) do
              fibaro:call(v, "sendDefinedEmailNotification", notification )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"sendDefinedEmailNotification\" ," .. notification .. ")" ) end 
      	  end
       end
    else
    	fibaro:call(device, "sendDefinedPushNotification", notification )
    	if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"sendDefinedEmailNotification\" ," .. notification .. ")" ) end 
	end
end,
setArmed = function (device,action) 
    if type(device) == "table" then
          for i,v in ipairs(device) do
            fibaro:call(v, "setArmed", action) 
       		 if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"setArmed\" ," .. action .. ")" ) end 
           end      
    else
        fibaro:call(device, "setArmed", action) 
        if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setArmed\" ," .. action .. ")" ) end 
    end
end,
setRGBColor = function (device, value)  
    fibaro:call(device, "setColor", value[1], value[2], value[3], value[4])
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setColor\" ," .. value[1] .. "," .. value[2] .. "," ..  value[3] .. "," ..  value[4] .. ")" ) end 
end,
setColor = function (device, value)  
    fibaro:call(device, "setColor", value[1], value[2], value[3], value[4])
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setColor\" ," .. value[1] .. "," .. value[2] .. "," ..  value[3] .. "," ..  value[4] .. ")" ) end 
end,
setW = function (device, value)  
    fibaro:call(device, "setW", value)
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setW\" ," .. value .. ")" ) end 
end,
setR = function (device, value)  
    fibaro:call(device, "setR", value)
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setR\" ," .. value .. ")" ) end 
end,
setG = function (device, value)  
    fibaro:call(device, "setG", value)
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setG\" ," .. value .. ")" ) end 
end,
setB = function (device, value)  
    fibaro:call(device, "setB", value)
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setB\" ," .. value .. ")" ) end 
end,
startProgram = function (device, program)  
    fibaro:call(device, "startProgram", program)
    if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"startProgram\" ," .. program .. ")" ) end 
end,
setTargetLevel = function (device, value)
    if type(device) == "table" then
      if type(value) == "table" then 
          for i,v in ipairs(device) do
              fibaro:call(v, "setTargetLevel", value[i] )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"setTargetLevel\" ," .. value[i] .. ")" ) end 
          end
       else  --set them all to a single value
          for i,v in ipairs(device) do
              fibaro:call(v, "setTargetLevel", value )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"setTargetLevel\" ," .. value .. ")" ) end 
      	  end
       end
    else
        fibaro:call(device, "setTargetLevel" , value )
        if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setTargetLevel\" ," .. value .. ")" ) end 
    end
end ,
setTime = function (device, value)
   if type(device) == "table" then
      if type(value) == "table" then 
          for i,v in ipairs(device) do
              fibaro:call(v, "setTime", value[i] )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"setTime\" ," .. value[i] .. ")" ) end 
          end
       else  --set them all to a single value
          for i,v in ipairs(device) do
              fibaro:call(v, "setTime", value )
       		if reportRun then  fibaro:debug( "fibaro:call(" .. v .. ", \"setTime\" ," .. value .. ")" ) end 
      	  end
       end
    else
    	fibaro:call(device, "setTime" , value )
    	if reportRun then  fibaro:debug( "fibaro:call(" .. device .. ", \"setTime\" ," .. value .. ")" ) end 
	end 
end,
setThermostat = function(device,setpoint)
     local currentTimestamp = os.time();
     if type(device) == "table" then     
          for i,v in ipairs(device) do
        	fibaro:call(v, "setTime", currentTimestamp + setpoint[2]);
          	fibaro:call(v, "setTargetLevel" , setpoint[1]);
       		if reportRun then  
                fibaro:debug( "setThermostat begin actions")
                fibaro:debug( "fibaro:call(" .. v .. ", \"setTargetLevel\" ," .. setpoint[1] .. ")" )
                fibaro:debug( "fibaro:call(" .. v .. ", \"setTime\" ," .. currentTimestamp + setpoint[2] .. ")" )
                fibaro:debug( "setThermostat end actions")      	
            end 
      	  end
    else
          fibaro:call(device, "setTime", currentTimestamp + setpoint[2]);
          fibaro:call(device, "setTargetLevel" , setpoint[1]);
         if reportRun then  
            fibaro:debug( "setThermostat begin actions")
            fibaro:debug( "fibaro:call(" .. device .. ", \"setTargetLevel\" ," .. setpoint[1] .. ")" )
            fibaro:debug( "fibaro:call(" .. device .. ", \"setTime\" ," .. currentTimestamp + setpoint[2] .. ")" )
            fibaro:debug( "setThermostat end actions")      	
        end 
    end
end,
killScenes = function (scene,values)
    fibaro:killScenes(scene)
    if reportRun then  fibaro:debug( "fibaro:killScenes(" .. scene ..  ")" ) end 
end ,
setSceneEnabled = function (scene,enabled)
  fibaro:setSceneEnabled(scene,enabled)
  if reportRun then  fibaro:debug( "fibaro:setSceneEnabled(" .. device .. ",\"" .. action .. "\")" ) end 
end,
debug = function (heading,message)
  fibaro:debug(heading .. ": " .. message)
  if reportRun then  fibaro:debug( "fibaro:debug(" .. ",\"" .. heading .. ": " .. message .. "\")" ) end 
end,
getValue = function(device,valueDestination)
      local currentValue =  fibaro:getValue(device,  valueDestination[2]);
      
      if valueDestination[1] == "debug" then
         fibaro:debug( "The value of " .. valueDestination[2] .. " for device " .. device .. " is " ..  currentValue );
      else
        fibaro:setGlobal( valueDestination[1],currentValue)        
        if reportRun then  
          fibaro:debug( "getValue begin actions")
          fibaro:debug( "fibaro:getValue(" .. device .. ",\"" .. valueDestination[2] .. "\")")
          fibaro:debug( "fibaro:setGlobal(\"" .. valueDestination[1] .. "\",\"" .. currentValue .. "\")")
          fibaro:debug( "getValue end actions")      	
    	end 
      end      
end, 
    
-- DO NOT EDIT SECTION END
-- USER EDIT SECTION START
-- add your own function call here but avoid long running or functions that sleep
getTimeValFromNow = function(device,valueDestination)
    
      local currentTimestamp =   os.time();
      local currentValue =   fibaro:getValue(device,  "timeStamp" );
      local currentValueRemain =   currentValue - currentTimestamp;
     
      if valueDestination == "debug" then
         fibaro:debug( "The time from device " .. device .. " is " ..  currentValue .. " time remaining " .. currentValueRemain);
      else
        fibaro:setGlobal( valueDestination,currentValueRemain)        
        if reportRun then  
          fibaro:debug( "getTimeValFromNow begin actions")
           fibaro:debug( "fibaro:setGlobal(\"" .. valueDestination .. "\",\"" .. currentValueRemain .. "\")")
          fibaro:debug( "getTimeValFromNow end actions")      	
    	end 
      end 
end,
SpecialFunctionExample = function(devices,gobals)
    luaDaySchedule:SpecialFunctionExample( devices,gobals);
end   
-- DO NOT MISS , WHEN YOU ADD
-- USER EDIT SECTION END
-- DO NOT EDIT SECTION START
  }
--access to functions
luaDaySchedule.fibMap = {
  ["call"] = fibaroLookup.call,
  ["setGlobal"] = fibaroLookup.setGlobal,
  ["startScene"] = fibaroLookup.startScene,
  ["pressButton"] = fibaroLookup.pressButton,
  ["setSlider"] = fibaroLookup.setSlider,
  ["setValue"] = fibaroLookup.setValue,
  ["sendEmail"] = fibaroLookup.sendEmail,
  ["sendGlobalPushNotifications"] = fibaroLookup.sendGlobalPushNotifications,
  ["sendGlobalEmailNotifications"] = fibaroLookup.sendGlobalEmailNotifications,
  ["sendDefinedPushNotification"] = fibaroLookup.sendDefinedPushNotification,
  ["sendDefinedEmailNotification"] = fibaroLookup.sendDefinedEmailNotification,
  ["setTime"] = fibaroLookup.setTime,
  ["setArmed"] = fibaroLookup.setArmed,
  ["setRGBColor"] = fibaroLookup.setRGBColor,
  ["setColor"] = fibaroLookup.setColor,
  ["setR"] = fibaroLookup.setR,
  ["setG"] = fibaroLookup.setG,
  ["setB"] = fibaroLookup.setB,
  ["setW"] = fibaroLookup.setW,
  ["startProgram"] = fibaroLookup.startProgram,
  ["setTargetLevel"] = fibaroLookup.setTargetLevel,
  ["killScenes"] = fibaroLookup.killScenes,
  ["setSceneEnabled"] = fibaroLookup.setSceneEnabled,
  ["debug"] = fibaroLookup.debug,
  ["setThermostat"] = fibaroLookup.setThermostat,
  ["getValue"] = fibaroLookup.getValue,  
-- DO NOT EDIT SECTION END
-- USER EDIT SECTION START
-- add map to your own function call here
  ["getTimeValFromNow"] = fibaroLookup.getTimeValFromNow  ,
  ["SpecialFunctionExample"] = fibaroLookup.SpecialFunctionExample
-- DO NOT MISS , WHEN YOU ADD
-- USER EDIT SECTION END
-- DO NOT EDIT SECTION START
  }
--ref table of catchUp
luaDaySchedule.catchUpInterval = {
  ["None"] = 0,
  ["24hrs"] = 24*60*60,
  ["1Week"] = 7*24*60*60
  }
 -- how long should be caught up
local doCatchUp = luaDaySchedule.catchUpInterval ["24hrs"]  
--ref table of days
luaDaySchedule.days = {
  ["Sunday"] = "0",
  ["Monday"] = "1",
  ["Tuesday"] = "2",
  ["Wednesday"] = "3",
  ["Thursday"] = "4",
  ["Friday"] = "5",
  ["Saturday"] = "6",
  ["All"] = "7",
  ["Weekend"] = "8",
  ["Weekday"] = "9"
  }
-- add the schedule tables for each day
function luaDaySchedule:init()  
-- populate tables to starter
  for i,d in pairs(luaDaySchedule.days) do
        schedule[d] = {};
    	scheduleSunLiveRise[d]= {};
    	scheduleSunLiveSet[d]= {};
  end 
  --create a generic counter that is used across functions
  count = luaDaySchedule:newCounter();
end
-- counter
function luaDaySchedule:newCounter ()
  local i = 0
  return function ()   -- anonymous function
    i = i + 1
    return i
  end
end  
-- get param as string for report/debug 
function luaDaySchedule:paramasstring(param , message) 
  local result;
  if  type(param) == "table" then  
      result =  " action/value "  .. table.concat (param , " param val "); 
  elseif  param == nil then
     result = "";
  else 
     result =   message  .. param;  ---" action/value "  .. param;
end  
  return result;
end
-- add the actions to the schedules
-- runs once on startup per action line
function luaDaySchedule:add( sTime, deviceID, fibaroAction, fibaroFunction,  sDays, catchUpFlag, sunShiftorRepeats, interval, valueIncrement)
  local cn;
  -- check a few param types
  if debugadd then 
    if sTime == nil then fibaro:debug("No time value." ) end 
    if deviceID == nil then fibaro:debug("No device value." ) end 
    if type(deviceID) == "table" then
      	if #deviceID == 0 then fibaro:debug("No device values." ) end 
    end
    if #sDays == 0 then fibaro:debug("No days sent. Device is " .. deviceID  .. " time is " .. sTime) end 
  	if fibaroFunction == nil then fibaro:debug("No function value." ) end 
    if fibaroAction == nil then fibaro:debug("No parameter value." ) end 
  	 if type(fibaroAction) == "table" then
      	if #fibaroAction == 0 then fibaro:debug("No parameter values." ) end 
    end  
  end
  -- loop through adding day schedules
  for  i,d in ipairs(sDays) do  
    	cn = count();
    	if debugadd then 
      		fibaro:debug("Action " .. cn .. " added for days " .. d .. " at " .. sTime .. luaDaySchedule:paramasstring ( deviceID , " for device ") .. " the function is " .. fibaroFunction ..  luaDaySchedule:paramasstring(fibaroAction, "") ) 
		end
        --add solar to the solar master as a template
    	if sTime == "Sunrise" or sTime == "Sunset" then
            --add sunrise and sunset master schedules      		
            if scheduleSunMaster[sTime] == nill then    
              scheduleSunMaster[sTime]= {};
              scheduleSunMaster[sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["sunshift"] = sunShiftorRepeats, ["solarevent"] = sTime , ["day"] = luaDaySchedule.days[d] , ["catchup"] = catchUpFlag };
            else
                scheduleSunMaster[sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["sunshift"] = sunShiftorRepeats, ["solarevent"] = sTime , ["day"] = luaDaySchedule.days[d] , ["catchup"] = catchUpFlag };
            end
    	else
          --add to the standard schedule table
          if schedule[luaDaySchedule.days[d]][sTime] == nill then    
              schedule[luaDaySchedule.days[d]][sTime]= {};
              schedule[luaDaySchedule.days[d]][sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["sunshift"] = sunShiftorRepeats , ["catchup"] = catchUpFlag };
          else
              schedule[luaDaySchedule.days[d]][sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["sunshift"] = sunShiftorRepeats , ["catchup"] = catchUpFlag };
          end                 
          --are there any repeats   
          if  interval ~= nil and sunShiftorRepeats ~= nil and sTime ~= "Sunrise" and sTime ~= "Sunset" then
              -- process  repeats    
              luaDaySchedule:multiadd(d,sTime,deviceID,fibaroAction, fibaroFunction, sDays, sunShiftorRepeats, interval, valueIncrement ,  catchUpFlag )  
          end
       end    	
  	end  
end
-- add any aditional actions defined as multi repeat
-- runs once on startup per action line that has multi
function luaDaySchedule:multiadd(d,sTime,deviceID,fibaroAction, fibaroFunction, sDays, sunShiftorRepeats, interval, valueIncrement ,  catchUpFlag )
  local newTime;
  local oldDay = luaDaySchedule.days[d] ;
  local newDay = oldDay ;
  local incrementNumber = 1;	
  local hourTime = tonumber(string.sub (sTime, 1 , 2) );
  local minutetime = tonumber(string.sub(sTime,4) );
  local todayIs = os.date("*t");
  local serialtodaytime = os.time{year=todayIs.year, month=todayIs.month, day=todayIs.day, hour=hourTime, min = minutetime};
  local todayDayIs = os.date("%w",serialtodaytime );
  -- loop repeats and add new action at incremented time
  while incrementNumber < (sunShiftorRepeats +1) do    		
    cn = count();      -- get a new index for action
    -- calculate the time
    --lets do the All case first as it is easy
    if oldDay == "7" then
      -- so get the date serial of the time for today and 
      -- then we can add the interval in seconds to get new time
      -- will count round from 23:59 to 00:00 but as all days no need to do 
      -- anything to the day
      newTime = os.date("%H:%M",(serialtodaytime + (interval * 60 * incrementNumber))) 
    elseif tonumber(oldDay) < 7 then
      -- individual days  handle going past 23:59 on days
      local tempserial = serialtodaytime - ( (tonumber(todayDayIs) - tonumber(oldDay)) * 24*60*60) + (interval * 60 * incrementNumber);
      newTime = os.date("%H:%M",tempserial);
      newDay = os.date("%w",tempserial );
    else
      -- how do we handle going past 23:59 on days for
      -- special case for weekdays and weekend
      fibaro:debug("you can not use repeat for weekday, weekend, sunrise or sunset schedules");
    end    
    -- do we want to increment the value
    if valueIncrement ~= nil then 
      -- case  dimmer etc          
      if type(fibaroAction) == "number" then          
        newfibaroAction =  fibaroAction + (incrementNumber * valueIncrement);
        -- case 2 virtual device slider and rgb
      elseif type(fibaroAction ) == "table" then 
        -- add increment for slider
        if table.getn(fibaroAction) == 2 then
        	newfibaroAction = {fibaroAction[1],fibaroAction[2] + (incrementNumber * valueIncrement)};
        elseif  table.getn(fibaroAction) == 4 then
       		newfibaroAction = {fibaroAction[1]+ (incrementNumber * valueIncrement[1]),fibaroAction[2] + (incrementNumber * valueIncrement[2]),fibaroAction[3]+ (incrementNumber * valueIncrement[3]),fibaroAction[4]+ (incrementNumber * valueIncrement[4])};
        else
       		fibaro:debug("Invalid parameter")   
        end
      end
    else
      --just copy the value from original command
      newfibaroAction =  fibaroAction;
    end    
    -- add the action    
    if debugadd then 
      fibaro:debug("Action repeat " .. cn .. " added for days " .. d .. " at " .. sTime .. luaDaySchedule:paramasstring ( deviceID , " for device ") .. " the function is " .. fibaroFunction ..  luaDaySchedule:paramasstring(fibaroAction, "") ) 
    end      
    --add to the standard schedule table
    if schedule[newDay][newTime] == nill then    
      schedule[newDay][newTime]= {};
      schedule[newDay][newTime][cn] = {["device"] =  deviceID, ["action"] =  newfibaroAction , ["func"] = fibaroFunction , ["catchup"] = catchUpFlag };
    else
      schedule[newDay][newTime][cn] = {["device"] =  deviceID, ["action"] =  newfibaroAction , ["func"] = fibaroFunction , ["catchup"] = catchUpFlag };
    end            
    incrementNumber = incrementNumber + 1 ;
    --more lines
  end  
end
--run a loop that checks for scedules every 1 min
--the one that does all the work at run time
function luaDaySchedule:run()
  run = true;  
  -- we are starting to run so first catch up
  luaDaySchedule:catchUp(); 
  local lastdayitem;
  -- so this is the loop that checks for items by time key in the table
  while run do     
    --get the day and time we want to search for
    local currentDay = tostring(os.date("%w"));    
    local scheduleCheck = os.date("%H:%M"); --currentHour .. ":" .. currentMinute;    
    --load actions to execute at this time    
    --table for any scheduled actions found
    local found = {};
    --if it is time prepare today's solar based events
    if prepareSunScheduleRise == scheduleCheck then
      luaDaySchedule:prepareSolarRise()
    end    
     if prepareSunScheduleSet == scheduleCheck then
      luaDaySchedule:prepareSolarSet()
    end    
    --check if there any solar for this day this time
    found["SolarRise"] = scheduleSunLiveRise[currentDay][scheduleCheck];       
    found["SolarSet"] = scheduleSunLiveSet[currentDay][scheduleCheck];  
    --this exact day e.g. Monday
    found["ThisDay"] = schedule[currentDay][scheduleCheck];    
    --All days
    found["AllDays"] = schedule["7"][scheduleCheck]; --all
    --weekend only
    if ( currentDay == "0" or currentDay == "6") then
      found["WeekendDays"] = schedule["8"][scheduleCheck]; --weekend
    end
    --all weekdays
    if ( tonumber(currentDay) > 0 and tonumber(currentDay)  < 6) then
      found["WeekDays"] =schedule["9"][scheduleCheck];  --weekday
    end    
    -- execute any schedules that have loaded
    for i,sch in pairs(found) do
    	luaDaySchedule:executeSchedule(sch);
    end            
    --time to calculate when we should run
    if currentDayItem == "NOTSET"  or currentDayItem == lastdayitem then    	
      	--solar recalculated or just a start           
      	currentDayItem , lastdayitem = luaDaySchedule:prepareTimes();      	
    end
    --daySchedules[tostring(endtime)] = {timeserl = endtime, nextrun = tostring[endtime], sleepfor = (60*1000)};
  	local sheduletime = daySchedules[currentDayItem];    
    -- how far away from 30s past the minute
    timeDrift = os.time() - tonumber(currentDayItem)    
    currentDayItem = sheduletime.nextrun;
    -- pause untill we are needed again
    if reportRun then
      fibaro:debug ( "Next Run at " .. os.date("%H:%M:%S", tonumber(currentDayItem)));
      fibaro:debug ( "Correct by " .. timeDrift .. "s error,");
      fibaro:debug ( "Going to sleep for " .. tonumber(sheduletime.sleepfor/60000)  .. "mins");  
     end
    -- correct the time so next run is at 30s past scheduled minute   
    --sleep baby    
    fibaro:sleep(sheduletime.sleepfor - (timeDrift * 1000));  
    if reportRun then fibaro:debug ( "Schedule running at "  .. os.date("%H:%M:%S") ) end;
  end  
end
--runs once a day to calculate the solar based actions for the day
--prepare todays' solar events
function luaDaySchedule:prepareSolarRise() 
 	if scheduleSunMaster["Sunrise"]  ~= nil then
      -- OK we need to translate the sunrise and sunset values into action times
      -- loop through the master and generate based on current sunrise and sunset + offset
      -- and insert into live solar shedule
      -- this executes once a day so low overhead 
      -- first get the date serial for todays sunrise and sunset
      local sunriseToday = 	fibaro:getValue(1, "sunriseHour");
      local hourTimerise = tonumber(string.sub (sunriseToday, 1 , 2) );
      local minuteTimeRise = tonumber(string.sub(sunriseToday,4) );
      local todayIs = os.date("*t");
      --calculate the time serial number
      local serialTodayTimeRise = os.time{year=todayIs.year, month=todayIs.month, day=todayIs.day, hour=hourTimerise, min = minuteTimeRise};
      local todayDayIs = os.date("%w",serialtodaytime );
      local serialTodayTimeRiseShift; 
        --make sure new items from solar are found by the run loop
        --refresh the run schedule at the end of this run
      currentDayItem = "NOTSET";  
      -- remove old solar events
      scheduleSunLiveRise = {};
      --reset solar counter
      count = luaDaySchedule:newCounter();
      -- prepare to add new actions by addind days to table
      for i,d in pairs(luaDaySchedule.days) do
        scheduleSunLiveRise[d]= {};
      end
      -- cycle through rise records in master and add actions for the correct time for today
      for i,a in pairs(scheduleSunMaster["Sunrise"]) do    
            -- add to the live schedule 
            --fibaro:debug ( sunriseToday .. " " .. todayDayIs .. " " .. a.day)
            if (a.day == "7" or 
                a.day == todayDayIs or 
                ( a.day == "8" and (todayDayIs == "0" or todayDayIs == "6")) or 
                (a.day == "9" and ( tonumber(todayDayIs) > 0 and tonumber(todayDayIs)  < 6)   ) )then
                --fibaro:debug ( "shift "  .. a.sunshift )
                -- calculate the time including offset
                if a.sunshift ~= nil then
                     serialTodayTimeRiseShift = serialTodayTimeRise + (a.sunshift *60);
                else
                     serialTodayTimeRiseShift = serialTodayTimeRise;
                end       
                --add a sunrise action
                local sunrisetoset =  os.date("%H:%M",serialTodayTimeRiseShift); 
                --fibaro:debug(sunriseToday .. " " .. sunrisetoset)
                luaDaySchedule:addSolarRise(sunrisetoset,a.device,a.action,a.func,todayDayIs, a.catchup)
            else
                fibaro:debug("Bad solar day record!");
            end    
          end
      end
  end
--called each time we  create a true action from a solar template in master
-- called by the above function during the one run a day
--add the solar events
function luaDaySchedule:addSolarRise(sTime,deviceID,fibaroAction, fibaroFunction, sday , catchUpFlag)
  	local cn = count();
  	-- will run every day so remove
  	--must add debug flag an instrumentation
  	if debug then fibaro:debug("solar action " .. cn .. " added for day ID" .. sday .. " time " .. sTime .. " device " .. deviceID .. " function " .. fibaroFunction .. " action/value " ) end;
    if scheduleSunLiveRise[sday][sTime] == nill then    
      scheduleSunLiveRise[sday][sTime]= {};
      scheduleSunLiveRise[sday][sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["catchup"] = catchUpFlag };
    else
      scheduleSunLiveRise[sday][sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["catchup"] = catchUpFlag };
    end
end
-- and the set
function luaDaySchedule:prepareSolarSet()   
  if scheduleSunMaster["Sunset"] ~= nill then
    -- OK we need to translate the sunrise and sunset values into action times
    -- loop through the master and generate based on current sunrise and sunset + offset
    -- and insert into live solar shedule
    -- this executes once a day so low overhead 
    -- first get the date serial for todays sunrise and sunset
    local sunsetToday = 	fibaro:getValue(1, "sunsetHour");  
    local hourTimeset = tonumber(string.sub (sunsetToday, 1 , 2) );
    local minuteTimeSet = tonumber(string.sub(sunsetToday,4) );
    local todayIs = os.date("*t");
    local serialTodayTimeset = os.time{year=todayIs.year, month=todayIs.month, day=todayIs.day, hour= hourTimeset, min = minuteTimeSet};
    local todayDayIs = os.date("%w",serialtodaytime );
    local serialTodayTimesetShift;  
    --make sure new items from solar are found
    currentDayItem = "NOTSET";
    -- remove old solar events
    scheduleSunLiveSet = {};
    --reset solar counter
    count = luaDaySchedule:newCounter();
    -- prepare to add new ones
     for i,d in pairs(luaDaySchedule.days) do
         scheduleSunLiveSet[d]= {};
    end
     for i,a in pairs(scheduleSunMaster["Sunset"]) do    
          -- add to the live schedule 
          --fibaro:debug ( sunsetToday .. " " .. todayDayIs .. " " .. a.day)
          if (a.day == "7" or 
              a.day == todayDayIs or 
              ( a.day == "8" and (todayDayIs == "0" or todayDayIs == "6")) or 
              (a.day == "9" and ( tonumber(todayDayIs) > 0 and tonumber(todayDayIs)  < 6)   ) )then
                --fibaro:debug ( "shift "  .. a.sunshift )
              -- calculate the time including offset
              if a.sunshift ~= nil then
                   serialTodayTimesetShift = serialTodayTimeset + (a.sunshift *60);
              else
                   serialTodayTimesetShift = serialTodayTimeset;
              end 
              --add a sunset action
              local sunsettoset =  os.date("%H:%M",serialTodayTimesetShift);
              --fibaro:debug(sunsetToday .. " " .. sunsettoset)
              luaDaySchedule:addSolarSet(sunsettoset,a.device,a.action,a.func,todayDayIs, a.catchup)
          else
              fibaro:debug("Bad solar day record!");
          end     
        end
   	end
end
--called each time we  create a true action from a solar template in master
-- called by the above function during the one run a day
--add the solar events
function luaDaySchedule:addSolarSet(sTime,deviceID,fibaroAction, fibaroFunction, sday, catchUpFlag)
  	local cn = count();
  	-- will run every day so remove
  	--must add debug flag an instrumentation
  	if debug then fibaro:debug("solar action " .. cn .. " added for day ID" .. sday .. " time " .. sTime .. " device " .. deviceID .. " function " .. fibaroFunction .. " action/value " ) end;
    if scheduleSunLiveSet[sday][sTime] == nill then    
       scheduleSunLiveSet[sday][sTime]= {};
      scheduleSunLiveSet[sday][sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["catchup"] = catchUpFlag };
    else
       scheduleSunLiveSet[sday][sTime][cn] = {["device"] =  deviceID, ["action"] =  fibaroAction , ["func"] = fibaroFunction , ["catchup"] = catchUpFlag  };
    end
end
--build a table of times for today to control when to run
function luaDaySchedule:prepareTimes() 
  local timenow = os.date("*t")
  local timeserial = os.time({year = timenow.year, month=timenow.month, day=timenow.day, hour=timenow.hour, min=timenow.min,sec=30});
  local hourTime = tonumber(string.sub (prepareSunScheduleRise, 1 , 2) );
  local minuteTime = tonumber(string.sub(prepareSunScheduleRise,4) );
  local serialprepareSunScheduleRise  = os.time({year = timenow.year, month=timenow.month, day=timenow.day, hour=hourTime, min=minuteTime,sec=30});
   hourTime = tonumber(string.sub (prepareSunScheduleSet, 1 , 2) );
   minuteTime = tonumber(string.sub(prepareSunScheduleSet,4) ); 
  local serialPrepareSunScheduleSet  =  os.time({year = timenow.year, month=timenow.month, day=timenow.day, hour=hourTime, min=minuteTime,sec=30});
  local forwardtime = timeserial   ; 
  local endtime = timeserial + (24*60*60);  
  local currentSolarDay = tostring(os.date("%w")); 
  --clear last set of times
  local daySchedulesworking = {};
  daySchedules = {};
  --go get everything that will run in the next 24
  --this gets refreshed each time we calc solar
  --so this is more than we need but safe
  while forwardtime < endtime do     
    --get the day and time
    -- change current to catch time and date
    local currentDay = tostring(os.date("%w",forwardtime)); --the catch day   
    local scheduleCheck = os.date("%H:%M",forwardtime); --the catch time
    --load actions to execute at this time    
    --table for any scheduled actions found
    local found = {};  
    --check if there any solar
    -- sunset and sunrise will ony exist for today but it will do any actions this
    -- that should happen today
    found["SolarRise"] = scheduleSunLiveRise[currentSolarDay][scheduleCheck];      
    found["SolarSet"] = scheduleSunLiveSet[currentSolarDay][scheduleCheck];     
    --this exact day e.g. Monday
    found["ThisDay"] = schedule[currentDay][scheduleCheck];    
    --All days
    found["AllDays"] = schedule["7"][scheduleCheck]; --all
    --weekend only
    if ( currentDay == "0" or currentDay == "6") then
      found["WeekendDays"] = schedule["8"][scheduleCheck]; --weekend
    end
    --all weekdays
    if ( tonumber(currentDay) > 0 and tonumber(currentDay)  < 6) then
      found["WeekDays"] =schedule["9"][scheduleCheck];  --weekday
    end
    -- store the latest event for that device or variable
    for i,sch in pairs(found) do
    	for j,a in pairs(sch) do    
        	--just store the time
        	-- as the table is keyed by time only one record will be stored
            table.insert (daySchedulesworking,  forwardtime );
      		--fibaro:debug ( "Timer " .. os.date("%x %X",forwardtime) )
      	end
    end 
    forwardtime = forwardtime + 60 ;  --add 1 min in seconds   
  end
  -- add a record for now if nothing was found now
  table.insert (daySchedulesworking,  timeserial );
 	-- make sure we run when this is due tmrw
 table.insert (daySchedulesworking,  endtime );
  -- make sure it runs when sun related rebuilt
  table.insert (daySchedulesworking,  serialprepareSunScheduleRise );
  table.insert (daySchedulesworking,  serialPrepareSunScheduleSet );  
  -- make sure it runs when sun related rebuilt tomorrow  BUG FIX 1.1.3
  -- both sets needed? needs  thinking as dpends on set and rises refresh time setting
  table.insert (daySchedulesworking,  serialprepareSunScheduleRise + (24*60*60) );
  table.insert (daySchedulesworking,  serialPrepareSunScheduleSet + (24*60*60)); 
  	--now sort in time serial order so the time order of execution is preserved  
  table.sort(daySchedulesworking) --,function(a,b)       
  	local lastfoundkey = tostring(timeserial);
  	local endkey = tostring(endtime);
  	local startkey = tostring(timeserial);
  	local lastfoundserial= timeserial;
  	local countl = luaDaySchedule:newCounter()
  	local cn
  	-- add the next and how long to sleep rather than have a runtime load
  	-- this creates a walkable sequence
  	for j,a in ipairs(daySchedulesworking) do  
            if lastfoundkey ~= tostring(a) then
                    cn = countl()
                    daySchedules[lastfoundkey] = {ind = cn, oldind = j, timeserl = lastfoundserial ,nextrun = tostring(a) , sleepfor = ((a - lastfoundserial ) *1000) , lastrun = endtime };
            end
    	lastfoundserial = a
      	lastfoundkey = tostring(a);   
     end   
 	-- make sure the last record is good
  	-- if anything fails reverts to every minute by directing back to this record
 	daySchedules[endkey] = {timeserl = endtime, nextrun = endkey, sleepfor = (60*1000)};
  	if debug then
            local lastin =  tostring(timeserial)  
            local a = daySchedules[lastin]
           --fibaro:debug ( "Timer " .. os.date("%H:%M:%S",a.timeserl) .. " Next Timer " .. os.date("%H:%M",a.nextrun) .. " Sleep for " ..    a.sleepfor )
            while endtime > a.timeserl do 
                a = daySchedules[lastin]
               fibaro:debug ( "Timer " .. os.date("%H:%M:%S",a.timeserl) .. " Next Timer " .. os.date("%H:%M:%S",a.nextrun) .. " Sleep for " ..    a.sleepfor )
            lastin =  tostring(a.nextrun)    	
            end  
        end
        -- return the keys
  	return startkey , endkey;
end
--builds a set of actions that should have run in the last 24hrs or week
--runs at startup only and puts the HC2 state to somewhere near what the HC2
-- should be at the time of restart
function luaDaySchedule:catchUp()  
  local timeserial = os.time();
  local catchtime = timeserial - doCatchUp ;  --set the catch up time to now - 1 day
  local finalstate = {};  
  local currentSolarDay = tostring(os.date("%w")); 
  while catchtime < os.time() do     
    --get the day and time
    -- change current to catch time and date
    local currentDay = tostring(os.date("%w",catchtime)); --the catch day   
    local scheduleCheck = os.date("%H:%M",catchtime); --the catch time
    --load actions to execute at this time    
    --table for any scheduled actions found
    local found = {};
    --solar info will be for now on Fibaro but the error should not impact
    --catch up
     --if it is time prepare today's solar based events
    if prepareSunScheduleRise == scheduleCheck then
      luaDaySchedule:prepareSolarRise()
    end    
    if prepareSunScheduleSet == scheduleCheck then
      luaDaySchedule:prepareSolarSet()
    end
    --check if there any solar
    -- sunset and sunrise will ony exist for today but it will do any actions this
    -- that should happen today
    found["SolarRise"] = scheduleSunLiveRise[currentSolarDay][scheduleCheck];    
    found["SolarSet"] = scheduleSunLiveSet[currentSolarDay][scheduleCheck];      
    --this exact day e.g. Monday
    found["ThisDay"] = schedule[currentDay][scheduleCheck];    
    --All days
    found["AllDays"] = schedule["7"][scheduleCheck]; --all
    --weekend only
    if ( currentDay == "0" or currentDay == "6") then
      found["WeekendDays"] = schedule["8"][scheduleCheck]; --weekend
    end
    --all weekdays
    if ( tonumber(currentDay) > 0 and tonumber(currentDay)  < 6) then
      found["WeekDays"] =schedule["9"][scheduleCheck];  --weekday
    end
    -- store the latest event for that scene, device or variable
    for i,sch in pairs(found) do
    	for j,a in pairs(sch) do    
        	--as we are going through in schedule order the 
        	--last call should be stored 
        	--when we get to now for each device or variable
        	if a.catchup then
    			finalstate[luaDaySchedule:paramasstring ( a.device , " for device ") .. a.func ] = {["device"] =  a.device, ["action"] =  a.action , ["func"] = a.func , ["timser"] = catchtime };
    			--fibaro:debug(a.device)
        	end
      	end
    end 
    catchtime = catchtime + 60 ;  --add 1 min in seconds   
  end    
  local sortedfinal = {};
  for i,a in pairs(finalstate) do    
    table.insert(sortedfinal,a)
  end  
  --now sort in time serial order so the time order of execution is preserved  
  table.sort(sortedfinal,function(a,b) 
      if a.timser == b.timser then return a.timser<b.timser end
      return a.timser<b.timser
    end)  
  --run the last event for each device/variable that should have executed 
  --by the schedule
  if reportRun then  fibaro:debug( "Catching up actions.")end
 	for i,a in ipairs(sortedfinal) do   
    	if reportRun then  fibaro:debug( "Event scheduled for " .. os.date("%x at %H:%M", a.timser))end
    	luaDaySchedule.fibMap[a.func](a.device, a.action);
    	--fibaro:sleep(1000); --pause 1 second to allow HC2 to process
    end
  if reportRun then  fibaro:debug( "Catching up finished.")end 
end
--execute the actions
--called each time an action is executed
function luaDaySchedule:executeSchedule(sRun)   
  	for i,a in pairs(sRun) do    
    	luaDaySchedule.fibMap[a.func](a.device, a.action);
    	--fibaro:sleep(1000); --pause 1 second to allow HC2 to process
    end
end
-- end schedule engine code
-- now lets set it up and run it
-- the debug will print the items you have set
-- only runs once on load so no overhead
-- all lines below  execute only once on start
-- init
luaDaySchedule:init();
-- DO NOT EDIT SECTION END
-- USER EDIT SECTION START
--***********************add the schedule items************************

-- users add all schedule actions to this section

--examples
--turnOn  device  id 101 every day at 22:53 with catchup
--luaDaySchedule:add("22:53","101", "turnOn" , "call", {"All"} , true ) 

--turnOff a device id 101 at 12:53 on Monday and Friday without catchup
--luaDaySchedule:add("12:53","101", "turnOff" , "call", {"Monday","Friday"} ,false) --turnOff a device

-- setValue to 50 for device id 104 at 06:53 on Monday to Friday
--luaDaySchedule:add("06:53","104", 50 , "setValue", {"weekday"}  ,false) 

-- you cad add many at intervals to slowly dim or brighten lights

--set a global TimeOfDay to Morning at 05:00 on Saturday and Sundaywith catchup
--luaDaySchedule:add("05:00","TimeOfDay", "Morning" , "setGlobal", {"Weekend"}  ,true)

--run scene id 21 at 13:30 Monday to Friday
--luaDaySchedule:add("13:30","21", "" , "startScene", {"Weekday"}  ,false) 

-- killScenes scene id 21 at 19:30 Monday to Friday
--luaDaySchedule:add("19:30","21", "" , "killScenes" {"Weekday"}  ,false) 

--setSceneEnabled id 21  at 15:30 Monday to Friday
--luaDaySchedule:add("15:30","21", true , "setSceneEnabled" {"Weekday"}  ,true) 

--debug dbg1: my message to the scene window   at 19:30 Monday to Friday
--luaDaySchedule:add("19:30","dbg1", "my message" , "debug" {"Weekday"}  ,true) 

-- press a virtual device id 78 button 1 at 13:30 on Weekend and wednesday
--luaDaySchedule:add("13:30","78", 1 , "pressButton", {"Weekend","Wednesday"}  ,false)

-- set a virtual device id 78 slider 2 set to 50 at 13:30 on Monday Tuesday and Wednesday
--luaDaySchedule:add("13:30","78", {2,50} , "setSlider", {"Monday","Tuesday","Wednesday"}  ,false)

-- set armed value of device 99 for door and window sensors
--luaDaySchedule:add("05:29","99", 0 , "setArmed", {"Weekday"}  ,false)

-- multi action uses 3 parameters after a normal schedule item
-- first is repeat
--second is interval
-- third is an increment added to the value for sliders and dimmers

-- press a virtual device id 184 button 1 at 07:51 + 5 more times at 2min interval on Tuesday and Wednesday 5 repeats
--luaDaySchedule:add("23:00","85",1,"pressButton",{"All"} ,false )  --,5,2  )
--luaDaySchedule:add("05:30","85",2,"pressButton",{"All"} ,false )
-- set a virtual device id 184 slider 6 set to 50 at 07:51 on Monday , Tuesday and Wednesday then increase 10 every 2 mins 5 repeats
--luaDaySchedule:add("07:51","184", {6,10} , "setSlider", {"Monday","Tuesday","Wednesday"} ,false ,5,2 ,10)

--turn 122 off at 7:51 each day and repeat  5 times at 2 min intervals
--luaDaySchedule:add("07:51","122", "turnOff" , "call", {"All"} ,false,5,2 )

-- set RGB value of device 109
--luaDaySchedule:add("05:29","109", { 255, 255, 255, 100 } , "setRGBColor", {"Weekday"} ,false )
-- or
--luaDaySchedule:add("05:29","109", { 255, 255, 255, 100 } , "setRGBColor", {"Weekday"} ,false )

-- set RGB value of device 109 and incremetn values with mutiple calls
--luaDaySchedule:add("05:29","109", { 170, 150, 80, 20 } , "setRGBColor", {"Weekday"} ,false,5,1,{ -10,20,30,10} ) 
--or
--luaDaySchedule:add("05:29","109", { 170, 150, 80, 20 } , "setColor", {"Weekday"} ,false,5,1,{ -10,20,30,10} ) 

-- also for RGB

--luaDaySchedule:add("05:29","109", 100  , "setW", {"Weekday"} ,false )
--luaDaySchedule:add("05:29","109", 100  , "setR", {"Weekday"} ,false )
--luaDaySchedule:add("05:29","109", 100  , "setG", {"Weekday"} ,false )
--luaDaySchedule:add("05:29","109", 100  , "setB", {"Weekday"} ,false )

-- and

--luaDaySchedule:add("05:29","109", 100  , "startProgram", {"Weekday"} ,false )



-- set temperature value of device 111 
--luaDaySchedule:add("05:29","109", 18 , "setTargetLevel", {"All"} ,true )

-- run at 11 minutes before sunset i.e. - 11 minutes the shift can be any + or - number
-- luaDaySchedule:add("Sunset","NightTime", "1" , "setGlobal", {"All"} ,false , - 11)
-- run at 27 minutes after sunrise  i.e. + 27 minutes
-- luaDaySchedule:add("Sunrise","NightTime", "0" , "setGlobal", {"All"}  ,false , 27 )

--setup thermostat id 62 to 16 and for 1h  at 11:19 everyday and catch up on restart
--luaDaySchedule:add("11:19","62", {16 , 3600}, "setThermostat", {"All"} ,true )

--get the value timeStamp from devise id 62  and save to global "myVar" at 12:19 everyday
--luaDaySchedule:add("12:19","62", {"myVar" , "timeStamp"}, "getValue", {"All"} ,true )
-- just print the value to debug
--luaDaySchedule:add("12:19","62", {"debug" , "timeStamp"}, "getValue", {"All"} ,true )

-- an example of adding a function "getTimeValFromNow"... you can add any function that takes two
-- parameters. Each parameter can be a table of values in this case two strings are used
-- see lines 
-- "add your own function call here but avoid long running or functions that sleep"
-- "add map to your own function call here"
-- if the function body is long put under comment "you could of course add any function here and schedule using the body"

--get the run time remaining from devise id 62  and save to global "myVar" at 12:19 everyday
--luaDaySchedule:add("12:19","62", "myVar" , "getTimeValFromNow", {"All"} ,true )
-- just print the value to debug
--luaDaySchedule:add("12:19","62", "debug" , "getTimeValFromNow", {"All"} ,true )
-- a function that gets the temperature from 4 temperature sensors  and stores in 4 globals every 30 mins
--luaDaySchedule:add("12:19",{167,168,169,170}, {"var1","var2","var3","var4"} , "SpecialFunctionExample", {"All"} ,true , 47, 30 );

-- mutiple devices , scenes , globals 
--turn multiple devices off at 10:30 
--luaDaySchedule:add("10:30",{"122","123","121","118","119"}, "turnOff" , "call", {"All"} ,true )

-- set target level 0f 62 and 175 to 20
--luaDaySchedule:add("10:49",{"62","175"}, 20 , "setTargetLevel", {"All"} ,true )

-- set target level 0f 62 to 20 and 175 to 18
--luaDaySchedule:add("10:49",{"62","175"}, {20,18} , "setTargetLevel", {"All"} ,true )

-- send notifications
--luaDaySchedule:add("10:49",{"2","2"}, {1,2} , "sendDefinedEmailNotification", {"All"} ,true )
--luaDaySchedule:add("10:49","2", 1 , "sendDefinedEmailNotification", {"All"} ,true )
--luaDaySchedule:add("10:49","229", 1 , "sendDefinedPushNotification", {"All"} ,true )
--luaDaySchedule:add("10:49",{"229","252"}, {2,2} , "sendDefinedPushNotification", {"All"} ,true )

--luaDaySchedule:add("10:49",{"2","2"}, {1,2} , "sendGlobalEmailNotifications", {"All"} ,true )
--luaDaySchedule:add("10:49","2", 1 , "sendGlobalEmailNotifications", {"All"} ,true )
--luaDaySchedule:add("10:49","229", 1 , "sendGlobalPushNotifications", {"All"} ,true )
--luaDaySchedule:add("10:49",{"229","252"}, {2,2} , "sendGlobalPushNotifications", {"All"} ,true )

--luaDaySchedule:add("10:49",'189', {'title' ,'body message'} , "sendEmail", {"All"} ,true )

--<ADD YOUR LINES HERE>


--*************************end of add******************************
-- you can change how many days of events are processsed to work out
-- what the current state should be uncomment the value you want
-- only one line should live
doCatchUp = luaDaySchedule.catchUpInterval ["24hrs"];
--doCatchUp = luaDaySchedule.catchUpInterval ["None"];
--doCatchUp = luaDaySchedule.catchUpInterval ["1Week"];
--**********************************************************************
--you could of course add any function here and schedule using the body
function luaDaySchedule:SpecialFunctionExample( devices, globals)
    --do what you like
  --in this example first param is an table of device id
  --the second an array of globals to save value 
  -- if we had the net lib in scenes we could call or get values from 
  -- another system  
  for i,v in ipairs(devices) do    
   	 fibaro:setGlobal(globals[i], fibaro:getValue(v,"value"));  
  end  
end
--**********************************************************************
-- USER EDIT SECTION END
-- DO NOT EDIT SECTION START
--run the schedule
luaDaySchedule:run();
-- DO NOT EDIT SECTION END
--end scene