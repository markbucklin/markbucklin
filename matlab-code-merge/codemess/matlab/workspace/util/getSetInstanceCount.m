function cnt = getSetInstanceCount(key)

mlock;
persistent instance_count

% CHECK IF THIS CLASS ALREADY HAS STORED ID-FACTORY
if isempty(instance_count)
	instance_count = containers.Map;
end

% CHECK IF ROOT HAS BEEN ESTABLISHED
if ~isKey(instance_count, key)
	cnt = 1;
else
	cnt = instance_count(key) + 1;
end

% UPDATE CLASS INSTANCE COUNT
instance_count(key) = cnt;


end




% Alternative version that was defined in ign.core.Handle class

% function [classCnt, handleCnt] = getSetInstanceCount(key)
% 
% % todo: fix to use either environment var only or persistent only
% 
% mlock;
% persistent class_instance_count
% %persistent environment_variable_reset
% persistent handle_instance_count 
% 
% lastCntVarName = 'ign.core.Handle:last_handle_instance_count';
% 
% % GET HANDLE-INSTANCE-COUNT
% if isempty(handle_instance_count)
% 	lastCntStrVal = getenv(lastCntVarName);
% 	if isempty(lastCntStrVal)
% 		lastCntStrVal = '0';
% 		environment_variable_reset = onCleanup(@() setenv(lastCntVarName, ''));
% 	end
% 	handle_instance_count = str2double(lastCntStrVal) + 1;
% else
% 	handle_instance_count = handle_instance_count + 1;
% end
% setenv(lastCntVarName, num2str(handle_instance_count));
% handleCnt = handle_instance_count;
% 
% %handleCnt = handle_instance_count + 1;
% %handleCnt = str2double(lastCntStrVal) + 1;
% %setenv(lastCntVarName, num2str(handle_instance_count));
% % todo -> is this slow??
% 	
% % INCREMENT INSTANCE COUNT FOR ALL HANDLES
% % if ~isempty(handle_instance_count)
% % 	handle_instance_count = handle_instance_count + 1;	
% % else
% % 	handle_instance_count = 0;
% % end
% 
% % CHECK IF THIS CLASS ALREADY HAS STORED ID-FACTORY
% if isempty(class_instance_count), class_instance_count = containers.Map; end
% 
% % CHECK IF ROOT HAS BEEN ESTABLISHED
% if ~isKey(class_instance_count, key)
% 	% todo: check environment variable
% 	classCnt = 1;
% else
% 	classCnt = class_instance_count(key) + 1;
% end
% 
% % UPDATE CLASS INSTANCE COUNT
% class_instance_count(key) = classCnt;
% 
% % WRITE INSTANCE COUNT TO ENVIRONMENT VARIABLE
% 
% end
% 
% % todo -> set semaphore for environment variable updates
% 
% % use environment variables storing current count and last update time (creation time)
% % lastTimeVarName = 'ign.core.Handle:last_instance_update_time';
% % curTime = now;
% % lastTimeStr = getenv(lastTimeVarName);
% % if isempty(lastTimeStr)
% % 	setenv(lastTimeVarName, datestr(curTime));
% % else
% % 	lastTime = datenum(lastTimeStr);
% % 	if( etime( datevec(curTime), datevec(lastTime)