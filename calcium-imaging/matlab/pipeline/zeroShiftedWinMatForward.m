function f = zeroShiftedWinMatForward(x,M)
% Constructs [MxN] matrix from [Nx1] or [1xN] vector, where each column, n, holds a moving window of the signal in
% vector x , shifted so that the first row is all zeros. 
%
%	e.g. f(:,n) = x(n:(n+M)) - x(n);
% 
% Can be used with matrix multiplication rather than using convolution followed by taking a derivative. 
% Mark Bucklin

x = x(:);
f = hankel(repmat(x(1), M, 1), [x; x(1:M)]);
f = f(:, M:end-1);
f = bsxfun(@minus, f, f(1,:));
