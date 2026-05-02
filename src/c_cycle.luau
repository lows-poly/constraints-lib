--[[
===================================== C_CYCLE =====================================
=        Author : @lowspoly                                                       =
=          Date : 27 Apr 2026                                                     =
=       Purpose : Reusable bidirectional constraint mover                         =
===================================================================================
]]
local signal = require("@game/ReplicatedStorage/shared/libraries/signal");

local DEFAULT_PRECISION_THRESHOLD = 0.025;

local C_COMPLETION_MODE_UNIDIRECTIONAL = 0;
local C_COMPLETION_MODE_BIDIRECTIONAL = 1;
local C_COMPLETED_ONCE = 0;
local C_COMPLETED_FULL = 1;
local C_INITIAL_FROM_CURRENT = "C_INITIAL_FROM_CURRENT"

local COMPLETED = 0;
local CANCELLED = 1;
local TIMEOUT = 2;

type constraint = PrismaticConstraint | HingeConstraint;

type configs = {
	precision: number | nil,
	timeout: number | nil
};

--// FORWARD DECLARATIONS
local estimate_move_time = function( constraint, initial, final ) end;
local get_remaining_dist = function( constraint, target ) end;

--// MODULE

local c_cycle = {};
c_cycle.__index = c_cycle;

c_cycle.C_COMPLETION_MODE_UNIDIRECTIONAL = C_COMPLETION_MODE_UNIDIRECTIONAL;
c_cycle.C_COMPLETION_MODE_BIDIRECTIONAL = C_COMPLETION_MODE_BIDIRECTIONAL;
c_cycle.C_INITIAL_FROM_CURRENT = C_INITIAL_FROM_CURRENT;
c_cycle.C_COMPLETED_ONCE = C_COMPLETED_ONCE;
c_cycle.C_COMPLETED_FULL = C_COMPLETED_FULL;

--// CONSTRUCTOR

function c_cycle.new( constraint: constraint, i_pos: number | string, f_pos: number, completion_mode: number | nil, configs: configs | nil )
	assert( constraint:IsA( "PrismaticConstraint" ) or constraint:IsA( "HingeConstraint" ),
	        tostring( constraint ) .. " IS NOT SUPPORTED" );
	
	configs = configs or {};
	
	local self = setmetatable( {}, c_cycle );
	self.constraint = constraint;
	self.is_prismatic = self.constraint:IsA("PrismaticConstraint");
	self.default_speed = self.is_prismatic and self.constraint.Speed or self.constraint.AngularSpeed;
	
	self._completion_mode = completion_mode or C_COMPLETION_MODE_UNIDIRECTIONAL;
	self._threshold = configs.precision or DEFAULT_PRECISION_THRESHOLD;
	self._timeout = configs.timeout or estimate_move_time( constraint, i_pos, f_pos );
	
	self._initial = i_pos;
	if ( i_pos == C_INITIAL_FROM_CURRENT ) then
		self._initial = nil;
	end
	
	self._final = f_pos;
	self._target = f_pos;
	
	self._movement_count = 0;
	self._moving = false;
	self._paused = false;
	self._cancelled = false;
	self._at_final = false;
	self._thread = nil;
	
	self.completed_signal = signal.new();
	
	return self;
end

--// PUBLIC FUNCTIONS

function c_cycle:is_completed()
	return get_remaining_dist( self.constraint, self._target ) <= self._threshold;
end

function c_cycle:move()
	if ( self._moving or self._cancelled ) then
		return;
	end
	
	if ( not self._initial ) then
		self._initial = self:_get_current_position();
	end
	
	self._cancelled = false;
	self._target = self._at_final and self._initial or self._final;
	self._moving = true;
	self._paused = false;
	
	self:_move_to( self._target );
	self:_create_move_thread();
end

function c_cycle:set_speed( speed )
	speed = math.abs( speed );
	
	if ( self.is_prismatic ) then
		self.constraint.Speed = speed;
	else
		self.constraint.AngularVelocity = speed;
	end
end

