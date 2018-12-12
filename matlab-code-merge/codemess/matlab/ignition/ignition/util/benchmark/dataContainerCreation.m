function dataContainerCreation(f,info)

N = 1000;
dc = cell(1,N);
for k=1:N
	dc{k} = f(:,:,1,1)+k; 
end
ic = cell(1,N);
for k=1:N
	ic{k} = info(1); ic{k}.FrameNumber=k; 
end

tic, 
for k=1:N
	obj(k) = ignition.core.type.DataContainerBase(dc{k},ic{k});
end
fprintf('%03.4g ms\n',1000*toc/N)
