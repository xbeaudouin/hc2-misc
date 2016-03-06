--[[
%% properties
3 WeatherConditionConverted
%% globals
--]]

-- Version 1.0.3 - (C) Xavier Beaudouin under the MPL 1.1 LICENSE

-- set here sensors
local tempsensors = { 34, 123 };
-- Create array with same index than temp sensors (used to cache max temps per day)
local max_temp = {
  [34] = -99.0,
  [123]= -99.0,
 };

-- Roller Shutter associated (ONLY ROLLER SHUTTER !) to the sensors
local a_shutters = {
   [34]  = { 96, 218 }, 
   [123] = { 97 },
  };

-- Door sensors associated to Roller Shutter
local shutter_sensors = {
   [96] = 77 ,
   [97] = 75 ,
   [218]= 83 ,
  };
   

-- set limit when shutter has to go down
local templimit     = 25.0;
local shutter_open  = 99.0;
-- Adjust with the right numbers needed to get right calibration.
local shutter_close = { 
  [96] = 44.0,
  [97] = 40.0,
  [218]= 20.0,
 };

-- Hour and minute in the morning when shutter are not to be upped if 
-- current time is below this hour and minutes
local minhour    = 10;
local minminutes = 30;

-- debug or not
debug = true;

-- Don't change anthing there
-- Variable delay stuff depending of meteo and night 
-- sleepdelta is number of 10 minutes respawn of this script
local sleepdelta = 1;

-- Avoid multiple launch of this script
if (fibaro:countScenes()>1) then 
  fibaro:debug('Second instance closed') 
  fibaro:abort(); 
end  

-- functions
function mydebug(string)
 if (debug)
 then
    fibaro:debug(string);
 end
end

function checktime()
  local todayIs = os.date("*t");
  local destdate = os.time{year=todayIs.year,month=todayIs.month, day=todayIs.day, hour=minhour, min=minminutes};
  local currenttime = os.time();
  mydebug("Time is : "..todayIs.hour..":"..todayIs.min);
  mydebug("Comparing to "..minhour..":"..minminutes);
  mydebug("Current time is : "..currenttime);
  mydebug("Dest time is : "..destdate);
  if (currenttime < destdate)
  then
    mydebug("Time is < -> ok");
    return true;
  else
    mydebug("Current time is > ");
    return false;
  end
  return false;
end

function check_shutter(shutters, what)
    local value;
    mydebug("-- check_shutter()");
    for s,z in ipairs(shutters) do
      if (what == "up")
      then
        value = shutter_open;
      elseif (what == "down")
      then
        value = shutter_close[z];
      end
      
      local cur_shutter = tonumber(fibaro:getValue(z, "value"));
      local shutter_name = fibaro:getName(z);
      mydebug("--- Shutter "..shutter_name.."("..z..") is currently : "..cur_shutter.." comparing to command : "..value);
      if (what == "up")
      then
        if (cur_shutter >= value)
        then
          mydebug("---- Shutter is ok, skip");
        else
          if (checktime())
          then
            mydebug("---- Current time is < to ".. minhour..":"..minminutes.." : don't up the shutter");
          else
            mydebug("---- Shutter is to be upped");
            fibaro:call(z, "setValue", value);
          end
        end
      elseif (what == "down")
      then
        if (cur_shutter <= value)
        then
          mydebug("---- Shutter is ok, skip");
        else
          mydebug("---- Shutter has to be downed");
          -- Check if door is open. If not, then close the shutter
          local door_is_open = tonumber(fibaro:getValue(shutter_sensors[z], "value"));
          if (door_is_open == 1)
          then
             mydebug("----- Door / Window is open : don't close "..z);
          else
             mydebug("----- Yes we close "..z);
             fibaro:call(z, "setValue", value);
           end
        end
      end
      -- Sleep for 10 seconds
      mydebug(" 10 sec sleep");
      fibaro:sleep(10*1000);
    end
    return 0;
end


function do_shutter_work()
  -- Do the real Shutter work
  sleepdelta=1;
  fibaro:debug("- Now figure if we need to get down shutter");
  for i,v in ipairs(tempsensors) do
    local cur_temp = tonumber(fibaro:getValue(v, "value"));
    local temp_name = fibaro:getName(v);
    fibaro:debug("- Sensor "..temp_name.."("..v..") has temperature "..cur_temp.."°C"); 
    -- Update the cache if needed.
    if (cur_temp > max_temp[v])
    then
      fibaro:debug("- Update cache for "..v);
      max_temp[v] = cur_temp;
      
      if (cur_temp > templimit)
      then
        fibaro:debug("-- Temp is out limit");
          
        check_shutter(a_shutters[v], "down");
      end
    else
      if (cur_temp < templimit)
      then
        fibaro:debug("-- Temp is under limit");
          
        check_shutter(a_shutters[v], "up");
      end
    end
 end
 end
  
-- main code
while true do
  -- Check it this is night
  if ( fibaro:getGlobalValue("NightTime") == "0")
  then
    local meteo = fibaro:getValue(3, "WeatherConditionConverted");
    
    -- Meteo can be : clear, fog, cloudy
 
    fibaro:debug("Weather is ".. meteo);
    if (meteo == "clear")
    then
      do_shutter_work();
    else
      if (meteo == "cloudy")
      -- Even if meteo is cloudy it can be hot
      then
        do_shutter_work();
      else
        -- Sleep for 20 Minutes
        sleepdelta=2;
      end
    end
  else
    fibaro:debug("This is night, nothing to do...");
    -- Reset the temperature to default values
    for i,v in ipairs(tempsensors) do
      max_temp[v] = -99.0;
    end
    -- Sleep for one hour
    sleepdelta=6;
  end
  if (sleepdelta == 0)
  then
     sleepdelta = 1; -- 10 Minutes
  end
  fibaro:debug("Sleep for "..(sleepdelta*10).." minutes...");
  fibaro:sleep(sleepdelta*600*1000);
end

