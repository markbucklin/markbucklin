function [files, filesizes] = pathLookupLocal(dirOrFile, includeSubfolders)
%PATHLOOKUPLOCAL Get file names and sizes resolved for a local input path.
%   FILES = pathLookup(PATH) returns the fully resolved file names for the
%   local or network path specified in PATH. This happens non-recursively
%   by default i.e. we do not look under subfolders while resolving. PATH
%   can be a single string denoting a path to a file or a folder. The path
%   can include wildcards.
%
%   FILES = pathLookup(PATH, INCLUDESUBFOLDERS) returns the fully resolved
%   file names for the local or network path specified in PATH taking
%   INCLUDESUBFOLDERS into account.
%   1) If a path refers to a single file, that file is added to the output.
%   2) If a path refers to a folder
%          i) all files in the specified folder are added to the output.
%         ii) if INCLUDESUBFOLDERS is false, subfolders are ignored.
%        iii) if INCLUDESUBFOLDERS is true, all files in all subfolders are
%             added.
%   3) If path refers to a wild card:
%          i) all files matching the pattern are added.
%         ii) if INCLUDESUBFOLDERS is false, folders that match the pattern
%              are looked up just for files.
%        iii) if INCLUDESUBFOLDERS is true, an error is thrown.
%
%   [FILES,FILESIZES] = pathLookupLocal(...) also returns the file sizes
%   for the resolved paths as an array of double values.
%
%   See also matlab.io.datastore.internal.pathLookup

%   Copyright 2015, The MathWorks, Inc.

persistent fileseparator;
if isempty(fileseparator)
    fileseparator = filesep;
end
if ischar(dirOrFile)
    [files, filesizes] = getFilesInDir(dirOrFile);
else
    error(message('MATLAB:datastoreio:pathlookup:invalidFilesInput'));
end
files = files(:);
filesizes = filesizes(:);

    function noFilesError(pth)
        error(message('MATLAB:datastoreio:pathlookup:fileNotFound',pth));
    end

    % Remove '.' and '..' from the directory listing
    function listing = removeDots(listing)
        idx = strcmp('.',listing) | strcmp('..',listing);
        listing(idx) = [];
    end

    function [files, filesizes] = getRecursiveListing(dirStruct, isfiles, pathStr, oneLevel)
        files = {};
        filesizes = [];
        dirList = removeDots({dirStruct(~isfiles).name});
        dirList = strcat(pathStr, fileseparator, dirList);
        while ~isempty(dirList)
            currentList = dirList;
            dirList = {};
            for ii = 1:length(currentList)
                currentDir = currentList{ii};
                currentDirStruct = dir(currentDir);
                currentIsfiles = not([currentDirStruct.isdir]);
                currentListing = strcat(currentDir, fileseparator, {currentDirStruct(currentIsfiles).name});
                files = [files, currentListing];
                filesizes = [filesizes, currentDirStruct(currentIsfiles).bytes];
                if ~oneLevel
                    currentDirList = removeDots({currentDirStruct(~currentIsfiles).name});
                    if ~isempty(currentDirList)
                        dirList = [dirList, strcat(currentDir, fileseparator, currentDirList)];
                    end
                end
            end
        end
    end

    function [files, filesizes] = getfullfiles(dof, pathStr, iswildcard)
        files = {};
        filesizes = [];
        if iswildcard && includeSubfolders
            error(message('MATLAB:datastoreio:pathlookup:wildCardWithIncludeSubfolders', dof));
        end
        dirStruct = dir(dof);
        if ~isempty(dirStruct)
            additionalListing = {};
            additionalFileSizes = [];
            isfiles = not([dirStruct.isdir]);
            listing = {dirStruct(isfiles).name};
            if iswildcard
                % A wildcard on folders is provided.
                % Lookup onelevel down in to the wildcard matching folders.
                [additionalListing, additionalFileSizes] = ...
                    getRecursiveListing(dirStruct, isfiles, pathStr, true);
            elseif includeSubfolders
                [additionalListing, additionalFileSizes] = ...
                    getRecursiveListing(dirStruct, isfiles, pathStr, false);
            end
            listing = strcat(pathStr, fileseparator, listing);
            files = [listing, additionalListing];
            filesizes = [dirStruct(isfiles).bytes, additionalFileSizes];
        elseif iswildcard
            noFilesError(dof);
        end
    end

    function pathStr = getAbsolutePath(pathStr)
        [exists, info] = fileattrib(pathStr);
        if exists
            pathStr = info.Name;
            return;
        end
        noFilesError(pathStr);
    end

    function [pathStr, iswildcard] = getParentPathStr(dof)
        % get parent folder name
        [pathStr, name, ext] = fileparts(dof);
        pathStr = getAbsolutePath(pathStr);
        if nargout == 2
            iswildcard = containsWildcard({name, ext});
        end
    end

    function iswildcard = containsWildcard(stringValues)
        iswildcard = false;
        for ii = 1:numel(stringValues)
            value = stringValues{ii};
            if ~isempty(value) && any(strfind(value, '*'))
                iswildcard = true;
                return;
            end
        end
    end

    function [files, filesizes] = getFilesInDir(dof)
        isexist = exist(dof, 'file');
        files = {};
        filesizes = [];
        switch isexist
            case 7
                % input is a directory
                pathStr = getAbsolutePath(dof);
                [files, filesizes] = getfullfiles(dof, pathStr, false);
                % throw empty folder error, and dont rely on check outside the switchyard
                if isempty(files), error(message('MATLAB:datastoreio:pathlookup:emptyFolder',dof)); end

            case 0
                % input might contain * wildcard extension eg., 'myfolder/*.csv'
                [pathStr, iswildcard] = getParentPathStr(dof);
                [files, filesizes] = getfullfiles(dof, pathStr, iswildcard);

            case 2
                % input is just a single file.
                % we want fully resolved paths, even for single files
                parentDir = getParentPathStr(dof);
                [files, filesizes] = getfullfiles(dof, parentDir, false);

                if isempty(files)% try to look it up as a partial path
                    files = which('-all',dof);
                    if numel(files) >= 1% reduce to one file if many
                        files = files(1);
                        dirStruct = dir(files{1});
                        filesizes = dirStruct.bytes;
                    end
                end
        end

        if isempty(files)
            noFilesError(dof);
        end

    end

end
