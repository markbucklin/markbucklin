function md = loadMultiDayRoi()
mouseDir = pwd;
expDir = dir('Ali*');
expDir = expDir([expDir.isdir]);
prevProc = false(numel(expDir),1);
for kDir = 1:numel(expDir)
   fullExpDir = [mouseDir,filesep,expDir(kDir).name];
   roiFile = dir([fullExpDir,'\Processed_ROIs_*.mat']);
   prevProc(kDir) = ~isempty(roiFile);
end
if isempty(expDir)
   cd ..
   md = loadMultiDayRoi;
   return
end
[selection, ok] = listdlg(...
   'PromptString','Select Experiments (Days) to Load',...
   'ListString',{expDir.name},...
   'SelectionMode','multiple',...
   'InitialValue',find(prevProc),...
   'OKString','Load',...
   'ListSize',[300 300]);
if ok ~= 1
   return
end
expDir = expDir(selection);
for kDir = 1:numel(expDir)
   % REGIONS OF INTEREST
   fullExpDir = [mouseDir,filesep,expDir(kDir).name];   
   roiFile = dir([fullExpDir,'\Processed_ROIs_*.mat']);
   [~,idx] = max(datenum({roiFile.date}'));
   roiFile = roiFile(idx);   
   fname = [fullExpDir, filesep, roiFile.name];
   rwt = load(fname,'R');
   md(kDir).roi = rwt.R;
   md(kDir).filename = roiFile.name;
   md(kDir).filepath = fname;
   md(kDir).experimentpath = fileparts(fname);
   % VIDEO STATISTICS
   statsFile = dir([fullExpDir,'\Processed_VideoStatistics_*.mat']);
   [~,idx] = max(datenum({statsFile.date}'));
   statsFile = statsFile(idx);     
   rvs = load([fullExpDir, filesep, statsFile.name],'vidStats');
   md(kDir).vidstats = rvs.vidStats;
    % PROCESSING SUMMARY
   sumFile = dir([fullExpDir,'\Processing_Summary_*.mat']);
   [~,idx] = max(datenum({sumFile.date}'));
   sumFile = sumFile(idx);     
   rvs = load([fullExpDir, filesep, sumFile.name],'vidProcSum');
   md(kDir).procsum = rvs.vidProcSum;
   % BEHAVIOR
   md(kDir).bhv = loadBehaviorData(fullExpDir);
end