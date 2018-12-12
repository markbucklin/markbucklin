function tspike = generateSpikeTimes(spikerate, Ts)

if nargin < 2
   Ts = 5;
   if nargin < 1
	  spikerate = 1;
   end
end
tau_ms = (0:(Ts*1000-1))';

tspikems = tau_ms(logical(poissrnd(spikerate/1000,size(tau_ms))));
tspike = tspikems./1000;
tspike = tspike(tspike<=Ts);