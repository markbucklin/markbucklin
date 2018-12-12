classdef Chainable
    %CHAINABLE Derivable class providing chainable method behavior
    %   Implements javascript-like chainable method behavior
	% 
	% Mark Bucklin - 2017
    
    properties
        MethodList
        UnderlyingType
        MethodHandle = {}
        MethodAnonymousHandle = {}
        Input
        Value
        Output
    end
    
    methods
        function obj = Chainable( wrappedObj )
            %CHAINABLE Construct an instance of this class
            %   Detailed explanation goes here
            
            %             mc = meta.class.fromName('Chainable');
            
            % todo: cache list results for speed
            
            warning('off','MATLAB:structOnObject');
            if nargin < 1
                mc = metaclass(obj);
            else
                mc = metaclass(wrappedObj);
                obj.Value = wrappedObj;
            end
            list = findobj(mc.MethodList, 'DefiningClass', mc);
            publicMask = strcmp( 'public', {list.Access});
            nondefaultMask = ~strcmp('empty', {list.Name});
            nonconstructorMask = ~strcmp(mc.Name, {list.Name});
            list = list(publicMask & nondefaultMask & nonconstructorMask);
            obj.MethodList = struct(list);
            className = mc.Name;
            obj.UnderlyingType = className;
            
        end
        
        function obj = callChainedMethod(obj,methodName, inputArg)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            
            
        end
        function srout = subsref(obj, srin)
            fcn = @() obj.Value;
            name = '';
            k = 0;
            while k < numel(srin)
                k = k + 1;
                switch srin(k).type
                    case '()'
                        if ~isempty(name)
                            priorFcn = fcn;                            
                            if isempty(srin(k).subs)
                                fcn = @() feval( str2func(name), priorFcn());
                            else
                                fcn = @() feval( str2func(name), priorFcn(), srin(k).subs{:});
                            end
                            name = '';
                        end
                    case '{}'
                        disp(name)
                    case '.' % Function Call
                        name = srin(k).subs;
                end
                
                
                
                %                 % show for debug
                %                 fprintf('\n[%d]\n\ttype: %s \n\tsubs: ', k, srin(k).type);
                %                 if isempty(srin(k).subs)
                %                     fprintf('\n');
                %                 else
                %                     disp(srin(k).subs);
                %                 end
            end
            
            % Call Stacked Function
            srout = fcn();
            
            
            %             srout = builtin('subsref', obj, srin);
        end
        function srout = subsasgn(obj, srin)
            fcn = @() obj.Value;
            k = 0;
            while k < numel(srin)
                k = k + 1;
                fprintf('\n[%d]\n\ttype: %s \n\tsubs: ', k, srin(k).type);
                if isempty(srin(k).subs)
                    fprintf('\n');
                else
                    disp(srin(k).subs);
                end
                
            end
            srout = [];
            %             srout = builtin('subsasgn', obj, srin);
        end
    end
end





%             k = numel(list);
%             while (k ~= 0)
%                 methodName = list(k).Name;
%                 hdl = eval( sprintf('@%s@%s', methodName, mc.Name));
%                 obj.MethodHandle{k} = hdl;
%                 % hdl = evalin('caller', sprintf('@%s',name));
%                 %                 if list(k).Static
%                 %                     %anonhdl = evalin('caller', sprintf('@(varargin) %s(varargin{:})',methodName));
%                 %                 else
%                 %                     %anonhdl = evalin('caller', sprintf('@(obj, varargin) %s(obj,varargin{:})',methodName));
%                 %                 end
%                 %                 obj.MethodAnonymousHandle{k} = anonhdl;
%                 k = k - 1;
%             end




%                         methodMask = strcmp( srin(k).subs, {obj.MethodList.Name});
%                         if nnz(methodMask) == 0
%                             srout = builtin('subsref',obj, srin);
%                         else
%                             keyboard
%                         end