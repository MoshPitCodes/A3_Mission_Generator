// Set-up mission variables.
params [ ["_zoneID", 0], ["_targetPos", [0,0,0]] ];

_centre = missionNamespace getVariable [format["ZMM_%1_Location", _zoneID], _targetPos];
_playerSide = missionNamespace getVariable [ "ZMM_playerSide", WEST ];
_radius = ((getMarkerSize format["MKR_%1_MIN", _zoneID])#0) max 25; // Area of Zone.
_locName = missionNamespace getVariable [format["ZMM_%1_Name", _zoneID], "this Location"];
_locType = missionNamespace getVariable [format["ZMM_%1_Type", _zoneID], "Custom"];

_missionDesc = [
		"Enemy forces are trying to take over <font color='#00FFFF'>%1</font>, defend the location at all costs.",
		"A number of enemy groups are advancing towards <font color='#00FFFF'>%1</font>, hold the area until called to exfil.",
		"Eliminate all enemy forces heading into <font color='#00FFFF'>%1</font>, hold off the enemy for a specified time.",
		"Enemy forces have launched an attack on <font color='#00FFFF'>%1</font>, defend the area until called to extract.",
		"The enemy is trying to occupy <font color='#00FFFF'>%1</font>, prevent enemy forces from taking the town.",
		"Enemy forces are planning to invade <font color='#00FFFF'>%1</font>, hold the area from attackers for a specified time before withdrawing."
	];
	
if (count (missionNamespace getVariable [ format["ZMM_%1_QRFLocations", _zoneID], []]) == 0) exitWith { 
	["ERROR", format["Zone%1 - No valid QRF locations, cannot create objective!", _zoneID]] call zmm_fnc_logMsg;
	false 
};

if (missionNamespace getVariable [format[ "ZMM_%1_QRFTime", _zoneID ], 0] == 0) then { missionNamespace setVariable [format[ "ZMM_%1_QRFTime", _zoneID ], 300] };

// Overwrite depending on location
_waves = switch (_locType) do {
	case "Airport": { 5 };
	case "NameCityCapital": { 5 };
	case "NameCity": { 4 };
	case "NameVillage": { 3 };
	case "NameLocal": { 3 };
	default { 3 };
};

_delay = missionNamespace getVariable [format[ "ZMM_%1_QRFTime", _zoneID ], 300];

_timePerWave = 300;
_time = _waves * _timePerWave;

[ _zoneID, false, _delay, _waves] spawn zmm_fnc_areaQRF;

// Create Information Trigger
_infTrigger = createTrigger ["EmptyDetector", _centre, FALSE];
_infTrigger setTriggerArea [_radius, _radius, 0, FALSE];
_infTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", FALSE];
_objTrigger setTriggerTimeout [120, 120, 120, FALSE];
_infTrigger setTriggerStatements [  "this", 
									format["['Command','Enemy forces inbound. Hold %1 for %2 minutes.'] remoteExec ['BIS_fnc_showSubtitle',0];", _locName, _time / 60],
									"" ];
									
// Create Completion Trigger
_objTrigger = createTrigger ["EmptyDetector", _centre, FALSE];
_objTrigger setTriggerArea [_radius, _radius, 0, FALSE];
_objTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", FALSE];
_objTrigger setTriggerTimeout [_time, _time, _time, FALSE];
_objTrigger setTriggerStatements [ 	"this", 
									format["['ZMM_%1_TSK', 'Succeeded', TRUE] spawn BIS_fnc_taskSetState; missionNamespace setVariable ['ZMM_DONE', TRUE, TRUE]; { _x setMarkerColor 'Color%2' } forEach ['MKR_%1_LOC','MKR_%1_MIN']", _zoneID, _playerSide],
									"" ];

// Create Task
_missionTask = [format["ZMM_%1_TSK", _zoneID], TRUE, [format["<font color='#00FF80'>Mission (#ID%1)</font><br/>", _zoneID] + format[selectRandom _missionDesc, _locName], ["Defence"] call zmm_fnc_nameGen, format["MKR_%1_LOC", _zoneID]], _centre, "AUTOASSIGNED", 1, FALSE, TRUE, "defend"] call BIS_fnc_setTask;

TRUE