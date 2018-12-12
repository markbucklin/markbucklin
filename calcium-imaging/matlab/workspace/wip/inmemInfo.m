
[mem.m, mem.mex, mem.c] = inmem('-completenames');

mfcn = cellfun(@getLoadedInfo, mem.m)



function fcn = getLoadedInfo(cstr)
warning('off', 'MATLAB:str2func:invalidFunctionName')
str = string(cstr);
%% Get matlab reference
[m.dir,m.base,m.ext] = fileparts(str);
prefix = m.dir;
ispkg = prefix.contains('+');
isclass = prefix.contains('@');
if ispkg || isclass
    if ispkg
        prefix = prefix.extractAfter("/+").replace("/+",".");
        prebase = ".";
    else
        prefix = prefix.extractAfter("/@");
        prebase = "/";
    end
    
    if isclass        
        prefix = prefix.replace("/@",".");
        prebase = "/";
    end
else
    prefix = "";
    prebase = "";
%     fcn.str = m.base;
end
fcn.str = prefix + prebase + m.base;


%% Make Function Handle
try
    fcn.handle = str2func(fcn.str);
catch
    fcn.handle = eval("@" + fcn.str);
end

%% Get Help text
fcn.help = help(fcn.str);
fcn.functions = functions(fcn.handle);

end
