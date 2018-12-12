function dFs = sampledSurroundBestDiff_scrapspmd(F, ds, Fthresh)
% Fast local contrast enhancement

% CONSTANTS
[r,c,n] = size(F);
if nargin < 2
	ds = 10;
end
if nargin < 3
	% 	Fthresh = std(F(:));
	Fthresh = mean(abs(mean(mean(F,ndims(F)),1) - mean(mean(F,ndims(F)),2)'));
end
Fthresh = int16(Fthresh);

% SURROUND -> SHIFT MATRIX BY DISTANCE ESTIMATED TO BE GREATER THAN 1 RADIUS OF THE LARGEST OBJECT
surroundDim = [1 1 2 2];
surroundSubs = {...
	[ones(1,ds), 1:r-ds], ...			% up
	[ds+1:r, r.*ones(1,ds)], ...		% down
	[ones(1,ds), 1:c-ds], ...			% left
	[ds+1:c, c.*ones(1,ds)]};			% right



if isa(F,'gpuArray')
	dFsurr = gpuArray.zeros([r c n 8], 'int16');
% 	dFpos = gpuArray.zeros([r c n], 'int16');
% 	dFneg = gpuArray.zeros([r c n], 'int16');
% 	countPosNeg = gpuArray.zeros([r c n], 'int8');
else
	dFsurr = zeros([r c n 8], 'int16');
% 	dFpos = zeros([r c n], 'int16');
% 	dFneg = zeros([r c n], 'int16');
% 	countPosNeg = zeros([r c n], 'int8');
end

for ksurr = 1:8
% 	ksurr = labindex();
	% GET SUBSCRIPTS FOR SAMPLED-SURROUND NEIGHBORHOOD
	if ksurr>4
		shiftedDim = surroundDim(ksurr-4);
		shiftedSubs = surroundSubs{ksurr-4};
		if shiftedDim==1
			Fs = F(shiftedSubs, :, :);
		else
			Fs = F(:, shiftedSubs, :);
		end
	elseif ksurr <= 4
		shiftedRowSubs = surroundSubs{1+mod(ksurr-1,2)};
		shiftedColSubs = surroundSubs{3+mod(ksurr-1,2)};
		Fs = F(shiftedRowSubs, shiftedColSubs, :);		
	end

	% COMPARE EACH PIXEL TO SURROUND
% 	dFsurr = int16(F)-int16(Fs);
dFsurr(:,:,:,ksurr) = int16(F)-int16(Fs);
end
	gtMaskPos = bsxfun(@gt, dFsurr , Fthresh);
	gtMaskNeg = bsxfun(@lt, dFsurr, -Fthresh);
	countPosNeg = sum( int8(gtMaskPos) - int8(gtMaskNeg), 4);
% 	dFpos = max(dFpos, dFsurr);
% 	dFneg = min(dFneg, dFsurr);
% 	countPosNegComposite = int8(gtMaskPos) - int8(gtMaskNeg);
% 	dFpos = uint16(gtMaskPos).*uint16( FdiffLoc);
% 	dFneg = uint16(gtMaskNeg).*uint16(-FdiffLoc);	
% end

% countPosNeg = sum(cat(4, countPosNegComposite{:}), 4);
maskPos = countPosNeg >  5;
maskNeg = countPosNeg < -5;

dFs = bsxfun(@times, max(dFsurr, [], 4), int16(maskPos)) ...
	+ bsxfun(@times, min(dFsurr, [], 4), int16(maskNeg));
% dFs = bsxfun(@times, dFpos, int16(maskPos)) + bsxfun(@times, dFneg, int16(maskNeg));

% Fdiff = cat(4, FdiffComposite{:});
% dFs = bsxfun(@times, max(Fdiff,[],4), int16(maskPos)) + bsxfun(@times, min(Fdiff,[],4), int16(maskNeg));

% dFs = 

% dFs(maskPos) = dFpos(maskPos);
% dFs(maskNeg) = dFneg(maskNeg);
% dFs = reshape(dFs, [r c n]);

% dFs = reshape(...
% 	accumarray(cat(1, find(maskPos), find(maskNeg)), cat(1, single(dFpos(maskPos)), -single(dFneg(maskNeg))), [r*c*n 1]),...
% 	[r, c, n]);

% gtMaskPos = F > (Fs+Fthresh);
% 		gtMaskNeg = F < (Fs-Fthresh);









% 
% 
% su = F([ones(1,ds), 1:r-ds], :, :);
% sd = F([ds+1:r, r.*ones(1,ds)], :, :);
% sl = F(:, [ones(1,ds), 1:c-ds], :);
% sr = F(:, [ds+1:c, c.*ones(1,ds)], :);
% 
% % CENTRAL PIXEL AND 3 IMMEDIATE NEIGHBORS ARE ALL GREATER INTENSITY THAN 3 SURROUNDING PIXELS
% Gu = min(min(min( F, fl), fd), fr) > max(max( sl, su), sr);
% Gr = min(min(min( F, fu), fl), fd) > max(max( su, sr), sd);
% Gd = min(min(min( F, fl), fu), fr) > max(max( sl, sd), sr);
% Gl = min(min(min( F, fu), fr), fd) > max(max( su, sl), sd);
% 
% 
% dFs = ...
% 	(Gu & Gr & Gd) |...
% 	(Gu & Gl & Gd) |...
% 	(Gl & Gu & Gr) |...
% 	(Gl & Gd & Gr);
