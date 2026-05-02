--[[
===================================== C_MOVE ======================================
=        Author : @lowspoly                                                       =
=          Date : 27 Apr 2026                                                     =
=       Purpose : Fire and forget, tween-liked constraint                         =
===================================================================================
]]
local DEFAULT_PRECISION_THRESHOLD = 0.025;

local COMPLETED = 0;
local CANCELLED = 1;
local TIMEOUT = 2;

type constraint = PrismaticConstraint | HingeConstraint;

type configs = {
	precision: number | nil,
	timeout: number | nil,
	on_completed: () -> () | nil
};

--// FORWARD DECLARATIONS
local estimate_move_time = function( constraint, initial, final ) end;
local get_remaining_dist = function( constraint, target ) end;
local get_start_pos = function( constraint ) end;

--// MODULE

local c_move = {};
c_move.__index = c_move;

--// CONSTRUCTOR

function c_move.new( constraint: constraint, target: number, configs: configs | nil )
	assert( constraint:IsA( "PrismaticConstraint" ) or constraint:IsA( "HingeConstraint" ),
	        tostring( constraint ) .. " IS NOT SUPPORTED" );
	
	configs = configs or {};
	
	local self = setmetatable( {}, c_move );
	self.constraint = constraint;
	self.target = target;
	
	self._start_pos = get_start_pos( self.constraint );
	self._threshold = configs.precision or DEFAULT_PRECISION_THRESHOLD;
	self._timeout = configs.timeout or estimate_move_time( constraint, self._start_pos, target ) + 5;
	
	self._callback = configs.on_completed;
	self._moving = false;
	self._paused = false;
	self._cancelled = false;
	self._thread = nil;
	
	return self;
end

--// PUBLIC FUNCTIONS

function c_move:is_completed()
	return get_remaining_dist( self.constraint, self.target ) <= self._threshold;
end

function c_move:move()
	if ( self._moving ) then
		return;
	end
	
	self._cancelled = false;
	self._start_pos = get_start_pos( self.constraint );
	self._moving = true;
	self._paused = false;
	
	self:_move_to( self.target );
	self:_create_move_thread();
end

function c_move:pause()
	if ( not self._moving or self._paused ) then
		return;
	end
	
	self._paused = true;
	self:_stop();
end

function c_move:resume()
	if ( not self._moving or not self._paused ) then
		return;
	end
	
	self._paused = false;
	self:_move_to( self.target );
end

function c_move:cancel()
	if ( not self._moving ) then
		return;
	end
	
	self._moving = false;
	self._cancelled = true;
	self:_move_to( self._start_pos );
	
	if ( self._callback ) then
		task.defer( self._callback, self, CANCELLED );
	end
end

function c_move:wait()
	while ( self._moving ) do
		task.wait();
	end
end

function c_move:destroy()
	self:cancel();
	
	if ( self._thread ) then
		task.cancel( self._thread );
		self._thread = nil;
	end
end

--// PRIVATE FUNCTIONS

function c_move:_move_to( target )
	if ( self.constraint:IsA( "PrismaticConstraint" ) ) then
		self.constraint.TargetPosition = target;
		return;
	end
	if ( self.constraint:IsA( "HingeConstraint" ) ) then
		self.constraint.TargetAngle = target;
		return;
	end
end

function c_move:_stop()
	if ( self.constraint:IsA( "PrismaticConstraint" ) ) then
		self.constraint.TargetPosition = self.constraint.CurrentPosition;
		return;
	end
	if ( self.constraint:IsA( "HingeConstraint" ) ) then
		self.constraint.TargetAngle = self.constraint.CurrentAngle;
		return;
	end
end

function c_move:_create_move_thread()
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
				self:_stop()
				
				if ( self._callback ) then
					task.defer( self._callback, self, TIMEOUT );
				end
				
				return;
			end
			
			if ( self:is_completed() ) then
				self._moving = false;
				
				if ( self._callback ) then
					task.defer( self._callback, self, COMPLETED );
				end
				
				return;
			end
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

get_start_pos = function( constraint )
	if ( constraint:IsA("PrismaticConstraint" ) ) then
		return constraint.CurrentPosition
	end
	if ( constraint:IsA("HingeConstraint") ) then
		return constraint.CurrentAngle;
	end
end

return c_move;
