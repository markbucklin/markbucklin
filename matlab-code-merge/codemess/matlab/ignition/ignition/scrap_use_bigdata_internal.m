

inmap = matlab.bigdata.internal.lazyeval.InputFutureMap.createPassthrough(1)





fcn = @fft;
chunkOp = matlab.bigdata.internal.lazyeval.ChunkwiseOperation(fcn,1,1)
hfcn = matlab.bigdata.internal.FunctionHandle(fcn)
hChunkOp = matlab.bigdata.internal.lazyeval.ChunkwiseOperation(hfcn,1,1)

chunkProcFact = matlab.bigdata.internal.lazyeval.ChunkwiseProcessor.createFactory(hfcn,1,inmap,1) %...createFactory(hfcn,1,inmap,1, @(varargin)[])
cpff = functions(chunkProcFact)
%chunkProc = chunkProcFact(    %partition%   );


nonpartProcFact = matlab.bigdata.internal.lazyeval.NonPartitionedProcessor.createFactory(hfcn,1,inmap)

dataProc = nonpartProcFact();

npff = functions(nonpartProcFact)

nonpartProc = nonpartProcFact()

%%
kframe=0;
ksubframe=0;
kchunk = 0;
N = 1024;
F = single(phantom(N));
Fout = cell.empty(0,1);
while kframe<N
	%%
	while ksubframe<16
		%%
		kframe=kframe+1;
		Flocout = process(nonpartProc, false, {F(:,kframe)});
		Fout = cat(1,Fout, Flocout);
		ksubframe=ksubframe+1;
	end
	%%
% 	kchunk = kchunk + 1;
% 	Flocout = process(nonpartProc, true, {F(:,kframe)});
% 	Fout = cat(1,Fout, Flocout);
	ksubframe = 0;	
	Fout
end
Flocout = process(nonpartProc, true, {F(:,kframe)});
	Fout = cat(1,Fout, Flocout);
%%

% Fout = process(nonpartProc, true, {F(:,N)});

%Fin = mapData(inmap, {F});
