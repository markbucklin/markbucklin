bmcparam = cat(1,...
	{'PyramidLevels',4,'NumIterations',[100 50 40 20]},...
	{'PyramidLevels',2,'NumIterations',[25 20]},...
	{'PyramidLevels',3,'NumIterations',[5 25 90]},...
	{'PyramidLevels',3,'NumIterations',[100 25 10]});


% poolSize = size(bmcparam,1);
% if isempty(gcp('nocreate'))
% 	pool = parpool(poolSize);
% else
% 	pool = gcp;
% 	if pool.NumWorkers < poolSize
% 		pool.NumWorkers = poolSize;
% 	end
% end
% rmcdata = gpuArray(rmcdata);
% N = size(rmcdata,3);
N=250;
nParam = size(bmcparam,1);
for kb=1:nParam
	locparam = bmcparam(kb,:);
	locbmc{kb} = scicadelic.NonrigidMotionCorrector(locparam{:},'UseGpu',true,'UsePct',false);
end
for kf=1:N
	locdata = gpuArray(rmcdata(:,:,kf));
	for kb = 1:nParam
		[gpdata(:,:,kb), locinfo(kb,kf)] = step(locbmc{kb}, locdata);
	end
% 	pdata(:,:,:,kf) = gather(gpdata);
pcdata{kf} = gather(gpdata);
end


% 		lpdata{kb,kf} = gather(locdata);
% 	end
% 	pinfo(kb,1) = unifyStructArray(lpinfo(kb,1));
% 	pdata(:,:,kb,:) = cat(4, lpdata{kb,:});
% end

for k=1:nParam
	pinfo(k) = unifyStructArray(locinfo(k,:));
end
imagesc(pdata(:,:,1,1));






pmode start 4
pmode client2lab data 1:4 locdata

spmd
for kf=1:N
	gdata = gpuArray(locdata(:,:,kf));
	[gdata motionInfo] = step(locbmc,gdata);
	cdata(:,:,kf) = gather(gdata);
	info(kf) = motionInfo;
end
end

pmode client2lab data 1:4 locdata
pmode lab2client cdata 1 data1
pmode lab2client cdata 2 data2
pmode lab2client cdata 3 data3
pmode lab2client cdata 4 data4

% 
% N=5;
% nParam = size(bmcparam,1);
% % for kb=1:nParam
% spmd(nParam)
% 	locparam = bmcparam(kb,:);
% 	locbmc = scicadelic.NonrigidMotionCorrector(locparam{:},'UseGpu',true,'UsePct',false);
% end
% % end
% for kf=1:N	
% 	curdata = rmcdata(:,:,kf);
% % 	for kb = 1:nParam
% spmd(nParam)
% 	kb = labindex;
% 	locdata = single(curdata);
% 	[gpdata, locinfo] = step(locbmc, gpuArray(locdata));
% 	cpdata = gather(gpdata);
% end
% pinfo(:,kf) = gather(locinfo(:));
% pdatac(kf,:) = gather(cpdata(:));
% pdata(:,:,:,kf) = cat(3,pdatac(kf,:));
% end