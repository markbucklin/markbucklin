function varargout = pnz(Fbw)
% PERCENT-NON-ZERO
% More accurately, this function returns the fraction of non-zeros.
% Percentage is printed if no output is requested

[numRows, numCols, ~, ~] = size(Fbw);
numPixels = numRows*numCols;


if ~nargout
	N = numel(Fbw);
	Nz = nnz(Fbw);
	fracNonZero = double(Nz)/double(N);
	fprintf('\t%3.3g%% \n',fracNonZero*100);
	
else
	Nz = double( sum(uint32( sum(uint16( Fbw~=0 ), 1)) ,2));
	fracNonZero = bsxfun(@rdivide, Nz, double(numPixels));
	varargout{1} = fracNonZero;
	
end



% if nargout
% 	varargout{1} = fracNonZero;
% else
% 	fprintf('\t%3.3g%% \n',fracNonZero*100);
% end

