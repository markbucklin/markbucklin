function varargout = dismissProc(proc)

procFields = fields(proc);
for k=1:numel(procFields);
	fn = procFields{k};
	
	if isobject(proc.(fn))
		if strncmp('scicadelic',class(proc.(fn)), 5)
			release(proc.(fn))
		end
	end
end

if nargout
	varargout{1} = proc;
end


	%
	% if ~exist('TL','var')
	% 	TL = scicadelic.TiffStackLoader;
	% 	TL.FramesPerStep = 16;
	% 	setup(TL)
	% else
	% 	reset(TL)
	% end
	% MF = scicadelic.HybridMedianFilter;
	% CE = scicadelic.LocalContrastEnhancer;
	% MC = scicadelic.MotionCorrector;
	% SC = scicadelic.StatisticCollector;
	% SC.DifferentialMomentOutputPort = true;
	%
	%
	% %% PREALLOCATE
	% % N = TL.NFrames;
	%
	%
	% proc.tl = TL;
	% proc.mf = MF;
	% proc.ce = CE;
	% proc.mc = MC;
	% proc.sc = SC;
	% proc.idx = 0;
	% proc.m = 0;