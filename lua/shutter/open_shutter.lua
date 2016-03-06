--[[
%% properties
%% globals
--]]

-- Version 1.0.0 - (C) Xavier Beaudouin - 2014 - Under The MPL 1.1 LICENSE

-- Shutter to be upped
local shutters = { 96, 218 };

-- Avoid multiple launch of this script
if (fibaro:countScenes()>1) then 
  fibaro:debug('Second instance closed') 
  fibaro:abort(); 
end  

-- Check if this the night
if (fibaro:getGlobalValue("NightTime") == "0")
then
	fibaro:debug("Daytime, so we can open");
	-- Daytime so we can work
	for i,v in ipairs(shutter) do
		-- Get the position of shutter
		local cur_shutter = tonumber(fibaro:getValue(v, "value"));
		if (cur_shutter < 99.0)
		then
			-- Up the shutter
			fibaro:call(v, "setValue", 99.0);
		end
		fibaro:sleep(6*1000);
	end
else
	fibaro:debug("Night Time !");
end
