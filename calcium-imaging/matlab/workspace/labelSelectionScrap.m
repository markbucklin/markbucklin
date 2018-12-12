%%
pl = structfun( @oncpu, struct(pp.pl),'UniformOutput',false);
size(midsizeIdx)
midsizeIdx = find( (pl.RegionArea > 40) & (pl.RegionArea < 400));

% pl.RegionSeedIdx(midsizeIdx)
L = pl.PrimaryRegionIdxMap;
% L(pl.RegionSeedIdx(midsizeIdx))

%%
imrc(pl.RegisteredRegionSeedIdxMap)
pl.RegisteredRegionSeedIdxMap(pl.RegionSeedIdx(midsizeIdx))
pl.PrimaryRegionIdxMap(pl.RegionSeedIdx(midsizeIdx))
pl.RegisteredRegionSeedIdxMap(pl.RegionSeedIdx(midsizeIdx))
nonzeros(pl.RegisteredRegionSeedIdxMap(pl.RegionSeedIdx(midsizeIdx)));
imrc(L)
imrc(pl.PrimaryRegionIdxMap)
nonzeros(pl.RegisteredRegionSeedIdxMap(pl.RegionSeedIdx(midsizeIdx)))
selectedLabels = nonzeros(pl.RegisteredRegionSeedIdxMap(pl.RegionSeedIdx(midsizeIdx)));
L = pl.PrimaryRegionIdxMap;
isSelected = any( L == reshape(selectedLabels,1,1,[]), 3);
L(~isSelected) = 0;

%%
imrc(L)
numel(selectedLabels)