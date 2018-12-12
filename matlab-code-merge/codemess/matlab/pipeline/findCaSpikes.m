% X = [R.RawTrace];
nRoi = numel(R);
Fs = 20;
M = 5*Fs;
N = size(X,1);
t = (0:N-1)/Fs;
nIter = 10;

fld = fields(S);
F = zeros(M,N,nRoi);
winsize = 2*Fs;
fprintf('\nFinding Ca-Response using WindowSize %f seconds\n',winsize/Fs)
parfor k = 1:nRoi
   fprintf('\tROI #%i\n',k)
   x = X(:,k);
   x0 = x;
   r = caResponse;
   r = r/sum(r);
   xupdate = zeros(length(x),nIter);
   for n = 1:nIter;
	  plot(t, x);
	  pause
	  f = hankel(repmat(x(1), M, 1), [x; x(1:M)]);
	  f = f(:, M:end-1);
	  f = bsxfun(@minus, f, f(1,:));
	  xguess = f' * r;
	  xupdate(:,n) = xguess;
	  x = x - xguess;
   end
   
end
%
% clf
% plot(t(1:M), f(:,yc>5), 'Color',[1 0 0 .2])
% hold on
% plot(t(1:M), f(:,(yc>4)&(yc<5)), 'Color',[0 1 0 .2])
% plot(t(1:M), f(:,(yc>3)&(yc<4))), 'Color',[0 0 1 .2])

%  p = zeros(N,1);
%    ycLast = ones(N,1);
%    for ns = 1:10
% 	  %    y = gcamp6fSpikeResponse([ns(:) ; zeros(M-find(logical(ns),1,'last'),1)]);
% 	  y = gcamp6fSpikeResponse([flipud((1:ns)') ; zeros(M-ns,1)]) ./ sum(1:ns);
% 	  yc = f' * y;
% 	  yc = yc.*fstd(:);
% 	  p = p + double(bsxfun(@gt, yc, ycLast));
% 	  ycLast = yc;
%    end
%    P(:,k) = p./100;



%    fmax = max(f,[],1);
%    fstd = std(f,1,1);
%    fmin = min(f,[],1);



