function expDir = getExperimentDirectories(targetFile)
if nargin < 1
   targetFile = [];
end
mouseDir = pwd;
expDir = dir('Ali*');
expDir = expDir([expDir.isdir]);
prevProc = false(numel(expDir),1);
if ~isempty(targetFile)
   for kDir = 1:numel(expDir)
	  fullExpDir = [mouseDir,filesep,expDir(kDir).name];
	  huaanFile = dir([fullExpDir,targetFile]);
	  prevProc(kDir) = isempty(huaanFile);
   end
end
if isempty(expDir)
   cd ..
   expDir = getExperimentDirectories(targetFile);
   return
end
[selection, ok] = listdlg(...
   'PromptString','Select Experiments (Days) to Process',...
   'ListString',{expDir.name},...
   'SelectionMode','multiple',...
   'InitialValue',find(prevProc),...
   'OKString','Return',...
   'ListSize',[300 300]);
if ok ~= 1
   return
end
expDir = expDir(selection);
end