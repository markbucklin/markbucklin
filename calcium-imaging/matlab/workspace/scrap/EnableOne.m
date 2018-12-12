classdef EnableOne < extmgr.EnableAtLeastOne
    %ENABLEONE Define the EnableOne extension constraint.
    %   The EnableOne constraint forces one extension to be enabled and
    %   prevents more than one extension from being enabled.
    
    %   Author(s): J. Schickler
    %   Copyright 2007-2010 The MathWorks, Inc.
    
    methods
        
        function this = EnableOne(type)
            % mlock keeps the instantiation of this class from throwing a warning when
            % the clear classes command is issued
            mlock
            
            this@extmgr.EnableAtLeastOne(type);
        end
        
        function vdb = findViolations(this, hSystem)
            %FINDVIOLATIONS   Find type constraint violations
            
            % Only one extension of type can be on
            hConfigDb = hSystem.ConfigurationSet;
            c = hConfigDb.Children;
            c = c([c.Enable]);
            enableCnt = length(find(strcmp({c.Type}, this.Type)));
            
            if enableCnt == 1
                vdb = [];
            else % either 0, or 2 or more
                % Extension type-constraint "EnableOne" violated for extension
                % enableCnt indicates number
                details = uiscopes.message('TextDetailNoEnabledExtensions', ...
                    enableCnt, this.Type);
                vdb = extmgr.TypeConstraintViolationSet;
                vdb.add(this.Type, class(this), details);
            end
        end
        
        function impose(this, hSystem)
            %IMPOSE   Impose the type constraint on the configuration.
            
            hConfigDb = hSystem.ConfigurationSet;
            hConfig = hConfigDb.Children;
            if ~isempty(hConfig)
                hConfig = hConfig([hConfig.Enable]);
                hConfig = hConfig(strcmp({hConfig.Type}, this.Type));
            end
            
            if length(hConfig) > 1
                
                % If there are more than one extensions of this type
                % enabled, disable all after the first.
                [hConfig(2:end).Enable] = deal(false); %#ok<NASGU>
            elseif isempty(hConfig)
                
                impose@extmgr.EnableAtLeastOne(this, hSystem);
            end
        end
        
        function b = willViolateIfDisabled(this, hSystem, hConfig) %#ok API
            %WILLVIOLATEIFDISABLED Returns true if disabling this extension
            %   will violate the constraint.
            
            b = hConfig.Enable;
            
        end
        
        function tableValueChanged(this, hSystem, hDlg, row, newValue)
            %TABLEVALUECHANGED React to table value changes.
            
            % Make sure that we only have 1 extension enabled
            type  = this.Type;
            nType = length(findConfig(hSystem.ConfigurationSet, type));
            if newValue
                
                % If we are turning on the selected extension, disable all
                % the other ones.
                for indx = 0:nType-1
                    if indx ~= row && ...
                            strcmpi(hDlg.getTableItemValue([type '_table'],indx,0), '1')
                        hDlg.setTableItemValue([type '_table'], indx, 0, '0');
                    end
                end
            else
                
                % If we are turning off the selected extension, make sure
                % that there is still at least 1 (and only 1) extension
                % still enabled.
                nEnab = 0;
                for indx = 0:nType-1
                    nEnab = nEnab + str2double(hDlg.getTableItemValue([type '_table'], indx, 0));
                    if nEnab > 1
                        hDlg.setTableItemValue([type '_table'], indx, 0, '0');
                    end
                end
                if nEnab == 0
                    hDlg.setTableItemValue([type '_table'], row, 0, '1');
                end
            end
        end
        
        function varargout = validate(this, hSystem, hDlg)
            %VALIDATE Returns true if this object is valid
            
            % When there is a single extension of this type, we do not need
            % to bother checking for the checkboxes because they are not
            % rendered. g427202
            if numel(findConfig(hSystem.ConfigurationSet, this.Type)) < 2
                if nargout > 0
                    varargout = {true, '', ''};
                end
                return;
            end
            
            % only one config of this type should be enabled
            enaCnt = getTableEnables(this, hSystem, hDlg) + ...
                getHiddenEnableCount(this, hSystem);
            success = (enaCnt == 1);
            exception = MException.empty;
            if ~success
                id = 'Spcuilib:extmgr:OneConstraintViolation';
                exception = MException(id, getString(message(id, this.Type)));
            end
            
            if nargout > 0
                varargout = {success, exception};
            elseif ~success
                throw(exception);
            end
        end
    end
end

% [EOF]
