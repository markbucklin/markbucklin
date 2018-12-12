function [S, X, dX, t] = findSpikeProb(R)
% R.normalizeTrace2WindowedRange
% R.makeBoundaryTrace
% R.filterTrace

%% get X
X = [R.RawTrace];
Xfilt = double([R.Trace]);

%%
nRoi = numel(R);
Fs = 20;
Ts = 5;
M = Ts*Fs;
N = size(X,1);
t = ((0:N-1)/Fs)';
tau = (0:M-1)/Fs;
Nspikerates = 10;
spikerate = 2.^(0:Nspikerates-1);
spikedur = (1:2*Fs)/Fs;
Nresponseperiods = numel(spikedur);
[~,dX] = gradient(Xfilt, 1:nRoi, t);

%%
znormcol = @(v)bsxfun(@rdivide,bsxfun(@minus,v,mean(v,1)),std(v,[],1));
znormrow = @(v)bsxfun(@rdivide,bsxfun(@minus,v,mean(v,2)),std(v,[],2));
pnormcol = @(v)bsxfun(@rdivide,bsxfun(@minus,v,min(v,[],1)),range(v,1));
pnormrow = @(v)bsxfun(@rdivide,bsxfun(@minus,v,min(v,[],2)),range(v,2));
CaNormZ = zeros(M,Nresponseperiods,Nspikerates);
Ca = zeros(M,Nresponseperiods,Nspikerates);
% Y = zeros(N,Nresponseperiods,Nspikerates);
% Tspikems = zeros(Nspike,Nlambda);
% maxval = zeros(N,Nspikerates);
% maxind = zeros(N,Nspikerates);
parfor kr = 1:Nspikerates;
   spikedur = (1:2*Fs)/Fs;
   ca = zeros(M,Nresponseperiods);
   for kT = 1:Nresponseperiods
	  tspike = [];
	  while isempty(tspike)
		 tspike = generateSpikeTimes(spikerate(kr), spikedur(kT));
	  end
	  tspike = tspike-tspike(1);
	  ca(:,kT) = gcamp6fResponse(tspike, Fs, Ts); %Nspike/nspikes
   end
   fprintf('Responses generated for spikerate = %f\n',spikerate(kr));
   CaNormZ(:,:,kr) = znormcol(ca);
   Ca(:,:,kr) = ca;
end

%%
winsize = 2*Fs;
% F = zeros(M,N,nRoi);
S = struct(...
   'yrate', repmat({zeros(N,1)}, nRoi, 1),...
   'srtrend', repmat({zeros(N,1)}, nRoi, 1),...
   'sreffect', repmat({zeros(N,1)}, nRoi, 1),...
   'dyratemax', repmat({zeros(N,1)}, nRoi, 1),...
   'dyratemin', repmat({zeros(N,1)}, nRoi, 1),...
   'dyratemean', repmat({zeros(N,1)}, nRoi, 1),...
   'ydur', repmat({zeros(N,1)}, nRoi, 1),...
   'sdtrend', repmat({zeros(N,1)}, nRoi, 1),...
   'sdeffect', repmat({zeros(N,1)}, nRoi, 1),...
   'dydurmax', repmat({zeros(N,1)}, nRoi, 1),...
   'dydurmin', repmat({zeros(N,1)}, nRoi, 1),...
   'dydurmean', repmat({zeros(N,1)}, nRoi, 1),...
   'med', repmat({zeros(N,1)}, nRoi, 1),...
   'mean', repmat({zeros(N,1)}, nRoi, 1),...
   'max', repmat({zeros(N,1)}, nRoi, 1),...
   'min', repmat({zeros(N,1)}, nRoi, 1));
CaRate = znormcol(squeeze(mean(CaNormZ,2)));
CaDur = znormcol(mean(CaNormZ,3));
parfor k = 1:nRoi
   spikedur = (1:2*Fs)/Fs;
   fprintf('\tROI #%i\n',k)
   x = X(:,k);
   f = hankel(repmat(x(1), M, 1), [x; x(1:M)]);
   f = f(:, M:end-1);
   f = znormcol(f);
   S(k).med = median(f(1:winsize, :), 1)';
   S(k).mean = mean(f(1:winsize, :), 1)';
   S(k).max = max(f(1:winsize, :), [], 1)';
   S(k).min = min(f(1:winsize, :), [], 1)';
   %    F(:,:,k) = f;
   yRate = f' * CaRate;
   [dsr, dyrate] = gradient(filtfilt(ones(9,1),1,yRate),spikerate,t);
   S(k).yrate = mean(yRate,2);
   S(k).srtrend = mean(diff(znormcol(dsr),1,2),2); % spike = srTrend < 0
   S(k).sreffect = mean(diff(znormcol(dyrate),1,2),2); % spike = srEffect > 0
   S(k).dyratemax = max(dyrate,[],2);
   S(k).dyratemin = min(dyrate,[],2);
   S(k).dyratemean = mean(dyrate,2);
   yDur = f' * CaDur;
   [dsd, dydur] = gradient(filtfilt(ones(9,1),1,yDur),spikedur,t);
   S(k).ydur = mean(yDur,2);
   S(k).sdtrend = mean(diff(znormcol(dsd),1,2),2); % spike = srTrend < 0
   S(k).sdeffect = mean(diff(znormcol(dydur),1,2),2); % spike = srEffect > 0
   S(k).dydurmax = max(dydur,[],2);
   S(k).dydurmin = min(dydur,[],2);
   S(k).dydurmean = mean(dydur,2);
   %    S(k).f = f;
end























