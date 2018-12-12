load('Processed_ROIs_Ali15-20140820-Devalue1_2014_11_11_2157.mat')
bhv = loadBehaviorData;
bhvc = colorRoiWithBehaviorCorr(R,bhv);
lags = (-12*20:12*20)/20;
longshort = bhvc.long-bhvc.short;
% SORTING INDICES
[~,longidx] = sort(mean(bhvc.long,1));
[~,shortidx] = sort(mean(bhvc.short,1));
[~,longshortidx] = sort(mean(bhvc.long - bhvc.short,1));
subplot(1,3,1), imagesc([],lags,bhvc.long(:,longidx)), title('long')
subplot(1,3,2), imagesc([],lags,bhvc.short(:,shortidx)), title('short')
subplot(1,3,3), imagesc([],lags,longshort(:,longshortidx)), title('long - short')


