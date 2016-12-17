// _missionName	STRING		Mission this is related to - Trigger will be created to DELETE the zone when this is TRUE (i.e. done)
// _part		STRING		Unique name for the DAC Zone itself.
// _location	ARRAY		Position of the 
// _size		INThe		Size of the DAC Zone (+300 for the trigger).
// _DACinit		ARRAY		DAC Init array.

params [["_missionName","",[""]], ["_part","",[""]], "_location", ["_size",500,[0]], "_DACinit"];

_zoneName = format["%1_%2", _missionName, _part];
_timeOut = 5;

// Check something isn't badly wrong.
if (!isNil (missionNamespace getVariable format["TR_%1", _zoneName])) exitWith {
	[format["[TG-%1] WARNING: Trigger 'TR_%1' already exists.",_zoneName]] call tg_fnc_debugMsg;
};

// DAC can only spawn one zone at a time, wait until the previous is completed.
waitUntil{sleep 0.5; DAC_NewZone == 0;};

// Create the DAC Zone
[format["[TG-%1] DEBUG: Zone Init: %2",_zoneName,_DACinit]] call tg_fnc_debugMsg;
[_location, _size, _size, 0, 0, [_zoneName] + _DACinit] call DAC_fNewZone;

// Create a Trigger to delete the Zone after mission completed and no-one is present.
_deleteAreaTrigger = createTrigger ["EmptyDetector", _location, false];
_deleteAreaTrigger setTriggerTimeout [_timeOut, _timeOut, _timeOut, false];
_deleteAreaTrigger setTriggerArea [_size + 300, _size + 300, 0, true];
_deleteAreaTrigger setTriggerActivation [format["%1", tg_playerSide], "NOT PRESENT", false];
//_deleteAreaTrigger setTriggerActivation ["ANYPLAYER", "NOT PRESENT", false];
_deleteAreaTrigger setTriggerStatements [	format["missionNamespace getVariable ['%1',false] && this", _missionName], 
											format["[] spawn {waitUntil{sleep 0.5; DAC_NewZone == 0;}; ['%1'] call DAC_fDeleteZone; ['Deleting TR_%1 - Completed %2 and %3 not present.'] call tg_fnc_debugMsg;};", _zoneName, _missionName, tg_playerSide], 
											"" ];

missionNamespace setVariable [format["TR_%1", _zoneName], _deleteAreaTrigger];

[format["[TG] DEBUG: Trigger 'TR_%1' created.",_zoneName]] call tg_fnc_debugMsg;