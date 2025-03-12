--This is the default template that will be reconciled with if a settings is missing
return {
	DebrisFolder = workspace.Debris,
	MazeFolder = workspace.Maze,
	
	MaxRooms = 500,
	MaxBigRooms = 90,
	MaxExitRooms = 2,
	MaxHallways = math.huge,

	RoomDensity = 15,
	BigRoomDensity = 5,

	MinExitDist = 250,
	ForceExitPercent = 50,
	ExitRatioPercent = 30,

	StartVector = Vector3.new(0,10,0),
	DebugMode = false
}
