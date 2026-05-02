local c_move = require("@self/c_move");
local c_cycle = require("@self/c_cycle");

local constraint = {};
constraint.c_move = c_move;
constraint.c_cycle = c_cycle;

constraint.COMPLETED = 0;
constraint.CANCELLED = 1;
constraint.TIMEOUT = 2;

constraint.C_COMPLETION_MODE_UNIDIRECTIONAL = c_cycle.C_COMPLETION_MODE_UNIDIRECTIONAL;
constraint.C_COMPLETION_MODE_BIDIRECTIONAL = c_cycle.C_COMPLETION_MODE_BIDIRECTIONAL;
constraint.C_INITIAL_FROM_CURRENT = c_cycle.C_INITIAL_FROM_CURRENT;
constraint.C_COMPLETED_ONCE = c_cycle.C_COMPLETED_ONCE;
constraint.C_COMPLETED_FULL = c_cycle.C_COMPLETED_FULL;

return constraint;
