function sg = getRoiSpecGram(R)

Fs = 20;
X = [R.RawTrace];
if isempty(X)
   X = [R.Trace];
end
N = numel(R);

% CHRONUX PARAMETERS
params.tapers = [Fs/2, Fs/2-1];
params.pad = 1;
params.Fs = 20;
params.fpass = [1 Fs/2];

[sg.s, sg.t, sg.f] = mtspecgramc(X, [2*Fs 5], params);

% for k=1:N
%    imagesc(sg.t, sg.f, log(sg.s(:,:,k)+1)')
%    axis xy
%    xlabel('Time (s)')
%    ylabel('Frequency (Hz)')
%    title(sprintf('Multi-Taper Spectrogram for ROI %i',k))
%    pause
% end
% S= bsxfun(@rdivide, sg.s, smean);
%  im = imaqmontage(permute(shiftdim(log(S+1), -1), [3 2 1 4]));
% axis xy
% colormap hot
% set(gca, 'Position', [0 0 1 1])

% winsize = Fs*2;
% [E,V] = dpss(winsize, 3);
% [sg(N).s,sg(N).f,sg(N).t] = spectrogram(X(:,N), win, winsize-Fs/2, [], Fs) ;
% parfor k=1:N
%    [sg(k).s,sg(k).f,sg(k).t] = spectrogram(X(:,k), 20, 5, .01:.01:10, 20) ; 
% end


