function vid = scaleIntStructVid(vid)

N = numel(vid);
inputDataType = class(vid(1).cdata);
inputRange = [min(min( cat(1,vid.cdata), [],1), [],2) , max(max( cat(1,vid.cdata), [],1), [],2)];
scaleFactor = getrangefromclass(vid(1).cdata);
scaleFactor = scaleFactor(2);


for k=1:numel(vid)
  im = double(vid(k).cdata);
  im = im.*(scaleFactor/double(inputRange(2)));
  vid(k).cdata = uint16(im); %todo
end
  
