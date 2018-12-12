function pf = proc2huaanpar()

mouseDir = pwd;
expDir = dir('Ali*');
prevProc = false(numel(expDir),1);
for kDir = 1:numel(expDir)
   fullExpDir = [mouseDir,filesep,expDir(kDir).name];
   huaanFile = dir([fullExpDir,'\*_HuaanData.mat']);
   prevProc(kDir) = isempty(huaanFile);
end
[selection, ok] = listdlg(...
   'PromptString','Select Experiments (Days) to Process',...
   'ListString',{expDir.name},...
   'SelectionMode','multiple',...
   'InitialValue',find(prevProc),...
   'OKString','Process',...
   'ListSize',[300 300]);
if ok ~= 1
   return
end
expDir = expDir(selection);
procMouseFcn = @procMouseDay;
for kDir = 1:numel(expDir)
   fullExpDir = [mouseDir,filesep,expDir(kDir).name];
   %    procMouseDay(expDir(kDir).name)
   pf(kDir) = parfeval(procMouseFcn, 0, fullExpDir);
end


   function procMouseDay(fdir)
	  cd(fdir);
	  fname = dir([fdir,'\Ali*.tif']);
	  [allVidFiles, R, info, uniqueFileName] = processFast(fname);
	  try
		 [data, vidinfo] = getData(allVidFiles);
		 data = squeeze(data);
		 makeTraceFromVid(R,data);
		 
		 M = numel(R);
		 maxArea = max([R.Area]);
		 maskSize = size(R(1).createMask);
		 roi(M,1) = struct(...
			'filename',uniqueFileName,...
			'mask', spalloc(maskSize(1), maskSize(2), maxArea),...
			'centroid', [0 0],...
			'df', R(M).Trace,...
			'time',vidinfo.time);
		 for k = 1:M
			roi(k,1).filename = uniqueFileName;
			roi(k,1).mask = sparse(R(k).createMask);
			roi(k,1).centroid = R(k).Centroid;
			roi(k).df = R(k).Trace;
			roi(k,1).time = vidinfo.time;
		 end
		 save(fullfile(fdir,[uniqueFileName,'_HuaanData']),'roi', '-v6')
		 save(fullfile(fdir,[uniqueFileName,'_ROIwithTraces']), 'R')
		 cd(mouseDir)
	  catch me
		 showError(me)
	  end
   end

end