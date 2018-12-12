
%%
% s = dsp.AudioPlayer;


%%
% dur = 5
% fs=44100; 
% f1=50; 
% f2=950;
% vol = 100;

% for f1 = 500:-7:20
% 	f2=520-f1;
% step(s, int16(32767*vol*repmat(cat(2, sin(f1*2*pi/fs*(0:fs*dur)'), sin(f2*2*pi/fs*(0:fs*dur)')), 1,3)))
% pause(.025)
% end

% step(s, vol*cat(2, sin(f1*2*pi/fs*(0:fs*dur)'), sin(f2*2*pi/fs*(0:fs*dur)')))



% ms = 441;


% step(s, 10*[ones(1*ms,2) ; zeros(9*ms,2); ones(5*ms,2) ; zeros(250*ms,2); ones(10*ms,2)])



%% SETUP DEVICES
allDevices = daq.getDevices;
dev(1) = allDevices(4);				% (primary sound driver)
dev(2) = allDevices(5);				% (Dell/NVIDIA HDMI)
dev(3) = allDevices(6);				% (S/PDIF)
dev(4) = allDevices(7);				% (S/PDIF)


%% SETUP SESSION
s = daq.createSession('directsound');
Fs = 50000;
for k = 1:numel(dev)
	chanGroup{k} = s.addAudioOutputChannel( dev(k).ID, dev(k).Subsystems.ChannelNames);%, 1:2)
end
channelPanel = cat(2, chanGroup{:});
s.Rate = Fs;



%%
ms = @(t) ceil(t*Fs/1000);

% PULSE TIMIMG
pulseDur = ms(1);
pulsePreDur = ms(2);
pulseStarts = ms(25):ms(25):ms(250);
pulseHighIdx = bsxfun(@plus, pulseStarts(:) , 1:pulseDur)';
pulsePreHighIdx = bsxfun(@plus, pulseStarts(:) , -pulsePreDur:0)';

fprintf('BEGINNING CHANNEL PULSE TEST\n')
for k=1:8
	fprintf('Channel %i\n',k)
	
	data = zeros(ms(500), 8);
	
	
	data(1:5, :) = 1; % trigger oscilloscope acquisition
	data(6:10, :) = -1; 
	data(11:15, :) = 1;
	
	data(pulseHighIdx(:), k) = 1;
	% 	data(pulsePreHighIdx(:), k) = -.5;
	
	
	queueOutputData(s, data)
	
	startForeground(s)
	
	
	fprintf('\t -> finished\n')
	pause(.5)
end


%  channels 5-6 are green line out on back of PC