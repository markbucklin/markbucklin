function pctVal = getApproxPercentile(data,pctl)
% NOT WORKING
pctlTol = .1;

pctl = double(pctl);
sz = size(data);
nFrames = sz(end);
sampSize = min(nFrames, 1000);
data = getDataSample(data, sampSize);
maxVal = double(max(data(:)));
minVal = double(min(data(:)));
medVal = double(median(data(:)));
% maxVal = max(data(:));
% minVal = min(data(:));
% medVal = median(data(:));
N = numel(data);

if pctl > 50
   halfRange = maxVal - medVal;
   pctVal = medVal + halfRange * (pctl-50)/50;   
   pctEst = 100 * (sum(data(:) < pctVal) / N);
   estErr = pctEst - pctl;
   while abs(estErr) > pctlTol
	  if estErr > 0
		 pctVal = (1 - estErr/100) * pctVal;
	  else
		 pctVal = (1 + estErr/100) * pctVal;
	  end	  
   end
elseif pctl < 50
   halfRange = medVal - minVal;
   pctVal = medVal - halfRange/2;
   
else
   pctVal = medVal;
   return
end
%TODO



sampval = mean(maxSamp) + exp(1)*std(double(maxSamp));
% maxval = min( double(maxval), double(sampval));
dataRange = getrangefromclass(data);
maxVal = min(sampval, dataRange(2));






%    lowEst = 50;
%    highEst = 100;
%    estRes = 1;
%    pctVal = shiftdim(medVal+halfRange.*(lowEst:estRes:highEst)/50,-1);
%    pctEst = sum(bsxfun(@ge, data(:), pctVal), 1);




% maxSamp = zeros(sampSize,1);
% sidx = ceil(linspace(1, nFrames, sampSize))';
% for ks=1:sampSize
%    maxSamp(ks) = double(max(max(data(:,:,sidx(ks)))));
% end


% maxVal = double(max(data(:)));
% minVal = double(min(data(:)));
% medVal = double(median(data(:)));