function [data, varargout] = tempAndSpatialFilter(data,fps,varargin)


if nargin < 2
   fps = 20;
   fnyq = fps/2;
end
if nargin < 3
   % FIR FILTER
   n = 50;
   fstop = 5; %Hz
   wstop = fstop/fnyq;
   % DESIGNED FILTER
   d = designfilt('lowpassfir','SampleRate',fps, 'PassbandFrequency',fstop-.5, ...
	  'StopbandFrequency',fstop+.5,'PassbandRipple',0.5, ...
	  'StopbandAttenuation',65,'DesignMethod','kaiserwin');%could also use butter,cheby1/2,equiripple
else
   d = varargin{1};
end



data = spatialFilter(data);
data = temporalFilter(data,d);


   function dmat = temporalFilter(dmat,d)
	  [phi,~] = phasedelay(d,1:5,fps);
	  phaseDelay = mean(phi(:));
	  h = d.Coefficients;
	  h = double(h);
	  filtPad = ceil(phaseDelay*4);
	  
	  % APPLY TEMPORAL FILTER
	  sz = size(dmat);
	  npix = sz(1)*sz(2);
	  nframes = sz(3);
	  % sdata = fftfilt( gpuArray(h), double( reshape( gpuArray(data), [npix,nframes])' ));
	  sdata = filter( h, 1, double( cat(3, flip(dmat(:,:,1:filtPad),3),dmat)), [], 3);
	  dmat = uint16(sdata(:,:,filtPad+1:end));
   end
   function dmat = spatialFilter(dmat)
	  N = size(dmat,3);
	  medFiltSize = [3 3];
	  for k=1:N
		 dmat(:,:,k) = gather(medfilt2(gpuArray(dmat(:,:,k)), medFiltSize));
	  end
   end


if nargout > 1
   varargout{1} = d;
end
end




% % SUBTRACT RESULTING BASELINE THAT STILL EXISTS IN NEUROPIL
% activityImage = imfilter(range(sdata,3), fspecial('average',201), 'replicate');
% npMask = activityImage < mean2(activityImage);
% npPixNum = sum(npMask(:));
% % npIdx = find(npMask);
% npBaseline = sum(sum(bsxfun(@times, sdata, npMask), 1), 2) ./ npPixNum; %average of pixels in mask
% % npBaseline = npBaseline(:);
% data = uint16(bsxfun(@minus, sdata, npBaseline));
% % data = uint16(reshape(transpose(bsxfun(@minus, sdata, npBaseline)), npix, npix, []));

