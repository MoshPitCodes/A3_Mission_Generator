// Set-up mission variables.
params [ ["_zoneID", 0], ["_targetPos", [0,0,0]] ];

private _centre = missionNamespace getVariable [format["ZMM_%1_Location", _zoneID], _targetPos];
private _enemySide = missionNamespace getVariable [format["ZMM_%1_EnemySide", _zoneID], EAST];
private _playerSide = missionNamespace getVariable [ "ZMM_playerSide", WEST ];
private _enemyType = selectRandom (missionNamespace getVariable[format["ZMM_%1Grp_Team",_enemySide],[""]]); // CfgGroups entry.
private _locName = missionNamespace getVariable [format["ZMM_%1_Name", _zoneID], "this Location"];

private _missionDesc = [
		"A <font color='#00FFFF'>%2</font> has been spotted at %1, find and kill them.",
		"A <font color='#00FFFF'>%2</font> has been spotted moving around %1, hunt them down.",
		"Track and eliminate a <font color='#00FFFF'>%2</font> unit somewhere near %1.",
		"One highly-trained group of <font color='#00FFFF'>%2</font> is located somewhere nearby, find them.",
		"A <font color='#00FFFF'>%2</font> of enemy soldiers have para-dropped into %1, locate and eliminate them.",
		"Find and kill a <font color='#00FFFF'>%2</font>, patrolling somewhere around %1."
	];	
	
private _grpName = format["%1 %2", selectRandom ["Elite","Specialist","Special","Veteran"], selectRandom ["Group","Unit","Forces","Squad","Operators"] ];

// Create Objective
private _milGroup = [([_centre, 1, 150, 2, 0, 0.5, 0, [], [ _centre, _centre ]] call BIS_fnc_findSafePos), _enemySide, _enemyType] call BIS_fnc_spawnGroup;
{_x addHeadGear "H_Beret_blk"; _x setSkill 0.5 + random 0.3; } forEach units _milGroup;
[_milGroup, _centre, 50] call bis_fnc_taskPatrol;

// Add to Zeus
{
	_x addCuratorEditableObjects [units _milGroup, TRUE];
} forEach allCurators;

// Create Completion Trigger
missionNamespace setVariable [format["ZMM_%1_GRP", _zoneID], _milGroup];

private _objTrigger = createTrigger ["EmptyDetector", _centre, false];
_objTrigger setTriggerStatements [ 	format["({alive _x} count units ZMM_%1_GRP) == 0", _zoneID], 
									format["['ZMM_%1_TSK', 'Succeeded', TRUE] spawn BIS_fnc_taskSetState; missionNamespace setVariable ['ZMM_DONE', TRUE, TRUE]; { _x setMarkerColor 'Color%2' } forEach ['MKR_%1_LOC','MKR_%1_MIN']", _zoneID, _playerSide],
									"" ];

// Create Task
private _missionTask = [format["ZMM_%1_TSK", _zoneID], TRUE, [format["<font color='#00FF80'>Mission (#ID%1)</font><br/>", _zoneID] + format[selectRandom _missionDesc, _locName, _grpName], ["Hunter"] call zmm_fnc_nameGen, format["MKR_%1_LOC", _zoneID]], _centre, "CREATED", 1, FALSE, TRUE, "kill"] call BIS_fnc_setTask;

TRUE