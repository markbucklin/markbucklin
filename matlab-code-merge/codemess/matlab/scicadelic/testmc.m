
release(MC)
clear MC
MC = scicadelic.RigidMotionCorrector;
clear mdata
data = step(CE, step(TL));
% mdata(:,:,1:2:15) = data;
mdata = repmat(data, 1, 1, 4);
for n=1:3
	for k=1:8
		if mod(k,2)
			imshift = -2*n;
		else
			imshift = 2*n;
		end
		mdata(:,:,n*8+k) = circshift(circshift(mdata(:,:,k), imshift, 1), imshift, 2);
	end
end
tic
[mcdata, info] = step(MC, mdata);
toc
% for k=1:8:25
% 	disp([info.ux(k+(0:7)), info.uy(k+(0:7))])
% 	fprintf('\n')
% end

ux = reshape(info.ux,8,[])
uy = reshape(info.uy,8,[])

uxc = bsxfun(@minus, ux, ux(:,1))
uyc = bsxfun(@minus, uy, uy(:,1))