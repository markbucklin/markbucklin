function drivesAvail = findDriveSizeAvailable()


%TODO: ispc, islinux, etc.

drivesAvail = struct.empty();

driveNum = 0;
k=0;
while k < 26
	k=k+1;
	driveLetter = char(64+k);
	[driveStat, driveStr] = system(sprintf('dir %s:\\',driveLetter));
	if driveStat == 0
		driveNum = driveNum + 1;
		[c,~] = textscan(driveStr, '%s', 'Delimiter','\n');
		c = c{1};
		lastLine = c{end};
		[c,~] = textscan(lastLine, '%*f %*s %s bytes free');
		c = c{1};
		bytesFreeStr = c{1};
		numBytes = str2double(bytesFreeStr);
		% 						  bytesFreeVec = str2num(bytesFreeStr);
		% 						  multiplierVec = 2 .^ (10*fliplr(0:(numel(bytesFreeVec)-1)));
		% 						  numBytes = sum( bytesFreeVec .* multiplierVec);
		numGigaBytes = round(numBytes / 2^30);
		dirList = dir(sprintf('%s:\\',driveLetter));
		
		drivesAvail(driveNum).driveLetter = driveLetter;
		drivesAvail(driveNum).gbAvailable = numGigaBytes;
		drivesAvail(driveNum).dirList = dirList;
	end
	
end