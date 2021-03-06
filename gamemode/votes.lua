local Vote = {}
local Votes = {}
GM.vote = { }

local function ccDoVote(ply, cmd, args)
	local vote = Votes[tonumber(args[1] or 0)]

	if not vote then return end
	if args[2] ~= "yea" and args[2] ~= "nay" then return end

	local canVote, message = hook.Call("CanVote", GAMEMODE, ply, vote)

	if vote.voters[ply] or vote.exclude[ply] or canVote == false then
		GAMEMODE:Notify(ply, 1, 4, message or "You cannot vote!")
		return
	end
	vote.voters[ply] = true

	vote:handleNewVote(ply, args[2])
end
concommand.Add("vote", ccDoVote)

function Vote:handleNewVote(ply, choice)
	self[choice] = self[choice] + 1

	local excludeCount = table.Count(self.exclude)
	local voteCount = table.Count(self.voters)

	if voteCount >= #player.GetAll() - excludeCount then
		self:handleEnd()
	end
end

function Vote:handleEnd()
	local win = self.yea > self.nay and 1 or self.nay > self.yea and -1 or 0

	umsg.Start("KillVoteVGUI", self:getFilter())
		umsg.String(self.id)
	umsg.End()

	Votes[self.id] = nil
	timer.Destroy(self.id .. "DarkRPVote")

	self:callback(win)
end

function Vote:getFilter()
	local filter = RecipientFilter()

	for k,v in pairs(player.GetAll()) do
		if self.exclude[v] then continue end
		local canVote = hook.Call("CanVote", GAMEMODE, v, self)

		if canVote == false then
			self.exclude[v] = true
			continue
		end

		filter:AddPlayer(v)
	end

	return filter
end

function GM.vote:create(question, voteType, target, time, callback, excludeVoters, fail)
	excludeVoters = excludeVoters or {[target] = true}

	local newvote = {}
	setmetatable(newvote, {__index = Vote})

	newvote.id = table.insert(Votes, newvote)
	newvote.question = question
	newvote.votetype = voteType
	newvote.target = target
	newvote.time = time
	newvote.callback = callback
	newvote.fail = fail or function() end
	newvote.exclude = excludeVoters
	newvote.voters = {}

	newvote.yea = 0
	newvote.nay = 0

	if #player.GetAll() <= table.Count(excludeVoters) then
		GAMEMODE:Notify(target, 0, 4, LANGUAGE.vote_alone)
		newvote:callback(1)
		return
	end

	if target:IsPlayer() then
		GAMEMODE:Notify(target, 1, 4, LANGUAGE.vote_started)
	end

	umsg.Start("DoVote", newvote:getFilter())
		umsg.String(question)
		umsg.Short(newvote.id)
		umsg.Float(time)
	umsg.End()

	timer.Create(newvote.id .. "DarkRPVote", time, 1, function() newvote:handleEnd() end)
end

function GM.vote.DestroyVotesWithEnt(ent)
	for k, v in pairs(Votes) do
		if v.Ent == ent then
			timer.Destroy(v.ID .. "timer")
			umsg.Start("KillVoteVGUI")
				umsg.String(v.ID)
			umsg.End()
			for a, b in pairs(player.GetAll()) do
				b.VotesVoted = b.VotesVoted or {}
				b.VotesVoted[v.ID] = nil
			end

			Votes[k] = nil
		end
	end
end

function GM.vote.HandleVoteEnd(id, OnePlayer)
	if not Votes[id] then return end

	local choice = 1

	if Votes[id][2] >= Votes[id][1] then choice = 2 end

	Votes[id].Callback(choice, Votes[id].Ent)
	
	for a, b in pairs(player.GetAll()) do
		if not b:GetTable().VotesVoted then
			b:GetTable().VotesVoted = {}
		end
		b:GetTable().VotesVoted[id] = nil
	end
	umsg.Start("KillVoteVGUI")
		umsg.String(id)
	umsg.End()

	Votes[id] = nil
end
