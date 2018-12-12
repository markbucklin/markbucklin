function im = frame2uint16(iminput)

fmin = min(iminput(:));
frange = max(iminput(:)) - fmin;
iminput = iminput - fmin;
im = im2uint16(iminput.*(65535/frange));