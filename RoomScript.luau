local RoomLogic = {}
RoomLogic.__index = RoomLogic
-------------[Constructor]-------------
function RoomLogic.new(AssetsModule)
	local self = setmetatable({}, RoomLogic)

	-- Store references to required module containing model tables
	self.Assets = AssetsModule

	-- Asset model categories tables
	self.HallwaysTable = self.Assets.Hallways
	self.RoomsTable = self.Assets.Rooms
	self.BigRoomsTable = self.Assets.BigRooms
	self.StartRoom = self.Assets.GetSpecialRoom("StartingRoom")
	self.ExitRoom = self.Assets.GetSpecialRoom("ExitRoom")
	
	return self
end

function RoomLogic:GetExitRoom()
	-- Returns a clone of exit room model
	return self.ExitRoom:Clone()
end

function RoomLogic:GetBigRoom()
	-- Returns a clone of a random big room model
	return self.BigRoomsTable[math.random(1, #self.BigRoomsTable)]:Clone()
end

function RoomLogic:GetRoom()
	-- Returns a clone of a random room model
	return self.RoomsTable[math.random(1, #self.RoomsTable)]:Clone()
end

function RoomLogic:GetHallway()
	-- Returns a clone of a random hallway model
	return self.HallwaysTable[math.random(1, #self.HallwaysTable)]:Clone()
end

return RoomLogic
