% R.normalizeTrace2WindowedRange
% R.makeBoundaryTrace
% R.filterTrace

% X = [R.Trace];
nRoi = numel(R);
Fs = 20;
M = 5*Fs;
N = size(X,1);
t = (0:N-1)/Fs;

S = struct(...
   'med', repmat({zeros(N,1)}, nRoi, 1),...
   'mean', repmat({zeros(N,1)}, nRoi, 1),...
   'max', repmat({zeros(N,1)}, nRoi, 1),...
   'min', repmat({zeros(N,1)}, 1));
P = struct(...
   'med', repmat({}, nRoi, 1),...
   'mean', repmat({}, nRoi, 1),...
   'max', repmat({}, nRoi, 1),...
   'min', repmat({}, 1));
fld = fields(S);
F = zeros(M,N,nRoi);
winsize = 2*Fs;
fprintf('\nFinding Ca-Response using WindowSize %f seconds\n',winsize/Fs)
parfor k = 1:nRoi
   fprintf('\tROI #%i\n',k)
   x = X(:,k);
   f = hankel(repmat(x(1), M, 1), [x; repmat(x(end),M,1)]);
   f = f(:, M:end-1);
   f = bsxfun(@minus, f, f(1,:));
   S(k).med = median(f(1:winsize, :), 1)';
   S(k).mean = mean(f(1:winsize, :), 1)';
   S(k).max = max(f(1:winsize, :), [], 1)';
   S(k).min = -min(f(1:winsize, :), [], 1)';
   for fn = 1:numel(fld)
	  fln = fld{fn};
	  [P(k).(fln).val, P(k).(fln).loc, P(k).(fln).width, P(k).(fln).prom] = findpeaks(double(S(k).(fln)), t,...
		 'MinPeakDistance', Fs/4, 'MinPeakProminence', 1.5);
   end
   S(k).min = -S(k).min;
   F(:,:,k) = f;
end

% for k = 1:nRoi
%    activityMetric(:,k) = (S(k).max - S(k).mean);
%    plot(t, [X(:,k), (S(k).max-S(k).mean), (S(k).mean+S(k).min)], 'LineWidth',1)
%    legend('Signal', 'Max - Mean', 'Mean + Min')
%    title('Signal Activity Metric')
%    xlabel('time')
%    pause
% end



% winsize = 1000*Fs; 
% beta = 10;
% k=nRoi;
% win = kaiser(winsize, beta);
% [Pxx(:,nRoi), freq] = pwelch(X(:,k), win, [], win, Fs);
% [Pxx, freq] = pwelch(X(:,k), win, [], win, Fs);
% plot(freq,Pxx)
% title(sprintf('Window Size %i',winsize))

% win = 4; 

for k=1:nRoi
   spikeLocs = P(k).max.loc*Fs+1;
   f = F(1:Fs*2, spikeLocs, k);
   plot(t(1:size(f,1)), f, 'Color',[.6 .6 .6 .2],'LineWidth',1.5);
   hold on
   plot(t(1:size(f,1)), mean(f,2), 'LineWidth',2, 'Color',R(k).Color);
   ylim([-.5 3])
   pause
   clf
end
%    plot(t, X(:,k)); 
%    hold on, 
%    plot(Pw(k,win).max.loc, Pw(k,win).max.prom,'.');
%    plot(Pw(k,win).min.loc, -Pw(k,win).min.prom,'.');
%    pause, clf, 
% end