function rpt = benchTimeFcn( absTimeFcn , elapsedTimeFcn)

if nargin < 1
	
	%import performance.utils.*
	%import matlab.internal.timing.*
	
	defaultAbsElapsFcn = {...
		@now ,									@(t0) now() - t0 ;...
		@clock,									@(t0) etime(clock, t0) ;...
		@()datenum(clock) ,			@(t0) datenum(clock) - t0 ;...
		@tic,										@(t0) toc(t0) ;...
		@cputime,								@(t0) cputime - t0 ;...
		@performance.utils.getMicrosecondTimer,...
		@(t0) performance.utils.getMicrosecondTimer() - t0 ;...
		@performance.utils.getMillisecondTimer,...
		@(t0) performance.utils.getMillisecondTimer() - t0 ;...
		@()matlab.internal.timing.timing('cpucount'),...
		@(t0) matlab.internal.timing.timing('cpucount') - t0 	};
	
	
	
	% 		@getMicrosecondTimer,   @(t0) getMicroSecondTimer() - t0 ;...
	% 		@getMiillisecondTimer,  @(t0) getMiillisecondTimer() - t0 ;...
	% 		@()timing('cpucount'),	@(t0) timing('cpucount') - t0 	};
	
	absTimeFcn = defaultAbsElapsFcn(:,1);
	elapsedTimeFcn = defaultAbsElapsFcn(:,2);
	
elseif nargin < 2
	if iscell(absTimeFcn)
		genElapsedTime = @(fcn) @(t0) fcn() - t0 ;
		elapsedTimeFcn = cellfun(genElapsedTime, absTimeFcn, 'UniformOutput',false);
	else
		elapsedTimeFcn = @(t0) absTimeFcn() - t0;
	end
end


if iscell(absTimeFcn)
	rptMap = containers.Map;
	for k=1:numel(absTimeFcn)
		absFcn = absTimeFcn{k};
		elapFcn = elapsedTimeFcn{k};
		fcnStr = func2str(absFcn);
		rptMap(fcnStr) = runTimeFcnBenchmark(absFcn, elapFcn);
	end
	
	% RETURN STRUCT ARRAY WITH MAP FIELD
	rptvals = rptMap.values;
	rpt = [rptvals{:}]
	rptnames = rptMap.keys;
	[rpt.name] = rptnames{:};
	% 	rptvals = rptMap.values;
	% 	rpt = [rptvals{:}]
	% 	rptnames = rptMap.keys;
	% 	[rpt.name] = rptnames{:};
	
	
	% OR RETURN A MAP CONTAINER
	% rpt = rptMap;
	
elseif isa(absTimeFcn, 'function_handle')
	rpt = runTimeFcnBenchmark(absTimeFcn, elapsedTimeFcn);
	
else
	error('Ignition:Util:BenchTimeFcn:UnexpectedInput',...
		'Expected input is either a function handle or cell array of function handles')
	
end


end


function rpt = runTimeFcnBenchmark(absFcn, elapFcn);

for k=1:50
	t0=absFcn();
	try,	tElap = elapFcn(t0); catch, end
end

% TIMEIT
rpt.AbsTimeitTimeMicros = timeit(@() absFcn(), 1)*2^20;
t0 = absFcn();
rpt.ElapTimeitTimeMicros = timeit(@() elapFcn(t0), 1)*2^20;
rpt.EnclosedTimeitTimeMicros = timeit(@() elapFcn(absFcn()), 1)*2^20;

% CHECK CONFORMANCE WITH SPECIFIED MATLAB 'PAUSE' TIME
rpt.PauseTime1Sec = checkPauseTime(absFcn,elapFcn, 1.0 );
rpt.PauseTime100MSec = checkPauseTime(absFcn,elapFcn, 0.1);
rpt.PauseTime10MSec = checkPauseTime(absFcn,elapFcn, 0.01);
rpt.PauseTime1MSec = checkPauseTime(absFcn,elapFcn, 0.001);

% CHECK CONFORMANCE SPECIFIED TIMER 'PERIOD'



end

function actualTimeSecs = checkPauseTime(absFcn,elapFcn,pauseTimeSecs)

N = ceil(1/pauseTimeSecs);
T = 0;
for k=1:N
	t0 = absFcn();
	pause(pauseTimeSecs);
	tElap = elapFcn(t0);
	T = T + double(tElap);
end

actualTimeSecs = T/N;

end
















% jo = com.mathworks.jmi.Callback
% set(jo,'DelayedCallback', @(varargin)fprintf('time is %f\n',now))
% jo.postCallback
% then = now;
% set(jo,'DelayedCallback', @(varargin)fprintf('time passed: %f\n',now-then));
% jo.postCallback



% microtimer = performance.utils.getMicrosecondTimer
% -> uint64

% matlab.internal.timing.timing('resolution_tictoc')*2^20
% t = matlab.internal.timing.timing('cpucount')
% matlab.internal.timing.timing('resolution_tictoc')
% matlab.internal.timing.timing('overhead_tictoc')*10^6
% matlab.internal.timing.timing('getcpuspeed_tictoc')
% matlab.internal.timing.timing('cpuspeed')
% matlab.internal.timing.timing('clocks_per_sec')
% matlab.internal.timing.timing('posixrtperftime')
% matlab.internal.timing.timing('posixrtperfspeed')
% matlab.internal.timing.timing('cpucount')