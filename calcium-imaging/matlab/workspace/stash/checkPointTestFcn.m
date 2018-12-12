function T = checkPointTestFcn(T, priority, progress)

% --> make u1 a cell array of executable tasks or call structures?? -> cache??

% INITIALIZE
persistent localLocker currentPriority
if nargin < 2, priority = 0; end
if nargin < 3, progress = 0; end
if isempty(localLocker)
		localLocker = struct('lastId',0,'id',[],'contents',{});
end
currentPriority = [ currentPriority, priority ];
	
% LOOP 
%		-->	UNTIL ALL TASKS ARE FINISHED
%		-->	OR PRIORITY LEVEL OF THIS CONTEXT IS EXCEEDING NEED 
numTasks = numel(u1);
while (progress < numTasks) &&  (priority <= min(currentPriority))
	% DO A TASK (cell of cells syntax)
	%task = T{progress};
	
	% EXTRACT TASK INPUT/OUTPUT & FUNCTION (ALTERNATIVE FORM) 
	t = getNext(T);
	out = T.Output;
	%exec = T.Executor;%TODO
	fcn = T.Function;
	in = T.Input;
	
	% ENSURE INPUTS ARE READY FOR WRITING & OUTPUTS FOR WRITING
	%(TODO -> SYNC INPUTS WITH THEIR SOURCES -> WAITFOR)
	
	% EXECUTE TASK-FUNCTION
	%[out.Data] = exec(fcn, in.Data);
	[out.Data] = feval(fcn, in.Data);
	
	% SYNCHRONIZE OUTPUTS WITH THEIR TARGETS
			
	
	
	% TASK COMPLETE -> MARK PROGRESS & TRY CONTINUE
	progress = progress + 1;
	
end

% CHECK IF TASK HAS FINISHED
if (progress < numTasks)
	fin = isDone(T);
	Tfin = T(fin);
	T = T(~fin);
end

% (PERHAPS) TODO -> EACH TASK SHOULD SPECIFY A FUNCTION 
%				TO CALL -> PASSING THE COMPLETED OUTPUTS
% will need to split outputs??

if ~isempty(T)
	tId = hangInQueue( tId, .25);
end

% end

end


function id = hangInQueue( id, timeout)

	tIn = tic;
	while(toc(tIn) < timeout)
		distcomp.nop; %pause(.001)
		
	end

end

function [id, prio] = checkSetContinue( id, prio )

end


















