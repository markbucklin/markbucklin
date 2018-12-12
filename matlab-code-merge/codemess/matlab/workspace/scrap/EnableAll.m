classdef EnableAll < extmgr.AbstractEnableConstraint
    %ENABLEALL Define the EnableAll extension constraint.
    %   The EnableAll constraint forces all extensions of its type to be
    %   enabled at all times.
    
    %   Author(s): J. Schickler
    %   Copyright 2007-2010 The MathWorks, Inc.
    
    methods
        function this = EnableAll(type)
            %ENABLEALL Construct an EnableAll constraint.
            
            % mlock keeps the instantiation of this class from throwing a warning when
            % the clear classes command is issued
            mlock
            
            this@extmgr.AbstractEnableConstraint(type);
        end
        
        function vdb = findViolations(this, hSystem)
            %FINDVIOLATIONS Find type constraint violation.
            
           
            % All extensions of this type should be enabled
            type = this.Type;
            hDisabled = findChild(hSystem.ConfigurationSet, 'Type', type, 'Enable', false);
            if isempty(hDisabled)
                vdb = [];
            else
                vdb = extmgr.TypeConstraintViolationSet;
                
                % Format the details.
                for indx = 1:length(hDisabled)
                    details = uiscopes.message('TextDetailExtensionNotEnabled', ...
                        type, hDisabled(indx).Name);
                    vdb.add(type, class(this), details);
                end
            end
        end
        
        function impose(this, hSystem)
            %IMPOSE   Impose the type constraint on the configuration.
            
            % Make sure that these all exist.
            createShallowConfigurations(hSystem, this.Type);
            
            % Enable all extensions of this type
            allConfigs = hSystem.ConfigurationSet.Children;
            hConfig = allConfigs(strcmp({allConfigs.Type}, this.Type));
            [hConfig.Enable] = deal(true);
        end
        
        function b = isEnableAll(this, hConfigDb) %#ok
            %ISENABLEALL True if the object is EnableAll
            
            b = true;
        end
    end
end

% [EOF]
