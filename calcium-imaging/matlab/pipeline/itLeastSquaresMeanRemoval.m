


% X0 = R.makeTraceFromVid(data);
X = X0;

y = sum(X,2);
b = (X'*X) \ (X'*y);
% b = X\y;
X = X - mean(X,2)*(1./b)';
strips(X(:,1:100:end))




