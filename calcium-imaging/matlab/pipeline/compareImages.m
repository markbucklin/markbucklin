function compareImages(data,varargin)
if iscell(data)
   if nargin > 1
	  imlabel = varargin{1};
	  if nargin > 2
		 prop = varargin{2};
	  end
   end
   for k=1:numel(data)
	  vd(k).cdata = data{k};
	  if nargin > 1
		 vd(k).label = imlabel{k};
	  else
		 vd(k).label = sprintf('Image %i',k);
	  end
   end
elseif isstruct(data)
   vd = data;
else
   if nargin > 1
	  vd(1).cdata = data;
	  for k=2:nargin
		 vd(k).cdata = varargin{k-1};
	  end
   end
end


for k=1:numel(vd)
   sz = size(vd(k).cdata);
   vd(k).nFrames = sz(end);
   vd(k).imSize = sz(1:2);
end
%% DISPLAY/COMPARE
N = min([vd.nFrames]);

for k=1:numel(vd)
   imin(k) = min(vd(k).cdata(:));
   imax(k) = max(vd(k).cdata(:));
end
wid = 1/numel(vd);
hFig = handle(figure);
hFig.Units = 'normalized';
for k=1:numel(vd)
   axes('parent',hFig,'position', [(k-1)*wid 0 wid 1]);
   hAx(k) = handle(gca);
   hIm(k) = handle(imshow(vd(k).cdata(:,:,1),...
	  'DisplayRange', [imin(k) imax(k)],...
	  'Parent',hAx(k)));
   hText(k) = handle(text(100,20,vd(k).label));   
end
set(hText,'FontWeight','bold')