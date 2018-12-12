function compareVidData(data1,data2, varargin)

vd(1).cdata = data1;
vd(2).cdata = data2;
if nargin > 2
   for k=3:nargin
	  vd(k).cdata = varargin{k-2};	  
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
	imin(k) = getNearMin(vd(k).cdata);
	imax(k) = getNearMax(vd(k).cdata);
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
	hText(k) = handle(text(100,20,sprintf('frame: 1')));
	whitebg('k')
end

%% MOVIE
for k=1:N
   if ~isvalid(hFig)
	  break
   end
	for kd=1:numel(vd)
	   try
		hIm(kd).CData = vd(kd).cdata(:,:,k);
		hText(kd).String = sprintf('frame %i',k);
	   catch me
	   end
	end
	drawnow
end