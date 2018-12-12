%%
gcp;
X = [R.Trace];
t = (1:size(X,1))./20;
N = size(X,1);
nRoi = numel(R);
Fs = 20;

% [~,dxdt] = gradient(X, 1:numel(R),t);
% Xb = sum(cat(3,dxdt, circshift(dxdt,-1,1)),3) > 0;
Xb = getStatePredictor(X);
Xbs = sparse(Xb);

%%
% PROBABILITY OVER ENTIRE SIGNAL
PX1 = binaryprob(Xb,1);
PX0 = binaryprob(~Xb,1);

%% SHANNON ENTROPY
Hs = -sum([PX0 PX1] .* log2([PX0 PX1]),2);

%% JOINT PROBABILITY
PXnX = binaryjoint(Xb,Xb);

%% JOINT PROBABILITY WITH BEHAVIOR
bhv = loadBehaviorData;
% LICKS
fld = fields(bhv.licklogical);
for fn = 1:numel(fld)
   fln = fld{fn};
   if islogical(bhv.licklogical.(fln))
	  jointx.lick.(fln) = binaryjoint(Xb, bhv.licklogical.(fln));
   end
end
% FIRST LICKS
fld = fields(bhv.licklogical.first);
for fn = 1:numel(fld)
   fln = fld{fn};
   if islogical(bhv.licklogical.first.(fln))
	  jointx.firstlick.(fln) = binaryjoint(Xb, bhv.licklogical.first.(fln));
   end
end
% SOUNDS
fld = fields(bhv.soundlogical);
for fn = 1:numel(fld)
   fln = fld{fn};
   if islogical(bhv.soundlogical.(fln))
	  jointx.sound.(fln) = binaryjoint(Xb, bhv.soundlogical.(fln));
   end
end


%% CONDITIONAL PROBABILITY
% ZERO LAG
PXIX = binaryconditional(Xb, Xb);
PXI_X = binaryconditional(Xb, ~Xb);
PXIS = binaryconditional(Xb,bhv.soundlogical.all);
PXIs1 = binaryconditional(Xb,bhv.soundlogical.short);
PXIs2 = binaryconditional(Xb,bhv.soundlogical.long);
PXIlick = binaryconditional(Xb,bhv.licklogical.first.lick);
PXnSIlick = binaryconditional({Xb, bhv.soundlogical.firstsecond}, bhv.licklogical.first.lick);
PXnSIslick = binaryconditional({Xb, bhv.soundlogical.firstsecond}, bhv.licklogical.first.soundlick);


bsl(:,3) = abs(PXIs2 - PXIs1) < .01;
bsl(:,2) = ((PXIs2 - PXIs1) >= .01)' & ~bsl(:,3);
bsl(:,1) = ((PXIs2 - PXIs1) <= -.01)' & ~bsl(:,3);
bsl = bsxfun(@times, double(bsl), pnormalize(abs(.5-PXIS)'));
for k=1:numel(R), R(k).Color = bsl(k,:); end

%% TRANSFER ENTROPY (from download)
firstFrameIdx = bhv.frameidx.alltrials;
avgTrialLength = mean(diff(firstFrameIdx));
lastFrameIdx = firstFrameIdx + avgTrialLength;
if lastFrameIdx > N
   firstFrameIdx = firstFrameIdx(1:end-1);
   lastFrameIdx = lastFrameIdx(1:end-1);
end
parfor kTrial = 1:numel(firstFrameIdx)
   xbs = Xbs(firstFrameIdx(kTrial):lastFrameIdx(kTrial),:);
   asdf = SparseToASDF(xbs', 50);
   [te(kTrial).te, te(kTrial).ci, te(kTrial).allte] = ASDFTE(asdf, 1:30, 3, 3);
end






%% PROBABILITY OVER MOVING WINDOW (and entropy)
% K = 3*Fs;
% PXk = zeros(N,nRoi);
% Hk = zeros(N,nRoi);
% parfor m=1:nRoi
%    xbk = circshift(makewinmat(Xb(:,m), K)' , K-1, 1); % shifts values from end of signal to the beginning -> xbk(1,:) = [xb(N-M+2 : N) , xb(1)];
%    pxk = sum(xbk,2) ./ K;
%    hk = -sum([pxk, 1-pxk] .* log2([pxk, 1-pxk]),2);
%    hk(isnan(hk)) = 0;
%    PXk(:,m) = pxk;
%    Hk(:,m) = hk
% CONDITIONAL ENTROPY

% end