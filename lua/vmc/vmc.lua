--[[
%% properties
26 value
121 value
49 value
17 value
%% globals
%% autostart
--]]

--[[
 Auto start VMC for HC2 v1.0.4 Beta
 By Xavier BEAUDOUIN
 License is MPL 1.1
--]]

-- ID of humidity modules 
-- Don't touch nb_cap !
local hum_cap  = {26, 121, 49, 17};
local nb_cap   = #hum_cap; 
-- ID of VMC modules
local vmc_low  = 108;
local vmc_high = 110;

-- Don't touch that
local run = 1;


function go_and_run(switch_off)
	local hum=0;
	local max_hum=0;
	local max_hum_high=0;
	local raize_vmc=0;
	local raize_vmc_high=0;
	local run = 1;

	fibaro:debug ("Run at ".. os.date("%H:%M:%S" ));
  
	for i,v in ipairs(hum_cap) do
	   local cur_hum = tonumber(fibaro:getValue(v, "value"));
	   hum = hum + cur_hum;
	end;

	hum = hum / nb_cap;
	-- Compute when to start low speed and high speed.
	max_hum_high = hum * 1.180;
	max_hum = hum * 1.105;

	fibaro:debug("Average humidity is " .. hum .. "%");
	fibaro:debug("Max hum check is ".. max_hum .. "% (Low) / " .. max_hum_high .."% (high)");

	fibaro:debug("Check if there some humidity extractor to do...");

	for i,v in ipairs(hum_cap) do
	   local cur_hum = tonumber(fibaro:getValue(v, "value"));
	   fibaro:debug("Humidity for " .. v .. " is " .. cur_hum .."%");
	   if cur_hum > max_hum
	   then
	      raize_vmc=1;
	      fibaro:debug("LOW");
	   end;
	   if cur_hum > max_hum_high
	   then
	      raize_vmc_high=1;
	      fibaro:debug("HIGH");
	   end;
	end;

	if hum > 75
	then
	   fibaro:debug("Avg Hum is > 85% VMC forced");
	   raize_vmc=1;
	   raize_vmc_high=1;
	end;
  
	-- If there is raize_vmc and raize_vmc_high, then start vmc
	if raize_vmc == 1
	then
	  fibaro:debug("Have switch on VMC...");
	  fibaro:call(vmc_low, "turnOn");
	  if raize_vmc_high == 1
	  then
	      fibaro:debug("Have switch HIGH speed on VMC...");
	      fibaro:call(vmc_high, "turnOn");
	  else
	      fibaro:debug("High speed off");
	      fibaro:call(vmc_high, "turnOff");
	  end;
	else
		if switch_off == 1
		then
			fibaro:debug("Switch all this off");
			fibaro:call(vmc_high, "turnOff");
			fibaro:sleep(500);	-- ZWave Tidy..
			fibaro:call(vmc_low, "turnOff");
		end;
	end;
end;


if (fibaro:countScenes() > 1)
then 
	fibaro:debug("Humidy event reached : recompute...");
	go_and_run(0);
	fibaro:sleep(1000);
	fibaro:abort();	
end;

-- Main loop
while run
do
	go_and_run(1);
	fibaro:sleep(10*60*1000);
end;
