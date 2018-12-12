function  showCrop(imfull,ySubs,xSubs)
im = imfull; 
im(ySubs,xSubs) = im(ySubs,xSubs)+mean2(im);
h = imshowpair(imfull,im);

