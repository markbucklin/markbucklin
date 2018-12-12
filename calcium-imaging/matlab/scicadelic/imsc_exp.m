function varargout = imsc_exp(im)
im = squeeze(im);
nFrames = size(im,3);
if nFrames > 1
	%    frameMean = mean2(getDataSample(im));
	%    frameStd = std2(getDataSample(im));
	frameNum = ceil(rand*nFrames);
	im = squeeze(im(:,:,frameNum));
	if isa(im,'gpuArray')
		txtString = sprintf('Frame: %i\nClass: %s (gpuArray)',frameNum,classUnderlying(im));
	else
		txtString = sprintf('Frame: %i\nClass: %s',frameNum,class(im));
	end
else
	%    frameMean = mean2(im);
	%    frameStd = mean2(im);
	%    txtString = sprintf('Class: %s',class(im));
	if isa(im,'gpuArray')
		txtString = sprintf('Class: %s (gpuArray)',classUnderlying(im));
	else
		txtString = sprintf('Class: %s',class(im));
	end
end
warning('off','MATLAB:Figure:SetPosition')

% frameMean = oncpu(frameMean);
% frameStd = oncpu(frameStd);

h.im = handle(imagesc(im));
h.ax = handle(h.im.Parent);
h.fig = handle(h.ax.Parent);

h.fig.Units = 'normalized';
% h.fig.Position = [0.01 0.39 0.97 0.56];
h.ax.Position = [0.005 .02 .93 .93];
h.ax.PlotBoxAspectRatioMode = 'manual';
h.ax.XTick = [];
h.ax.YTick = [];
% h.ax.CLim = frameMean + [-frameStd frameStd];
try
if islogical(im)
	clow = 0;
	chigh = 1;
else
	clow = oncpu(min(im(im(:)>min(im(:)))));
	chigh = oncpu(max(im( im < (max(im(:))))));
end
if isempty(clow)
	clow = min(im(:));
end
if isempty(chigh)
	chigh = max(im(:));
end
if (clow >= chigh)
	crange = getrangefromclass(im);
	clow = crange(1);
	chigh = crange(2);
end
if clow<chigh
	h.ax.CLim = [clow chigh];
end
% h.ax.CLim = [frameMean/3 frameMean+5*frameStd];
catch me
end
h.fig.Renderer = 'opengl';


n = 4096;

redtrans = round(n/5);
bluetrans = round(n/10);
greentrans = 50;

chan.red = [ zeros(n-redtrans-greentrans,1) ; logspace(2, log10(n), redtrans+greentrans)'./(redtrans+greentrans) ];%log10(n-redtrans)
chan.green = [zeros(greentrans,1) ; linspace(0, 1, n-greentrans-redtrans)'; fliplr(linspace(.5, 1, redtrans-1))' ; .25];
chan.blue = [fliplr( logspace(1, 2, n-bluetrans)./250)'-log(2)/500 ; zeros(bluetrans,1)];
% chan.blue = [fliplr( logspace(1, 2, n-bluetrans)./250)'-log(2)/500 ; linspace(log(2)./500, .5, bluetrans)'];
cmap = max(0, min(1, [chan.red(:) chan.green(:) chan.blue(:)]));
colormap(cmap)
text(20,50,txtString);
try
if ~islogical(im)
	h.cb = handle(colorbar);
	h.cb.Ticks = linspace(clow, chigh, 10);
	ticks = num2cell(cast(h.cb.Ticks, 'like',im));
	h.cb.TickLabels = ticks;
end
catch me
end
% lpos = h.ax.Position(1)+h.ax.Position(3);
% h.cb.Position(1) = lpos;
assignin('base', 'h', h);

if nargout
	varargout{1} = h.im;
end





function f = oncpu(f)
if isa(f,'gpuArray')
	f = gather(f);
end
f = double(f);