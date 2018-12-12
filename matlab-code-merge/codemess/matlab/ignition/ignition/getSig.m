function sig = getSig(fcn)
% GETSIG Retrieves the signature of a function/class.
% Returns a structure analogous to mcrFunctionSignature.

    sig = struct('vhInputs', {}, 'vhOutputs', {}, 'bVarargin', {}, 'bVarargout', {}, 'bScript', {}, 'hFuncname', {}, 'hClassname', {}, 'pragma', {}, 'vhGlobals', {});

    [p, name] = fileparts(fcn);
    % Naming convention from parser/interpreter: argument kind ('i' or 'o')
    % followed by a 0-based index, i.e. i0, i1... o0, o1...
    inStr = {'i', 'in'};
    outStr = {'o', 'out'};
    
    function list = argList(kind, count)
        if count < 0
            list = cell(1, -count);
            for k = 1:numel(list)-1
                list{k} = sprintf('%s%d', char(kind(1)), k-1);
            end
            list{-count} = sprintf('vararg%s', char(kind(2)));
        else
            list = cell(1,count);
            for k = 1:numel(list)
                list{k} = sprintf('%s%d', char(kind(1)), k-1);
            end
        end
    end
    if(exist(name) == 5 && exist(name, 'file') == 0) % built-in 
        nIn = nargin(name);
        nOut = nargout(name);
        sig(1).vhInputs = argList(inStr, nIn);
        sig(1).vhOutputs = argList(outStr, nOut);
        sig(1).bVarargin = nIn < 0; 
        sig(1).bVarargout = nOut < 0; 
        sig(1).bScript = false;
        sig(1).hFuncname = name;
        sig(1).hClassname = {};
        sig(1).pragma = 0;
        sig(1).vhGlobals = {};
        return;
    end
    savePath = path;
    if(~isempty(p))    
        path(p, path); % so that "which" can find it when it is not in the current folder
    end 
    whichFcn = which(fcn);
    if(~isempty(whichFcn))
        fcn = whichFcn;
    end
    existReturn = exist(fcn);
    
    switch existReturn
        case 3 % MEX-file 
            sig(1).vhInputs = {'varargin'};
            sig(1).vhOutputs = {'varargout'};
            sig(1).bVarargin = true;
            sig(1).bVarargout = true;
            sig(1).bScript = false;
            sig(1).hFuncname = name;       
            sig(1).hClassname = {};
            sig(1).pragma = 0;
            sig(1).vhGlobals = {};
            path(savePath);
            return;
         case 6 % P-file 
            isScript = false;
            ins = {};
            outs = {};
            try           
                nIn = nargin(name);
            catch
                isScript = true;
            end
            if(isScript)
                sig(1).vhInputs = {};
                sig(1).vhOutputs = {};
                sig(1).bVarargin = false;
                sig(1).bVarargout = false;
                sig(1).bScript = true;
                sig(1).hFuncname = name;
                sig(1).hClassname = {};
                sig(1).pragma = 0;
                sig(1).vhGlobals = {};
            else
                nOut = nargout(name);
       
                sig(1).vhInputs = argList(inStr, nIn);
                sig(1).vhOutputs = argList(outStr, nOut);
                sig(1).bVarargin = nIn < 0;
                sig(1).bVarargout = nOut < 0;
                sig(1).bScript = false;
                sig(1).hFuncname = name;
                sig(1).hClassname = {};
                sig(1).pragma = 0;
                sig(1).vhGlobals = {};
            end
            path(savePath);
            return;
    end
   
    mt = mtree(fcn, '-file');
    myRoot = mt.root;
    
    switch myRoot.kind
        case 'CLASSDEF'
            sig(1).vhInputs = {'varargin'};
            sig(1).vhOutputs = {'varargout'};
            sig(1).bVarargin = true;
            sig(1).bVarargout = true;
            sig(1).bScript = false;
            if(strcmp(myRoot.Cexpr.kind, 'LT')) 
                % class derivation
                sig(1).hFuncname = myRoot.Cexpr.Left.string;
            else
                sig(1).hFuncname = myRoot.Cexpr.string;
            end
  %          sig(1).hFuncname = name;
            sig(1).hClassname = sig(1).hFuncname;
            sig(1).pragma = 0;
            sig(1).vhGlobals = {};
         case 'FUNCTION'
            mt = mtree(fcn, '-file', '-com');

            % top level functions
            fncs = indices(mtfind(List(root(mt)), 'Kind', 'FUNCTION'));
            events = [];
            externals = [];
            % find pragmas
            for i = mt.indices
                   n = mt.select(i);
                   if(ismember(i, fncs))
                       currFunc = i;
                       continue;
                   end
                   if(exist('currFunc', 'var') && strcmp(n.kind, 'COMMENT'))
                       if(strcmp(n.string, '%#event') && ~ismember(currFunc, externals))
                            events(end + 1) = currFunc;
                       end
                       if(strcmp(n.string, '%#external') && ~ismember(currFunc, events))
                            externals(end + 1) = currFunc;
                       end
                   end
            end
         
            for fncInd = fncs
                if(ismember(fncInd, externals))
                    p = 1;
                elseif(ismember(fncInd, events))
                    p = 2;
                else
                    p = 0;
                end
                if(fncInd == fncs(1)) % main function
                    temp = makeFuncSig(mt.select(fncInd), p);
                    temp.hFuncname = name;
                    sig(end + 1) = temp;
                elseif(p > 0)
                    sig(end + 1) = makeFuncSig(mt.select(fncInd), p); 
                end
            end
    
        otherwise 
            % script
            sig(1).vhInputs = {};
            sig(1).vhOutputs = {};
            sig(1).bVarargin = false;
            sig(1).bVarargout = false;
            sig(1).bScript = true;
            sig(1).hFuncname = name;
            sig(1).hClassname = {};
            sig(1).pragma = 0;
            sig(1).vhGlobals = listGlobals(mt);
    end
    path(savePath);
end

function funcSig = makeFuncSig(node, pragma)
    if(~strcmp(node.kind, 'FUNCTION'))
        funcSig = [];
        return;
    end
    funcSig.vhInputs = listIns(node);
    funcSig.vhOutputs = strings(List(node.Outs));
    funcSig.bVarargin = ~isempty(funcSig.vhInputs) && strcmp(funcSig.vhInputs(end), 'varargin');
    funcSig.bVarargout = ~isempty(funcSig.vhOutputs) && strcmp(funcSig.vhOutputs(end), 'varargout');
    funcSig.bScript = false;
    funcSig.hFuncname = node.Fname.string;
    funcSig.hClassname = {};
    
    funcSig.pragma = pragma;
   
     funcSig.vhGlobals = listGlobals(node.Body);
end
function ins = listIns(node)
    ins = {};
    curr = node.Ins;
    tildeCount = 0;
    tildeBase = 75; % hex2dec('4b');
    while ~curr.isnull
        if(strcmp(kind(curr), 'NOT')) % tilde
            ins{end + 1} = sprintf('%%U%x', tildeBase + tildeCount);
            tildeCount = tildeCount + 1;
        else
            ins{end + 1} = curr.string;
        end
        curr = curr.Next;
    end
end
function globals = listGlobals(node)
    l = List(node);
    
    globals = {};

    g = mtfind(l.Tree, 'Kind', 'GLOBAL');

    for i = g.indices
        n = g.select(i);
        globals{end + 1} = string(n.Arg);
    end
end
 
