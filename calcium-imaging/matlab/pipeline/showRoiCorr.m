function [xc,varargout] = showRoiCorr(R,bhv,varargin)
X = [R.Trace];

[C,P] = corrcoef(X);
title('Zero-Lag Cross-Correlation Coefficient between ROIs')

fps = 5;
maxlag = 6*fps;
lagbuf = 1;
nRoi = size(X,2);
if nargin < 3
   Crk = zeros(2*maxlag+1,nRoi, nRoi,'like', X);
   [~,lags] = xcorr(X(:,1), X(:,2) , maxlag, 'coeff');
   parfor kRef = 1:nRoi
	  for k=1:nRoi
		 Crk(:,k, kRef) = xcorr(X(:,kRef),X(:,k), maxlag, 'coeff');
	  end
   end
   % Crk = xcov(fg(1:1000,:), maxlag);
   lags = lags/5;
   
   
   fld = fields(bhv.sig);
   for fln = 1:numel(fld)
	  if isnumeric(bhv.sig.(fld{fln}))
		 Csig = zeros(2*maxlag+1,nRoi,'like', X);
		 behaviorSignal = bhv.sig.(fld{fln});
		 parfor kRef = 1:numel(R)
			Csig(:,kRef) =xcorr(behaviorSignal, X(:,kRef),maxlag, 'coeff');
		 end
		 xc.bhvc.(fld{fln}) = Csig;
	  end
   end
   xc.coef = C;
   xc.normC = exp(bsxfun(@minus, log(permute(Crk, [2 3 1]) + 1) , log(xc.coef + 1))) - 1;
   [xc.lead.maxval, xc.lead.maxind] = max(xc.normC(:,:,find(lags > lagbuf)),[], 3);
   [xc.lead.minval, xc.lead.minind] = min(xc.normC(:,:,find(lags > lagbuf)),[], 3);
   [xc.lag.maxval, xc.lag.maxind] = max(xc.normC(:,:,find(lags < -lagbuf)),[], 3);
   [xc.lag.minval, xc.lag.minind] = min(xc.normC(:,:,find(lags < -lagbuf)),[], 3);
   
   % xc.neg = squeeze(mean(xc.normC(find(lags < -2),:,:),1));
   
   xc.slope = (mean(xc.normC(:,:,find(lags< lagbuf & lags>0)), 3) - mean(xc.normC(:,:, find(lags> -lagbuf & lags<0)), 3))./(2*lagbuf);
else
   xc = varargin{1};
end
% im = cat(3,xc.pos./(mean(xc.pos(:))+std(xc.pos(:))),...
%    xc.coef./max(xc.coef(:)),...
%    xc.neg./(mean(xc.neg(:))+std(xc.neg(:))));
% imshow(im)
% title('ROI Cross-Correlation Coefficients (green) with Positive (red) and Negative (blue) Lagged X-Corr')
% im2 = cat(3,xc.pos./(mean(xc.pos(:))+std(xc.pos(:))),...
%    xc.slope./max(abs(xc.slope(:))),...
%    xc.neg./(mean(xc.neg(:))+std(xc.neg(:))));
% imshow(im2)
% title('ROI Cross-Correlation Slope at Zero-Lag (green) with Positive (red) and Negative (blue) Lagged X-Corr')
% im3 = cat(3,xc.pos./(mean(xc.pos(:))+std(xc.pos(:))),...
%    1-xc.slope./max(abs(xc.slope(:))),...
%    xc.neg./(mean(xc.neg(:))+std(xc.neg(:))));
% imshow(im3)


% im = cat(3, xc.lead.maxval - xc.lag.minval, xc.slope./max(xc.slope(:)), xc.lag.maxval - xc.lead.minval);
% imshow(im)
%
% [idx.pos.x, idx.pos.y] = find(abs(im2(:,:,1) > 10));
% idx.pos.val = im2(idx.pos.y, idx.pos.x, 1);
% [idx.neg.x, idx.neg.y] = find(abs(im2(:,:,3) > 10));
% idx.neg.val = im2(idx.neg.y, idx.pos.x, 3);
% [idx.slope.x, idx.slope.y] = find(abs(im2(:,:,2) > .75));
% idx.slope.val = im2(idx.slope.y, idx.slope.x, 2);
%
% set(R(idx.pos.y), 'Color', [1 0 0])
% set(R(idx.pos.x), 'Color', [0 0 1])
% show(R)
%
% set(R(idx.neg.y), 'Color', [1 0 0])
% set(R(idx.neg.x), 'Color', [0 0 1])
% show(R)
%
% set(R(idx.slope.y), 'Color', [1 0 0])
% set(R(idx.slope.x), 'Color', [0 0 1])
% show(R)
nline = 0;
ccThresh = .45;
slopeThresh = .02;
minLineWidth = .1;
maxslope = max(abs(xc.slope(:)));
% roicolor.red = mean(xc.bhvc.long,1);
% roicolor.green = mean(xc.bhvc.lick,1);
% roicolor.blue = mean(xc.bhvc.short,1);
% roicolor.red = roicolor.red/max(roicolor.red);
% roicolor.green = roicolor.green/max(roicolor.green);
% roicolor.blue = roicolor.blue/max(roicolor.blue);
normsig = normfunctions;
colorsource = normsig.poslt1(xc.bhvc.long - xc.bhvc.short);
for k=1:numel(R)
   c = colorsource(:,k);
   R(k).Color = [mean(c(end-5:end)) mean(c(1:5)) mean(c)];
end
h = show(R);
h.line = [];
for kRef=1:numel(R)
   for k = (kRef+1):numel(R)
	  % 	  if k==kRef
	  % 		 continue
	  % 	  end
	  rcoef = xc.coef(k,kRef);
	  rslope = xc.slope(k,kRef);
	  if abs(rcoef) >= ccThresh || abs(rslope) >= slopeThresh
		 nline = nline+1;
		 
		 % 		 curv = sign(rcoef) *(1.2-abs(rcoef));
		 curv = rslope/maxslope;
		 [x,y] = bezline(R(kRef).Centroid, R(k).Centroid, curv);
		 if rcoef > 0
			linecolor = [rcoef, abs(rslope)/maxslope, 0, .4];
		 else
			linecolor = [0, abs(rslope)/maxslope, abs(rcoef), .4];
		 end
		 linewidth = abs(rcoef) + minLineWidth;
		 h.line(nline) = line(x,y,'Parent',h.ax,...
			'LineWidth',linewidth,...
			'Color',linecolor);
	  end
   end
   %    drawnow update
end
drawnow
if nargout > 1
   varargout{1} = h;
end

% for kRef=1:numel(R)
%    refslope = xc.slope(:,kRef)./maxslope;
%    ch.red = refslope;
%    ch.blue = -refslope;
%    ch.red(ch.red < 0) = 0;
%    ch.blue(ch.blue < 0) = 0;
%    for k=1:numel(R)
% 	  R(k).Color = [ch.red(k) 0 ch.blue(k)];
%    end
%    R(kRef).Color = [0 1 0];
%    show(R)
%    pause
% end

% for k=1:numel(md)
% [md(k).xc, md(k).h] = showRoiCorr(md(k).roi, md(k).bhv, md(k).xc);
% print(md(k).h.fig, fullfile(fileparts(md(k).filepath),'Figures','ROI Xcorr HubMap'),'-dpng');
% delete(md(k).h.line);
% close(md(k).h.fig);
% end
















