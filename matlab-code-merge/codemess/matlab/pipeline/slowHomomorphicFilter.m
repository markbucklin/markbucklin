function vid = slowHomomorphicFilter(vid,varargin)
% Implemented by Mark Bucklin 6/12/2014
%
% FROM WIKIPEDIA ENTRY ON HOMOMORPHIC FILTERING
% Homomorphic filtering is a generalized technique for signal and image
% processing, involving a nonlinear mapping to a different domain in which
% linear filter techniques are applied, followed by mapping back to the
% original domain. This concept was developed in the 1960s by Thomas
% Stockham, Alan V. Oppenheim, and Ronald W. Schafer at MIT.
%
% Homomorphic filter is sometimes used for image enhancement. It
% simultaneously normalizes the brightness across an image and increases
% contrast. Here homomorphic filtering is used to remove multiplicative
% noise. Illumination and reflectance are not separable, but their
% approximate locations in the frequency domain may be located. Since
% illumination and reflectance combine multiplicatively, the components are
% made additive by taking the logarithm of the image intensity, so that
% these multiplicative components of the image can be separated linearly in
% the frequency domain. Illumination variations can be thought of as a
% multiplicative noise, and can be reduced by filtering in the log domain.
%
% To make the illumination of an image more even, the high-frequency
% components are increased and low-frequency components are decreased,
% because the high-frequency components are assumed to represent mostly the
% reflectance in the scene (the amount of light reflected off the object in
% the scene), whereas the low-frequency components are assumed to represent
% mostly the illumination in the scene. That is, high-pass filtering is
% used to suppress low frequencies and amplify high frequencies, in the
% log-intensity domain.[1]
%
% More info HERE: http://www.cs.sfu.ca/~stella/papers/blairthesis/main/node35.html

%% DEFINE PARAMETERS and PROCESS INPUT
if nargin>1
  filtSize = varargin{1};
else
  filtSize = round(size(vid(1).cdata,1)/5);
end
hLP = gpuArray(fspecial('average',filtSize));

N = numel(vid);

% GET RANGE FOR CONVERSION TO INTENSITY IMAGE
if isa(vid(1).cdata, 'integer')
  inputRange = getrangefromclass(vid(1).cdata);
else
  inputRange = [min(min( cat(1,vid.cdata), [],1), [],2) , max(max( cat(1,vid.cdata), [],1), [],2)];
end
filterFunction = @(vidFrame)filterSingleFrame(vidFrame, hLP, inputRange);
t = hat;

% USE EITHER ARRAYFUN (88ms/f)
% fprintf('Applying SLOW Homomorphic Filter to remove UNEVEN ILLUMINATION\n')
% vid = arrayfun(filterFunction, vid);
% t = hat-t;
% fprintf('Finished %i frames in %0.2f seconds (%0.1f ms/frame) \n\n',...
%   N, t, 1000*t/N)

% USE A FOR LOOP (80 ms/f)
% h = waitbar(0,  sprintf('Post-Filtering Frame %g of %g (%f secs/frame)',1,N,0));
multiWaitbar('Applying Homomorphic Filter',0)
for k = 1:N   
  vid(k) = feval(filterFunction, vid(k));  
  multiWaitbar('Applying Homomorphic Filter',k/N)
  %   waitbar(k/N, h, sprintf('Post-Filtering Frame %g of %g (%0.1f ms/frame)',k,N,1000*(hat-t)));
  %   t = hat;
end
delete(h);

end




function vidFrame = filterSingleFrame(vidFrame, hLP, inputRange)
im = vidFrame.cdata;
inputDataType = class(im);
% TRANSFER TO GPU AND CONVERT TO DOUBLE-PRECISION INTENSITY IMAGE
im = gpuArray(im);
im = mat2gray(im, inputRange) + 1;
% USE MEAN TO DETERMINE A SCALAR BASELINE ILLUMINATION INTENSITY IN LOG DOMAIN
% io = log(mean(im(:) ));
io = log( mean(im(im<median(im(:))))); % mean of lower 50% of pixels
% LOWPASS-FILTERED IMAGE (IN LOG-DOMAIN) REPRESENTS UNEVEN ILLUMINATION
lp = imfilter( log(im), hLP, 'replicate');
% SUBTRACT LOW-FREQUENCY "ILLUMINATION" COMPONENT AND RETRIEVE HIGH-FREQUENCY INFO
im = exp( imlincomb(1, log(im), -1, lp, io)) - 1;
% RESCALE FOR CONVERSION BACK TO ORIGINAL DATATYPE
if any(strcmpi(inputDataType,{'uint8','uint16'}))
  im = im.*inputRange(2);
end
% CLEAN UP LOW-END (SATURATE TO ZERO)
im(im<inputRange(1)) = inputRange(1);
% CAST TO ORIGINAL DATATYPE AND RETRIEVE FILTERED IMAGE FROM GPU
im = cast(im, inputDataType);
vidFrame.cdata = gather( im );
end





