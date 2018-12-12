function behaviordata = loadBehaviorData(varargin)

previousPath = pwd;
if nargin > 0
   cd(varargin{1})
end
pnormcol = @(v)bsxfun(@rdivide,bsxfun(@minus,v,min(v,[],1)),range(v,1));
Fs = 20;

% LOAD TRIAL AND LICK DATA (trial)
trialdata = importTrialData();
nTrial = min(200, size(trialdata,1));
trialdata = trialdata(1:nTrial,:);
try
   lickdata = importLickData();
catch
   load('lickdata.mat')
end
% LOAD VIDEO TIMESTAMP INFO
file.vid = dir('Processed_VideoFiles*');
[~,idx] = max(datenum({file.vid.date}));
load(file.vid(idx).name);
info = getInfo(allVidFiles);
t = cat(1,info.time);

% FIND FRAME INDICES ALIGNED WITH TRIAL STARTS
trialidx.short = find(trialdata.stim == min(trialdata.stim));
trialidx.long = find(trialdata.stim == max(trialdata.stim));
trialidx.longovershort = cat(1,trialidx.long, trialidx.short);
frameidx.alltrials = find(any(bsxfun(@ge, t, trialdata.tstart') & bsxfun(@lt, circshift(t,1), trialdata.tstart'),2));
frameidx.shorttrial =frameidx.alltrials(trialidx.short);
frameidx.longtrial = frameidx.alltrials(trialidx.long);

nTrials = numel(frameidx.alltrials);
M = numel(t);

% FIND FRAME INDICES ALIGNED WITH LICKS
frameidx.alllicks = find(any( bsxfun(@ge, t, lickdata.tlick') & bsxfun(@lt, circshift(t,1), lickdata.tlick'), 2));
lickbool = false(M,1);
lickbool(frameidx.alllicks) = true;
for k = 1:nTrials
   trialBin = false(M,1);
   if k<nTrials
	  trialBin(frameidx.alltrials(k):frameidx.alltrials(k+1)) = true;
   else
	  trialBin(frameidx.alltrials(k):end) = true;
   end
   if any(lickbool & trialBin)
	  frameidx.firstlick(k,1) =  find(lickbool & trialBin, 1, 'first');
   else
	  frameidx.firstlick(k,1) = NaN;
   end
end
frameidx.shortlick = frameidx.firstlick(trialidx.short);
frameidx.longlick = frameidx.firstlick(trialidx.long);

% CONSTRUCT BINARY BEHAVIOR STRUCTURE (SYNC TO VIDEO FRAMES)
nLicks = numel(frameidx.alllicks);
bhvlogical.lick = false(M,1);
bhvlogical.lick(frameidx.alllicks) = true;
bhvlogical.soundlick = false(M,1);
bhvlogical.soundlick(frameidx.alllicks) = logical(lickdata.duringsound(1:nLicks));
bhvlogical.windowlick = false(M,1);
bhvlogical.windowlick(frameidx.alllicks) = logical(lickdata.duringwindow(1:nLicks));
bhvlogical.itilick = false(M,1);
bhvlogical.itilick(frameidx.alllicks) = logical(lickdata.duringiti(1:nLicks));
bhvlogical.shortlick = false(M,1);
% note: sometimes the lickdata.stim data takes on 3 values {0,1,2}, with the first few readings being 0 -> should
% be fixed in labview code running experiment (or better yet, drop labview entirely!)
% bhvlogical.shortlick(frameidx.alllicks) = lickdata.stim(1:nLicks) == min(lickdata.stim(:));
bhvlogical.shortlick(frameidx.alllicks) = lickdata.stim(1:nLicks) == max(lickdata.stim(:)) - 1;
bhvlogical.longlick = false(M,1);
bhvlogical.longlick(frameidx.alllicks) = lickdata.stim(1:nLicks) == max(lickdata.stim(:));
fld = fields(bhvlogical);

% STRUCTURE OF LOGICAL FIRST LICKS
for fn = 1:numel(fld)
   bhvlogical.first.(fld{fn}) = false(M,1);
end
for k=1:nTrials
   trialBin = false(M,1);
   if k<nTrials
	  trialBin(frameidx.alltrials(k):frameidx.alltrials(k+1)) = true;
   else
	  trialBin(frameidx.alltrials(k):end) = true;
   end
   for fn = 1:numel(fld)
	  bhvlogical.first.(fld{fn})(find(bhvlogical.(fld{fn}) & trialBin, 1, 'first')) = true;
   end
end

% STRUCTURE OF NAN LICKS LICKS
for fn = 1:numel(fld)
   bhvlogical.nan.(fld{fn}) = NaN(M,1);
   bhvlogical.nan.(fld{fn})(bhvlogical.(fld{fn})) = 1;
end

% STRUCTURE OF NAN FIRST LICKS
for fn = 1:numel(fld)
   bhvlogical.nanfirst.(fld{fn}) = NaN(M,1);
   bhvlogical.nanfirst.(fld{fn})(bhvlogical.first.(fld{fn})) = 1;
end

% LOGICAL SOUND/TRIAL STRUCTURE
L = 6*Fs-1;
slog.all = false(M,1);
slog.firstsecond = false(M,1);
slog.long = false(M,1);
slog.short = false(M,1);
for k=1:nTrials
   n = frameidx.alltrials(k);
   slog.all(n:n+L) = true;
   slog.firstsecond(n:n+Fs-1) = true;
   if any(k== trialidx.long)
	  slog.long(n:n+L) = true;
   else
	  slog.short(n:n+L) = true;
   end
end

% ADD BEHAVIOR SIGNALS AS CONVOLVED IMPULSES WITH ESTIMATED GAUSSIAN RESPONSE KERNEL
sig.kern.lick = gausswin(20,6);
sig.kern.long = chebwin(80,120);
sig.kern.short = chebwin(80,120);
sig.lick = zeros(M,1,'single');
sig.short = zeros(M,1,'single');
sig.long = zeros(M,1,'single');
sig.short(frameidx.shorttrial) = 1;
sig.long(frameidx.longtrial) = 1;
sig.lick(frameidx.alllicks) = 1;
sig.short = pnormcol(conv(sig.short, sig.kern.short, 'same'));
sig.long = pnormcol(conv(sig.long, sig.kern.long, 'same'));
sig.lick = pnormcol(conv(sig.lick, sig.kern.lick, 'same'));

% ADD PERFORMANCE DATA
performance = getTaskPerformance(frameidx);

behaviordata.performance = performance;
behaviordata.licklogical = bhvlogical;
behaviordata.soundlogical = slog;
behaviordata.frameidx = frameidx;
behaviordata.trialidx = trialidx;
behaviordata.sig = sig;
behaviordata.t = t;
behaviordata.file = file;






cd(previousPath)



% strips(bhv.sig.short(3000:9000))
% hold on
% strips(bhv.sig.long(3000:9000))
% strips(bhv.licklogical.lick(3000:9000))
% strips(bhv.licklogical.first.lick(3000:9000))
% strips(bhv.licklogical.first.windowlick(3000:9000))
% strips(bhv.licklogical.first.soundlick(3000:9000))
% strips(bhv.licklogical.first.itilick(3000:9000))
% legend( 'Short Tone', 'Long Tone', 'All Licks', 'First Lick (of trial)', 'First Lick in Response Window', 'First Lick during Sound', 'First Lick during ITI')
% title('Early Trial Structure Example with Licks')
% xlabel('Frames')