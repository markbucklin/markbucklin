function Xs = getActivationState(R, t)
% SAME AS convert2StateSpace(), but without so many scraps and comments
if nargin < 2
   t = (0:size(R(1).Trace,1)-1)/20;
end
winsize = [7 11 23]; % [6 11 16]; %[7 12 17 22]+1 % [9 14 19 24] % [8 13 18] % [20 25 30](bestiqr)
X = [R.Trace];
optimset('UseParallel',true);
statset('UseParallel',true);
Xs = false(size(X));
maxwin = max(winsize);
nwin = numel(winsize);
% FIND RISING SECTIONS OF EACH CALCIUM SIGNAL
parfor kx=1:size(X,2)
   x = X(:,kx);
   Xf = zeroShiftedWinMat(x, maxwin, 0);
   
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
   dx = gradient(x, 1:numel(x), t);
   
   % USE GAUSSIAN-MIXTURE-MODEL TO FIND CA-SIGNAL INCREASES
   idxPos = find(dx>0);
   xdxPos = [x(idxPos), dx(idxPos), C(idxPos,:), xskew(idxPos), xkurt(idxPos)];
   xdxPos = bsxfun(@rdivide, xdxPos, range(xdxPos, 1));
   %    xdxPos = znormalize([x(idxPos), dx(idxPos), C(idxPos,:), xskew(idxPos), xkurt(idxPos)]);
   gmmPos = fitgmdist(xdxPos,2);
   idxPosComp = cluster(gmmPos, xdxPos);
   [~, activePosGmmComp] = max(gmmPos.mu(:,1).*gmmPos.mu(:,2));
   gmmPosPredictor = false(size(x));
   gmmPosPredictor(idxPos(idxPosComp==activePosGmmComp)) = true;
   
   % COMBINE PREDICTORS TO MARK SIGNIFICANT POSITIVE FLUCTUATIONS IN CA SIGNAL
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

% GREAT VISUALIZATION (if using 3 components)
% xdx = [x, dx, C, xskew, xkurt];
% xdx = bsxfun(@rdivide, xdx, range(xdx, 1));
% gmm = fitgmdist(xdx,5);
% gmpost = posterior(gmm,xdx);
% for k=1:7, scatter(xdx(:,2), xdx(:,k), 10, gmpost(:,[1,2,4]), 'filled'), pause, end