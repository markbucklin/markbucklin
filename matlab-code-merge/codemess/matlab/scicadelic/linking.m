

N = numel(Rcell);
hWait = waitbar(0,'processing time');
for kFrame = 1:N-1
	tStart = hat;
	
	
	Rcurrent = Rcell{kFrame};
	Rnext = Rcell{kFrame+1};
	
	OV = overlaps(Rcurrent, Rnext);
	
	for k = 1:numel(Rcurrent)
		R = Rcurrent(k);
		ov = OV(k,:);
		% 		ov = overlaps(R, Rnext);
		linkToNext(R, Rnext(ov));
	end
	
	
	
	t = hat - tStart;
	fprintf('Frame: %i     Processing-time: %-03.3g s/frame\n',kFrame, t)
% 	t = hat - tStart;
% 	waitbar(kFrame/N, hWait, sprintf('processing time: %-03.3g ms/frame',t));
end





% bigamists = Rnext(sum(ov,1) == 2);
% 	polygamists = Rnext(sum(ov,1) > 2);
% 	virgins = Rnext(sum(ov,1) < 1);
% 	
% 
% 
% 	monogamousMale = sum(uint16(ov),2) == 1;
% 	for kFrame=1:numel(monogamousMale)
% 		if monogamousMale(kFrame)
% 			linkToNext(Rcurrent(kFrame), Rnext(ov(kFrame,:)));
% 		end
% 	end
% 	monogamousFemale = sum(ov,1) == 1;
	