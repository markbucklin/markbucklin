



for k=1:8, viewStatePredictor([md(k).roi.Trace], md(k).xs), pause,print(gcf,fullfile(pwd,sprintf('Activation-State-Predictor (sample) Ali15 day %i',k)), '-dpng'), end
for k=1:8, [~,idx] = sort(binaryprob(md(k).xs)); imagesc(md(k).bhv.t./60, [],imfilter(double(md(k).xs(:,idx)'), fspecial('average',[1 120]))), axis xy, xlabel('time (minutes)'), ylabel('ROI'),title(sprintf('ROI Activity (filtered) Ali15 day %i',k)), pause, print(gcf,fullfile(pwd,sprintf('ROI Activity (filtered) Ali15 day %i',k)), '-dpng'), end
% for k=1:10, fteLag{k} = fastTE(Xs, Xs, k, 1); disp(k), end
for k=1:10, scatter(mean(fteLag{k},2), mean(fteLag{k}, 1),10,'filled'), xlim([0 .005]), ylim([0 .005]), pause, end