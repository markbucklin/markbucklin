normsig.z = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), std(v,[],1));
normsig.poslt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, min(v,[],1)), range(v,1));
normsig.zmlt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), max(abs(v),[],1));
normsig.poslog = @(v) log( bsxfun(@plus, bsxfun(@minus, v, min(v,[],1)) , std(v,[],1)));

% LOAD ROIs (with traces)
file.roi = dir([pwd,'\Processed_ROIs_*.mat']);
[~,idx] = max(datenum({file.roi.date}));
load(file.roi(idx).name);
nRoi = numel(R);
X = double([R.Trace]);
N = size(X,2);
s.groupmean = mean(X,2);

% HIGHPASS X
Fs = 20;
% d  = fdesign.highpass('N,F3dB,Ap', 20, 1.5, .1, Fs);
% Hd = design(d, 'cheby1');
% fvtool(Hd)
% D = designfilt('highpassiir', 'FilterOrder', 10, ...
%    'PassbandFrequency', 1, 'PassbandRipple', 0.2,...
%    'SampleRate', 20);
fCutoff = 2;
Wn = fCutoff / (Fs/2);
[h.b, h.a] = butter(20, Wn, 'high'); 
d.xhp = filtfilt(h.b, h.a, X);
[C.dxhp, P.dxhp]=corrcoef(d.xhp);
s.grouphp = mean(d.xhp,2);
s.hpgroup = filtfilt(h.b, h.a, s.groupmean);

% LOAD MOTION SIGNAL FROM PROCESSING SUMMARY
file.procsum = dir([pwd,'\Processing_Summary_*.mat']);
[~,idx] = max(datenum({file.procsum.date}));
load(file.procsum(idx).name);
tmp = cat(1, vidProcSum.xc);
s.motion = 1 - cat(1,tmp.cmax);

% DIFFERENTIAL?
d.x = diff([X(1,:) ; X],1,1);
[C.dx, P.dx]=corrcoef(d.x);
imagesc(C.dx)
d.xnan = d.x;
d.xnan( bsxfun(@ge, abs(bsxfun(@minus, X, median(X,1))),std(X,[],1))) = NaN;
[C.dxnan,P.dxnan]=corrcoef(d.xnan,'rows','pairwise');
imagesc(C.dxnan), colormap hot, colorbar
C.dist = centroidSeparation(R);

Xdif = zeros(size(X));
for k=1:size(X,2)
   cdx = C.dxnan(:,k); 
   cdist = C.dist(:,k);
   thresh = .5;
   idx = [];
   while numel(idx) < N/10
	  idx = find((abs(cdx) > thresh) & cdist > 30);
	  idx = idx(idx~=k);
	  thresh = thresh*.9;
	  if thresh<.05
		 break
	  end
   end   
   if thresh<.05
	  Xdif(:,k) = normsig.poslt1(X(:,k));
	  continue
   end
   w = cdx(idx);
   C.comco(k,1).idx = idx;
   C.comco(k,1).w = w;   
   x = X(:,k);
   n = numel(w);
   xref = (1/sqrt(n)) .* X(:,idx) * w;
   Xdif(:,k) = normsig.poslt1( exp( normsig.poslog(x) - normsig.poslog(xref) + log(mean(x))));
end

imagesc(C.dx - C.dxnan)
[~,cdidx] = sort(mean(C.dxnan-Cdx, 2));
C.dxsig = C.dx-C.dxnan;
[~,cdidx] = sort(mean(C.dxsig, 2));
imagesc(C.dxsig)
colorbar
imagesc(C.dxsig(cdidx,cdidx))
colorbar
[~,cdidx] = sort(mean(C.dxsig, 2),'descend');
imagesc(C.dxsig(cdidx,cdidx))
colorbar
imagesc(C.dxnan)
find(C.dxnan(50,:) > .9)
find(C.dxnan(50,:) > .8)
find(C.dxnan(50,:) > .5)
plot(X(:,find(C.dxnan(50,:) > .75)))
x = X(:,50);
plot(X(:,find(C.dxnan(50,:) > .75)),'--')
plot(X(:,find(C.dxnan(50,:) > .75)),':')
xk = X(:,50);
xkrefidx = find(C.dxnan(50,:) > .75);
% xkrefidx
xkrefidx = xkrefidx(xkrefidx ~= 50)
xkref = X(:,xkrefidx);
dxkref = diff([xkref(1,:) ; xkref],[],1);
cxkref = C.dxnan(50,xkrefidx)
xkdenoise = xk - xkref * cxkref';