

%%
traceOut = traceOutRed;
thresh = 20;
[numFrames, numCells] = size(traceOut);

%%
traceOutBin = (traceOut > thresh);
hasActivity = any(traceOutBin, 2);
allObservedActivitySamples = traceOutBin(hasActivity,:);
[observedPatterns, firstFrameIdx, patternIdx] = unique(allObservedActivitySamples,'rows');
subplot(2,1,1), spy(observedPatterns')
patternProbability = histcounts(int32(patternIdx), 'Normalization', 'probability', 'BinMethod', 'integers');
subplot(2,1,2), bar(patternProbability)

%%

traceOutSequenceCoded = zeros(numFrames, numCells, 'uint8');
for k = 1:numCells
    b = uint8(traceOutBin(:,k));
    B = toeplitz( [b(1) ; zeros(7,1)], b);           
    
    D = bsxfun( @times,  B , uint8(2 .^(0:7))' );
    d = sum(D,1)';
    traceOutSequenceCoded(:, k) = uint8(d);    
    
end
%%
hasActivity = any(traceOutSequenceCoded, 2);
allObservedActivitySamples = traceOutSequenceCoded(hasActivity,:);
[observedPatterns, firstFrameIdx, patternIdx] = unique(allObservedActivitySamples,'rows');
patternProbability = histcounts(int32(patternIdx),...
    'Normalization', 'probability', 'BinMethod', 'integers');
pThreshold = max(patternProbability) / 4;
subplot(2,1,1), image(observedPatterns(patternProbability >= pThreshold, :)')
subplot(2,1,2), bar(patternProbability(patternProbability >= pThreshold))



% Bchar = num2str(B)';
% d = bin2dec(Bchar);