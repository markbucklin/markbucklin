



%% NET
asm = NET.addAssembly('mscorlib')
nfo = System.IO.FileInfo([pwd,filesep,'localPeakPointer.m'])
nfo.CreationTime.ToString






%% or JAVA

import java.nio.file.*
import java.nio.file.attribute.*

fs = FileSystems.getDefault()
d.ig = dir(pwd)
d.pathstr = pwd


% while k<=numel(d.ig),
% if ~(d.ig(k).isdir),
% d.det(k).javapath = fs.getPath( d.pathstr, d.ig(k).name);
% %d.det(k).javareader = Files.newBufferedReader( d.det(k).javapath);
% end
% k = k+1;
% end

path = fs.getPath( d.pathstr, d.ig(k).name);
path = d.det(k).javapath
path.getFileName
file = path.toFile()
file.getFreeSpace
file.getUsableSpace
file.getName
file.lastModified

%attrs = Files.readAttributes( path, BasicFileAttributes.class)
%attrs = Files.readAttributes( file, BasicFileAttributes.class)