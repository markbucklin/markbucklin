function Xs = convert2StateSpace(X, winsize)
% SAME AS getStatePredictor()
if nargin < 2
   winsize = [7 13 17 23]; % [6 11 16]; %[7 12 17 22]+1 % [9 14 19 24] % [8 13 18] % [20 25 30](bestiqr)
end

optimset('UseParallel',true);
statset('UseParallel',true);
Xs = false(size(X));
maxwin = max(winsize);
minwin = min(winsize);
nwin = numel(winsize);
reach = 5;
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
   xskew = skewness(zeroShiftedWinMat(x, 5, 35))';
   xkurt = kurtosis(zeroShiftedWinMat(x,5, 35))' - 3;
   dx = gradient(x);
   momentPredictor = ((xskew>0) | (xkurt>0)) & (dx>0);
   % FIND SLOPE THRESHOLD BY MAXIMIZING CONSENSUS ACROSS SCALES NORMALIZED NUMBER ACTIVITY PERIODS DETECTED
   rlow = double( min( -trimmean(dx(dx<0),10), trimmean(dx(dx>0),10))) / 5; %previously 4
   rhigh = double(mean(dx(dx>0)) + 3*std(dx(dx>0)));
   risePredictFcn = @(r) double( sum( bsxfun(@and, bsxfun(@ge,C,r), momentPredictor) ));
   %    risePredictFcn = @(r) sum(diff(bsxfun(@ge,C,r),1,1)>0).*(maxwin./(winsize-1));
   strongConformanceFcn = @(r) std(risePredictFcn(r)) / sum(risePredictFcn(r));
   slopeThresh = fminbnd(strongConformanceFcn, rlow, rhigh);
   % COMBINE PREDICTORS TO MARK SIGNIFICANT POSITIVE FLUCTUATIONS IN CA SIGNAL
   xRise = any( bsxfun(@ge, C, slopeThresh), 2) & momentPredictor;
   % EXTEND RISING EDGES BY ITERATIVELY REACHING FOR PEAKS FROM RISING REGIONS
   xGenPos = dx >= (.25*slopeThresh); % previously .5*slopeThresh
   xRise(1:maxwin) = false;
   xRise((end-maxwin):end) = false;
   xReach = xRise;
   iter = 0;
   while any(xReach)
	  xRise = xRise | xReach;
	  xReach = any(shiftedWinMat(xReach,0,reach)',2) & (xGenPos);
	  iter = iter+1;
	  if iter > maxwin, break, end
   end
   Xs(:,kx) = xRise;
end


% POTENTIAL SIGNAL MINIMUM-SLOPE THRESHOLD PREDICTORS
% rmin = -mean(C(C<0)) + std(C(C<0));
% rmin = std(C,[],1);
% rmin = -mean(dx(dx<0)) + std(dx(dx<0));
% rmin = mean(abs(dx));

% POTENTIALLY USEFUL LITTLE CLEVER LITTLE FUNCTIONS
% rightSideChopped = @(x) x(x < -(prctile(x(x<0),.1)))
% idxSample = @(x,dim,n) unique(ceil( size(x,dim).*rand(n,1)))

% "Kurtosis is a measure of how outlier-prone a distribution is"
% Xkurt = kurtosis(X);
% Xskew = skewness(X);
% xkurt = kurtosis(zeroShiftedWinMat(x,5, 115))-3;
% xskew = skewness(zeroShiftedWinMat(x, 5, 115));


% WINSIZE PARAMETER TESTING (with FIGURE GENERATION)
% win = [5 10 15 20]
% for k=1:5, multiwin{k,1} = win + k-1; end
% for k=1:5, multiwin{k,2} = win(1:3) + k-1; end
% for k=1:5, multiwin{k,3} = win(2:4) + k+5; end
% for k=1:5, multiwin{k,4} = [win, 2*win+k]; end
% multiwin = multiwin(:);
% for k=1:numel(multiwin), multiXs{k,1} = convert2StateSpace(X,multiwin{k}); disp(k), end
% Xs = multiXs{1};
% idxSample = @(x,dim,n) unique(ceil( size(x,dim).*rand(n,1)));
% idxt = 15000:25000;
% idx = idxSample(Xs,2,6);
% for k=1:numel(multiwin)
%    Xs = multiXs{k};
%    viewStatePredictor(X(idxt,idx),Xs(idxt,idx));
%    spframe(k) = getframe(gca);
% end
% winsizetestimage = cat(4,spframe.cdata);
% Xs = cat(3,multiXs{:});
% % figure, surfc(squeeze(sum(Xs,1))./size(Xs,1))
% mwPtotal = squeeze(sum(Xs,1))./size(Xs,1);
% [~,winsidx] = sort(mean(mwPtotal,1))
% [~,roisidx] = sort(mean(mwPtotal,2))
% figure, surfc(mwPtotal(roisidx,winsidx))
% shading flat
% xlabel('Winsize Inputs')
% ylabel('ROI')
% title('Activation State Probability Across All Time -  for Multi-Parameter Investigation in State-Prediction')
% ax = gca
% mwstr = cellfun(@mat2str,multiwin, 'UniformOutput',false)
% ax.XTickLabel = mwstr(winsidx);
% TRYING ANOTHER STRATEGY WITH TRUE/FALSE-POSITIVE ASSUMPTIONS
% mwjudge = squeeze(sum(bsxfun(@and, Xs, dX>0),1));
% N = size(Xs,1);
% mwTP = squeeze(sum(bsxfun(@and, Xs, dX>0),1))/N;
% mwTN = squeeze(sum(bsxfun(@and, ~Xs, dX<0),1))/N;
% mwFN = squeeze(sum(bsxfun(@and, ~Xs, dX>0),1))/N;
% mwFP = squeeze(sum(bsxfun(@and, Xs, dX<0),1))/N;
% mwPrecision = mwTP./(mwTP+mwFP);
% mwSensitivity = mwTP ./ (mwTP + mwFN);
% [~,roisidx] = sort(mean(mwSensitivity,2));
% imagesc(mwSensitivity(roisidx,:))
% ax = gca
% ax.XTick = 1:size(mwSensitivity,2)
% ax.XTickLabelRotation = 45
% ax.XTickLabel = mwstr(winsidx);
% title('Activation State Prediction Sensitivity -  for Multi-Parameter Investigation in State-Prediction')
% xlabel('window-size input')
% ylabel('ROI')
% colorbar
% mwAccuracy = (mwTP + mwTN) ./ (mwTP + mwTN + mwFN + mwFP);
% P = squeeze(sum(Xs,1))/N;
% [~,pidx] = sort(mean(P,2));
% figure, imagesc(P(pidx,:))
% ax = gca;
% ax.XTick = 1:size(mwSensitivity,2);
% ax.XTickLabelRotation = 45;
% ax.XTickLabel = mwstr;
% title('Activation State Mean Activation Probabability -  for Multi-Parameter Investigation in State-Prediction')
% xlabel('window-size input')
% ylabel('ROI')
% colorbar
% figure,bar([std(P,[],1); iqr(P,1); mean(P,1)]'), legend('StDev','IQR', 'Mean')
% title('Dependence of Predicted Mean-Probability on WinSize Parameter')
% ax = gca;
% ax.XTick = 1:20;
% ax.XLim = [0 21]
% ax.XTickLabel = mwstr;
% ax.XTickLabelRotation = 45;
% xlabel('window-size input')
% ylabel('Mean Activation Probability')






% winsize = [8 10 15 20 30];
% npeaks = 10;
% xs = false(size(C));
%  r = 1;
%    while all( (sum(diff(xs,1,1)>0) .* (winsize/maxwin)) < npeaks) % OR sum(diff( bsxfun(@ge, C, r) ,1,1) > 0) .* (maxwin./(1-winsize))
% 	  xs = bsxfun(@ge, C, r.*rstd);
% 	  r = r - .01;
%    end

% numRiseFun = @(r) sum(diff( bsxfun(@ge, C, r) ,1,1) > 0)
% lenghtNormNumRiseFun = @(r) numRiseFun(r) .* (maxwin./(winsize-1))

% ~any(all(xs,2))
% WORKING TO IDENTIFY MIDDLE OF RISES
% Xs = false(size(X));
% winsize = [6 10 15 20];
% maxwin = max(winsize);
% fwinsize = ceil(winsize/2);
% bwinsize = floor(winsize/2);
% for kx=1:size(X,2)
%    x = X(:,kx);
%    Xf = zeroShiftedWinMat(x, max(fwinsize), max(bwinsize));
%    Xlin = [ones(maxwin,1), cumsum(ones(maxwin,1))];
%    rstd = findRiseRateStd(x,winsize);
%    C = zeros(size(x,1),nwin);
%    for k=1:nwin
% 	  windex = (max(bwinsize)-bwinsize(k) + 1) : (max(bwinsize)+fwinsize(k));
% 	  xlin = Xlin(1:numel(windex),:);
% 	  xf = Xf(windex,:);
% 	  c = (xlin' * xlin) \ xlin' * xf;
% 	  C(:,k) = c(2,:)';
%    end
%    xs = false(size(C));
%    r = 1;
%    while ~any(xs(:))
% 	  xs = bsxfun(@ge, C, r.*rstd);
% 	  r = r - .01;
%    end
%    Xs(:,kx) = any(xs,2);
% end
% WORKING TO IDENTIFY MIDDLE OF RISES


%
% tau = 1/20.*(0:(numel(x1)-1))';
% g = fittype( @(b, x) a*2.^(b*x))
% [curve, gof, output] = fit( tau, x, g, 'StartPoint', [-1/.142] );
% plot(tau, [x(:), (a*2.^(-.4314*tau))])
% lsqnonlin, lsqcurvefit


% Xlin = [ones(winsize,1), cumsum(ones(winsize,1))];
%    Xf = zeroShiftedWinMat(x, ceil(winsize/2),floor(winsize/2));
%    Cf = (Xlin' * Xlin) \ Xlin' * Xf;
%    rateThresh = findRiseRateStd(x,winsize);
%    xs = bsxfun(@ge, Cf(2,:)', rateThresh);
%    Xs(:,k) = any(xs,2);



% Xf = zeroShiftedWinMat(x, 20,0);
% Xb = zeroShiftedWinMat(x,0,20);
% xrise = sum(Xf,1)./abs(sum(Xb,1)) > std(sum(Xf,1));
% Xs = squeeze(bsxfun(@ge, mean(Xf,1)./abs(mean(Xb,1)), std(mean(Xf,1),[],2))) ;
% Xs = squeeze(all(Xf>0, 1) | all(Xb<0,1));
% rateThresh = .9 * std(diff(X,1,1),[],1);
% Xs(:,k) = squeeze( (mean(diff(Xf,1,1),1) > rateThresh) | (mean(diff(Xb,1,1),1) > rateThresh));