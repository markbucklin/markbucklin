normsig.z = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), std(v,[],1));
normsig.poslt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, min(v,[],1)), range(v,1));
normsig.zmlt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), max(abs(v),[],1));

md = loadMultiDayRoi();
for kDay=1:numel(md)
   md(kDay).dist = centroidSeparation(md(kDay).roi);
   md(kDay).ss = cat(1,md(kDay).roi.PixelSubScripts); 
   md(kDay).mask = weightedMask(md(kDay).roi);
   md(kDay).f = single([md(kDay).roi.Trace]);
   % PEARSON, PCA EIGDECOMP
   X = md(kDay).f;
   D = bsxfun(@minus, X, mean(X,1));
   n = size(D,1);
   S = (D' * D) / (n-1);
   for k = 1:size(D,2)
	  D(:,k) = D(:,k) ./ sqrt( sum(D(:,k).^2) );
   end
   R = D' * D;
   Rnan = R;
   Rnan(1:size(R,1)+1:numel(R)) = NaN;
   [colMaxVal, maxRowIdx] = nanmax(Rnan);
   [maxVal, maxColIdx] = max(colMaxVal);
   maxRowIdx = maxRowIdx(maxColIdx);
   [V, lambda] = eig(S);
   V = bsxfun(@rdivide, V, min(abs(V), [],1));
   principalVar = flipud(diag(lambda));
   principalComp = fliplr(V);
   accountedVariance = cumsum(abs(principalVar)) / sum(abs(principalVar));
   pc2 = normsig.z(principalComp(:,2));
   Y = zeros(size(D,1),size(principalComp,2));
   for k=1:size(principalComp,2)
	  Y(:,k) =  D * principalComp(:,k);
   end
   md(kDay).corrcov = S;
   md(kDay).pearson = R;
   md(kDay).eigvec = V;
   md(kDay).eigval = lambda;
end


% for k=1:20, set(R(pc(:,k) >.5), 'Color',[1 0 0]); set(R(pc(:,k) <-.5), 'Color',[0 0 1]); set(R(abs(pc(:,k) )<.5), 'Color',[0 1 0]); show(R), pause, end
