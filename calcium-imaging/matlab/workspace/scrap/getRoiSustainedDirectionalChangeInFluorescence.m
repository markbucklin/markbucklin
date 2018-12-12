function Xrsoc = getRoiSustainedDirectionalChangeInFluorescence(R, alpha)
warning('getRoiSustainedDirectionalChangeInFluorescence.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')

if nargin < 2
	alpha = .99;
end

X = [R.Trace];
[~,Xt] = gradient(X);
Xrsoc = Xt;
[numFrames, numRoi] = size(Xrsoc);
fAbsSmooth = zeros(1,numRoi);

for k=1:numFrames;
	% 	Xrsoc(k,:) = ...
	% 		(Xt(k,:)+Xt(min(k+1,N),:)) ...
	% 		./ (abs(Xt(max(1,k-2),:))+abs(Xt(max(1,k-1),:)));
	
	fForward = Xt(k,:) ...
		+ Xt(min(k+1,numFrames),:) ...
		+ Xt(min(k+2,numFrames),:);
	fAbsBackward = ...
		abs(Xt(max(1,k-3),:))...
		+ abs(Xt(max(1,k-2),:))...
		+ abs(Xt(max(1,k-1),:));
	if alpha > 0
		a = min(1-1/k, alpha);
		fAbsSmooth = a.*fAbsSmooth + (1-a).*fAbsBackward;
		fAbsNorm = fAbsSmooth;
	else
		fAbsNorm = fAbsBackward;
	end
	
	Xrsoc(k,:) = ...
		fForward ...
		./ fAbsNorm;
	
end





try
	N = min(numRoi, 150);
	plot(bsxfun(@plus, 10.*(1:N), Xrsoc(:,randi([1,size(Xrsoc,2)],N,1))));
	ylim([0 N*10]), xlim([0 size(Xrsoc,1)])
	
catch
	
end
