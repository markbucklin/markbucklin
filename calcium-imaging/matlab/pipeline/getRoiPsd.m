function [Pxx, F] = getRoiPsd(R)


X = [R.Trace];
N = numel(R);
 [Pxx(:,N), F] = pcov(X(:,N), 201, 2000, 20);
parfor k=1:numel(R)
   Pxx(:,k) = pcov(X(:,k), 201, 2000, 20);
end

% 
% normsig = normfunctions
% Pxnorm = normsig.poslt1(log(Pxx(101:end,:)));
% Fnorm = F(101:end);
% [~,idx] = sort(mean(Pxnorm(find(Fnorm>2), :), 1));
% imagesc([], Fnorm(101:end), Pxnorm(101:end,idx)), axis xy
% title('Power Spectral Density above 2Hz of Ali15-0812')
% xlabel('ROI')
% ylabel('Hz')