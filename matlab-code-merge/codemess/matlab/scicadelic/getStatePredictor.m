function Xs = getStatePredictor(X, winsize)
% SAME AS convert2StateSpace(), but without so many scraps and comments
if nargin < 2
	winsize = [7 11 23]; % [6 11 16]; %[7 12 17 22]+1 % [9 14 19 24] % [8 13 18] % [20 25 30](bestiqr)
end

optimset('UseParallel',true);
statset('UseParallel',true);
Xs = false(size(X));
maxwin = max(winsize);
% minwin = min(winsize);
nwin = numel(winsize);
% reach = maxwin;
% FIND RISING SECTIONS OF EACH CALCIUM SIGNAL
parfor kx=1:size(X,2)
	x = X(:,kx);
	Xf = zeroShiftedWinMat(x, maxwin, 0);
	%    Xf = zeroShiftedWinMat(x, maxwin-minwin, minwin); % changed tail?
	% FIND SLOPE OF LINEAR FIT BY LEAST SQUARES
	Xlin = [ones(maxwin,1), cumsum(ones(maxwin,1))];
	C = zeros(size(x,1),numel(winsize));
	% USE MULTIPLE WINDOW SIZES TO DETECT CHANGES AT SEVERAL SCALES
	for k=1:nwin
		xlin = Xlin(1:winsize(k),:);
		xf = Xf(1:winsize(k),:);	% need to fix?
		c = (xlin' * xlin) \ xlin' * xf;
		C(:,k) = c(2,:)';
	end
	
	
	% CALCULATE KURTOSIS AND SKEWNESS TO AID THRESHOLDING
	xskew = skewness(zeroShiftedWinMat(x, 5, 12*20-5))';
	xkurt = kurtosis(zeroShiftedWinMat(x,5, 35))' - 3;
	%    xmean = trimmean(x,10);
	dx = gradient(x);
	%    momentPredictor = ((xskew>skewness(x)) | (xkurt>0)) & (dx>0);
	
	% FIND SLOPE THRESHOLD BY MAXIMIZING CONSENSUS ACROSS SCALES NORMALIZED NUMBER ACTIVITY PERIODS DETECTED
	%    rlow = double( min( -trimmean(dx(dx<0),10), trimmean(dx(dx>0),10))) / 5; %previously 4
	%    rhigh = double(mean(dx(dx>0)) + 3*std(dx(dx>0)));
	%    risePredictFcn = @(r) double( sum( bsxfun(@and, bsxfun(@ge,C,r), momentPredictor) ));
	%    %    risePredictFcn = @(r) sum(diff(bsxfun(@ge,C,r),1,1)>0).*(maxwin./(winsize-1));
	%    strongConformanceFcn = @(r) std(risePredictFcn(r)) / sum(risePredictFcn(r));
	%    slopeThresh = fminbnd(strongConformanceFcn, rlow, rhigh);
	%    slopePredictor = any( bsxfun(@ge, C, slopeThresh), 2);
	
	% USE GAUSSIAN-MIXTURE-MODEL TO FIND CA-SIGNAL INCREASES
	idxPos = find(dx>0);
	xdxPos = znormalize([x(idxPos), dx(idxPos), C(idxPos,:), xskew(idxPos), xkurt(idxPos)]);
	try
		gmmPos = fitgmdist(xdxPos,2);
		idxPosComp = cluster(gmmPos, xdxPos);
		[~, activePosGmmComp] = max(gmmPos.mu(:,1));
		gmmPosPredictor = false(size(x));
		gmmPosPredictor(idxPos(idxPosComp==activePosGmmComp)) = true;
	catch
		gmmPosPredictor = false(size(x));
		% 		gmmPosPredictor(idxPos(idxPosComp==activePosGmmComp)) = false;
	end
	% USE GAUSSIAN-MIXTURE-MODEL TO FIND CA-SIGNAL DECREASES (IF ANY)
	%    idxNeg = find(dx<0 & x<xmean);
	%    xdxNeg = znormalize([x(idxNeg), dx(idxNeg), C(idxNeg,:), xskew(idxNeg), xkurt(idxNeg)]);
	%    gmmNeg = fitgmdist(xdxNeg,2);
	%    idxNegComp = cluster(gmmNeg, xdxNeg);
	%    [~, activeNegGmmComp] = min(gmmNeg.mu(:,1));
	%    gmmNegPredictor = false(size(x));
	%    gmmNegPredictor(idxNeg(idxNegComp==activeNegGmmComp)) = true;
	
	% COMBINE PREDICTORS TO MARK SIGNIFICANT POSITIVE FLUCTUATIONS IN CA SIGNAL
	%    xRise = slopePredictor & momentPredictor & gmmPredictor;
	xRise = gmmPosPredictor;
	
	% EXTEND RISING EDGES BY ITERATIVELY REACHING FOR PEAKS FROM RISING REGIONS
	%    xGenPos = dx >= (1*slopeThresh); % (generally-positive) previously .5*slopeThresh
	%    xGenPos = dx > mean(dx(~gmmPredictor));
	%    xRise(1:maxwin) = false;
	%    xRise((end-maxwin):end) = false;
	%    xReach = xRise;
	%    iter = 0;
	%    while any(xReach)
	% 	  xRise = xRise | xReach;
	% 	  xReach = any(shiftedWinMat(xReach,0,reach)',2) & (xGenPos);
	% 	  iter = iter+1;
	% 	  if iter > maxwin, break, end
	%    end
	Xs(:,kx) = xRise;
end