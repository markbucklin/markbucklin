%%
a = arduino

%%
dev = spidev(a,'D4', 'Mode', 3, 'BitOrder', 'msbfirst', 'Bitrate', 2000000);

%%
readMask = uint8(hex2dec('7f'));
motRegAddr = uint8(hex2dec('02'));
writeRead(dev, bitand(readMask, motRegAddr), 'uint8')
motRegOut = writeRead(dev, uint8(0), 'uint8');
for k=1:4
deltaXYOut(k) = writeRead(dev, bitand(readMask, (motRegAddr+1)));
end
disp(deltaXYOut)