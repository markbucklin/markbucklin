clear all
close all
[fname,fdir] = uigetfile;
load([fdir,fname])
load([fdir,'ExperimentStructure.mat'])
% load the "Processed_ROIs" file
% load('Processed_ROIs_med1-2611_2015_03_03_1304.mat')

X = [R.Trace];
framestart = experimentStructure.trialFirstFrame(1:end-1);
tlen = 600; % number of frames to plot
secondsBefore = 5;
secondsAfter = 25;
for k=1:numel(framestart)
   f1 = framestart(k)-100;
   f2=f1+tlen-1; Xtrial(:,:,k) = X(f1:f2,:);
end
show(R);
stripSeparation = 1;
hax = gca;
for k=1:numel(R) % number of ROIs
   for kt = 1:numel(framestart) % number of trials
	  line(linspace(-secondsBefore, secondsAfter, tlen), Xtrial(:,k,kt)+stripSeparation*(k-1), 'Color', [R(k).Color .2], 'Parent',hax);
   end
   line(linspace(-secondsBefore, secondsAfter, tlen),mean(Xtrial(:,k,:),3)+stripSeparation*(k-1), 'Color', [R(k).Color .9], 'Parent',hax);
end
title(experimentStructure.currentExperimentName)
savefig([fdir,'stripplot_',experimentStructure.currentExperimentName])
save([fdir,'roitrace_',experimentStructure.currentExperimentName],'X','Xtrial')

