// Defend a specified location or area.
// Set-up mission variables.
params [ ["_zoneID", 0], ["_targetPos", [0,0,0]] ];

private _centre = missionNamespace getVariable [format["ZMM_%1_Location", _zoneID], _targetPos];
private _playerSide = missionNamespace getVariable [ "ZMM_playerSide", WEST ];
private _radius = ((getMarkerSize format["MKR_%1_MIN", _zoneID])#0) max 25; // Area of Zone.
private _locName = missionNamespace getVariable [format["ZMM_%1_Name", _zoneID], "this Location"];
private _locType = missionNamespace getVariable [format["ZMM_%1_Type", _zoneID], "Custom"];

private _missionDesc = [
		"Enemy forces are trying to take over <font color='#00FFFF'>%1</font>. Clear out and then defend the location at all costs for <font color='#00FFFF'>%2 Minutes</font>.",
		"A number of enemy groups are advancing towards <font color='#00FFFF'>%1</font>. Eliminate any enemy already there, then hold the area for <font color='#00FFFF'>%2 Minutes</font> until called to exfil.",
		"Eliminate all enemy forces heading into <font color='#00FFFF'>%1</font>. Enemy forces may already be present, secure the area, then hold off the enemy for <font color='#00FFFF'>%2 Minutes</font>.",
		"Enemy forces have launched an attack on <font color='#00FFFF'>%1</font>. Eliminate any contact already present in the area, then defend it for <font color='#00FFFF'>%2 Minutes</font> until called to extract.",
		"The enemy is trying to occupy <font color='#00FFFF'>%1</font>. Clean out any forces already present, while preventing enemy reinforcements from taking the town. Hold it for <font color='#00FFFF'>%2 Minutes</font>.",
		"Enemy forces are planning to invade <font color='#00FFFF'>%1</font>. Eliminate any enemy forces already present, then hold the area from attackers for <font color='#00FFFF'>%2 Minutes</font> before withdrawing."
	];
	
if !(_radius isEqualType 0) then { _radius = 25 };
	
if (count (missionNamespace getVariable [ format["ZMM_%1_QRFLocations", _zoneID], []]) == 0) then { 
	private _QRFLocs = [];
	private _qrfDist = if ((_radius * 3) < 1000) then { 1500 } else { (_radius * 3) min 2000 };

	for [{_i = 0}, {_i <= 360}, {_i = _i + 5}] do {
		private _roads = ((_centre getPos [_qrfDist, _i]) nearRoads 150) select {count (roadsConnectedTo _x) > 0};
		private _tempPos = [];	
		
		_tempPos = if (count _roads > 0) then { getPos _roads#0 } else { (_centre getPos [_qrfDist, _i]) isFlatEmpty  [15, -1, -1, -1, -1, false] };
		
		if ({_x distance2D _tempPos < 350} count _QRFLocs == 0 && !(_tempPos isEqualTo [])) then {
			_QRFLocs pushBack _tempPos;
		};
	};
	missionNamespace setVariable [ format["ZMM_%1_QRFLocations", _zoneID], _QRFLocs ]; // Set QRF Locations
};

// Overwrite depending on location
private _waves = switch (_locType) do {
	case "Airport": { 5 };
	case "NameCityCapital": { 5 };
	case "NameCity": { 4 };
	case "NameVillage": { 3 };
	case "NameLocal": { 3 };
	default { 3 };
};

private _delay = (missionNamespace getVariable [format[ "ZMM_%1_QRFTime", _zoneID ], 300]) max 200;

private _timePerWave = 300;
private _time = _waves * _timePerWave;

// Create Information Trigger
private _infTrigger = createTrigger ["EmptyDetector", _centre, FALSE];
_infTrigger setTriggerArea [_radius, _radius, 0, FALSE];
_infTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", FALSE];
_infTrigger setTriggerTimeout [120, 120, 120, true];
_infTrigger setTriggerStatements [  "this", 
									format["['Command','Additional enemy forces are inbound ETA 5 Minutes. Defend %1 for %2 minutes.'] remoteExec ['BIS_fnc_showSubtitle',0];
									[] spawn { sleep 240; [ %3, false, %4, %5 ] spawn zmm_fnc_areaQRF; } 
									", _locName, _time / 60, _zoneID, _delay, _waves],
									"" ];
									
// Create Completion Trigger
private _objTrigger = createTrigger ["EmptyDetector", _centre, FALSE];
_objTrigger setTriggerArea [_radius, _radius, 0, FALSE];
_objTrigger setTriggerActivation ["ANYPLAYER", "PRESENT", FALSE];
_objTrigger setTriggerTimeout [(_time + 180), (_time + 240), (_time + 300), true];
_objTrigger setTriggerStatements [ 	"this", 
									format["['ZMM_%1_TSK', 'Succeeded', TRUE] spawn BIS_fnc_taskSetState; missionNamespace setVariable ['ZMM_DONE', TRUE, TRUE]; { _x setMarkerColor 'Color%2' } forEach ['MKR_%1_LOC','MKR_%1_MIN']", _zoneID, _playerSide],
									"" ];

// Create Task
private _missionTask = [format["ZMM_%1_TSK", _zoneID], TRUE, [format["<font color='#00FF80'>Mission (#ID%1)</font><br/>", _zoneID] + format[selectRandom _missionDesc, _locName, round (_time / 60)], ["Defence"] call zmm_fnc_nameGen, format["MKR_%1_LOC", _zoneID]], _centre, "CREATED", 1, FALSE, TRUE, "defend"] call BIS_fnc_setTask;

TRUE