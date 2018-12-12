function [allCoher, f] = getHualouCoherence(R)

X = [R.Trace];
N = size(X,2);
fs = 20;
winsize = 6 * fs;
win = hanning(winsize);
allCoher = zeros(N, N, winsize/2);

parfor m = 1:N
   for n = 1:N
	  x1 = toeplitz(repmat(X(1,m), winsize, 1),  X(:,m));
	  x2 = toeplitz(repmat(X(1,n), winsize, 1),  X(:,n));
	  [coh,~] = coh_fft(x1, x2, win, fs);
	  allCoher(m,n,:) = coh;
   end
end

x1 = toeplitz(repmat(X(1,1), winsize, 1),  X(:,1));
x2 = toeplitz(repmat(X(1,2), winsize, 1),  X(:,2));
[~,f] = coh_fft(x1, x2, win, fs);


