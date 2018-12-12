function im = frame2uint8(iminput)

fmin = min(iminput(:));
frange = max(iminput(:)) - fmin;
iminput = iminput - fmin;
im = im2uint8(iminput.*(255/frange));

% switch class(iminput)
% 	case 'double'
% 		im = uint8(iminput.*(255/frange));
% 	case 'single'
% 		im = uint8(iminput.*(single(intmax('uint8'))/frange));
% 	case 'uint16'
% 		im = uint8(iminput.*(uint16(intmax('uint8'))/frange));
% 	case 'uint8'
% 		im = uint8(iminput.*(uint8(intmax('uint8'))/frange));
% 	otherwise
% 		keyboard
% end




% %% back to int16
% fmin = min(vid(1).cdata(:));
% frange = max(vid(1).cdata(:)) - fmin;
% s = cat(3,vid.cdata) - fmin;
% s(s<0) = 0;
% s = int16(s.*(single(intmax('int16')*.5)/frange));
% for k = 1:numel(vid)
% 	vid(k).cdata = s(:,:,k);
% end