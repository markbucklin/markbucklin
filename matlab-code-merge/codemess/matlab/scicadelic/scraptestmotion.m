function [Uxy, UxyTest, UxyDif, mot] = scraptestmotion(F, MC)

N = 32;
F = oncpu(F(:,:,ceil(size(F,3)*rand(1))));
if nargin < 2
	MC = scicadelic.MotionCorrector;
	MC.CorrectionInfoOutputPort = true;
end


% for k=N:-1:1, frxy(:,:,k) = gather(uint16(imfilter(F, fspecial('motion',double(rPix(k))+eps,double(rTheta(k)))))); end

% CREATE SHIFTED TEST SET
ux = round(exp(randn(N,1)) - exp(randn(N,1)) + 10*sin(linspace(0, 2*pi*N/15, N)' + pi*rand(1)));
uy = round(exp(randn(N,1)) - exp(randn(N,1)) + 10*sin(linspace(0, 2*pi*N/15, N)' + pi*rand(1)));
ux = ux - ux(1);
uy = uy - uy(1);

for k=N:-1:1
	Ftest(:,:,k) = circshift(circshift(F,ux(k),2), uy(k),1);
end
fCorrect = ongpu(F);


idx = 0;
while idx(end) < N
	idx = idx(end) + (1:16);
	idx = idx(idx<=N);
	
	f = gpuArray(Ftest(:,:,idx));
	
	[fOut, motionInfo(k)] = step(MC, f);
	for k=1:numel(idx)
		imcomposite(fOut(:,:,k), f(:,:,k), fCorrect);
		% 		pause(.02)
		drawnow
	end
	
end

mot = unifyStructArray(motionInfo);
Uxy = [mot.uy mot.ux];
UxyDif = [mot.uy+uy , mot.ux+ux];
UxyTest = [uy ux];
release(MC)