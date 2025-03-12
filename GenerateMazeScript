-- Main server script

-------------[Modules and Events]-------------
local MazeGenerator = require(script:WaitForChild("MazeScript"))
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GenerateMazeFunction = ReplicatedStorage:WaitForChild("GenerateFunction")
local ResetMazeFunction = ReplicatedStorage:WaitForChild("ResetFunction")
local ChangeValueFunction = ReplicatedStorage:WaitForChild("ChangeValueFunction")

-------------[Folders]-------------
local MazeFolder = game.Workspace.Maze
local DebrisFolder = game.Workspace.Debris

local MyMaze = MazeGenerator.new() 

-- Updates a variable to a new value
local function ChangeValue(Player, Value, Type)
	local Result = MyMaze:UpdateValue(Value, Type)
	return Result
end

-- Calls the maze generation function
local function GenerateFunction(Player)
	local A = MyMaze:Reset()
	task.wait(0.5)
	local Result = MyMaze:Generate()
	return Result
end 

-- Calls the maze reset function
local function ResetFunction(Player)
	local Result = MyMaze:Reset()
	return Result
end

ResetMazeFunction.OnServerInvoke = ResetFunction
GenerateMazeFunction.OnServerInvoke = GenerateFunction
ChangeValueFunction.OnServerInvoke = ChangeValue
