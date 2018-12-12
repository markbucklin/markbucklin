function reloadTraceData()
mouseDir = pwd;
expDir = getExperimentDirectories();
for kDir = 1:numel(expDir)   
   fprintf('Re-Loading data from %s\n',expDir(kDir).name);
   fdir = [mouseDir,filesep,expDir(kDir).name];
   
   cd(fdir)
   % LOAD ROI DATA (R)
   file.roi = dir([pwd,'\Processed_ROIs_*.mat']);
   [~,idx] = max(datenum({file.roi.date}));
   roiFileName = file.roi(idx).name;
   load(file.roi(idx).name);
   
   file.vid = dir([pwd,'\Processed_VideoFiles_*.mat']);
   [~,idx] = max(datenum({file.vid.date}));
   load(file.vid(idx).name);
   [data, info] = getData(allVidFiles);
   % Frame Numbers
   %    fn = cat(1,info.FrameNumber);
   %    fnmax = max(fn);
   %    fn = round(unwrap(fn.*(2*pi/fnmax)) .* (fnmax/(2*pi)));
   %TODO: FIX TIME
   try
	  makeTraceFromVid(R, data);
	  clear data
	  for k = 1:numel(R)
		 R(k).RawTrace = R(k).Trace;
	  end
	  R.normalizeTrace2WindowedRange
	  R.makeBoundaryTrace
	  R.filterTrace
	  save(fullfile(fdir,['Re_',roiFileName]), 'R')
	  cd(mouseDir)
   catch me
	  showError(me)
	  keyboard
   end
end