function guid = generateGUID()

% CHOOSE FASTEST METHOD AVAILABLE FOR CURRENT PLATFORM/ENVIRONMENT
% (todo: write generic function for this)
persistent preferredFcn
availableFcnList = {@javaGUID,@tempnameGUID,@mexGUID,@dotnetGUID};
if isempty(preferredFcn)
	for k=1:numel(availableFcnList)
		fcn = availableFcnList{k};
		try
			fcnRunTime(k) = timeit(@() fcn(), 1);
		catch
			fcnRunTime(k) = inf;
		end
	end
	[fastestFcnRunTime,fastestFcnIdx] = min(fcnRunTime);
	if ~isinf(fastestFcnRunTime)
		preferredFcn = availableFcnList{fastestFcnIdx};
		fprintf('Optimized %s: fastest function is %s (runtime = %3.3gms)\n',...
			mfilename, func2str(preferredFcn), fastestFcnRunTime*1000);
	else
		error(generatemsgid('FastestFunctionFailure2Find',which(mfilename)));
	end
end

% CALL FASTEST AVAILABLE FUNCTION (STORED IN PERSISTENT FUNCTION HANDLE)
guid = preferredFcn();


end




% ========================================
% AVAILABLE FUNCTIONS
% ========================================

function guid = javaGUID()
% TRY JAVA IMPLEMENTATION
guid = toString(java.util.UUID.randomUUID());
%juuid = toString(java.util.UUID.randomUUID());
% guid = char(juuid.toString);
% .getLeastSignificantBits
% .getMostSignificantBits
end

function guid = tempnameGUID()
% GENERATE UUID STRING USING TEMPNAME FUNCTION (OS-DEPENDENT?)
[~, tempfileid] = fileparts(tempname);
if strcmp(tempfileid(1:2),'tp')
	tempfileid = tempfileid(3:end);
end
% CONVERT HEXADECIMAL CHARACTER ARRAY
guid = strrep(tempfileid, '_', '-');
end

function guid = mexGUID()
% MEX IMPLEMENTATION (FASTER, FROM LEV MUCHNIK)
% todo: make mex implementation available in external sources folder
mexguid = mexCreateGUID();
guid = lower(mexguid(2:end-1));
end

function guid = dotnetGUID()
persistent asm
if isempty(asm)
	asm = NET.addAssembly('mscorlib');
end
guid = ToString(System.Guid.NewGuid);
end


