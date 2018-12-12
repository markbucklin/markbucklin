f = dir('*.tif')
f = f(~[f.isdir])
funkyFileBytes = [f.bytes]
fprintf('%d\n', uint64([f.bytes]))
bytesPerFrame = (2 * 2^20)
fileBytes = [f.bytes]
fixedFileBytes = fix( fileBytes ./ bytesPerFrame) .* bytesPerFrame
fprintf('%d\n', uint64(fixedFileBytes))