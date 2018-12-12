function [y, varargout] = caResponse(tRise, tDecay, M, Fs, fPeak)
if nargin < 5
   fPeak = 1;
   if nargin < 4
	  Fs = 20;
	  if nargin < 3
		 M = Fs * 2;
		 if nargin < 2
			tDecay = .142;
			if nargin < 1
			   tRise = .045;
			end
		 end
	  end
   end
end
% yRise = zeros(M,1);
% yDecay = zeros(M,1);
y = zeros(M,1);

a = fPeak/tRise;
b = 1/tDecay;
t = linspace(0, (M-1)/Fs, M);
mPeak = find(t >= tRise, 1, 'first');

y(1:mPeak-1) = a * t(1:mPeak-1);
y(mPeak) = a * (tRise-t(mPeak)) + fPeak * 2^(-b*(t(mPeak)-tRise));
y(mPeak+1:end) = fPeak * 2 .^ (-b*(t(mPeak+1:end)-tRise));

if nargout > 1
   varargout{1} = t;
end