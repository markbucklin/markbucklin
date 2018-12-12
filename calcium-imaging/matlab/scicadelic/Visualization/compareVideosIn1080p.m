% scraps for now
scaleTo8 = @(X) uint8( single(X-min(X(:))) ./ (single(range(X(:)))/255));
directToSingleChannel = @(X) permute(shiftdim(scaleTo8(X),-1),[2 3 1 4]);


N = size(regData,3);
midcolumn = floor(1920/2);
regmovie = zeros(1080,1920,3,N,'uint8');
subs.row = floor((1080-1024)/2)+(1:1024);
subs.colleft = 1:1024;
colmid = 1920/2;
subs.colright = (1920-1024+1):1920;


fromLogDomain = @(X) cast(expm1(X).*double(dMax), dClass);
rm = fromLogDomain(u.runningmean);

% 1080 X 1920 X 3   SCREEN   
%			LEFT SIDE IS PRE-OPERATION (motion correction in this case)
%			RIGHT SIDE IS POST-OPERATION

% GREEN CHANNEL: ABSOLUTE DIFFERENCE BETWEEN EACH DATA AND A (REGISTERED) RUNNING MEAN
regmovie(subs.row,subs.colright, 2, :) = permute(shiftdim(bsxfun(@imabsdiff,scaleTo8(regData), scaleTo8(rm)),-1),[2 3 1 4]);
regmovie(subs.row,subs.colleft(1:midcolumn), 2, :) = permute(shiftdim(bsxfun(@imabsdiff,scaleTo8(data(:,1:midcolumn,:)), scaleTo8(rm(:,1:midcolumn))),-1),[2 3 1 4]);

