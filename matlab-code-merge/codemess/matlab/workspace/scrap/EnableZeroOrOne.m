classdef EnableZeroOrOne < extmgr.AbstractEnableConstraint
    %ENABLEZEROORONE Define the EnableZeroOrOne extension constraint.
    %   The EnableZeroOrOne constraint prevents more than one extension of
    %   its type from being enabled at a time.

    %   Author(s): J. Schickler
    %   Copyright 2007-2010 The MathWorks, Inc.

    methods
        function this = EnableZeroOrOne(type)
            
            % MLOCK the file to hide it from clear classes
            mlock;
            
            this@extmgr.AbstractEnableConstraint(type);
        end

        function vdb = findViolations(this, hSystem)
            %FINDVIOLATIONS   Find type constraint violations.

            hConfigDb = hSystem.ConfigurationSet;
            c = hConfigDb.Children;
            c = c([c.Enable]);
            nEnabled = length(find(strcmp({c.Type}, this.Type)));
            if nEnabled > 1
                details = uiscopes.message('TextDetailNoEnabledExtensions', ...
                    nEnabled, this.Type);
                vdb = extmgr.TypeConstraintViolationSet;
                vdb.add(this.Type, class(this), details);
            else
                vdb = [];
            end
        end

        function impose(this, hSystem)
            %IMPOSE Impose the constraint on the configurations.

            hConfigDb = hSystem.ConfigurationSet;
            hConfig = hConfigDb.Children;
            hConfig = hConfig([hConfig.Enable]);
            hConfig = hConfig(strcmp({hConfig.Type}, this.Type));
            
            % If there is more than 1 enabled configuration of this type,
            % disable all but the first.
            if length(hConfig) > 1
                [hConfig(2:end).Enable] = deal(false); %#ok<NASGU>
            end
        end

        function tableValueChanged(this, hSystem, hDlg, row, newValue)
            %TABLEVALUECHANGED React to table value changes.

            % If we are unchecking a box, we do not need to do anything.
            if newValue

                hConfigDb = hSystem.ConfigurationSet;
                % Make sure that have no more than 1 extension enabled
                nType = length(findobj(hConfigDb.Children, 'Type', this.Type));

                % Loop over all extensions in the type and uncheck them unless
                % they are the extension that was just checked.  This will
                % allow the user to enable an extension without having to
                % disable the currently enabled extension.  If there is no
                % current extension, this is basically a no op because all of
                % the extensions are already disabled.
                for indx = 0:nType-1
                    if indx ~= row
                        hDlg.setTableItemValue([this.Type '_table'], indx, 0, '0');
                    end
                end
            end
        end
        
        function varargout = validate(this, hSystem, hDlg)
            %VALIDATE Returns true if this object is valid

            success = getTableEnables(this, hSystem, hDlg) + ...
                getHiddenEnableCount(this, hSystem) < 2;
            exception = MException.empty;
            if ~success
                id = 'Spcuilib:extmgr:ZeroOrOneConstraintViolation';
                exception = MException(id, ...
                    getString(message(id, this.Type)));
            end

            if nargout
                varargout = {success, exception};
            elseif ~success
                throw(exception);
            end
        end
    end
end

% [EOF]
