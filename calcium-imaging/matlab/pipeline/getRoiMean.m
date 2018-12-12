function roi = getRoiMean(F0)
% 
% filename = 'R1.tif';
% info = imfinfo(filename);
% nFrames = numel(info);
% for k = 1:nFrames
%     im(k).image = imread(filename,k);
% end
% R1 = cat(4,im(:).image);
% R1 = double(squeeze(R1(:,:,1,:)));
% 
% % GET dF/F0
% F0 = double(max(R1,[],3));
% for k = 1:nFrames
%     dFoverF(k).im = (F0 - R1(:,:,k))./F0;
% end
% dfoverf = cat(3,dFoverF(:).im);

F0 = squeeze(F0);
N = size(F0,ndims(F0));


waitfor(msgbox('Select a Region of Interest by clicking the image to mark polygon vertices'));
doAnotherRoi = 'yes';
k = 0;
imagesc(range(F0,ndims(F0)));
hAx = gca;
   set(hAx, 'Position',[.025 .025 .95 .95], 'XTick',[], 'YTick',[],...
	  'Box','off', 'PlotBoxAspectRatio', [1 1 1]);
while(strcmpi(doAnotherRoi,'yes'))
   k = k +1;
   roi(k).poly = impoly(hAx);
   roi(k).mask = roi(k).poly.createMask;
   roi(k).sum = sum(roi(k).mask(:));
   roi(k).vertices = roi(k).poly.getPosition;
   doAnotherRoi = questdlg('Do Another?');
end
close(gcf)
nRoi = k;

for k=1:nRoi
roi(k).mean = sum(sum( bsxfun(@times, F0,cast(roi(k).mask,'like',F0)) ,1),2) ./ roi(k).sum;
roi(k).mean = roi(k).mean(:);
end



subplot(2,1,1)
hAx = handle(gca);
hLine = plot(hAx, cat(2, roi.mean), 'LineWidth', 1);
title('ROI Mean')
xlabel('Frames')



% FIGURES
try	
   subplot(2,1,2)
   hIm = imagesc(mean(F0,3));
   title('Regions Of Interest (ROI) Overlaid on F_0')   
   hAx = gca;
   set(hAx, 'Position',[.025 .005 .95 .475], 'XTick',[], 'YTick',[],...
	  'Box','off', 'PlotBoxAspectRatio', [1 1 1]);
   colormap gray
   for k = 1:nRoi
	  x = roi(k).vertices(:,1);
	  y = roi(k).vertices(:,2);
	  c = hLine(k).Color;
	  roi(k).patch = patch(x,y, c);	  
	  roi(k).line = hLine(k);
   end
   set([roi.patch], 'FaceAlpha',.5, 'EdgeAlpha',.7)
catch
   disp('fusion failure')
end




