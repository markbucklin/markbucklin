function Xbf = shiftedWinMat(x,Mf,Mb)
warning('shiftedWinMat.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
% Constructs [MxN] matrix from [Nx1] or [1xN] vector, where each column, n, holds a moving window of the signal in
% vector x , shifted so that the Mb+1 row is all zeros. If no Mb is given, Mb is zero, and first row is all zeros.
%
%	e.g. f(:,n) = x(n:(n+M)) - x(n);
%
% Can be used with matrix multiplication rather than using convolution followed by taking a derivative.
% Mark Bucklin

if nargin < 3
   Mb = 0;
end

% HANDLE MATRIX WITH DATA IN COLUMNS
if (size(x,2) > 1) && (size(x,1) > 1)
   if isnumeric(x)
	  Xbf = zeros(Mf+Mb, size(x,1), size(x,2), 'like', x);
   elseif islogical(x)
	  Xbf = false(Mf+Mb, size(x,1), size(x,2));
   else
	  %?
   end
   for k = 1:size(x,2)
	  Xbf(:,:,k) = shiftedWinMat(x(:,k), Mf, Mb);
   end
   return
end
M = max(Mf, Mb);
x = x(:);
% FORWARD LOOKING COMPONENT
Xf = hankel(repmat(x(1), M, 1), [x; x(1:M)]);
Xf = Xf(:, M:end-1);
% REAR LOOKING COMPONENT
if Mb > 0
   Xb = circshift(Xf((M-Mb+1):end,:), M, 2);
   if Mf < M
	  % 	  if Mf >= 1
	  Xbf = cat(1, Xb, Xf(1:Mf,:));
	  % 	  else
	  % 		 Xf = cat(1, Xb, Xf(1,:));
	  % 	  end
   else
	  Xbf = cat(1, Xb, Xf);
   end
else
   Xbf = Xf;
end

% Xf = bsxfun(@minus, Xf, Xf(Mb+1,:));
% Xbf = bsxfun(@minus, Xbf, x');
