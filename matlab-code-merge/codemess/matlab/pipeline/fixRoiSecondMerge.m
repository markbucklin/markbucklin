function fixRoiSecondMerge(mouseDir)
if nargin < 1
   mouseDir = pwd;
end
expDir = dir('Ali*');
expDir = expDir([expDir.isdir]);

for kDir = 1:numel(expDir)
   fullExpDir = [mouseDir,filesep,expDir(kDir).name];
   allRoiFile = dir([fullExpDir,'\allROI.mat']);
   vidDataFile = dir([fullExpDir,'\*VideoFiles*.mat']);
   if ~isempty(allRoiFile)
	  fprintf('Fixing Pixel Counts in: %s\n',fullExpDir)
	  load(fullfile(fullExpDir,allRoiFile.name));
	  R = fixPixCounts(R);
	  R = reduceSuperRegions(R);
	  fds = zeros(numel(R),1);
	  for k=1:numel(R)
		 fds(k,1) = sum(diff(R(k).Frames) == 1) / sum(diff(R(k).Frames) > 2);
	  end
	  fdsmin = 1;
	  while sum(fds >= fdsmin) > 1000
		 fdsmin = fdsmin + .1;
	  end
	  R = R(fds >= fdsmin);	  
   end
   if ~isempty(vidDataFile)
	  load(fullfile(fullExpDir, vidDataFile(1).name));
	  [data, vidinfo] = getData(allVidFiles);
	  makeTraceFromVid(R,data);
   end
   save(fullfile(fullExpDir, 'PixCountFixedROI.mat'), 'R');
end


% 
% previousFullPath = fullfile(fullExpDir,allRoiFile.name);
% 	  [previousPath,previousName] = fileparts(previousFullPath);
% 	  newFileName = [previousName,...
% 	   datestr(allRoiFile.datenum,'_yyyymmdd_HHMM'),...
% 	   '.mat'];
% 	newFullPath = fullfile(mouseDir, newFileName);
% 	copyfile(previousFullPath, newFullPath)
% 	movefile(previousFullPath, fullfile(previousPath,newFileName));