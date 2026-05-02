<h1 align="center"> constraints-lib </h1>
<p align="center"> A physic constraints module for detecting whether <b>PrismaticConstraint</b> or <b>HingeConstraint</b> has reached to its target position </p>

# Dependencies:
[Signal - Sleitnick](https://github.com/Sleitnick/RbxUtil/blob/main/modules/signal/init.luau)

# APIs:
### Completed reasons:
<pre>COMPLETED <br>CANCELLED <br>TIMEOUT</pre>
<details>
	<summary>c_move</summary>
	<b> configs: </b>
	<pre>[number/default = 0.025] precision <br>[number/default = ( dist / speed ) + 5] timeout <br>[callback] on_completed<br></pre>
	<b> constructor: </b>
	<pre>[read] constraint <br>[read] target <br>[read] configs</pre>
	<b> is_completed: </b>
	<pre>[out] boolean</pre>
	<b> move: </b>
	<pre>[write] set constraint target to the specified target in constructor</pre>
	<b> pause: </b>
	<pre>[write] set constraint target to the current position</pre>
	<b> resume: </b>
	<pre>[write] set constraint target to the target position specified target in constructor</pre>
	<b> cancel: </b>
	<pre>[write] set constraint target to its' starting position</pre>
	<b> wait: </b>
	<pre>wait until constraint movement is completed</pre>
	<b> destroy: </b>
	<pre>[write] destroy the instance</pre>
</details>
<details>
	<summary>c_cyle</summary>
	<b> configs: </b>
	<pre>[number/default = 0.025] precision <br>[number/default = ( dist / speed ) + 5] timeout</pre>
	<b> completion modes: </b>
	<pre>C_COMPLETION_MODE_UNIDIRECTIONAL <br>C_COMPLETION_MODE_BIDIRECTIONAL</pre>
	<b> constructor: </b>
	<pre>[read] constraint <br>[read] initial <br>[read] final <br>[read] completion_mode <br>[read] configs</pre>
	<b> set_speed: </b>
	<pre>[in] number <br>[write] constraint's speed</pre>
	<b> reset_speed: </b>
	<pre>[write] reset constraint's speed to its starting speed</pre>
	<b> is_completed: </b>
	<pre>[out] boolean</pre>
	<b> move: </b>
	<pre>[write] set constraint target to the specified target in constructor</pre>
	<b> pause: </b>
	<pre>[write] set constraint target to the current position</pre>
	<b> resume: </b>
	<pre>[write] set constraint target to the target position specified target in constructor</pre>
	<b> cancel: </b>
	<pre>[write] set constraint target to its' starting position</pre>
	<b> wait: </b>
	<pre>wait until constraint movement is completed</pre>
	b> destroy: </b>
	<pre>[write] destroy the instance</pre>
</details>

# Examples:
### cannon's recoil:
> PRISMATIC: recoil knockback<br>
> HINGE: wheels rotation
```luau
local base_cannon = require("./base_cannon");
local constraint_lib = require("../libraries/constraint");
local c_cycle = constraint_lib.c_cycle;

local UNIDIRECTIONAL = constraint_lib.C_COMPLETION_MODE_UNIDIRECTIONAL;
local COMPLETED_ONCE = constraint_lib.C_COMPLETED_ONCE;
local COMPLETED_FULL = constraint_lib.C_COMPLETED_FULL;

--// INHERITANCE

local p_cannon = setmetatable( {}, base_cannon );
p_cannon.__index = p_cannon;

--// CONSTRUCTOR

function p_cannon.new( object )
	local cannon = base_cannon.new( object );
	local self = setmetatable( cannon, p_cannon );

	--// CONSTRAINTS
	self.prismatic = self.root:FindFirstChild("PrismaticConstraint");
	self.hinge = self.object:FindFirstChild("WheelSpokes"):FindFirstChild("HingeConstraint");

	--// C_CYCLE
	self.c_prismatic = c_cycle.new( self.prismatic, 0, self.prismatic.UpperLimit, UNIDIRECTIONAL, { timeout = 7 } );

	--// LISTEN FOR COMPLETED SIGNAL
	self.conn = self.c_prismatic.completed_signal:Connect(function( reason, completed_mode )

		--// STOP WHEELS' ROTATION/SPIN EVERY TIME PRISMATIC IS COMPLETED
		self.hinge.AngularVelocity = 0;

		--[[
		* RECOIL KNOCKBACK IS FINISHED:
		* WAIT 2 SECONDS
		* SLOWLY MOVE CANNON TO IT'S STARTING POSITION
		--]]
		if ( completed_mode == COMPLETED_ONCE ) then
			task.wait(2);
			self.c_prismatic:set_speed( 1 );
			self.hinge.AngularVelocity = -1;
			self.c_prismatic:move();
			return;
		end

		--[[
		* FULL CYCLE IS COMPLETED:
		* CANNON HAS MOVED BACK TO IT'S ORIGINAL POSITION AND READY TO FIRE
		--]]
		if ( completed_mode == COMPLETED_FULL ) then
			self.c_prismatic:reset_speed();
			return;
		end
	end)
	
	return self;
end

--[[
* FIRE CANNON:
* ANIMATE RECOIL KNOCKBACK VIA PRISMATIC CONSTRAINT
* ANIMATE WHEEL ROTATION VIA HINGE CONSTRAINT
--]]
function p_cannon:on_fired()
	self.hinge.AngularVelocity = 3;
	self.c_prismatic:move();
end

return p_cannon;
```

### C_MOVE EXAMPLE:
```luau
self.hinge = self.root:FindFirstChild("HingeConstraint");
self.c_reload = c_move.new( self.hinge, 0, {
	--// MANUALLY SET TIMEOUT
	timeout = 22,

	--// RELOAD MOVEMENT IS COMPLETED
	on_completed = function( c_instance, reason )
	self.axle_hinge.AngularVelocity = 0;
		task.wait( math.random(1, 2) );
		elf._ready = true;
	end
});
```
