pool = gcp;

fcn = @countTimeSinceStart;
leaderFcn = @(varargin) [];
printFcn = @printIfReceive;

spmd
	if labindex == 1
		T = timer('ExecutionMode','fixedRate','TasksToExecute',500,'Period',.01,'TimerFcn', printFcn);
		
	else
		T = timer('ExecutionMode','fixedRate','TasksToExecute',25,'Period',.1,'TimerFcn', fcn);		
		
	end
	start(T)
	
	while ~strcmpi(T.Running,'off')
% 		data = []
% 		if labindex>1
% 			
% 		else
			pause(.01)
% 		end
	end
	
	delete(T)
	
end



% 
% 	while ~strcmpi(T.Running,'off')
% 		dataFrom = []
% 		if labindex>1
% 			if ~isempty(T.UserData)
% 				dataFrom = T.UserData;
% 				%labSend(T.UserData, 1);
% 			end
% 		else
% 			[isDataAvail,srcWkrIdx,tag] = labProbe();
% 			if isDataAvail
% 				data = labReceive(srcWkrIdx);
% 				s.srcWkrIdx = srcWkrIdx;
% 				s.data = data;
% 			end
% 			
% 		end
% 	end
% 	