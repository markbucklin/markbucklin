
TL = scicadelic.TiffStackLoader;
SC1 = scicadelic.StatisticCollector;
setup(TL)

N=100;
k=0;
frameSize = TL.FrameSize;
datatype = TL.InputDataType;
data = zeros([frameSize N], datatype);
jbmad = zeros([frameSize N], 'double');
jbma = zeros(frameSize);

while k<N
	k=k+1;
	[cdata, frameInfo] = step(TL);
	gdata = gpuArray(cdata);
	step(SC1, gdata);
	data(:,:,k) = gather(gdata);
	nma = max(20,k);
	jb = SC1.JarqueBera;
	jbma = 1/nma * jb + (nma-1)/nma * jbma;
	jbmad(:,:,k) = gather(jb-jbma);
end


