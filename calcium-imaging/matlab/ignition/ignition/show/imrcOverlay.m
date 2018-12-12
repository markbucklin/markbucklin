function varargout = imrcOverlay(L,Loverlay, bgColor)
% FOR PLOTTING LABEL WITH TRANSPARENCY OVERLAY THATS CLICK-REMOVABLE
%
% L -> Label-Matrix
% P -> Layer-Probability-Matrix
%
%

if nargin < 3
	bgColor = [.2 .2 .2];
end
h.imRandomColor = imrc(oncpu(L), bgColor); % h.imRandomColor = imrc(oncpu(L), .25*[1 1 1]);
h.axRandomColor = handle(h.imRandomColor.Parent);
h.fig = handle(gcf);

pMinOnClick = .25;

P = oncpu(Loverlay);
imSize = size(P);

h.axOverlay = handle(axes('Parent',gcf,'Position',h.axRandomColor.Position));
h.axOverlay.Visible = 'off';
% overlayimdata = bsxfun(@times, ones(1024,1024,3,'uint8'), uint8(cat(3,.5,.9,.4)));
% overlayimdata = ones(imSize)*.15;
overlayimdata = zeros(imSize);
h.imOverlay = image('CData',overlayimdata,...
	'Parent',h.axOverlay);
h.axOverlay.Position = h.axRandomColor.Position;
h.axOverlay.OuterPosition = h.axRandomColor.OuterPosition;
h.axOverlay.XLim = h.axRandomColor.XLim;
h.axOverlay.YLim = h.axRandomColor.YLim;
h.axOverlay.Visible = 'off';
h.axOverlay.PlotBoxAspectRatio = [1 1 1];
h.fig.UserData = P;
set(h.imOverlay,'AlphaData', ones(imSize)*.5);
axis image ij
set(h.fig, 'WindowButtonDownFcn', @clickShowP); % 1-(P+1)/2
set(h.fig, 'WindowButtonUpFcn', @unclickHideP)

% set(h.fig, 'WindowButtonDownFcn', @(~,~)set(h.imOverlay,'AlphaData', (1-max(pMinOnClick,P))/(1-pMinOnClick))); % 1-(P+1)/2
% set(h.fig, 'WindowButtonUpFcn', @(~,~)set(h.imOverlay,'AlphaData', ones(imSize)*.5))


if nargout
	varargout{1} = h;
end






function clickShowP(src, ~)
	Pcurrent = oncpu(src.UserData);
	h.imOverlay.AlphaData = (1-max(pMinOnClick,Pcurrent))/(1-pMinOnClick);
end

function unclickHideP(~, ~)
	h.imOverlay.AlphaData = ones(imSize)*.5;
end


end
