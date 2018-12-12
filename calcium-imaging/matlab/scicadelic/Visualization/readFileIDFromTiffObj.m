function [fid] = readFileIDFromTiffObj(tiffObj)

tiffStruct = struct(tiffObj);
fid = tiffStruct.FileID;