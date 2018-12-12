% R.normalizeTrace2WindowedRange
% R.makeBoundaryTrace
% R.filterTrace

X = [R.Trace];
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
% winsize = Fs;
% for win = 1:10
%    winsize = min(win*Fs/2, M);
winsize = Fs;
fprintf('\nFinding Ca-Response using WindowSize %f seconds\n',winsize/Fs)
parfor k = 1:nRoi
   fprintf('\tROI #%i\n',k)
   %    x = filtfilt(b, a, X(:,k));
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
   %    CaResp{k} = f(:, P(k).max.loc * Fs +1);
   S(k).min = -S(k).min;
   F(:,:,k) = f;
   %    signifInc = max > 2;
   %    signifDec = med < -1;
   %    fSignif = f(:,signifInc);
end
%    Sw(:,win) = S;
%    Pw(:,win) = P;
% end

% for k = 1:nRoi
%    activityMetric(:,k) = (S(k).max - S(k).mean);
%    plot(t, [X(:,k), (S(k).max-S(k).mean), (S(k).mean+S(k).min)], 'LineWidth',1)
%    legend('Signal', 'Max - Mean', 'Mean + Min')
%    title('Signal Activity Metric')
%    xlabel('time')
%    pause
% end







