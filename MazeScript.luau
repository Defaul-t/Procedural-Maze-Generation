-- Maze generator script

--!optimize 2

local MazeGenerator = {}
MazeGenerator.__index = MazeGenerator

-------------[Modules]-------------
local AssetsModule = require(script.Parent.Parent:WaitForChild("AssetsModule"))
local RoomLogic = require(script.Parent:WaitForChild("RoomScript"))
local SettingsTemplate = require(script.Parent.SettingsTemplate)
-------------[Helper Functions]-------------
local function Divide(Number1, Number2) 
	return Number1 * (1/Number2) --legitmately faster somehow because 1/Number2 is faster than Number1/Number2 due to how division and multiplication is handled by computers
end

-------------[Constructor]-------------
local function Reconcile(Template: {}, Table: {})
	--Add any missing data from a table, with a base table
	local FixedTable = Table
	
	for Index, Value in Template do
		if not FixedTable[Index] then
			FixedTable[Index] = Value
		end
	end
	
	return FixedTable
end

function MazeGenerator:MakeTrackers()
	-- Make instance trackers (Instances have a better synchronization mechanism for multithreading)
	self.TotalRooms = self.MaxRooms + self.MaxBigRooms
	self.ForceExitNum = self.TotalRooms * self.ForceExitPercent
	self.ExitRatioNum = self.TotalRooms * self.ExitRatioPercent
	
	self.ExitLock = Instance.new("BoolValue")

	self.BigRoomChance = Instance.new("NumberValue")
	self.RoomChance = Instance.new("NumberValue")

	self.RunningWorkers = Instance.new("IntValue")
	self.HallwayCount = Instance.new("IntValue")
	self.ExitRoomCount = Instance.new("IntValue")
	self.RoomCount = Instance.new("IntValue")
	self.BigRoomCount = Instance.new("IntValue")
	
	self.BranchOutCount = Instance.new("IntValue")
	self.CheckSpaceCount = Instance.new("IntValue")
end
--MazeGenerator.new(MazeFolder, DebrisFolder, MaxRooms, MaxBigRooms, MaxExitRooms, MaxHallways, RoomDensity, BigRoomDensity, StartVector, MinExitDist, ForceExitPercent, ExitRatioPercent, DebugMode)
function MazeGenerator.new(settings: {MazeFolder: Folder?,	DebrisFolder: Folder?,	MaxRooms: number?, MaxBigRooms: number?, MaxExitRooms: number?, MaxHallways: number?, RoomDensity: number?, BigRoomDensity: number?, StartVector: Vector3?, MinExitDist: number?, ForceExitPercent: number?, ExitRatioPercent: number?, DebugMode: boolean?})

	settings = settings or {} 
	settings = Reconcile(SettingsTemplate,settings)
	local self = setmetatable({}, MazeGenerator) 
	-- Setup properties 
	self.MazeFolder = settings.MazeFolder or game.Workspace.Maze
	self.DebrisFolder = settings.DebrisFolder or game.Workspace.Debris
	self.RoomLogic = RoomLogic.new(AssetsModule)
	
	self.StartVector = settings.StartVector
	
	self.MaxRooms = settings.MaxRooms
	self.MaxBigRooms = settings.MaxBigRooms
	self.MaxExitRooms = settings.MaxExitRooms
	self.MaxHallways = settings.MaxHallways

	self.RoomDensity = settings.RoomDensity * 0.01 -- in%
	self.BigRoomDensity = settings.BigRoomDensity * 0.01 -- in%
	self.ForceExitPercent = settings.ForceExitPercent * 0.01 -- Percent of rooms to place forcing exit rooms to be placed until max is reached
	self.ExitRatioPercent = settings.ExitRatioPercent * 0.01 -- Percent of rooms to place before allowing exit rooms to generate
	
	self.MinExitRoomDistance = settings.MinExitDist

	-- Trackers and locks
	self.RoomsPerExit = Divide(self.MaxRooms,self.MaxExitRooms)
	self.ExitRoomPositions = {}
	self.ExitRoomQueue = {}


	self.BranchOutsPerWait = 10
	self.CheckSpacesPerWait = 40
		
	self:MakeTrackers()

	self.DebugMode = settings.DebugMode

	if self.DebugMode then
		print("[DEBUG]: DEBUG ACTIVATED -> Maze generation will be slowed for easier tracking")
	end
	
	return self
end

