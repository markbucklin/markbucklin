classdef TypeConstraintViolationSet < extmgr.AbstractSet
    %TypeConstraintViolationSet Define the TypeConstraintViolationSet class.
    
    %   Copyright 2012 The MathWorks, Inc.
    
    methods
        
        function this = TypeConstraintViolationSet(varargin)
            %TypeConstraintViolationSet   Construct the
            %TypeConstraintViolationSet class.
            if nargin > 0
                add(this, varargin{:});
            end
        end
        
        function add(this, arg, varargin)
            %ADD Add violations to database.
            %  ADD(hVDb,V) adds TypeConstraintViolation object V to violations
            %  database.  V is copied before being added.
            %
            %  ADD(hVDb,hVDb2) adds all violations in database hVDb2 to database by
            %  making copies of each violation and adding them individually to hVDb.
                        
            if isa(arg,'extmgr.TypeConstraintViolationSet')
                % Add a database of violations (arg is hVDb2)
                for v = arg.Children
                    add(this,v);
                end
            elseif ischar(arg) || isa(arg, 'extmgr.TypeConstraintViolation')
                add@extmgr.AbstractSet(this, arg, varargin{:});
            else
                error(message('Spcuilib:extmgr:ErrorUnsupportedArgument', class( arg )));
            end
        end
        
        function msgs = messages(this)
            %MESSAGES Return formatted violation messages.
            
            msgs = ''; % state persists in nested function below
            
            hViolation = this.Children;
            
            N = numel(hViolation);
            if N > 0
                if N > 1
                    msgs = sprintf('%d %s\n', N, uiscopes.message('TextConfigurationViolationsFound'));
                else
                    msgs = sprintf('%d %s\n', N, uiscopes.message('TextConfigurationViolationFound'));
                end
                for violation = hViolation
                    msgs = [msgs message(violation)]; %#ok
                end
            end
        end
    end
    methods (Access = protected, Static)
        function childClass = getChildClass
            childClass = 'extmgr.TypeConstraintViolation';
        end
    end
end

% [EOF]
