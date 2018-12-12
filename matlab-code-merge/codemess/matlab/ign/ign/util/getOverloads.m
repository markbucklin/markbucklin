function outputList = getOverloads(topic, onlyGetFirstOverload)

    outputList = {};
    
    if nargin < 2
       onlyGetFirstOverload = false; 
    end
    
    objectNameParts = regexp(topic,'(.*?)[./]?(\w*)$','tokens','once','emptymatch');
    
    objectPart = objectNameParts{1};
    methodPart = objectNameParts{2};

    overloadList = getListOfClassesWithOverload(methodPart);
    
    overloadList(strcmp(objectPart,overloadList)) = [];
        
    for i = 1:numel(overloadList)
        
        qualifiedName = getQualifiedName(overloadList{i}, methodPart);
        
        if ~isempty(qualifiedName)
            outputList{end+1} = qualifiedName; %#ok<AGROW>
            
            if onlyGetFirstOverload
               break; 
            end
        end
    end

    if numel(outputList) > 1
        [~, sortedIndex] = sort(lower(outputList));
        outputList = outputList(sortedIndex);
    end
end

function classNames = getListOfClassesWithOverload(topic)

    classNames = {};
    
    callerImports = builtin('_toolboxCallerImports');
    cellfun(@import, callerImports);

    [overloadPath, overloadComment] = which(topic, '-all');
    
    if numel(overloadComment) < 2
       return; 
    end
        
    isValidOverload = cellfun(@isValidOverloadRule, overloadPath, overloadComment);

    overloadComment = overloadComment(isValidOverload);
    
    qualifier = regexp(overloadComment,'(?<qualifier>[\w.]+)\smethod','names','once');
    qualifier = [qualifier{:}];
    
    if ~isempty(qualifier)
        classNames = {qualifier.qualifier};
        classNames = unique(classNames);
    end
end

function isValid = isValidOverloadRule(path, comment)
    [~, ~, ext] = fileparts(path);
    isValid = ~isempty(ext) && ~strcmp(ext,'.p') && ~isempty(comment) && ~strcmp(comment, 'Shadowed');
end

function [qualifiedName] = getQualifiedName(qualifiedName, fcnName)

    [sep, isHidden] = getMCOSSeperator(qualifiedName, fcnName);
    
    if isHidden   
        qualifiedName = '';
    else
        if isempty(sep)
            sep = getUDDSeperator(qualifiedName, fcnName);
        end

        if isempty(sep)
            sep = '/';
        end

        qualifiedName = [qualifiedName sep fcnName];
    end
end

function [sep, isHidden] = getMCOSSeperator(qualifiedName, fcnName)

    sep      = '';
    isHidden = false;

    try %#ok<TRYNC>
        classInfo = meta.class.fromName(qualifiedName);

        if ~isempty(classInfo)
            methodMatch = strcmp({classInfo.MethodList.Name},fcnName);
            methodInfo  = classInfo.MethodList(methodMatch);

            if ~isempty(methodInfo)
                isHidden = classInfo.Hidden || all([methodInfo.Hidden]);

                if all([methodInfo.Static])
                    sep = '.';
                else
                    sep = '/';
                end
            end
        end
    end
 end

function sep = getUDDSeperator(qualifiedName, fcnName)

    sep = '';

    parts = strsplit(qualifiedName,'.');

    if numel(parts) == 2
        package = findpackage(parts{1});
        for class = package.Classes'
            if strcmp(parts{2}, class.Name)
                for method = class.Methods'
                    if strcmp(fcnName, method.Name)
                        if strcmp(method.Static,'off')
                            sep = '/';
                        else
                            sep = '.';
                        end
                        return;
                    end
                end
            end
        end
    end       
end