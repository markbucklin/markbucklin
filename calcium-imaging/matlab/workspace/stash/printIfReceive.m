function printIfReceive(varargin)

spmd
	[isDataAvail,srcWkrIdx,tag] = labProbe();

	if isDataAvail
		data = labReceive(srcWkrIdx);
		fprintf('Data received from %i\n', srcWkrIdx)
		if numel(data) < 100
			disp(data)
		end
	end
end


% printFcn = @printIfReceive;
% spmd,
% if labindex == 1,
% T = timer('ExecutionMode','fixedRate','TasksToExecute',500,'Period',.01,'TimerFcn', printFcn);
% else,
% T = timer('ExecutionMode','fixedRate','TasksToExecute',25,'Period',.1,'TimerFcn', fcn);
% start(T)
% end,
% end


% 
% function printIfReceive(t,evnt)
% 
% % spmd
% % 	[isDataAvail,srcWkrIdx,tag] = labProbe();
% 	
% % 	if isDataAvail
% % 		data = labReceive(srcWkrIdx);
% if ~isempty(t.UserData)
% 	s = t.UserData;
% 		fprintf('Data received from %i\n', s.srcWkrIdx)
% 		if numel(data) < 100
% 			disp(s.data)
% 		end
% 		t.UserData = [];
% end
% % 	end
% % end