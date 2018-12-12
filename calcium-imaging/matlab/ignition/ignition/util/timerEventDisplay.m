function timerEventDisplay(src,evnt)

persistent lastCallTime
persistent meanElapsedTime

% currentCallTime = datenum(evnt.Data.time);

tVec = evnt.Data.time;
currentCallTime = tVec(end) + 60*tVec(end-1) + 3600*tVec(end-2);

if ~isempty(lastCallTime)
	elapsedTime = currentCallTime - lastCallTime;
	meanElapsedTime = .98*meanElapsedTime + .02*elapsedTime;
else
	meanElapsedTime = 0;
end
	
lastCallTime = currentCallTime;


fprintf('%3.2gms\n',meanElapsedTime*1000)
