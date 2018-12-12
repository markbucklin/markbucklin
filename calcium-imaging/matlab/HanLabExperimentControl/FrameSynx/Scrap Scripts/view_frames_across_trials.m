for n = -5:15 
imaqmontage(...
		 double(obj.redData(:,:,:,stim2on(1:min([length(stim2on),length(stim3on)])) + n)) ...
		 ./ double(obj.redData(:,:,:,stim3on(1:min([length(stim3on),length(stim2on)])) + n)),...
		 [0 2])
 title(sprintf('Red Frames - Stimulus Difference (Stim-Trigger Offset: %i)',n))
 pause
end
for n = -5:15 
imaqmontage(...
		 double(obj.greenData(:,:,:,stim2on(1:min([length(stim2on),length(stim3on)])) + n)) ...
		 ./ double(obj.greenData(:,:,:,stim3on(1:min([length(stim3on),length(stim2on)])) + n)),...
		 [0 2])
 title(sprintf('Green Frames - Stimulus Difference (Stim-Trigger Offset: %i)',n))
 pause
end
close