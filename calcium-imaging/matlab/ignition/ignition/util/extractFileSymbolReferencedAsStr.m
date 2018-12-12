function result = extractFileSymbolReferencedAsStr(file)
% Prototype for auto-detection of files referenced as strings in m-code.

    result = struct([]);
    
    % A list of frequently used file reading functions and their default file extension.
    fcn_list = mostFrequentlyUsedFileReadingTools();
    
    mt = matlab.depfun.internal.cacheMtree(file);
    
    for k = keys(fcn_list)
        fcn_name = k{1};
        fcn_nodes = mtfind(mt, 'Kind', 'ID', 'String', fcn_name);
        if ~isempty(fcn_nodes)
            fcn_node_ids = indices(fcn_nodes);
            for n = 1:numel(fcn_node_ids)
                right_node = Right(trueparent(select(mt, fcn_node_ids(n))));
                if ~isempty(right_node)                    
                    right_node_kind = kind(right_node);

                    sym = '';
                    if strcmp(right_node_kind, 'STRING')
                        % Find directly referenced files
                        string_node = right_node;
                        direct_str = string(string_node);
                        [sym, w] = checkFileSymbol(direct_str, fcn_list(fcn_name));                    
                    elseif strcmp(right_node_kind, 'ID')
                        % Find indirectly referenced files
                        nid = indices(mtfind(mt, 'Kind', 'EQUALS', ...
                            'Left.Kind', 'ID', 'Left.String', string(right_node)));                        
                        if ~isempty(nid)
                            string_node = Right(select(mt,nid(end)));
                            if ~isempty(string_node) && strcmp(kind(string_node), 'STRING')
                                indirect_str = string(string_node);
                                [sym, w] = checkFileSymbol(indirect_str, fcn_list(fcn_name));
                            end
                        end
                    end

                    if ~isempty(sym)
                        result(end+1).file = file; %#ok
                        result(end).lineno = lineno(string_node); 
                        result(end).symbol = sym;
                        result(end).path = w;                    
                        result(end).exp = tree2str(trueparent(select(mt, fcn_node_ids(n))),0,true);
                    end
                end
            end
        end
    end
    
    % Sort result based on the line number
    if ~isempty(result)
        [~,idx] = sort([result.lineno]);
        result = result(idx);
    end
end

function [sym, w] = checkFileSymbol(str, default_ext)
    sym = '';
    w = '';
    
    if ~isempty(str)
        if str(1)=='''' && str(end)==''''
            str = str(2:end-1);
        end

        if matlab.depfun.internal.cacheExist(str,'file')
            sym = str;
        elseif ~isempty(default_ext)
            for t = 1:numel(default_ext)
                str_with_default_ext = [str default_ext{t}];
                if matlab.depfun.internal.cacheExist(str_with_default_ext, 'file')
                    sym = str_with_default_ext;
                end
            end
        end
        
        % Convert symbol to file full path.
        if ~isempty(sym)
            w = matlab.depfun.internal.cacheWhich(sym);            
            if isempty(w)
                % Try one more thing for WHICH
                w = matlab.depfun.internal.cacheWhich([sym '.']);
            end
        end
    end
end    
