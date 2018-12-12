
%% load
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0809 - 42DAT\0628GE-M2LH-042DAT-60fps00001\ROIs (2files).mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0809 - 42DAT\0628GE-M2LH-042DAT-60fps00001\BlueTraceROIs.mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0809 - 42DAT\0628GE-M2LH-042DAT-60fps00001\RedTraceROIs.mat')
m2lh.roi.dat42 = R;
m2lh.blue.dat42 = traceOutBlue;
m2lh.red.dat42 = traceOutRed;
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0809 - 42DAT\0628GE-M2RH-042DAT-60fps00001\BlueTraceROIs.mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0809 - 42DAT\0628GE-M2RH-042DAT-60fps00001\RedTraceROIs.mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0809 - 42DAT\0628GE-M2RH-042DAT-60fps00001\ROIs (2files).mat')
m2rh.roi.dat42 = R;
m2rh.blue.dat42 = traceOutBlue;
m2rh.red.dat42 = traceOutRed;
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0919 - 83DAT\0628GE-M2LH-083DAT-60fps00002\BlueTraceROIs.mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0919 - 83DAT\0628GE-M2LH-083DAT-60fps00002\RedTraceROIs.mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0919 - 83DAT\0628GE-M2LH-083DAT-60fps00002\ROIs (2files).mat')
m2lh.roi.dat83 = R;
m2lh.blue.dat83 = traceOutBlue;
m2lh.red.dat83 = traceOutRed;
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0919 - 83DAT\0628GE-M2RH-083DAT-60fps00001\BlueTraceROIs.mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0919 - 83DAT\0628GE-M2RH-083DAT-60fps00001\RedTraceROIs.mat')
load('Z:\Data\susie\[Temp Data] Processing\[SC0628] mCerulean;turboRFP;tdTomato;mCherry;GCaMP\I0919 - 83DAT\0628GE-M2RH-083DAT-60fps00001\ROIs (2files).mat')
m2rh.roi.dat83 = R;
m2rh.blue.dat83 = traceOutBlue;
m2rh.red.dat83 = traceOutRed;

%% get structure of functions
fcn = binaryStatisticFunctions();

%% get firing rate

thresh.blue =.75;
thresh.red = 10;

mouseSiteName = {'m2lh','m2rh'};
colorName = {'blue','red'};
datName = {'dat42','dat83'};
statfcnName = fields(fcn);
% datnum = {42, 83};
% datName = cellfun(@(num)sprintf('dat%d',num), datnum ,'UniformOutput','false');

s.m2rh = m2rh;
s.m2lh = m2lh;

%%


for kSite = 1:numel(mouseSiteName)
    for kColor = 1:numel(colorName)
        for kDat = 1:numel(datName)
            for kStatfcn = 1:numel(statfcnName)
                site = mouseSiteName{kSite};
                color = colorName{kColor};
                dat = datName{kDat};
                statfcn = statfcnName{kStatfcn};
                f = fcn.(statfcn);
                x = s.(site).(color).(dat);
                result = feval(f,  x > thresh.(color));
                out.(statfcn).(site).(color).(dat) = result;
            end            
        end
    end
end


%%
histogram( out.P_X.m2rh.blue.dat42, 40 )
histogram( out.P_X.m2rh.blue.dat83, 40 )
histogram( out.P_X.m2lh.blue.dat42, 40 )
histogram( out.P_X.m2lh.blue.dat83, 40 )
legend({'dat42','dat83'}), title('firingprobability: m2rh (blue>1)')
cla



%%
%     for kStatfcn = 1:numel(statfcnName)
%                 site = mouseSiteName{kSite};
%                 color = colorName{kColor};
%                 dat = datName{kDat};
%                 %                 statfcn = statfcnName{kStatfcn};
%                 %                 f = fcn.(statfcn);                
%                 statfcn = 'P_X';
%                 x = s.(site).(color).(dat);
%                 result = feval(fcn.P_X,  x > thresh.(color));
%                 out.(statfcn).(site).(color).(dat) = result;
%                 statfcn = 'P_XandY';
%                 x = s.(site).(color).(dat);
%                 result = feval(fcn.P_X,  x > thresh.(color));
%                 out.(statfcn).(site).(color).(dat) = result;
%                 statfcn = 'P_X';
%                 x = s.(site).(color).(dat);
%                 result = feval(fcn.P_X,  x > thresh.(color));
%                 out.(statfcn).(site).(color).(dat) = result;
% %             end
%             





%             P_X.(site).(color).(dat) = fcn.P_X((site).(color).(dat));
%             P_XandY.(site).(color).(dat) = fcn.P_XandY((site).(color).(dat));
% m2lh.pblue.dat42 = fcn.P_X(m2lh.blue.dat42 > bluethresh);
% m2lh.pblue.dat83 = fcn.P_X(m2lh.blue.dat83 > bluethresh);
% m2rh.pblue.dat42 = fcn.P_X(m2rh.blue.dat42 > bluethresh);
% m2rh.pblue.dat83 = fcn.P_X(m2rh.blue.dat83 > bluethresh);
%
%
% redthresh = 10;
% m2lh.pred.dat42 = fcn.P_X(m2lh.blue.dat42 > bluethresh);
% m2lh.pred.dat83 = fcn.P_X(m2lh.blue.dat83 > bluethresh);
% m2rh.pred.dat42 = fcn.P_X(m2rh.blue.dat42 > bluethresh);
% m2rh.pred.dat83 = fcn.P_X(m2rh.red.dat83 > bluethresh);