-------------[Class Functions]-------------
function MazeGenerator:UpdateValue(Value, Type)
	-- Updates a value
	local VariableMap = {
        ["StartVector"] = "StartVector",
        ["MaxRooms"] = "MaxRooms",
        ["MaxBigRooms"] = "MaxBigRooms",
        ["MaxExitRooms"] = "MaxExitRooms",
        ["MaxHallways"] = "MaxHallways",
        ["RoomDensity"] = "RoomDensity",
        ["BigRoomDensity"] = "BigRoomDensity",
        ["ForceExitPercent"] = "ForceExitPercent",
        ["ExitRatioPercent"] = "ExitRatioPercent",
        ["MinExitRoomDistance"] = "MinExitRoomDistance"
    }
	
	local VarName = VariableMap[Type]

	-- Update the variable if it exists
	if VarName then
		local OldValue = self[VarName]
		self[VarName] = Value
		return string.format("Updated %s from (%s) to (%s)", Type, tostring(OldValue), tostring(Value))
	else
		return "Unknown variable type: ", Type
	end
end

function MazeGenerator:DestroyObject(Object: Instance)
	-- Destroys an object
	assert(Object:IsA("Instance"), "Object to remove is not an instance")
	
	if self.DebugMode then
		print(`[DEBUG]: Removing Object; {Object}`)
	end
	
	task.spawn(function()
		game.Debris:AddItem(Object,0)
		return
	end)
end

function MazeGenerator:ResetTrackers()
	-- Reset generation trackers
	self.ExitRoomQueue = {}
	self.ExitRoomPositions = {}
	
	self.RunningWorkers.Value = 0
	self.RoomCount.Value = 0
	self.BigRoomCount.Value = 0
	self.ExitRoomCount.Value = 0
	self.HallwayCount.Value = 0
	self.BigRoomChance.Value = 0
	self.RoomChance.Value = 0
	self.ExitLock.Value = false

	if self.DebugMode == true then
		print("[DEBUG]: Reset Trackers")
		print("[DEBUG] WorkersNum:".. self.RunningWorkers.Value)
		print("[DEBUG] RoomCount:".. self.RoomCount.Value)
		print("[DEBUG] BigRoomCount:".. self.BigRoomCount.Value)
		print("[DEBUG] ExitRoomCount:".. self.ExitRoomCount.Value)
		print("[DEBUG] BigRoomChance:".. self.BigRoomChance.Value)
		print("[DEBUG] ExitRoomChance:".. self.RoomChance.Value)
		print(self.ExitLock.Value)
		task.wait(1)
	end
end

function MazeGenerator:IsExitTooClose(Position)
	-- Checks if a position is too close to placed exit rooms
	for _, ExitPos in ipairs(self.ExitRoomPositions) do
		local Distance = (Position - ExitPos).Magnitude
		if Distance < self.MinExitRoomDistance then
			if self.DebugMode then
				print("[DEBUG]: Rejected exit room - too close to existing exit (" .. Distance .. " < " .. self.MinExitRoomDistance .. ")")
			end
			return true
		end
	end
	return false
end
local CheckBox = Instance.new("Part")
CheckBox.Parent = workspace.Debris

