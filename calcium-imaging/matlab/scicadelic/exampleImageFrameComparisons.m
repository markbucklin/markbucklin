function exampleImageFrameComparisons(A, ref)



% MEAN-SQUARE-ERROR
err = immse(A, ref);


% STRUCTURAL SIMILARITY INDEX
[ssimval, ssimmap] = ssim(single(A), single(ref));
imagesc(ssimmap), colorbar
title(' STRUCTURAL SIMILARITY INDEX')
ssimval

% PEAK SIGNAL TO NOISE RATIO
[peaksnr, snr] = psnr(A, ref)





clear ssimval ssimmap 
cemax = max(ceData,[],3);
cemin = min(ceData,[],3); 
cemean = uint16(mean(single(ceData(:,:,1:5:1024)), 3));
% ceRef = cat(3, single(cemax),single(cemean),single(cemin));
ceRef = cat(2, cemax,cemean,cemin);
[nRows, nCols, N] = size(ceData);

parfor k=1:N
	[ssimval(k,1), localSimMap] = ssim(single(ceRef), single(repmat(ceData(:,:,k),1,3)));
	ssimmap(:,:,:,k) = reshape(uint8(255.*localSimMap), nRows, nCols, 3);
end






% ssimmap = reshape(ssimmap, size(ceData,1), size(ceData,2), 3, []);


