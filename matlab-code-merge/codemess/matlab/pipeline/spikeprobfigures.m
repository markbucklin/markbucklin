% JOINT PROBABILITY WITH SOUND
histogram(jointx.sound.all)
hold on
histogram(jointx.sound.long)
histogram(jointx.sound.short)
title('Joint Probability Distributions of Neural Activity with Stimulus Conditions')
legend('All','Long','Short')
xlabel('Joint Probability of Positive Activity with Sound')
ylabel('Number of ROIs (neurons)')


roicol(:,3) = abs(PXIs2 - PXIs1) < .01;
roicol(:,2) = ((PXIs2 - PXIs1) >= .01)' & ~roicol(:,3);
roicol(:,1) = ((PXIs2 - PXIs1) <= -.01)' & ~roicol(:,3);
roicol = bsxfun(@times, double(roicol), pnormalize(abs(.5-PXIS)'));
for k=1:numel(R), R(k).Color = roicol(k,:); end



% hscat = scatter(jointx.sound.all, jointx.sound.firstsecond,'.');
hscat = scatter(jointx.sound.long, jointx.sound.short,'.');
hline = line([0 1], [0 1],'Parent',gca);
xlim([.1 .2]);
ylim([.1 .2]);
