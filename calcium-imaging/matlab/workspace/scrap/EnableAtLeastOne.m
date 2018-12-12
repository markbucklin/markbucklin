classdef EnableAtLeastOne < extmgr.AbstractEnableConstraint
    %ENABLEATLEASTONE Define the EnableAtLeastOne extension constraint.
    %   The EnableAtLeastOne constraint forces at least one extension to be
    %   enabled at all times.
    
    %   Author(s): J. Schickler
    %   Copyright 2007-2011 The MathWorks, Inc.
    
    methods
        function this = EnableAtLeastOne(type)
            % mlock keeps the instantiation of this class from throwing a warning when
            % the clear classes command is issued
            mlock;
            
            this@extmgr.AbstractEnableConstraint(type);
        end
        
        function vdb = findViolations(this, hSystem)
            %FINDVIOLATIONS   Find type constraint violations
            
            
            nEnabled = length(findobj(hSystem.ConfigurationSet.Children, 'Type', this.Type, 'Enable', true));
            
            % Make sure that there is at least 1 extension enabled.
            if nEnabled < 1
                details = uiscopes.message('TextDetailNoEnabledExtensions', ...
                    nEnabled, this.Type);
                vdb = extmgr.TypeConstraintViolationSet;
                vdb.add(this.Type, class(this), details);
            else
                vdb = [];
            end
        end
        
        function impose(this, hSystem)
            %IMPOSE   Impose the constraint on the configuration.
            
            % If there are no enabled configurations of the type, enable
            % the first one.
            hConfigDb = hSystem.ConfigurationSet;
            hConfig = hConfigDb.Children;
            if ~isempty(hConfig)
                hConfig = hConfig([hConfig.Enable]);
                allTypes = {hConfig.Type};
                hConfig = hConfig(strcmp(allTypes, this.Type));
            end
            
            if isempty(hConfig)
                hConfig = hConfigDb.Children;
                if ~isempty(hConfig)
                    allTypes = {hConfig.Type};
                    hConfig = hConfig(strcmp(allTypes, this.Type));
                end
                
                % If there are no configurations for this type, try to
                % create them from the registers.
                if isempty(hConfig)
                    hRegisters  = findVisibleRegistrations(hSystem, this.Type);
                    
                    % If there are no visible registrations, just use the
                    % first of the invisible.
                    if isempty(hRegisters)
                        hRegisters = findHiddenRegistrations(hSystem, this.Type);
                    end
                    
                    % If there are no invisible registrations either, this
                    % is an error condition.
                    if isempty(hRegisters)
                        error(message('Spcuilib:extmgr:ImposeViolationNoRegisters', class(this), this.Type));
                    end
                    
                    % Add the first registration found to the configuration
                    % database so that we can enable it.
                    hConfig = createShallowConfig(hRegisters(1));
                    hConfigDb.add(hConfig);
                    hConfig.Enable = true;
                else
                    for indx = 1:numel(hConfig)
                        if hConfig(indx).Registration.Visible
                            hConfig(indx).Enable = true;
                            return;
                        end
                    end
                    if ~isempty(hConfig)
                        hConfig(1).Enable = true;
                    end
                end
            end
        end
        
        function b = isEnableAll(this, hConfigDb)
            %ISENABLEALL True if the object is EnableAll
            
            % If there is only 1 extension of this type, then it must
            % always be enabled.
            b = length(hConfigDb.findConfig(this.Type)) == 1;
        end
        
        function b = willViolateIfDisabled(this, hSystem, hConfig)
            %WILLVIOLATEIFDISABLED Returns true if disabling the extension
            %   will cause a violation.
            
            % If the passed configuration is enabled
            if hConfig.Enable
                hEnab = hSystem.ConfigurationSet.findChild('Type', this.Type, 'Enable', true);
                b = length(hEnab) < 2;
            else
                b = false;
            end
        end
        
        function tableValueChanged(this, hSystem, hDlg, row, newValue)
            %TABLEVALUECHANGED React to table value changes.
            
            % If we are enabling, then we do not need to check anything, return early.
            if newValue == 1
                return
            end
            
            % If there are now no entries enabled, do not allow the current action.
            if this.getTableEnables(hSystem, hDlg) + ...
                    this.getHiddenEnableCount(hSystem) == 0
                hDlg.setTableItemValue([this.Type '_table'], row, 0, '1');
            end
        end
        
        function varargout = validate(this, hSystem, hDlg)
            %VALIDATE Returns true if this object is valid
            
            enaCnt = this.getTableEnables(hSystem, hDlg) + ...
                getHiddenEnableCount(this, hSystem);
            success = (enaCnt > 0);
            exception = MException.empty;
            if ~success
                id = 'Spcuilib:extmgr:AtLeastOneConstraintViolation';
                exception = MException(id, getString(message(id, this.Type)));
            end
            
            if nargout
                varargout = {success, exception};
            elseif ~success
                throw(exception)
            end
        end
    end
end

% [EOF]
