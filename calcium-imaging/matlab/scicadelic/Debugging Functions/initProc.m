function proc = initProc(procInput)

if nargin < 1
	procInput = [];
end

TL = [];
chunkSize = [];

if ~isempty(procInput)
	if isstruct(procInput)
		if isfield(procInput, 'tl')
			procInput = dismissProc(procInput);
			TL = procInput.tl;		
		end		
	elseif strcmp('scicadelic.TiffStackLoader',class(procInput))
		TL = procInput;	
	elseif isnumeric(procInput)
		chunkSize = procInput;
	end
end




if isempty(TL)
	TL = scicadelic.TiffStackLoader;
	TL.FramesPerStep = chunkSize;
	setup(TL)	
else
	reset(TL)
end


MF = scicadelic.HybridMedianFilter;
CE = scicadelic.LocalContrastEnhancer;
MC = scicadelic.MotionCorrector;
TF = scicadelic.TemporalFilter;
SC = scicadelic.StatisticCollector;
SC.DifferentialMomentOutputPort = true;


%% PREALLOCATE
% N = TL.NFrames;


proc.tl = TL;
proc.mf = MF;
proc.ce = CE;
proc.mc = MC;
proc.tf = TF;
proc.sc = SC;
proc.idx = 0;
proc.m = 0;