function MazeGenerator:CheckSpace(NewPosition, RoomSize)
	-- Checks if the space is clear to add a room
	CheckBox.Anchored = true
	CheckBox.Size = RoomSize
	CheckBox.Position = NewPosition
	local partsInCheckBox = game.Workspace:GetPartsInPart(CheckBox)
	if self.DebugMode == true then
		print("[DEBUG]: Num parts in checkbox:".. #partsInCheckBox)
		task.wait(1) 
	end
	self:DestroyObject(CheckBox)
	return #partsInCheckBox <= 0 
	
end

function MazeGenerator:SetCFrame(Model, cf)
	-- Sets the CFrame of the model
	if self.DebugMode == true then 
		print("[DEBUG] Assigned CFrame:") 
		print(cf)
	end
	Model:SetPrimaryPartCFrame(cf)
end

function MazeGenerator:ConnectAsset(RoomModel, NewPosition, PartPos)
	-- Connects a room CFrame to a doorface
	task.spawn(function() 
		RoomModel.Parent = self.MazeFolder
		self:SetCFrame(RoomModel, CFrame.new(NewPosition, PartPos))
		self:SetCFrame(
			RoomModel, 
			CFrame.new(RoomModel.PrimaryPart.Position) * 
				CFrame.Angles(
					math.rad(0), -- X
					math.rad(RoomModel.PrimaryPart.Orientation.Y), -- Y
					math.rad(RoomModel.PrimaryPart.Orientation.Z) -- Z
				)
		)
		return
	end)
end

function MazeGenerator:MakeStartRoom(StartingPosition, StartingRoom)
	-- Creates and generates the starting room
	local Start = StartingRoom:Clone()
	Start.Parent = self.MazeFolder
	self:SetCFrame(Start, CFrame.new(StartingPosition))
	return Start
end

function MazeGenerator:FillDoor(Part)
	-- Fills in a doorway that doesn't lead to a new room
	Part.Material = Enum.Material.Plastic
	Part.Color = Color3.fromRGB(160, 95, 53)
	Part.Transparency = 0
	
	--TODO (Make a path from 2 filled doors that connect to eachother)
end

function MazeGenerator:CalcBoxSize(Room)
	-- Calculates the size of the part -> used in checkbox check if it can be safely placed without clipping
	local width = 0
	local length = 0

	for _, Part in pairs(Room:GetChildren()) do
		if Part:IsA("BasePart") and Part.Name == "Floor" then
			local partSize = Part.Size
			if partSize.X > partSize.Z then
				width = math.max(width, partSize.X)
				length = length + partSize.Z
			else
				width = width + partSize.X
				length = math.max(length, partSize.Z)
			end
		end
	end
	if self.DebugMode == true then
		print("[DEBUG]: Boxsize width and length:", width, length)
	end
	return Vector3.new(width, 20, length)
end

function MazeGenerator:AssetChance(Chance, Density)
	if math.random() < Chance.Value then
		Chance.Value = Density
		return true
	end
	Chance.Value = math.min(Density*2, 1)
	return false
end

function MazeGenerator:CalculateExitRoomScore(position)
	-- Calculates a score for potential exit room candinates, and generates the one with the highest score
	local score = 0

	-- Distance from start point - prefer exits further from start
	local distanceFromStart = (position - self.StartVector).Magnitude
	score += distanceFromStart * 0.5

	-- Distance from other exits - prefer exits far from other exits
	local minDistanceToOtherExit = math.huge

	for _, exitPos in ipairs(self.ExitRoomPositions) do
		local distance = (position - exitPos).Magnitude
		minDistanceToOtherExit = math.min(minDistanceToOtherExit, distance)
	end

	-- If we have other exits, factor in the distance
	if #self.ExitRoomPositions > 0 then
		score += minDistanceToOtherExit * 2
	end
	return score
end

-- Add this function to process the exit room queue
function MazeGenerator:ProcessExitRoomQueue()
	-- If we're already processing or we have enough exit rooms, don't continue
	if self.ExitLock.Value or self.ExitRoomCount.Value >= self.MaxExitRooms then
		return
	end

	self.ExitLock.Value = true
	-- Process queue until we've placed all required exit rooms or emptied the queue
	while #self.ExitRoomQueue > 0 and self.ExitRoomCount.Value < self.MaxExitRooms do
		-- Sort the queue by the highest "quality" score (e.g., distance from other exits)
		table.sort(self.ExitRoomQueue, function(a, b) return a.score > b.score end)
		-- Get the best candidate
		local candidate = table.remove(self.ExitRoomQueue, 1)

		-- Double-check that we can place it
		if self:CheckSpace(candidate.position, candidate.size) and not self:IsExitTooClose(candidate.position) then
			-- Place the exit room
			self:ConnectAsset(candidate.model, candidate.position, candidate.doorPosition)
			candidate.counter.Value += 1
			table.insert(self.ExitRoomPositions, candidate.position)
			if self.DebugMode then
				print("[DEBUG]: Placed exit room at position: ", candidate.position)
				print("[DEBUG]: Exit rooms placed: " .. self.ExitRoomCount.Value .. "/" .. self.MaxExitRooms)
			end
			for _, Room in ipairs(self.ExitRoomQueue) do
				print("new scores")
				Room.score = self:CalculateExitRoomScore(Room.position)
			end
			-- Fill or destroy the door that this exit came from
			if candidate.door then
				self:DestroyObject(candidate.door)
			end
		else
			self:FillDoor(candidate.door)
		end
	end

	-- Release the lock
	self.ExitLock.Value = false
end

function MazeGenerator:SelectNextRoom()
	-- Selects the next room to be placed based on various conditions
	if not self.ExitLock.Value and self.ExitRoomCount.Value < self.MaxExitRooms then
		-- Check if we should create an exit room
		local CurrentRooms = self.BigRoomCount.Value + self.RoomCount.Value
		local AllowExits = CurrentRooms > self.ExitRatioNum
		if AllowExits then
			local ForceExit = Divide(CurrentRooms,self.RoomsPerExit) >= self.ExitRoomCount.Value or self.RoomCount.Value > self.ForceExitNum
			local RollExit = math.random(self.RoomsPerExit*0.01, self.RoomsPerExit) == self.RoomPerExit or ForceExit
			if RollExit then
				return self.RoomLogic:GetExitRoom(), self.ExitRoomCount
			end
		end
	end
	
	local MakeRoom = self:AssetChance(self.RoomChance, self.RoomDensity)
	local MakeBigRoom = self:AssetChance(self.BigRoomChance, self.BigRoomDensity)
	
	if self.RoomCount.Value < self.MaxRooms and MakeRoom then
		self.RoomChance.Value = 0 
		return self.RoomLogic:GetRoom(), self.RoomCount
	end
	if self.BigRoomCount.Value < self.MaxBigRooms and MakeBigRoom then
		self.BigRoomChance.Value = 0 
		return self.RoomLogic:GetBigRoom(), self.BigRoomCount
	end
	
	return self.RoomLogic:GetHallway(), self.HallwayCount
end


function MazeGenerator:Branchout(Model)
	-- Branch out from a model to expand the maze
	self.RunningWorkers.Value += 1
	self.BranchOutCount.Value += 1
	self.CheckSpaceCount.Value += 1

	
	if self.BranchOutCount.Value == self.BranchOutsPerWait then
		self.BranchOutCount.Value = 0
		task.wait() 
	end
	
	for _, part in pairs(Model:GetChildren()) do
		-- Iterate on every part and according to conditions branch out a new room from a doorface
		if part:IsA("BasePart") and part.Name == "DoorFace" then
			local NextRoom, Counter = self:SelectNextRoom()
			
			local EntranceFace = NextRoom.EntranceFace
			local Distance = (NextRoom.PrimaryPart.Position - EntranceFace.Position).Magnitude
			local RoomSize = self:CalcBoxSize(NextRoom)
			
			self:DestroyObject(EntranceFace)
			local newPosition = part.Position + part.CFrame.LookVector * Distance
			-- Special handling for exit room queuing
			if NextRoom:GetAttribute("IsExit") ~= nil then
				table.insert(self.ExitRoomQueue, {
					model = NextRoom,
					position = newPosition,
					size = RoomSize,
					doorPosition = part.Position,
					door = part,
					counter = Counter,
					score = self:CalculateExitRoomScore(newPosition)
				})
				self:ProcessExitRoomQueue()
			elseif self:CheckSpace(newPosition, RoomSize) and self.HallwayCount.Value < self.MaxHallways and self.RoomCount.Value < self.MaxRooms then
				if self.CheckSpacesPerWait == self.CheckSpaceCount.Value then
					task.wait()
					self.CheckSpaceCount.Value = 0
				end
				
				task.spawn(function()
					-- Check if we can place the room
					-- Place the new room
					self:ConnectAsset(NextRoom, newPosition, part.Position)
					Counter.Value += 1
					-- Continue branching
					local self_ref = self -- Capture self reference for the coroutine
					--coroutine.wrap(function() self_ref:Branchout(NextRoom) end)()
					self:Branchout(NextRoom)
					self:DestroyObject(part)
				end)
			else
				-- Handle placement failure
				self:FillDoor(part)
			end
		end
	end
	self.RunningWorkers.Value -= 1
end

-- Resets the current maze in batches 
function MazeGenerator:Reset()
	if self.RunningWorkers.Value > 0 then
		return "Maze Is Currently Generating"
	end
	local Added = 0
	local PartsPerBatch = 700
	local PartsPerWait = 350

	local Batch = {}

	for _, Part in pairs(self.MazeFolder:GetChildren()) do
		Added += 1
		table.insert(Batch,Part)
		if Added == PartsPerBatch then
			task.spawn(function()
				local PartsRemoved = 0
				local CurrentBatch = table.clone(Batch)
				table.clear(Batch)

				Added = 0
				for _, Part in CurrentBatch do
					PartsRemoved += 1
					self:DestroyObject(Part)
					if PartsRemoved == PartsPerWait then
						PartsRemoved = 0
						task.wait()
					end
				end
			end)
			task.wait()
		end
	end

	for _, Part in Batch do
		self:DestroyObject(Part)
	end
	return "Maze Reset"
end

-- Generates a new maze with set variables
function MazeGenerator:Generate()
	self:ResetTrackers()
	
	local Start = self:MakeStartRoom(self.StartVector, self.RoomLogic.StartRoom:Clone())
	self.RoomCount.Value = 1
	local StartTick = tick()
	-- Begin generating the maze
	self:Branchout(Start)

	while self.RunningWorkers.Value > 0 do
		task.wait(1)
	end
	return "Maze generated in "..tick()-StartTick.." seconds.\n Spawned exits:"..self.ExitRoomCount.Value
end

function MazeGenerator:Dump()
	-- Data Dump
	print("Preparing to dump all data below:\n\n------------------------------DATA DUMP------------------------------")
	print("ClassData", self)
	print("Room Logic", self.RoomLogic)
	print("Assets", self.RoomLogic.Assets)
	print("------------------------------DATA DUMP------------------------------")
	print("Completed the dump <3")
	
end

return MazeGenerator
