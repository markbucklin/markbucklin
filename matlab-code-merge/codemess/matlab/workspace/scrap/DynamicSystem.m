classdef DynamicSystem < extmgr.System
    %Manager   Define the System class.
    
    %   Copyright 2012 The MathWorks, Inc.
    %   $Revision: 1.1.2.8 $  $Date: 2014/05/08 20:11:39 $
    
    properties (SetAccess = private, Hidden)
        ExtensionSet;
        RegistrationSet;
    end
    
    properties (Access = private)
        
        ExtensionDbChildListeners;
        ConfigEnableChangedListener;
        MessageLogBeingShownListener;
    end
    
    properties (SetAccess = private, Hidden, Dependent)
        ExtensionDb;
        RegisterDb;
    end
    
    methods
        function this = DynamicSystem(hApplication, extFile, regName, varargin)
            %System   Construct the System class.
            
            mlock;
            this.Application = hApplication;
            if numel(varargin) > 0 && isa(varargin{end}, 'uiservices.MessageLog')
                this.MessageLog = varargin{end};
                varargin(end) = [];
            end
            
            if isempty(extFile)
                return;
            end
            
            % Create registration database.
            % RegisterLib creates its own MessageLog, as it is a "singleton"
            % library service and maintains its own, session-persistent state.
            hRegisterLib = extmgr.Library.Instance;
            
            % Link RegisterLib's (global/singleton) message log to Driver's message log
            % so we see the RegisterLib messages, and any messages from child
            % RegisterDb's.  Note that Driver's log is generally the same log for the
            % application instance as well, so by indirection, all of RegisterLib's
            % messages will be seen by the application message log.
            %
            % (Messages from this and ExtensionDb also show up there, by simple
            % "direct connection" of the handle, performed below.)
            hMessageLog = this.MessageLog;
            
            if ~isempty(hMessageLog)
                this.MessageLogBeingShownListener = event.listener(this.MessageLog, ...
                    'DialogBeingShown', @(~,~) dialogBeingShownCallback(this));
            end
            
            % Get registration database from global registration library manager
            %
            % This will either register extensions of this file name (i.e., a lot of
            % loading work is done, with possible messages thrown), or quickly return
            % the previously-cached database.
            hRegisterDb = hRegisterLib.getRegistrationSet(extFile, regName);
            this.RegistrationSet = hRegisterDb;
            
            if numel(varargin) > 0
                configSetLoaded = loadConfigSet(this, varargin{:});
            else
                configSetLoaded = false;
            end
            
            if configSetLoaded
                hConfigDb = this.ConfigurationSet;
            else
                % If there was nothing loaded, then we need to make our own ConfigDb
                hConfigDb = extmgr.ConfigurationSet;
                hConfigDb.AllowConfigEnableChangedEvent = false;
                this.ConfigurationSet = hConfigDb;
                
                % Impose register type constraints, such as EnableAll or EnableOne.
                imposeTypeConstraints(this);
            end
            
            % Create (empty) instance database object
            % Pass reference to Driver's message log to ExtensionDb
            % (Could be an empty handle - meaning no log)
            %
            % Note that this is coordinated in a simpler and different way from the
            % RegisterLib message log.  Here, ExtensionDb simply posts all messages to
            % the same log that Driver maintains.  However, RegisterLib has its own -
            % because it's a global/singleton instance.  So for that situation, we
            % allow the two logs to coexist and we link them together.
            this.ExtensionSet = extmgr.ExtensionSet(hRegisterDb, hConfigDb, ...
                this.Application, hMessageLog);
            
            % Setup listener on EnabledChanged event from individual Config objects,
            % via ConfigEnableChanged event on ConfigDb.
            %
            % NOTE: ev.Data holds hConfig whose enable property was changed
            this.ConfigEnableChangedListener = ...
                event.listener(hConfigDb, 'ConfigEnableChanged', ...
                @(hConfigDb,ev) process(this,ev.Data));
            
            % If the file has an extension, use that one as the default
            % extension for the driver.
            [~, ~, ext] = fileparts(this.LastAccessedFile);
            if ~isempty(ext)
                this.FileExtension = ext(2:end);
            end
            
            hConfigDb.AllowConfigEnableChangedEvent = true;
            
            % Create all of the enabled extensions.
            processAll(this);
        end
        
        function b = processNext(~)
            
            % Do nothing.
            b = true;
        end
        
        function renderWidgets(this)
            renderWidgets(this.ExtensionSet);
        end
        
        function renderMenus(this)
            renderMenus(this.ExtensionSet);
        end

        function renderToolbars(this)
            renderToolbars(this.ExtensionSet);
        end

        function l = createExtensionListener(this, callback)
            eSet = this.ExtensionSet;
            l = event.proplistener(eSet, eSet.findprop('Children'), 'PostSet', callback);
        end
        
        function createShallowConfigurations(this, varargin)
            createShallowConfigs(this.RegistrationSet, this.ConfigurationSet, varargin{:});
        end
        
        function disp(this)
            disp@handle(this);
            disp('Enabled extensions');
            
            for config = this.ConfigurationSet.Children
                if config.Enable
                    fprintf('    %s:%s\n', config.Type, config.Name);
                end
            end
            if strcmpi(get(0, 'FormatSpacing'), 'loose')
                disp(' ');
            end
        end
        
        function enableExtension(this, type, name)
            
            % see if it already is present in the config
            allConfigs = this.ConfigurationSet.Children;
            hC = allConfigs(strcmp({allConfigs.Type}, type) & strcmp({allConfigs.Name}, name));
            
            % if not then this is an older config
            % enable measurements by default if it is registered
            allRegisters = this.RegisterDb.Children;
            hR = allRegisters(strcmp({allRegisters.Type}, type) & strcmp({allRegisters.Name}, name));
            if ~isempty(hR)
                if isempty(hC)
                    this.ConfigurationSet.add(type, name);
                    hC = this.ConfigurationSet.findConfig(type, name);
                    hC.Registration = hR;
                end
                
                % throw event to install
                hC.Enable = true;
            end
        end
        
        function [success, varargout] = fevalOnExtension(this, type, name, fcn, nonfcn)
            % Try to find the extension
            hExtension = getExtension(this.ExtensionSet, type, name);
            if isempty(hExtension)
                success = false;
                
                % If there is no extension, but outputs were requested,
                if nargin == 5
                    [varargout{1:nargout-1}] = nonfcn();
                elseif nargout > 1
                    varargout = repmat({[]}, 1, nargout-1);
                end
            else
                
                % Run the function on the extension.
                [varargout{1:nargout-1}] = fcn(hExtension);
                success = true;
            end
        end
        
        function hRegisters = findHiddenRegistrations(this, type)
            hRegisters = findobj(this.RegistrationSet.Children, 'Type', type, 'Visible', false);
        end
        
        function hRegister = findRegistration(this, varargin)
            hRegister = findRegistration(this.RegistrationSet, varargin{:});
        end
        
        function type = findType(this, typeTag)
            type = findType(this.RegistrationSet.TypeDescriptionSet, typeTag);
        end
        
        function hRegisters = findVisibleRegistrations(this, type)
            %FINDVISIBLEREGISTERS Return all visible registers for the type.
            
            % Only show the visible extensions.
            hRegisters = findobj(this.RegistrationSet.Children, 'Type', type, ...
                'Visible', true);
            
            % If we've specified no HiddenExtensions, then return early.
            hiddenExtensions = this.HiddenExtensions;
            if isempty(hiddenExtensions)
                return;
            end
            
            % If any of the hidden extensions match the type exactly we want to hide
            % all the non-enabled
            if any(strcmp(type, hiddenExtensions))
                hConfigs = findobj(this.ConfigurationSet.Children, 'Type', type, 'Enable', true);
                hEnabRegisters = cell(numel(hConfigs), 1);
                for indx = 1:numel(hConfigs)
                    hEnabRegisters{indx} = findobj(hRegisters, 'Name', hConfigs(indx).Name);
                end
                hRegisters = [hEnabRegisters{:}];
            else
                % Loop over all the Registers and remove any that match the
                % HiddenExtensions values.
                indx = 1;
                while indx <= length(hRegisters)
                    if any(strcmp(hRegisters(indx).FullName, hiddenExtensions))
                        hRegisters(indx) = [];
                    else
                        indx = indx+1;
                    end
                end
            end
        end
        
        function hc = getAllConfigurations(this)
            hc = [this.ExtensionSet.Children.Configuration];
        end
        
        function he = getAllExtensions(this)
            he = this.ExtensionSet.Children;
        end
        
        function d = getAppData(this, varargin)
            d = getAppData(this.RegistrationSet, varargin{:});
        end
        
        function c = getConstraint(this, type)
            c = getConstraint(this.RegisterDb.TypeDescriptionSet, type);
        end
        
        function hExtension = getExtension(this,varargin)
            %GETEXTENSION Return handle to extension instance.
            %   getExtension(H,TYPE,NAME) returns handle to the extension specified by
            %   TYPE and NAME strings.
            %
            %   getExtension(H,HREG) specifies the TYPE and NAME via the Register
            %   object HREG.
            %
            %   Returns empty if no extension with matching type/name is found.
            
            hExtension = getExtension(this.ExtensionSet, varargin{:});
        end
        
        function stn = getSortedTypeNames(this)
            stn = this.RegistrationSet.SortedTypeNames;
        end
        
        function y = hasOptions(this)
            % Returns false if all the constraints are EnableAll and getPropsSchema is
            % empty for all extensions.
            
            if isEnableAll(this)
                hEDb = this.ExtensionDb;
                y = false;
                for hExt = hEDb.Children;
                    if ~isempty(feval(hExt.Register, 'getPropsSchema', hExt.Config, []));
                        y = true;
                        break;
                    end
                end
            else
                y = true;
            end
        end
        
        function b = isRegistered(this, type, name)
            b = ~isempty(this.RegistrationSet.findChild('Type', type, 'Name', name));
        end
        
        function [loaded, cfgFile] = loadConfigSet(this, varargin)
            %LOADCONFIGSET Load extension configuration properties.
            %   LOADCONFIGSET(H) opens a dialog to chose where to load a file
            %   containing a configuration set and then loads the configuration set.
            %
            %   LOADCONFIGSET(H, FNAME) loads the configuration set specified by FNAME.
            
            % Loads a ConfigurationSet database, not a ScopeCfg
            % We don't recall scope position, docking, etc, in a config set
            % (That's the business of an instrument set!)
            
            if isempty(this.ConfigurationSet)
                oldEnableState = false;
            else
                oldEnableState = this.ConfigurationSet.AllowConfigEnableChangedEvent;
            end
            
            [loaded, cfgFile] = loadConfigSet@extmgr.System(this, varargin{:});
            
            % React to any enabled extension configurations only if the Allow flag was
            % set to true when we entered this function.
            if oldEnableState
                processAll(this);
            end
        end
        
        function process(this, hConfig, varargin)
            %PROCESS Process one extension configuration enable state.
            %   process(hDriver, hConfig) process a single configuration's enable
            %   state, including property merging and extension instantiation.  This
            %   method is called by the listener to the ConfigEnableChanged event.
            
            % Find registration for extension that has changed enable state
            hRegister = hConfig.Registration;
            if isempty(hRegister)
                % Registration info not found
                
                % Throw a message and disable extension
                local_RegNotFoundErrMsg(this,hConfig);
                hConfig.Enable = false;
                errorIfConstraintViolation(this);
                
                % We refresh dialog if open, so don't return early
            else
                % Registration info found
                %
                if hConfig.Enable
                    % Extension enabled
                    if isempty(getExtension(this.ExtensionSet, hRegister))
                        
                        % Add the extension to the database.
                        add(this.ExtensionSet, hRegister, hConfig, varargin{:});
                    end
                    
                    % Even when there's an error, we still want to update the
                    % property dialog ... say, to remove a bogus extension.
                    % So don't return early!
                else
                    % Disable extension
                    
                    % Extension was just disabled
                    % Remove from instance list, if present.
                    if nargin < 3
                        checkDependencyViolation(this);
                    end
                    remove(this.ExtensionSet, hRegister);
                end
            end
            
            % Update preferences dialog to reflect any changes in enable state,
            % additional property dialog tabs, etc, but only if dialog is open.
            %
            editConfigSet(this,false); % don't create new dialog; update only, look
            % into doing this with listeners
        end
        
        function processAll(this)
            %processAll Process extension configuration enable states.
            %   processAll(hDriver) reacts to the enable-state of each extension
            %   configuration in the config database, including property merging and
            %   extension instantiation.
            %
            %   This is a manual-scan of enable states across the current configuration
            %   database.
            %
            %   Note that we might attempt to enable an extension that fails to execute
            %   properly, and corrective actions include disabling it and posting a
            %   message.
            
            % Sort configurations by registration order and dependencies
            %
            sort(this.ConfigurationSet, this.RegistrationSet);
            
            % Check for violations in overall config set
            % process() below will not generally check overall config violations
            % It only checks config if an extension must be disabled due to an error
            errorIfConstraintViolation(this);
            
            checkDependencyViolation(this);
            
            % Visit each config in the database and process it individually.  Postpone
            % rendering until we have every extension loaded.  Process disabled first
            % so they are removed before adding new extensions.
            hDisabled = findobj(this.ConfigurationSet.Children, 'Enable', false);
            for indx = 1:length(hDisabled)
                process(this, hDisabled(indx), false);
            end
            hEnabled = findobj(this.ConfigurationSet.Children, 'Enable', true);
            for indx = 1:length(hEnabled)
                process(this, hEnabled(indx), false);
            end
            
            % Render the GUI.  Extensions may have added information to UIMgr and we
            % have suppressed all rendering by passing process the false argument.
            hGUI = getGUI(this.Application);
            if ~isempty(hGUI) && hGUI.IsRendered
                render(hGUI);
            end
        end
        
        function delete(this)
            delete(this.ExtensionSet);
        end
        
        function extDb = get.ExtensionDb(this)
            extDb = this.ExtensionSet;
        end
        
        function regDb = get.RegisterDb(this)
            regDb = this.RegistrationSet;
        end
    end
    
    methods (Access = protected)
        function imposeTypeConstraints(this)
            %IMPOSETYPECONSTRAINTS Enforce extension type constraints.
            %   IMPOSETYPECONSTRAINTS(H) applies extension type constraint to
            %   extension configurations.  Extensions may need to be enabled or
            %   disabled in order to achieve constraint.
            %
            %   Events are suppressed when changing enable-properties in order to
            %   impose constraints without continuous updates.  processAll is called to
            %   keep the extensions up to date at the end of the method only if the
            %   AllowConfigEnableChangedEvent is set to true when this method is
            %   called.
            %
            %   See RegisterType for details on type constraints.
            
            % Get database of registered extension types
            % Note that not all extension types are registered, only those for which a
            % client has generally set optional attributes, such as a constraint.
            hRegisterTypeDb = this.RegistrationSet.TypeDescriptionSet;
            
            % If there are no registered types, there is nothing to impose.
            if isEmpty(hRegisterTypeDb)
                return;
            end
            
            hConfigDb = this.ConfigurationSet;
            
            % We "turn off" enable-property change detection prior to touching the
            % enable properties.  We don't want to initiate the process of adding
            % extensions due to enable/disable at this time.  We do this uniformly for
            % all extensions later, when processAll() is called as an iterator.
            oldEnableState = hConfigDb.AllowConfigEnableChangedEvent;
            hConfigDb.AllowConfigEnableChangedEvent = false;
            
            % Visit each registered RegisterType to implement constraint
            for h = hRegisterTypeDb.Children
                impose(h.Constraint, this);
            end
            
            % Re-enable event that broadcasts changes to the Enable property
            hConfigDb.AllowConfigEnableChangedEvent = oldEnableState;
            
            % Force an update here, only if the Allow flag was set to true when we
            % entered this function.  If it is false, then the caller would not expect
            % extensions to be created/destroyed until it calls processAll explicitly.
            if oldEnableState
                processAll(this);
            end
        end
    end
end

function errorIfConstraintViolation(this)
%ERRORIFCONSTRAINTVIOLATION Throw error if there is a constraint violation.

vdb = [];
% Visit each registered RegisterType to check for constraint violations
for h = this.RegistrationSet.TypeDescriptionSet.Children
    vio = h.Constraint.findViolations(this);
    if ~isempty(vio)
        if isempty(vdb)
            vdb = extmgr.TypeConstraintViolationSet;
        end
        vdb.add(vio);
    end
end

if ~isempty(vdb)
    % Rethrow extension type-constraint violations in current config set as
    % an error.
    error(message('Spcuilib:scopes:ErrorExtensionConstraintViolated',messages(vdb)));
end
end

% -------------------------------------------------------------------------
function local_RegNotFoundErrMsg(this,hConfig)
% Error occurred when attempting to find Register
% corresponding to Config instance.

hMessageLog = this.MessageLog;
% Send error to MessageLog
summary = 'Could not find extension registration.';
details=sprintf([ ...
    'Failed to find extension registration.<br>' ...
    '<ul>' ...
    '<li><b>Type:</b> %s<br>' ...
    '<li><b>Name:</b> %s<br>' ...
    '</ul>' ...
    '<b>Cannot enable this extension.</b><br>'], ...
    hConfig.Type, hConfig.Name);
if isempty(hMessageLog)
    warning('Spcuilib:extmgr:RegisterNotFound', 'Could not find registration for ''%s:%s''.', ...
        hConfig.Type, hConfig.Name);
else
    hMessageLog.add('Fail','Extension',summary,details);
end
end

% -------------------------------------------------------------------------
function checkDependencyViolation(this)

% If the configuration is not enabled, it cannot cause a dependency violation
allConfigs = this.ConfigurationSet.Children;
hConfigs   = allConfigs([allConfigs.Enable]);

hMsgLog = this.MessageLog;

allTypes = {allConfigs.Type};
allNames = {allConfigs.Name};

for indx = 1:numel(hConfigs)
    
    hRegister = hConfigs(indx).Registration;
    
    % Loop over and check each dependency.
    d = hRegister.Depends;
    for jndx = 1:length(d)
        [dependType, dependName] = strtok(d{jndx}, ':');
        dependName(1) = [];
        hConfigDepend =  allConfigs(strcmp(allTypes, dependType) & strcmp(allNames, dependName));
        if isempty(hConfigDepend)
            hConfigs(indx).Enable = false;
            process(this, hConfigs(indx), false);
            details = sprintf('Assert: Invalid dependency %s.', hRegister.Depends{jndx});
            if isempty(hMsgLog)
                warning('Spcuilib:extmgr:InvalidDependency', details); %#ok<SPWRN>
            else
                hMsgLog.add('fail', 'Registration', ...
                    'Invalid dependency', details);
            end
        elseif ~hConfigDepend.Enable
            hConfigs(indx).Enable = false;
            process(this, hConfigs(indx), false);
            details = sprintf('Cannot enable "%s:%s" unless "%s" is enabled.', ...
                hRegister.Type, hRegister.Name, hRegister.Depends{jndx});
            if isempty(hMsgLog)
                warning('Spcuilib:extmgr:DependencyViolation', details); %#ok<SPWRN>
            else
                hMsgLog.add('warn', 'Configuration', ...
                    'Dependency violated', details);
            end
        end
    end
end
end


% -------------------------------------------------------------------------
function dialogBeingShownCallback(this)

hRegisterLib = extmgr.Library.Instance;

this.MessageLog.LinkedLogs = hRegisterLib.MessageLog;
end
% [EOF]
