function vid = applyHomomorphicFilters(vid, vidHomFilt)
% vidHomFilt has 2 fields
%	"lp" i.e. "long-pass"
%	"io" i.e "intensity-zero"
%vidHomFilt = generateHomomorphicFilters(vidInput);
try
  % PROCESS INPUT
  inputDataType = class(vid(1).cdata);
  if isa(vid(1).cdata, 'integer')
	 inputRange = getrangefromclass(vid(1).cdata);
  else
	 inputRange = [min(min( cat(1,vid.cdata), [],1), [],2) , max(max( cat(1,vid.cdata), [],1), [],2)];
  end
  
  io = vidHomFilt.io;
  lp = vidHomFilt.lp;
  for k = 1:numel(vid)
	 im = vid(k).cdata;
	 % CONVERT TO DOUBLE-PRECISION INTENSITY IMAGE
	 % 	 im = gpuArray(im);
	 im = mat2gray(im, inputRange) + 1;
	 im = exp( imlincomb(1, log(im), -1, lp, io)) - 1;
	 vid(k).cdata = exp( log( im2single( im )) - vidHomFilt.lp + vidHomFilt.io);
	 % RESCALE FOR CONVERSION BACK TO ORIGINAL DATATYPE
	 if any(strcmpi(inputDataType,{'uint8','uint16'}))
		im = im.*inputRange(2);
	 end
	 % CLEAN UP LOW-END (SATURATE TO ZERO)
	 im(im<inputRange(1)) = inputRange(1);
	 % CAST TO ORIGINAL DATATYPE AND RETRIEVE FILTERED IMAGE FROM GPU
	 im = cast(im, inputDataType);
	 vid(k).cdata = im;
	 % 	 vidFrame(k).cdata = gather( im );
  end
  
  
catch me
  keyboard
end

% (this method is no faster than the for-loop above)
% fh = @(frame)( exp(log(im2single(frame.cdata)) - vidHomFilt.lp + vidHomFilt.io));
% filteredFrames = arrayfun(fh, vid, 'UniformOutput',false);
% [vid.cdata] = deal(filteredFrames{:});



% (from SLOWHOMOMORPHICFILTER)
% function vidFrame = filterSingleFrame(vidFrame, hLP, inputRange)
% im = vidFrame.cdata;
% inputDataType = class(im);
% % TRANSFER TO GPU AND CONVERT TO DOUBLE-PRECISION INTENSITY IMAGE
% im = gpuArray(im);
% im = mat2gray(im, inputRange) + 1;
% % USE MEAN TO DETERMINE A SCALAR BASELINE ILLUMINATION INTENSITY IN LOG DOMAIN
% % io = log(mean(im(:) ));
% io = log( mean(im(im<median(im(:))))); % mean of lower 50% of pixels
% % LOWPASS-FILTERED IMAGE (IN LOG-DOMAIN) REPRESENTS UNEVEN ILLUMINATION
% lp = imfilter( log(im), hLP, 'replicate');
% % SUBTRACT LOW-FREQUENCY "ILLUMINATION" COMPONENT AND RETRIEVE HIGH-FREQUENCY INFO
% im = exp( imlincomb(1, log(im), -1, lp, io)) - 1;
% % RESCALE FOR CONVERSION BACK TO ORIGINAL DATATYPE
% if any(strcmpi(inputDataType,{'uint8','uint16'}))
%   im = im.*inputRange(2);
% end
% % CLEAN UP LOW-END (SATURATE TO ZERO)
% im(im<inputRange(1)) = inputRange(1);
% % CAST TO ORIGINAL DATATYPE AND RETRIEVE FILTERED IMAGE FROM GPU
% im = cast(im, inputDataType);
% vidFrame.cdata = gather( im );
% end
