function R = fixPixCounts(R)

for k=1:numel(R)
   R(k).PixelCounts = round(double(R(k).PixelWeights)*numel(R(k).Frames)/255); 
   R(k).PixelWeights = double(R(k).PixelWeights)/255;
   R(k).NumberOfMerges = 1;
   R(k).isMerged = true;
end