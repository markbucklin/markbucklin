close all, clear all

count = 1;
load('BlueTraceROIs.mat')

for thresh = 1;
    traceOut = traceOutBlue;
    [numFrames, numCells] = size(traceOut);

    %% Binary pattern distribution and Network entropy
    traceOutBin = (traceOut >= thresh);
    traceOutValid = uint8(traceOut - thresh)+thresh;
    
    Psingle = nnz(traceOutBin) / numel(traceOutBin);
    hasActivity = any(traceOutBin, 2);
    Pgroup = nnz(hasActivity) / numFrames;
    allObservedActivitySamples = traceOutBin(hasActivity,:);
    [observedPatterns, firstFrameIdx, patternIdx] = unique(...
        allObservedActivitySamples,'rows');
    
    subplot(2,1,1), spy(observedPatterns')
    patternProbability = histcounts(int32(patternIdx),...
        'Normalization', 'probability', 'BinMethod', 'integers');
    subplot(2,1,2), bar(patternProbability)
    pause(1)
    
    idvEntropy = zeros(1,size(patternProbability,2));
    for i = 1:size(patternProbability,2);
        idvEntropy(i) = patternProbability(i).*log2(patternProbability(i));
    end
    NetworkEntropy(count) = -sum(idvEntropy(1,:));

    %% Individual cell firing probability
    fcn = binaryStatisticFunctions();
    BlueFiringProb(count,:) = feval(fcn.P_X, traceOutBlue >= thresh);
    
    %% Save binary and 8-bit data from each ROI
    B = traceOutBin;
    
    for k=1:numCells
        Bpacked{k} = bwpack(B(:,k));
        Valid{k} = traceOutValid(:,k);
    end
    
   [status, msg, msgID] = mkdir('binary_traces',strcat('thresh',num2str(thresh),'_bin'));
    mkdir('8bit_traces',strcat('thresh',num2str(thresh),'_8bit'));

    d = dir(fullfile(pwd,'binary_traces',strcat('thresh',num2str(thresh),'_bin')));
    d = d(~[d.isdir]);
    d8 = dir(fullfile(pwd,'8bit_traces',strcat('thresh',num2str(thresh),'_8bit')));
    d8 = d8(~[d8.isdir]);
    
    if isempty(d)
        for k=1:numCells
            fname = [ 'roi_',num2str(k),'_',num2str(thresh),'_bin','.bin'];
            fid = fopen( fullfile(pwd,'binary_traces',strcat('thresh',num2str(thresh),'_bin'),fname), 'W');
            b = typecast( Bpacked{k}, 'uint8');
            cnt = fwrite(fid, b);
            fclose(fid);
        end
    end
    
    if isempty(d8)
        for k=1:numCells
            fname8 = [ 'roi_',num2str(k),'_',num2str(thresh),'_8bit'];
            fid8 = fopen( fullfile(pwd,'8bit_traces',strcat('thresh',num2str(thresh),'_8bit'),fname8), 'W');
            b8 = typecast(Valid{k}, 'uint8');
            cnt8 = fwrite(fid8, b8);
            fclose(fid8);
        end
    end
    
    compressDir_bin{count} = [ strcat('thresh',num2str(thresh),'_bin')];
    compressDir_8bit{count} = [ strcat('thresh',num2str(thresh),'_8bit')];

    %%
    S = whos('B');
    sizeInVariableMB = S.bytes /10^6;
    Spack = whos('Bpacked');
    sizeInVariablePackedMB = Spack.bytes /10^6;
    sizeInFilesMB = sum([d.bytes])/10^6;
    uncompressedBitStorageRatio = (numCells*numFrames) / (sum([d.bytes]) * 8);
      
    %%
%     traceOutSequenceCoded = zeros(numFrames, numCells, 'uint8');
%     for k = 1:numCells
%         b = uint8(traceOutBin(:,k));
%         B = toeplitz( [b(1) ; zeros(7,1)], b);
%         
%         D = bsxfun( @times,  B , uint8(2 .^(0:7))' );
%         d = sum(D,1)';
%         traceOutSequenceCoded(:, k) = uint8(d);     
%     end

    %%
%     hasActivity = any(traceOutSequenceCoded, 2);
%     codedActivityProbability = nnz(traceOutSequenceCoded) / numel(traceOutSequenceCoded);
%     
%     Psingle = nnz(traceOutSequenceCoded) / numel(traceOutSequenceCoded);
%     hasActivity = any(traceOutSequenceCoded, 2);
%     Pgroup = nnz( hasActivity) / numFrames;
%     
%     allObservedActivitySamples = traceOutSequenceCoded(hasActivity,:);
%     [observedPatterns, firstFrameIdx, patternIdx] = unique(allObservedActivitySamples,'rows');
%     patternProbability = histcounts(int32(patternIdx),...
%         'Normalization', 'probability', 'BinMethod', 'integers');
%     pThreshold = max(patternProbability) / 10;
%     
%     subplot(2,2,3), image(observedPatterns(patternProbability >= pThreshold, :)')
%     subplot(2,2,4), bar(patternProbability(patternProbability >= pThreshold))
%     pause
    
legendInfo{count} = [ num2str(thresh)];
count = count + 1;

end
close
% Bchar = num2str(B)';
% d = bin2dec(Bchar);

% Compression ratio

cd('binary_traces')
for k=1:count-1
    compressCommandZip = sprintf('7z a %s.zip ".\\%s\\*"', compressDir_bin{k},compressDir_bin{k});
    system(compressCommandZip)
    compressCommand7z = sprintf('7z a %s.7z ".\\%s\\*"', compressDir_bin{k},compressDir_bin{k});
    system(compressCommand7z)
    d = dir(compressDir_bin{k});
    d = d(~[d.isdir]);
    
    dOut = dir([compressDir_bin{k} '.zip']);
    dOut = dOut(~[dOut.isdir]);
    compressionRatio_bin_Zip (k) = sum([d.bytes]) / [dOut.bytes];
    
    dOut = dir([compressDir_bin{k} '.7z']);
    dOut = dOut(~[dOut.isdir]);
    compressionRatio_bin_7z (k) = sum([d.bytes]) /[dOut.bytes] ;
    
    compressInfoZip = sprintf('7z l %s.zip',compressDir_bin{k});
    [status, cmdout] = system(compressInfoZip);
    c = [textscan(cmdout,'%*s %*s %*s %s %s %*[^\n]')];
    C = [c{:}];
    C([1:10 end-1 end],:) = [];
    A = [cellfun(@str2num,C(:,1))];
    B = [cellfun(@str2num,C(:,2))];
    ROIcompressionRatio_bin(k,:) = A./B;
end

cd ..\
cd('8bit_traces')
for k=1:count-1
    compressCommandZip = sprintf('7z a %s.zip ".\\%s\\*"', compressDir_8bit{k},compressDir_8bit{k});
    system(compressCommandZip)
    compressCommand7z = sprintf('7z a %s.7z ".\\%s\\*"', compressDir_8bit{k},compressDir_8bit{k});
    system(compressCommand7z)
    d8 = dir(compressDir_8bit{k});
    d8 = d8(~[d8.isdir]);
    
    dOut8 = dir([compressDir_8bit{k} '.zip']);
    dOut8 = dOut8(~[dOut8.isdir]);
    compressionRatio_8bit_Zip(k) = sum([d8.bytes]) / [dOut8.bytes];
    
    dOut8 = dir([compressDir_8bit{k} '.7z']);
    dOut8 = dOut8(~[dOut8.isdir]);
    compressionRatio_8bit_7z (k) = sum([d8.bytes]) / [dOut8.bytes];
    
    compressInfoZip = sprintf('7z l %s.zip',compressDir_8bit{k});
    [status, cmdout] = system(compressInfoZip);
    c = [textscan(cmdout,'%*s %*s %*s %s %s %*[^\n]')];
    C = [c{:}];
    C([1:10 end-1 end],:) = [];
    A = [cellfun(@str2num,C(:,1))];
    B = [cellfun(@str2num,C(:,2))];
    ROIcompressionRatio_8bit(k,:) = A./B;
end

cd ..\
[compressionRatio_8bit_7z compressionRatio_bin_7z NetworkEntropy]'

%% Firing probability histogram
figure
histogram(BlueFiringProb(1,:),0.0005:.0005:max(BlueFiringProb(1,:)),'FaceColor',rand(1,3),'facealpha',.5,'edgecolor','none')
hold on
for k=1:count-2
    histogram(BlueFiringProb(k+1,:),0.0005:.0005:max(BlueFiringProb(1,:)),'FaceColor',rand(1,3),'facealpha',.5,'edgecolor','none')
end
legend(legendInfo,'location','northeast')
legend boxoff

figure
histogram(ROIcompressionRatio_8bit(1,:),'FaceColor',rand(1,3),'facealpha',.5,'edgecolor','none')
hold on
for k=1:count-2
    histogram(ROIcompressionRatio_8bit(k+1,:),'FaceColor',rand(1,3),'facealpha',.5,'edgecolor','none')
end
legend(legendInfo,'location','northeast')
legend boxoff

figure
histogram(ROIcompressionRatio_bin(1,:),'FaceColor',rand(1,3),'facealpha',.5,'edgecolor','none')
hold on
for k=1:count-2
    histogram(ROIcompressionRatio_bin(k+1,:),'FaceColor',rand(1,3),'facealpha',.5,'edgecolor','none')
end
legend(legendInfo,'location','northeast')
legend boxoff


save('varThresh.mat','legendInfo','NetworkEntropy'...
    ,'compressionRatio_bin_Zip',...
    'compressionRatio_bin_7z','compressionRatio_8bit_Zip',...
    'compressionRatio_8bit_7z','BlueFiringProb',...
    'ROIcompressionRatio_bin','ROIcompressionRatio_8bit')