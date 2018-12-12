function stat = updateStatisticStructure(F, stat)




% INFO ABOUT INPUT
fpType = 'single';
% [~, ~, numFrames] = size(F);
[numRows, numCols, numFrames] = size(F);


% INITIALIZE STAT STRUCTURE
if (nargin < 2)
	stat = [];
end
if isempty(stat)
	if isa(F, 'gpuArray')
		initZeroVal = gpuArray.zeros(1,fpType);
		initZeroMat = gpuArray.zeros(numRows, numCols, 1, fpType);
	else
		initZeroVal = zeros(1,fpType);
		initZeroMat = zeros(numRows, numCols, 1, fpType);
	end
	stat.N = initZeroVal;
	stat.Min = min(F, [], 3);
	stat.Max = max(F, [], 3);
	stat.M1 = initZeroMat;
	stat.M2 = initZeroMat;
	stat.M3 = initZeroMat;
	stat.M4 = initZeroMat;
end


% STATISTIC CONTRIBUTION COUNTS/WEIGHTS
na = stat.N;
nb = numFrames;
n = na + nb;

% MAX & MIN
stat.Min = min(min(F, [], 3), stat.Min);
stat.Max = max(max(F, [], 3), stat.Max);

% CENTRAL MOMENTS
if nb == 1 % Run faster implementation if only updating with 1 frame
	d = cast(F, fpType) - stat.M1;
	dk = d./n;
	dk2 = dk.^2;
	s = d.*dk.*(n-1);
	stat.M1 = stat.M1 + dk;
	m2 = stat.M2;
	m3 = stat.M3;
	stat.M4 = stat.M4 + s.*dk2.*(n^2-3*n+3) + 6*dk2.*m2 - 4.*dk.*m3;
	stat.M3 = m3 + s.*dk.*(n-2) - 3.*dk.*m2;
	stat.M2 = m2 + s;
	
else	% Not optimized, but easier to follow
	m1a = stat.M1;
	m2a = stat.M2;
	m3a = stat.M3;
	m4a = stat.M4;
	
	m1b = cast(mean(F, 3, 'default'), fpType);
	m2b = moment(cast(F,fpType), 2, 3);
	m3b = moment(cast(F,fpType), 3, 3);
	m4b = moment(cast(F,fpType), 4, 3);
	
	d = bsxfun(@minus, m1b , m1a);
	stat.M1 = bsxfun(@plus, m1a , bsxfun(@times, d, (nb/n))); % 				dk = d.*(Nb/N);
	stat.M2 = m2a  +  m2b  +  (d.^2).*(na*nb/n); % dk2 = (d.^2).*Na.*Nb./N
	stat.M3 = m3a  +  m3b  +  (d.^3).*(na*nb*(na-nb)/(n^2))  ...
		+  3*(na.*m2b - nb.*m2a).*d./n;
	stat.M4 = m4a  +  m4b  +  (d.^4).*((na*nb*(na-nb)^2)/(n^3))  ...
		+  6*(m2b.*na^2 + m2a.*nb.^2).*((d.^2)./(n^2))  ...
		+  4*(m3b.*na  -  m3a.*nb).*(d./n);
end


stat.N = n;




end