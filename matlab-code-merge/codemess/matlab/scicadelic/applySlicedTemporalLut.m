function bw = applySlicedTemporalLut(bw, tlut)
[nrow,ncol,nk] = size(bw);
npx = nrow*ncol;
vslice = reshape( bw, npx, nk);
hslice = reshape( permute(bw, [2 1 3 4]), npx, nk);
vslice = reshape( bwlookup( vslice, tlut), nrow, ncol, nk); %addchannels
hslice = reshape( bwlookup( hslice, tlut), ncol, nrow, nk); %addchannels
bw = vslice | permute(hslice, [2 1 3 4]);

end