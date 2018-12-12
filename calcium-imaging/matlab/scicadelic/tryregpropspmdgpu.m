


% 	obj.regionPropStatsAvailable.basicStats,...

% stats = cat(1, ...
% 	obj.regionPropStatsAvailable.pixelValueStats,...
% 	obj.regionPropStatsAvailable.shapeStats);


%
% numFrames = size(lm,3);
% spmd(numFrames)
% 	if labindex <= numFrames
% 		locLm = getLocalPart(lm);
% 		disp(size(locLm))
% 		locData = getLocalPart(gdata);
% 		rpc = regionprops(locLm, locData, stats);
% 	end
% end

numFrames = size(bw,3);
% stats = obj.regionPropStatsAvailable.fasterStats;


% bw = logical(lm);

benchTime = zeros(size(stats));

% gcp
% rp = struct.empty(0,1);
for kbench = 1:numel(stats)
	tStart = hat;
	statsMinusOne = stats([1:numel(stats)]~=kbench);	
	
	
	clear rp
	parfor k=1:numFrames
		rpc = regionprops(bw(:,:,k), gdata(:,:,k), stats);
		rp{k} = rpc;
	end
	
	tic
	parfor k=1:numFrames
		rpc = regionprops(cbw(:,:,k), cdata(:,:,k), stats);
		crp{k} = rpc;
	end
	toc
	
	
	crpc2 = regionprops(reshape(bw, [],size(bw,2),1) , reshape(gdata, [], size(gdata,2), 1), stats);
	wait(dev)
	benchTime(kbench) = hat - tStart;
	disp(benchTime)
end


% 		'PixelValues'         [0.5653]*
%     'WeightedCentroid'    [0.6156]*
%     'MeanIntensity'       [0.4260]
%     'MinIntensity'        [0.4151]
%     'MaxIntensity'        [0.4025]
%     'Area'                [0.3722]
%     'Centroid'            [0.3740]
%     'BoundingBox'         [0.4054]
%     'SubarrayIdx'         [1.3362]***
%     'MajorAxisLength'     [0.5396]*
%     'MinorAxisLength'     [0.5589]*
%     'Eccentricity'        [0.5327]*
%     'Orientation'         [0.5506]*
%     'Image'               [1.3364]***
%     'Extrema'             [2.2523]*****
%     'EquivDiameter'       [0.3637]
%     'Extent'              [0.3860]
%     'PixelIdxList'        [0.4331]
%     'PixelList'           [0.4447]
