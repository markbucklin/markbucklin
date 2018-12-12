function [xc,varargout] = showRoiTE(R,bhv,varargin)

show(R)
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
















