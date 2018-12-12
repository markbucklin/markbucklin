function [coh, f] = coh_fft(x, y, window, Fs, pad);
%
% Squared Coherence calculation based on FFT directly
%
%  [cohfft, f] = coh_fft(x, y, window, Fs, pad);
%
% Input:
%   x, y: T x N respectively, T - length of TS, N - size of ensemble
%   pad:  padding for fft window, which CAN'T increase the resolution of spec.
%   Fs:   sampling frequency
%   window: window used, e.g. hanning.
% Output:
%    coh: squared coherence between x and y
%    f:   freq

%
%  Hualou Liang, 11/09/98, FAU
%


[T, N] = size(x);  
if nargin<5,
  pad = T;
end

if nargin<4,
  Fs = 200;
end

if nargin<3,
  window = boxcar(T);  % T x 1
end

% window data here
% window = hanning(T);
x = x.*window(:,ones(1, N));
y = y.*window(:,ones(1, N));

X = fft(x, pad);
Y = fft(y, pad);
nfft = size(X, 1)/2;

Pxx = sum(X.*conj(X), 2)/N;
Pyy = sum(Y.*conj(Y), 2)/N;
Pxy = sum(X.*conj(Y), 2)/N;

coh = abs(Pxy(1:nfft)).^2 ./ (Pxx(1:nfft).*Pyy(1:nfft));

% f = [1:nfft]*Fs/size(X, 1);
f = [0:nfft-1]*Fs/size(X, 1);

