function y = gcamp6fResponse(tSpike, Fs, T, fPeak)
% run time ~1ms
if nargin < 4
   fPeak = 1;
   if nargin < 3
	  T = 5;
	  if nargin < 2
		 Fs = 20;
	  end
   end
end
% DEFINE SIGNAL TIME-CONSTANTS
% tDecay = .142;
% tRise = .045;

M = Fs*T;
N = numel(tSpike);
tau = linspace(0, (M-1)/Fs, M);
% ROUND TSPIKE TO NEAREST 1ms
tSpike = round(tSpike*1000)./1000;

sFs = 1000;
sM = round(sFs*T);
sMsingle = min(2*sFs, sM-sFs*max(tSpike));
s_tau = linspace(0, (sM-1)/sFs, sM);

s_y = zeros(sM,1);
tDecay = .142 + randn(N,1).*.011;
tRise = .045 + randn(N,1).*.004;
for k=1:numel(tSpike)   
   m1 = ceil(tSpike(k)*sFs+eps);
   m2 = m1+sMsingle-1;
   s_y(m1:m2) = s_y(m1:m2) + caResponse(tRise(k), tDecay(k), sMsingle, sFs, fPeak);
end
y = interp1(s_tau, s_y, tau);
y = y(:);

