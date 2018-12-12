
TL = scicadelic.TiffStackLoader;
SC = scicadelic.StatisticCollector;
CE1 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 256,'LpFilterSigma',31);
CE2 = scicadelic.LocalContrastEnhancer('BackgroundFrameSpan', 5, 'LpFilterSigma',5);
MC = scicadelic.RigidMotionCorrector;
% BGR = scicadelic.BackgroundRemover;
setup(TL)

N=500;
k=0;
frameSize = TL.FrameSize;
datatype = TL.InputDataType;
data = zeros([frameSize N], datatype);
predata = zeros([frameSize N], datatype);
info(N).frame = struct.empty();
info(N).motion = struct.empty();


% JARQUE-BERA
jbmad = zeros([frameSize N], 'single');
jbma = zeros(frameSize);

while k<N
	k=k+1;
	[cdata, frameInfo] = step(TL);
	gdata = gpuArray(cdata);
	gdata = step(CE1,gdata);
	predata(:,:,k) = gather(gdata);
	[gdata, motionInfo] = step(MC,gdata);
	gdata = step(CE2,gdata);
	step(SC, gdata);
	% 	gdata = step(BGR, gdata);
	
	info(k).frame = frameInfo;
	info(k).motion = motionInfo;
	data(:,:,k) = gather(gdata);
	
	% JARQUE-BERA
	if k>1000;
		nma = max(100,k-999);
		jb = SC.JarqueBera;
		jbma = 1/nma * jb + (nma-1)/nma * jbma;
		jbmad(:,:,k-999) = gather(log1p(single(jb./jbma)));
	end
	
end
info = unifyStructArray(info);




bmcparam{1,:} = {'AccumulatedFieldSmoothing',1};
bmcparam{2,:} = {'AccumulatedFieldSmoothing',3};
bmcparam{3,:} = {'AccumulatedFieldSmoothing',5};
bmcparam{4,:} = {'AccumulatedFieldSmoothing',15};




% pool = parpool(4);
rmcdata = gpuArray(data(:,:,1:500));
N = size(rmcdata,3);
parfor kb=1:numel(bmcparam)
	locparam = bmcparam(kb,:);
	locbmc = scicadelic.NonrigidMotionCorrector(locparam{:});
	for kf=1:N
		[locdata, locinfo] = step(locbmc, rmcdata(:,:,kb));
		pinfo(kb,1) = locinfo;
		pdata{kb,kf} = gather(locdata);
	end
	release(locbmc)
end