function c_cycle:reset_speed()
	if ( self.is_prismatic ) then
		self.constraint.Speed = self.default_speed;
	else
		self.constraint.AngularVelocity = self.default_speed;
	end
end

function c_cycle:pause()
	if ( not self._moving or self._paused ) then
		return;
	end

	self._paused = true;
	self:_stop();
end

function c_cycle:resume()
	if ( not self._moving or not self._paused ) then
		return;
	end
	
	self._paused = false;
	self:_move_to( self._target );
end

function c_cycle:cancel()
	if ( not self._moving ) then
		return;
	end
	
	self._moving = false;
	self._cancelled = true;
	self._at_final = false;
	self._movement_count = 0;
	self:_move_to( self._initial );
	
	self.completed_signal:Fire( CANCELLED );
end

function c_cycle:wait()
	while ( self._moving ) do
		task.wait();
	end
end

function c_cycle:destroy()
	self:cancel();

	if ( self._thread ) then
		task.cancel( self._thread );
		self._thread = nil;
	end

	self.completed_signal:Destroy();
end

--// PRIVATE FUNCTIONS

function c_cycle:_get_current_position()
	if ( self.is_prismatic ) then
		return self.constraint.CurrentPosition;
	else
		return self.constraint.CurrentAngle;
	end
end

function c_cycle:_move_to( target )
	if ( self.is_prismatic ) then
		self.constraint.TargetPosition = target;
	else
		self.constraint.TargetAngle = target;
	end
end

function c_cycle:_stop()
	if ( self.is_prismatic ) then
		self.constraint.TargetPosition =  self.constraint.CurrentPosition;
	else
		self.constraint.TargetAngle = self.constraint.CurrentAngle;
	end
end

function c_cycle:_update_cycle_state()
	self._at_final = not self._at_final;
	self._movement_count += 1;
	
	if ( self._completion_mode == C_COMPLETION_MODE_UNIDIRECTIONAL ) then
		return true;
	end
	if ( self._completion_mode == C_COMPLETION_MODE_BIDIRECTIONAL ) then
		if ( self._movement_count < 2 ) then
			return false;
		end
		
		return true;
	end
	
	return false;
end

function c_cycle:_create_move_thread()
	if ( self._thread ) then
		task.cancel( self._thread );
		self._thread = nil;
	end
	
	self._thread = task.spawn( function()
		local elapsed = 0;
		local dt;
		
		while ( self._moving ) do
			dt = task.wait();
			
			if ( self._paused ) then
				continue;
			end
			
			elapsed += dt;
			
			if ( elapsed >= self._timeout ) then
				self._moving = false;
				self.completed_signal:Fire( TIMEOUT );
				return;
			end
			
			if ( not self:is_completed() ) then
				continue;
			end
			
			local is_completed = self:_update_cycle_state();
			if ( is_completed ) then
				self._moving = false;
				self.completed_signal:Fire( COMPLETED );
				
				if ( self._movement_count % 2 == 0 ) then
					self.completed_signal:Fire( COMPLETED, C_COMPLETED_FULL );
					self._movement_count = 0;
				else
					self.completed_signal:Fire( COMPLETED, C_COMPLETED_ONCE );
				end
				
				return;
			end
			
			elapsed = 0;
		end
	end);
end

--// HELPERS

estimate_move_time = function( constraint, initial, final )
	local distance = math.abs( initial - final );
	local speed;
	
	if ( constraint:IsA("PrismaticConstraint") ) then
		speed = constraint.Speed;
	end
	if ( constraint:IsA("HingeConstraint") ) then
		speed = constraint.AngularSpeed;
	end
	
	if ( not speed or speed == 0 ) then
		return math.huge;
	end
	
	return distance / speed;
end

get_remaining_dist = function( constraint, target )
	if ( constraint:IsA("PrismaticConstraint") ) then
		return math.abs( constraint.CurrentPosition - target );
	end
	if ( constraint:IsA("HingeConstraint") ) then
		return math.abs( constraint.CurrentAngle - target );
	end
end

return c_cycle;
