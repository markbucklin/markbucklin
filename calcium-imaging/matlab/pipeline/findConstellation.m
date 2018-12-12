function [cs, commonOverlap] = findConstellation(md, dr)
if nargin < 2
   dr = 5;
end
Nday = numel(md);


dxyBounds = 25 .* [-dr dr];
dx = dxyBounds(1):(dr/2):dxyBounds(2);
dy = dxyBounds(1):(dr/2):dxyBounds(2);

n=0;
for kd1 = 1:Nday
   R1 = md(kd1).roi;
   for kd2 = (kd1+1):Nday
	  n=n+1;
	  cs(n).kd = [kd1 kd2];
	  R2 = md(kd2).roi;
	  % GET CENTROID SEPARATION BETWEEN ROI SETS
	  [cs(n).Y, cs(n).X] = centroidSeparation(R1, R2);
   end
end
commonOverlap = zeros(numel(dy), numel(dx), n);
parfor k = 1:n
   csY = cs(k).Y;
   csX = cs(k).X;
   nMaxOverlap = min(size(csY));
   [~,minDim] = min(size(csX));
   [~,maxDim] = max(size(csX));
   % MINIMIZATION FUNCTION
   % 	  alignFcn = @(dx,dy)  nMaxOverlap - sum(any( abs(csX-dx)<dxyThresh & abs(csY-dy)<dxyThresh, 2));
   comov = squeeze(...
	  sum(any( bsxfun(@and,...
	  abs(bsxfun(@minus, csX, shiftdim(dx,-1)))<dr,...
	  abs(bsxfun(@minus, csY, shiftdim(dy,-2)))<dr),...
	  minDim),maxDim));
   commonOverlap(:,:,k) = comov;
   %    cs(k).commonoverlap = comov;
end
for k=1:n
   %    cs(k).comov = commonOverlap(:,:,k);
   imagesc(dx,dy,commonOverlap(:,:,k))
   title(sprintf('Global Maximization of ROI-Overlap (threshold<%f): Day %i vs Day %i',dr, cs(k).kd(1), cs(k).kd(2)));
   xlabel('x-shift (px)')
   ylabel('y-shift (px)')
   drawnow
   pause(1)
   cs(k).frame = getframe(gcf);   
end



% % md = loadMultiDayRoi
% clearvars -except md
% nDay = numel(md);
% N = cellfun(@numel, {md.roi});
% for k = 1:nDay
%    c = cat(1,md(k).roi.Centroid);
%    c = c - 512;
%    %    c = bsxfun(@minus, c , min(c) + range(c)/2);
%    [th,r] = cart2pol(c(:,1), -c(:,2));
%    th(th<0) = bsxfun(@minus, 2*pi, abs(th(th<0)));
%    th180 = fix(th*180/pi) + 1;
%
%    C{k} = c;
%    TH{k} = th180;
%    R{k} = r;
%    %    polar(TH{k}, R{k}, '.'), hold on
% end
%
%
%
%
%
%
%
% for k=1:numel(md), c(k).xy = cat(1,md(k).roi.Centroid); end
% for k=1:numel(md), [c(k).theta, c(k).r] = cart2pol(512-c(k).xy(:,2), 512-c(k).xy(:,1)); end
% for k=1:numel(md)
%    c(k).ddr = bsxfun(@minus, c(k).r, c(k).r');
%    [c(k).csy, c(k).csx] = centroidSeparation(md(k).roi);
%    [c(k).cstheta, c(k).csr] = cart2pol(c(k).csx, c(k).csy);
% end


% for k=1:numel(md), [c(k).feats, c(k).validpts] = extractFeatures(vday(k).Std, c(k).xy,'Method','Block'); end
% tmp = matchFeatures(c(1).feats, c(2).feats,'Unique',true)
% showMatchedFeatures(vday(1).Std, vday(2).Std, c(1).validpts(tmp(:,1),:), c(2).validpts(tmp(:,2),:))

% nDay = numel(md);
% N = cellfun(@numel, {md.roi});
% for k = 1:nDay
%    [ydist{k}, xdist{k}] = md(k).roi.centroidSeparation;
%    [th{k}, r{k}] = cart2pol(xdist{k}, ydist{k});
%    c = r{k} + i*th{k};
%    M = size(c,1);
%    constel = false(360,M);
%    for m=1:M
% 	  cm = c(:,m);
% 	  cshell = cm(real(cm) > 50 & real(cm) < 60);
% 	  [~,idx] = sort(imag(cshell), 'ascend');
% 	  cshell = cshell(idx);
% 	  cdeg = fix((imag(cshell)+pi)*(180/pi))+1;
% 	  constel(cdeg,m) = true;
%    end
%    B{k} = constel;
% end


% f = bsxfun(@and, B{1}, permute(shiftdim(B{2},-1), [2 1 3])) ...
%    |bsxfun(@and, B{1}, permute(shiftdim(circshift(B{2},1,1),-1), [2 1 3])) ...
%    |bsxfun(@and, B{1}, permute(shiftdim(circshift(B{2},2,1),-1), [2 1 3])) ...
%    |bsxfun(@and, B{1}, permute(shiftdim(circshift(B{2},3,1),-1), [2 1 3])) ...
%    |bsxfun(@and, B{1}, permute(shiftdim(circshift(B{2},-1,1),-1), [2 1 3])) ...
%    |bsxfun(@and, B{1}, permute(shiftdim(circshift(B{2},-2,1),-1), [2 1 3])) ...
%    |bsxfun(@and, B{1}, permute(shiftdim(circshift(B{2},-3,1),-1), [2 1 3]));
%
% [ix, iy] = find(squeeze(sum(f,1)) > 5);
% for k=1:numel(ix), show([md(1).roi(ix(k)) ; md(2).roi(iy(k))]); pause, end