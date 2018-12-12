function y = gcamp6fSpikeResponse(nSpike)
% run time ~1ms

fPeak = 1;
Fs = 20;
tDecay = .142;
tRise = .045;
% GENERATE RANDOMIZED SPIKE TIMES
M = sum(nSpike,1);
fSpike = find(nSpike>0);
tSpike = zeros(M,1);
k = 1;
for m = 1:numel(fSpike)
   tFrame = (m-1)/Fs ;
   for n = 1:nSpike(fSpike(m))
	  tSpike(k) = tFrame + rand/Fs;
	  k=k+1;
   end
end

synFs = max(Fs, ceil(max(1./diff([-.005 ; tSpike(:)]))));
synM = synFs*ceil(3+max(tSpike));
synMsingle = 2*synFs;
synT = linspace(0, (synM-1)/synFs, synM);


synY = zeros(synM,1);
% multY = zeros(synM,numel(tSpike));
for k=1:numel(tSpike)
   m1 = ceil(tSpike(k)*synFs);
   m2 = m1+synMsingle-1;
   synY(m1:m2) = synY(m1:m2) + caResponse(tRise, tDecay, synMsingle, synFs, fPeak);
%    multY(m1:m2,k) = caResponse(tRise, tDecay, synMsingle, synFs, fPeak);
end
M = Fs*ceil(3+max(tSpike));
t = linspace(0, (M-1)/Fs, size(nSpike,1));

y = reshape(interp1(synT, synY, t), size(nSpike));
