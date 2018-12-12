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
	elseif strcmp('rtsci.TiffStackLoader',class(procInput))
		TL = procInput;	
	elseif isnumeric(procInput)
		chunkSize = procInput;
	end
end




if isempty(TL)
	TL = rtsci.TiffStackLoader;
	TL.FramesPerStep = chunkSize;
	setup(TL)	
else
	reset(TL)
end


MF = rtsci.HybridMedianFilter;
CE = rtsci.LocalContrastEnhancer;
MC = rtsci.MotionCorrector;
TF = rtsci.TemporalFilter;
SC = rtsci.StatisticCollector;
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
