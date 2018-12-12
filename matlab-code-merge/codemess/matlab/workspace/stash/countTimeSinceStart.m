function countTimeSinceStart(varargin) %t,evnt)

persistent firstTic currentIter allToc

if isempty(firstTic)
	firstTic = tic;
end
if isempty(currentIter)
	currentIter = 0;
else
	currentIter = currentIter + 1;
end
N = 25;

allToc = [allToc toc(firstTic)];

if currentIter == N
	spmd
		labSend( allToc, 1)
	end
	% 	t.UserData = allToc;
elseif currentIter > N	
	currentIter = 0;
	firstTic = tic;
end
