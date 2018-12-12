function varargout = imcompare(data1,data2, varargin)

vd(1).cdata = double(oncpu(data1));
vd(1).name = inputname(1);
vd(2).cdata = double(oncpu(data2));
vd(2).name = inputname(2);
if nargin > 2
   for k=3:nargin
	  vd(k).cdata = varargin{k-2};
		vd(k).name = inputname(k);
   end
end
for k=1:numel(vd)
   sz = size(vd(k).cdata);
   vd(k).nFrames = sz(end);
   vd(k).imSize = sz(1:2);
end
%% DISPLAY/COMPARE
N = min([vd.nFrames]);

hGRoot = handle(groot);
if ~isempty(hGRoot.CurrentFigure)
	curFig = handle(gcf);
	if strcmpi(curFig.Name,'imcompare-fig')
		h.fig = curFig;
		figure(h.fig)
		clf;
	else
		h.fig = handle(figure);
	end
else
	h.fig = handle(figure);
end
h.fig.Name = 'imcompare-fig';

for k=1:numel(vd)
	low_high = prctile(vd(k).cdata(:), [.1 99.995]);
	imin(k) = oncpu(low_high(1));
	imax(k) = oncpu(low_high(2));
end
wid = 1/numel(vd);
h.fig = handle(gcf);
h.fig.Units = 'normalized';
figName = 'ImageComparison';
for k=1:numel(vd)
	axes('parent',h.fig,'position', [(k-1)*wid 0 wid 1]);	
	h.ax(k) = handle(gca);
	h.im(k) = handle(imshow(vd(k).cdata(:,:,1),...
		'DisplayRange', [imin(k) imax(k)],...
		'Parent',h.ax(k)));
	% 	h.text(k) = handle(text(100,20,sprintf('frame: 1')));
	if ~isempty(vd(k).name)
		axName = strrep(vd(k).name,'_',' ');
		h.ax(k).Title = title(h.ax(k), axName);
		figName = [figName,' - ',axName];
	end
	whitebg('k')	
end
if isprop(h.fig, 'FileName')
	h.fig.FileName = figName;
end
colormap(scicadelicColormap);
linkaxes(h.ax)

if nargout
	varargout{1} = h;
end

%% MOVIE
% for k=1:N
%    if ~isvalid(h.fig)
% 	  break
%    end
% 	for kd=1:numel(vd)
% 	   try
% 		h.im(kd).CData = vd(kd).cdata(:,:,k);
% 		h.text(kd).String = sprintf('frame %i',k);
% 	   catch me
% 	   end
% 	end
% 	drawnow
% end