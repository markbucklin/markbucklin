function futVal = fevalAsync( fcnHandle, numOut, varargin)

persistent fidx futMap
if isempty(fidx), fidx = int32(0); end
if isempty(futMap)
	futMap = containers.Map('KeyType','int32','ValueType','any');
end


% SHARED WITH THIS EVAL
t = timer;
fidx = fidx + 1;
t.TimerFcn = @(~,~) evalFcnFcn( fidx, fcnHandle, numOut, varargin{:});
t.StartDelay = .001;

cleanupObj = onCleanup(@() tryDeleteTimer(t));

futVal = @() fetchFcnOutput(fidx);

start(t)

% todo -> handle situation where nargout = 0;


% TODO -> MAKE EFFICIENT

	function evalFcnFcn( idx, fcn, numOut, varargin)
		out = cell(1,numOut);
		[out{:}] = feval( fcn, varargin{:});
		futMap(idx) = out;
	end
	function out = fetchFcnOutput(idx)
		try
			out = futMap(idx);			
			try
                cleanupObj.task(t);
            catch
                delete(t);
            end
			futMap(idx) = [];
			futMap.remove(idx);
		catch me
			msg = getReport(me);
			disp(msg)
			start(t)
		end
	end
    function tryDeleteTimer(tIn)
        try
            delete(tIn)
        catch
        end
    end
end



%promFcnStruct = struct('Function', fcn, 'Idx', idx, 'FetchOutputFcn', futVal);
% function s = emptyPromiseStruct(fcn,fut)
% if nargin < 2
% 	fut = @() getFcnOutput(promFcn);
% end
% if nargin < 1
% 	fcn = @() [];
% end
%
% s = struct( 'Function', @()[],
% end