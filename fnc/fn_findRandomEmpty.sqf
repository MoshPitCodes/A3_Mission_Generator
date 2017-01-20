// Finds a small random empty position, can avoid blacklisted areas (tg_blackList) - Defaults to a random empty area if position not provided.
//
// *** PARAMETERS ***
// _searchPos	ARRAY		Position to search around.
// _minDist		INT		
// _maxDist		INT
// _skipSafe	BOOLEAN		Skip any Blacklist/Safe Zone checking.
//
// *** RETURNS ***
// Position Array
//
// *** USAGE ***
// _searchPos = [[0,0,0], 100, 500, false] call tg_fnc_findRandomEmpty;

params [["_searchPos",[],[[]]], ["_minDist",1,[1]], ["_maxDist",1000,[1000]], ["_skipSafe", false, [false]]];

//[format ["[TG] DEBUG - fn_findRandomEmpty: Called (Pos: %1, Min: %2, Max: %3, Skip: %4)", _searchPos, _minDist, _maxDist, _skipSafe]] call tg_fnc_debugMsg;

// If no position was passed, use world centre
if (_searchPos isEqualTo []) then {
	_searchPos = [] call tg_fnc_findWorldLocation;
};

// Get blackList of Safe Zones, otherwise use empty array.
_blackList = if (_skipSafe) then { [] } else { missionNamespace getVariable ["tg_blackList_marker",[]] };

_searchPos = [[_searchPos select 0, _searchPos select 1, 0], _minDist, _maxDist, 3, 0, 0.25, 0, _blackList] call BIS_fnc_findSafePos;

// World centre has been passed so try and find something near that point, ignoring safety.
if (getArray(configFile >> "CfgWorlds" >> worldName >> "centerPosition") isEqualTo _searchPos && !_skipSafe) then {
	[format ["[TG] DEBUG - fn_findRandomEmpty: No safe position found at %1 - WorldCentre was read", _searchPos]] call tg_fnc_debugMsg;
	_searchPos = [_searchPos, 400, 1000, true] call tg_fnc_findRandomEmpty;
};

/*if tg_debug then {
	_tmpMkr = createMarkerLocal[format["markerRandomEmpty_%1", ceil random 100000], _searchPos];
	_tmpMkr setMarkerTextLocal "RandomEmpty";
	_tmpMkr setMarkerShapeLocal "ICON";
	_tmpMkr setMarkerColorLocal "colorBlue";
	_tmpMkr setMarkerSizeLocal [0.5,0.5];
	_tmpMkr setMarkerTypeLocal "mil_dot";
};*/

_searchPos = [_searchPos select 0, _searchPos select 1, 0];

[format ["[TG] DEBUG - fn_findRandomEmpty: Returning %1", _searchPos]] call tg_fnc_debugMsg;

_searchPos