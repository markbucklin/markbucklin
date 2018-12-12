% LOAD DATA FROM MAT-FILE
[filename,pathname] = uigetfile('*.mat');
load([pathname,filesep,filename]);
md = mouseData;
fpath = uigetdir('point to the wmv-file video directory');

% DEFINE CONSTANTS
pixPerCm = md.bowl.diameter/30.48;

vidReader = VideoReader(fullfile(fpath,md.fname));
fps = vidReader.NumberOfFrames/vidReader.Duration;
framePeriod = 1/fps;
laserOnFrame = round(2*60*fps);
laserOffFrame = round(4*60*fps);
numFrames = length(md.x);
md.t = linspace(1/fps, vidReader.Duration, numFrames);

% AMBULATION - 
dx = diff([md.x(1) ; md.x(:)]);
dy = diff([md.y(1) ; md.y(:)]);
ambulation = hypot(dx,dy)/framePeriod./pixPerCm;  % difference of squares
winsize = 2*(round(.5*fps)/2)+1;    % makes window-size an odd number (required for smooth function)
smambulation = smooth(ambulation,winsize,'moving');

plot(md.t(1:laserOnFrame),smooth(smambulation(1:laserOnFrame),40))
hold on
plot(md.t(laserOnFrame+1:laserOffFrame),smooth(smambulation(laserOnFrame+1:laserOffFrame),40),'g');
plot(md.t(laserOffFrame+1:end),smooth(smambulation(laserOffFrame+1:end),40),'k');
ambulationPeriods = smambulation > 2;
preLaserAmbFrames = sum(ambulationPeriods(1:laserOnFrame));
duringLaserAmbFrames = sum(ambulationPeriods(laserOnFrame:laserOffFrame));
postLaserBinFrame = round([laserOnFrame*3 laserOnFrame*4 laserOnFrame*5]);
postLaserAmbFrames1 = sum(ambulationPeriods(laserOffFrame:postLaserBinFrame(1)));
postLaserAmbFrames2 = sum(ambulationPeriods(postLaserBinFrame(1):postLaserBinFrame(2)));
postLaserAmbFrames3 = sum(ambulationPeriods(postLaserBinFrame(2):end));


% IMMOBILITY
immobulationPeriods = smambulation < 1.5;
preLaserimmobFrames = sum(immobulationPeriods(1:laserOnFrame));
duringLaserimmobFrames = sum(immobulationPeriods(laserOnFrame:laserOffFrame));
postLaserBinFrame = round([laserOnFrame*3 laserOnFrame*4 laserOnFrame*5]);
postLaserimmobFrames1 = sum(immobulationPeriods(laserOffFrame:postLaserBinFrame(1)));
postLaserimmobFrames2 = sum(immobulationPeriods(postLaserBinFrame(1):postLaserBinFrame(2)));
postLaserimmobFrames3 = sum(immobulationPeriods(postLaserBinFrame(2):end));

% ROTATION
[thetaRump,rhoRump] = cart2pol(md.bodyPosition(:,1)-md.rumpPosition(:,1), -(md.bodyPosition(:,2)-md.rumpPosition(:,2)));
thetaRump(find(rhoRump<5)) = NaN;
thetaRump(find(rhoRump>100)) = NaN;
while any(thetaRump)
		blankval = find(isnan(mouseData.theta),1,'first');
		thetaRump(blankval) = thetaRump(blankval-1);
	end




























