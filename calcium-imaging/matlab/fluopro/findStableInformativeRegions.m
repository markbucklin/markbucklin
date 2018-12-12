% findStableInformativeRegions


F = getDataSample(data,500);

% FIND MAX PEAKS IN ENTROPY-FILTERED STACK, MINIMIZED OVER TIME
nhoodSize = 7;
nhoodSize = 1+2*floor(nhoodSize/2);
efNhood = true(nhoodSize);
[nrows, ncols, N] = size(F);
entropyFilteredFrame = zeros(nrows,ncols,N,'double');
frameEntropy = zeros(1,1,N);
parfor k=1:N
   entropyFilteredFrame(:,:,k) = entropyfilt(F(:,:,k), efNhood);   
   frameEntropy(k) = entropy(F(:,:,k));
end
normalizedEff = bsxfun(@rdivide, entropyFilteredFrame, frameEntropy) - 1;
temporalMinEff = min(normalizedEff,[],3);
temporalMaxEff = max(normalizedEff,[],3);
temporalSumEff = sum(normalizedEff, 3);
temporalStdEff = std(normalizedEff,1,3);
temporalRangeEff = temporalMaxEff - temporalMinEff;

% [Fx, Fy, Ft] = gradient(single(F));
% dFt = std(Ft,1,3);
% Fr = sqrt(Fx.^2 + Fy.^2);

% implay(mat2gray(normalizedEff))
% imagesc(temporalMaxEff./abs(temporalMinEff), [0 5]), colorbar
% imagesc(log1p(temporalMaxEff./abs(temporalMinEff))), colorbar
