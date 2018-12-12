warning('scraprunneighborMI.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

% displacements = [];
displacements = pow2(0:4); % maxdiameter=33pixels
% Qmin = .1;

numDisplacements = numel(displacements);
idx0 = 512;


[numRows,numCols,numFrames] = size(Fr);
chunkSize = 16;
numChunks = floor((numFrames - idx0)/chunkSize);
pmi = zeros(numRows,numCols,8*numel(displacements), numChunks, 'int8');


% INIT
P = [];
Qmin = [];
P0 = [];
m=0;
idx = idx0;

a = single(0.0);
b = single(.02);



while (idx(end)<4096-16)
	idx = idx(end)+(1:16);
	m=m+1;
	% 	Q = 1/255 .* single(gpuArray(squeeze(Frgb(:,:,1,idx))));
	
	Q = single(gpuArray(Fr(:,:,idx)));
	[PMI, Hab, P] = pointwiseMutualInformationRunGpuKernel(Q, P, Qmin, displacements);
	pmi(:,:,:,m) = gather( int8( 127.*PMI) );
	
	% TEMPORAL FILTERING (prevent static buildup...?)
	P.a = max(0, P.a - b);
	P.b = max(0, P.b - b);
	P.ab = max(0, P.ab - b^2);
	% 	if isempty(P0)
	% 		P0 = P;
	% 	else
	% 		P.a = max(0, (1-a).*P.a + a.*P0.a - b);
	% 		P.b = max(0, (1-a).*P.b + a.*P0.b - b);
	% 		P.ab = max(0, (1-a).*P.ab + a.*P0.ab - b);
	% 		% 		P0 = P;
	% 	end

	% 	imsc(mean(Hab,3))
	% 	imsc(squeeze(sum(PMI,3)))
	% 	drawnow
end

ringStep = 0;
pmirgb = uint8( single(pmi(:,:,ringStep+[1,6,5],:)) - single(pmi(:,:,ringStep+[8,3,4],:)) + 128).*(1/numDisplacements);
for kRing = 2:numDisplacements
	ringStep = (kRing-1)*8;
	pmirgb = pmirgb + uint8( single(pmi(:,:,ringStep+[1,6,5],:)) - single(pmi(:,:,ringStep+[8,3,4],:)) + 128).*(1/numDisplacements);

end
imrgbplay(pmirgb,.1)


% pmirgb2 = uint8(128.*(pmi(:,:,8+[1,4,6],:) - pmi(:,:,8+[8,5,3],:) +1));

% imrgbplay(pmirgb)
% imrgbplay(pmirgb2)

% imrgbplay((pmirgb+pmirgb2)/2);


