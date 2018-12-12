function [F, varargout] = feedFrameChunk(proc)
% Mark Bucklin
% >> F = feedFrameChunk(proc);
% >> [F, mot, dstat] = feedFrameChunk(proc);
% >> [F, mot, dstat, proc] = feedFrameChunk();
persistent h

if nargin < 1
	proc = initProc();
	assignin('base','proc',proc)
end

% idx = proc.idx;
m = proc.m;

N = proc.tl.NumFrames;
numFrames = proc.tl.FramesPerStep;
% numSteps = ceil(N/numFrames);


benchTic = tic;
m=m+1;

% LOAD
[F, idx] = proc.tl.step();
fprintf('IDX: %d-%d ===\t',idx(1),idx(end));
loadTime = toc(benchTic);
fprintf('Load: %3.3gms\t',1000*loadTime/numFrames); benchTic=tic;


% HYBRID MEDIAN FILTER ON GPU
F = step(proc.mf, F);

% CONTRAST ENHANCEMENT
if isfield(proc, 'ce') && ~isempty(proc.ce)
	F = step(proc.ce, F);
	processTime = toc(benchTic);
	fprintf('PreProc: %3.3gms\t',1000*processTime/numFrames);benchTic=tic;
end

% GAUSSIAN SMOOTHING FILTER (NEW)
% F = uint16(gaussFiltFrameStack(F, 1.5));

% MOTION CORRECTION
if ~isempty(proc.mc)
	F = step( proc.mc, F);
	processTime = toc(benchTic);
	fprintf('MotionCorrection: %3.3gms\t',1000*processTime/numFrames);benchTic=tic;
	mot = proc.mc.CorrectionInfo;
	if nargout > 1
		varargout{1} = mot;
	else
		assignin('base','mot',mot);
	end
end

% TEMPORAL SMOOTHING
F = step(proc.tf, F);


% STATISTIC COLLECTION
dstat = step(proc.sc, F);
processTime = toc(benchTic);
fprintf('Stats: %3.3gms\t',1000*processTime/numFrames);%benchTic=tic;

proc.idx = idx;
proc.m = m;

if nargout > 2
	varargout{2} = dstat;
else
	assignin('base','dstat',dstat);
end

if nargout > 3
	varargout{3} = proc;
end


%% DISPLAY
% try
% TODO: use imscplay -> in imscplay provide option for immediate play
% im = max(abs(diffMoment.M4),[],3);
% im = log1p(abs(im));% .* sign(im);
% im_gpu = gaussFiltFrameStack(log1p(abs(diffMoment.M4)),1.5);
% im = oncpu(im_gpu);
% if ~exist('h','var') || isempty(h) || ~isfield(h, 'fig') || ~ishandle(h.fig) || ~isvalid(h.fig)
% 	h = imscplay(im, .05, true);
% else
% 	s = getappdata(h.fig, 's');
% 	s.f = im;
% 	s.k = 1;
% 	s.n = size(im,3);	
% 	setappdata(h.fig, 's',s);
% 	setappdata(h.fig, 'k',1);
% 
% 	t = getappdata(h.fig, 't');
% 	isRunning = strcmpi(t.Running, 'on'); startTimeout = tic;
% 	while isRunning && (toc(startTimeout) < .5)
% 		pause(.05);
% 		isRunning = strcmpi(t.Running, 'on');		
% 	end
% 	if ~isRunning
% 		start(t)
% 	end
% 	% 	h.CData = gather(im);
% 	
% end
% h.ax.CLim = [18 31];
% drawnow
% catch me
% 	keyboard
% end

%%
fprintf('\n')
if idx(end) >= N
	reset(proc.tl);
end
