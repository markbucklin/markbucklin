function fullTE = myte(X,Y, lagWin)
if nargin < 2
   Y = X;
end
if nargin < 3
   lagWin = 5;
end
partialTE = @(yi,yilag,xilag) binaryjoint(yi, {yilag,xilag}) .* log2(binaryconditional(yi, {yilag,xilag})./binaryconditional(yi,yilag)) ;

M = size(X,2);
N = size(Y,2);
fullTE = zeros(M,N);
for ksource = 1:M
   xi = X(:,ksource);
   for kdest = 1:N
	  yi = Y(:,kdest);
	  xilag = any(shiftedWinMat(xi,1,lagWin),1)';
	  yilag = any(shiftedWinMat(yi,0,lagWin),1)';
	  fullTE(ksource,kdest) = 0 ...
		 + partialTE( yi,  yilag, xilag) ...
		 + partialTE( yi,  yilag,~xilag) ...
		 + partialTE( yi,~yilag, xilag) ...
		 + partialTE( yi,~yilag,~xilag) ...
		 + partialTE(~yi, yilag, xilag) ...
		 + partialTE(~yi, yilag,~xilag) ...
		 + partialTE(~yi,~yilag, xilag) ...
		 + partialTE(~yi,~yilag,~xilag) ;
   end
end
