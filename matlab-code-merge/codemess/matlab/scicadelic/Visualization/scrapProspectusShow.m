
seedMap = obj.RegisteredRegionSeedIdxMap;
statMap = obj.DetectedRegionPixelStatistics;
psbw2 = (statMap.SeedProbability > .1);
psbw = (statMap.SeedProbability > .4);
sbw = cat(3, psbw & ~bwSeed, psbw2 & ~psbw & ~bwSeed, bwSeed);

graybg1 = abs(real(statMap.MeanCentroidDist));
graybg2 = abs(real(statMap.MeanBoundaryDist));

graybg1 = abs(statMap.MeanBoundaryDist);
graybg2 = abs(statMap.MeanCentroidDist);
imcomposite( sbw , graybg1, graybg2)
title('Seed-Map (RED) with Seed-Probability Thresholded at 0.4 (GREEN) and 0.1 (BLUE) overlaying Normalized-Mean-Centroi-Dist (GRAY-BG)')
