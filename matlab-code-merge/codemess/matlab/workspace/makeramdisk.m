
% WIP
% make a ramdisk for temporary data storage with fast read/write access

if isunix()
    !sudo mkdir /mnt/ramdisk
    !sudo chmod 777 /mnt/ramdisk
    !sudo mount -t tmpfs -o size=32g myramdisk /mnt/ramdisk
elseif ispc()
    % TODO: use imdisk program
else
    % TODO: mac
end