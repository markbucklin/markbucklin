fs = 20;
vstack.ntrials = numel(bhv.frameidx.alltrials);
vstack.maxlag = 10*fs;
vstack.lags = -vstack.maxlag : vstack.maxlag;
vstack.lags = vstack.lags + 5*fs;
% stdata = zeros([size(data,1) , size(data,2) ,...
%    vstack.ntrials , (2*vstack.maxlag + 1)],...
%    'like', data);
vstack.stim = zeros(vstack.ntrials,1);
vstack.stim(bhv.trialidx.short) = 1;
vstack.stim(bhv.trialidx.long) = 2;
vstack.shortmean = zeros([size(data,1) , size(data,2) ,1, (2*vstack.maxlag + 1)],'single');
vstack.longmean = zeros([size(data,1) , size(data,2) ,1, (2*vstack.maxlag + 1)],'single');
vstack.allmean = zeros([size(data,1) , size(data,2) ,1, (2*vstack.maxlag + 1)],'single');
for k=1:vstack.ntrials
   idx = vstack.lags + bhv.frameidx.alltrials(k);
   idx(idx<1) = 1;
   idx(idx>size(data,3)) = size(data,3);
   %    stdata(:,:,k,:) = data(:,:, idx);
   stseq = single(permute(shiftdim(data(:,:, idx),-1), [2 3 1 4]));
   preidx = idx(1:20)-20;
   preidx(preidx<1) = 1;
   stpreseq = single(mean(permute(shiftdim(data(:,:, preidx,:),-1), [2 3 1 4]), 4, 'double'));
   stseq = bsxfun(@minus, stseq, stpreseq);
   if vstack.stim(k) == 1
	  vstack.shortmean = vstack.shortmean + stseq * (1/numel(bhv.trialidx.short));
   else
	  vstack.longmean = vstack.longmean + stseq * (1/numel(bhv.trialidx.long));
   end
   vstack.allmean = vstack.allmean + stseq * (1/numel(bhv.trialidx.longovershort));
   %    if vstack.stim(k) == 1
   % 	  vstack.shortmean = vstack.shortmean + single(stdata(:,:,k,:)) * (1/numel(bhv.trialidx.short));
   %    else
   % 	  vstack.longmean = vstack.longmean + single(stdata(:,:,k,:)) * (1/numel(bhv.trialidx.long));
   %    end
   %    vstack.allmean = vstack.allmean + single(stdata(:,:,k,:)) * (1/numel(bhv.trialidx.longovershort));
end
% stmean = cat(3, ...
% vstack.shortmean = single(mean(stdata(:,:,bhv.trialidx.short, :), 3));
% vstack.longmean = single(mean(stdata(:,:,bhv.trialidx.long, :), 3));
% vstack.allmean = single(mean(stdata, 3));
%    repmat(single(mean(data,3)), [ 1 1 1 numel(idx)]));
stmean = cat(3, ...
   vstack.shortmean - vstack.allmean,...
   vstack.longmean - vstack.allmean,...
   vstack.allmean);
% stmean(stmean < 0) = 0;
stmean8 = uint8(bsxfun(@rdivide, stmean*255, max(max(max(stmean,[],1),[],2),[],4)));
stmean8(1:50,1:50, :, find(vstack.lags > 0 & vstack.lags < 2*fs)) = 255;

% stmean8(:,:,3,:) = 255 - stmean8(:,:,3,:);
% stmean = cat(3, ...
%    mean(stdata(:,:,bhv.trialidx.short, :), 3, 'native'),...
%    mean(stdata(:,:,bhv.trialidx.long, :), 3, 'native'),...
%    repmat(mean(data,3, 'native'), [ 1 1 1 numel(idx)]));

