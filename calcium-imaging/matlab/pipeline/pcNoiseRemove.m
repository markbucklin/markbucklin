
normlt1 = @(v) bsxfun(@rdivide, bsxfun(@minus, v, mean(v,1)), max(abs(v),[],1));
pc = normlt1(principalComp);
for k=1:25
   pcNoise(:,:,k) = abs(acos(X*pc(:,k))) * pc(:,k)';
end

t = 0:1/20:(size(f,1)/20);
N=5000;
for k=1:25
   imagesc(t(1:N),1:size(pc,1),normZ(squeeze(pcNoise(1:N,:,k)))')
   title(sprintf('PC: %d',k))
   xlabel('time');
   set(gca,'XTick', 0:6:t(N), 'XGrid','on')
   pause
end

