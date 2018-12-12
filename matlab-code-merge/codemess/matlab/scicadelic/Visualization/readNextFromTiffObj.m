function [data,idx] = readNextFromTiffObj(tiffObj)


tiffStruct = struct(tiffObj);
fid = tiffStruct.FileID;
if ~logical(fid)
   open(tiffObj)
end
tiffObj.nextDirectory
idx = tiffObj.currentDirectory;
data = read(tiffObj);