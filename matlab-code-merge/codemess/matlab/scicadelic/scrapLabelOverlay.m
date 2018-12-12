% SCRAPS FOR PLOTTING LABEL WITH TRANSPARENCY OVERLAY THATS CLICK-REMOVABLE

clf
him = imrc(oncpu(L), .25*[1 1 1]);
hax = him.Parent;
hfig = gcf;

pMinOnClick = .5;

P = oncpu(P);
imSize = size(P);

ax = axes('Parent',gcf,'Position',hax.Position);
ax.Visible = 'off';
% overlayimdata = bsxfun(@times, ones(1024,1024,3,'uint8'), uint8(cat(3,.5,.9,.4)));
% overlayimdata = ones(imSize)*.15;
overlayimdata = zeros(imSize);
im = image('CData',overlayimdata,...
	'Parent',ax);
ax.Position = hax.Position;
ax.OuterPosition = hax.OuterPosition;
ax.XLim = hax.XLim;
ax.YLim = hax.YLim;
ax.Visible = 'off';
ax.PlotBoxAspectRatio = [1 1 1];
set(im,'AlphaData', ones(imSize)*.5);
axis image ij
set(hfig, 'WindowButtonDownFcn', @(~,~)set(im,'AlphaData', (1-max(pMinOnClick,P))/(1-pMinOnClick))); % 1-(P+1)/2
set(hfig, 'WindowButtonUpFcn', @(~,~)set(im,'AlphaData', ones(imSize)*.5))
















