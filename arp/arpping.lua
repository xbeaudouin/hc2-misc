local thismodule = fibaro:getSelfId();
local ip = fibaro:get(thismodule, 'IPAddress');
local port = fibaro:get(thismodule, 'TCPPort');
local cgi = "/kiwi/arp.pl";
local what = "ikiwi";
-- DON'T FORGET to create global variable Phone_ with "what" content
-- ie if what="ikiwi", then the GV will be : Phone_ikiwi or change the 
-- following
local gbname = "Phone_"..what;

fibaro:debug("ARP : http://"..ip..":"..port..cgi);

local arpstuff = pcall(function()

    -- Create the global variable name
    local gbname = "Phone_"..what;
    
    local ARP = Net.FHttp(ip,port);

    local response, status, errorCode = ARP:GET(cgi.."?host="..what);
    --fibaro:debug("Debug : r : "..response.."\n");
    --fibaro:debug("Debug : s : "..status.."\n");
    --fibaro:debug("Debug : e : "..errorCode.."\n");
    if(tonumber(status)==200)
    then
	-- enregistrement du retour de l API dans une table
	response = json.decode(response);
	fibaro:debug(response.hostname);
	fibaro:debug(response.MAC);
	if(response.MAC == "unknown")
	then
		fibaro:debug(what.." is not at home");
		if (fibaro:getGlobalValue(gbname)=="1")
		then
			fibaro:setGlobal(gbname,"0");
		end;	
		fibaro:log(what.." is not at home");
	else
		fibaro:debug(what.." is at home");
		if (fibaro:getGlobalValue(gbname)=="0")
		then
			fibaro:setGlobal(gbname,"1");
		end
		fibaro:log(what.." is at home");
	end;
			
    else
       fibaro:debug("status: " .. tostring(status or "")); 
       fibaro:debug("error code: " .. tostring(errorCode or "")); 
    end;
end);
    

if (not arpstuff) then
	fibaro:debug("ARP polling failed");
end;

