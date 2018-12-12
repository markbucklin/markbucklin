


runsfcn = @(fcn,s) cell2struct( cellfun( fcn, struct2cell(s), 'uniformoutput',false), fields(s) )


ifelsefcn = @(cond, truefcn, falsefcn) feval( @(n,cfcn) feval(cfcn{n}), double(~cond)+1, {truefcn,falsefcn});
ifelsefcn( true, @()fprintf('true function\n'), @()fprintf('false function\n'))
%ifelsefcn( true, {@(n)fprintf('true function %d\n',n), 5}, {@(n)fprintf('false function %d\n',n), 6})



evalEachFcn = @(varargin) cellfun( @(fcn) ifelsefcn(iscell(fcn), feval(fcn{:}), feval(fcn)), varargin , 'UniformOutput', false);
fevalNumoutFcn = @(fcn,varargin) 

