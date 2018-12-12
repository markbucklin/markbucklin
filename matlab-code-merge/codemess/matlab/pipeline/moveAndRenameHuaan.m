function moveAndRenameHuaan(mouseDir)
if nargin < 1
   mouseDir = pwd;
end
expDir = dir('Ali*');

for kDir = 1:numel(expDir)
   fullExpDir = [mouseDir,filesep,expDir(kDir).name];
   huaanFile = dir([fullExpDir,'\*_HuaanData.mat']);
   if ~isempty(huaanFile)
	  previousFullPath = fullfile(fullExpDir,huaanFile.name);
	  [previousPath,previousName] = fileparts(previousFullPath);
	  newFileName = [previousName,...
	   datestr(huaanFile.datenum,'_yyyymmdd_HHMM'),...
	   '.mat'];
	newFullPath = fullfile(mouseDir, newFileName);
	copyfile(previousFullPath, newFullPath)
	movefile(previousFullPath, fullfile(previousPath,newFileName));
   end
end