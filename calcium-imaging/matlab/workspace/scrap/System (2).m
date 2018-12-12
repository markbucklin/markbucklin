classdef System < handle
    %System   Define the System class.
    
    %   Copyright 2013 The MathWorks, Inc.
    
    properties
        HiddenTypes = {};
        HiddenExtensions = {};
        FileExtension = 'cfg';
    end
    
    properties (SetAccess = protected, Hidden)
        ConfigurationDialog;
        ConfigurationSet;
        Application;
    end
    
    properties (SetAccess = protected)
        % We do NOT own this - it's a shared resource,
        % generally created by parent application (hAppInst)
        %
        % Optional handle to a MessageLog repository
        % If present, it is used for reporting messages
        % If not present, messages are ignored
        % (Note that RegisterDb's message log gets linked in to this log)
        MessageLog;
    end
    
    properties (Access = protected)
        % Store the full name to the last file loaded or saved.
        LastAccessedFile = '';
    end
    
    properties (Hidden, SetAccess = private, Dependent, Transient)
        ConfigDb;
    end
    
    methods
        function l = createExtensionListener(~, varargin)
            % Extensions cannot be added or removed.  When we support full
            % edit extension system this will have to be revisited.
            l = [];
        end
        
        function createShallowConfigurations(~, ~)
            % NO OP
        end
        
        function varargout = editConfigSet(this,varargin)
            %EDITCONFIGSET Open extension configuration properties dialog.
            %   EDITCONFIGSET(H) opens a new configuration dialog, or updates the
            %   existing dialog, based on current extension driver information.
            %
            %   EDITCONFIGSET(H, false) will not open a new dialog, but will attempt to
            %   update an existing one.
            
            hDlg = this.ConfigurationDialog;
            
            if isempty(hDlg)
                
                % If we are just updating the dialog and we don't have one
                % yet, just return early.
                if nargin > 1 && ~varargin{1} && nargout < 1
                    return
                end
                
                % Generate any missing configurations here.  This is done now as
                % opposed to init to avoid making configurations that are not needed.
                createShallowConfigurations(this);
                
                % Create dialog object
                hDlg = extmgr.ConfigurationDialog(this);
                
                hDlg.MessageLog       = this.MessageLog;
                
                this.ConfigurationDialog = hDlg;
            end
            
            hDlg.HiddenTypes      = this.HiddenTypes;
            hDlg.HiddenExtensions = this.HiddenExtensions;
            
            show(hDlg, varargin{:});
            
            if nargout > 0
                varargout = {hDlg};
            end
        end
        
        function editOptions(this, varargin)
            %EDITOPTIONS Edit the options.
            
            if nargin > 2 && ~varargin{2}
                hd = this.ConfigurationDialog;
                if isempty(hd)
                    return;
                end
            else
                hd = editConfigSet(this, false);
            end
            
            hd.editOptions(varargin{:});
        end
        
        function enableExtension(~, varargin)
            % Everything possibel to enable is always enabled.  Consider
            % going to full edit extension system when the specified
            % extension is not enabled.
        end
        
        function latestConfiguration = getLatestConfiguration(this)
            %GETLATESTCONFIGURATION Get the latestConfiguration.
            
            latestConfiguration = copyAllConfigs(this.ConfigurationSet);

            % Make sure that all the extensions have a chance to get their properties
            % up to date.
            for hExtension = getAllExtensions(this);
                if hExtension.Configuration.Enable
                    updatePropertySet(hExtension, latestConfiguration.findConfiguration(hExtension.Registration));
                end
            end
            
            % Prune out properties that are still set to their defaults.
            if isempty(this.LastAccessedFile)
                loaded = {};
            else
                loaded = {extmgr.ConfigurationSet.createAndLoad(this.LastAccessedFile)};
            end
            pruneDefaultProperties(latestConfiguration, this, loaded{:});
        end
        
        function y = isEnableAll(this,type)
            %local_isEnableAll True if type has constraint EnableAll or if it is
            %   EnableOne and there is only 1 extension of that type.
            
            if nargin < 2
                type = getSortedTypeNames(this);
            else
                type = {type};
            end
            y = true;
            for indx = 1:numel(type)
                hConstraint = getConstraint(this, type{indx});
                y = y && hConstraint.isEnableAll(this.ConfigurationSet);
            end
        end
        
        function [loaded, cfgFile] = loadConfigSet(this, cfgFile, passedConfigurationSet)
            
            loaded = false;
            
            if nargin < 2
                
                wildExt = sprintf('*.%s', this.FileExtension);
                
                % If no configuration file is specified, use UIPUTFILE to get one.
                [cfgFile, path] = uigetfile( ...
                    {wildExt, sprintf('Configuration Files (%s)', wildExt); ...
                    '*.*',   ' All Files(*.*)'}, ...
                    'Load Configuration');
                
                % If the 'Cancel' button is pressed, return early.
                if isequal(cfgFile, 0)
                    return;
                end
                
                % attach the path to cfgFile incase it differs from pwd.
                cfgFile = fullfile(path, cfgFile);
            end
            
            % Try to load specified config file into separate ConfigurationSet object
            if isempty(cfgFile) || ~ischar(cfgFile)
                loadedConfigurationSet = [];
                cfgFile = '';
            else
                
                [loadedConfigurationSet, loaded] = extmgr.ConfigurationSet.createAndLoad(...
                    cfgFile, this.MessageLog);
                % If we could not load the file, return early, nothing to do and
                % the message has already been sent to the message log.
                if ~loaded
                    return;
                end
            end
            
            if isempty(loadedConfigurationSet)
                if nargin > 2
                    % If we've been passed a configuration database, use its settings.
                    loadedConfigurationSet = passedConfigurationSet;
                else
                    return;
                end
            elseif nargin > 2 && ~isempty(passedConfigurationSet)
                simpleMergeOver(loadedConfigurationSet, passedConfigurationSet);
            end
            
            % If we have no configurations to use in the driver, return early.
            if isempty(loadedConfigurationSet)
                return;
            end
            
            % Prune out any configurations that do not have a matching register.
            hConfig = loadedConfigurationSet.Children;
            allRegister = this.RegistrationSet.Children;
            allTypes = {allRegister.Type};
            allNames = {allRegister.Name};
            for indx = 1:numel(hConfig)
                hRegister = allRegister(strcmp(allTypes, hConfig(indx).Type) &  ...
                    strcmp(allNames, hConfig(indx).Name));
                if isempty(hRegister)
                    remove(loadedConfigurationSet, hConfig(indx));
                else
                    hConfig(indx).Registration = hRegister;
                end
            end
            
            hConfigurationSet = this.ConfigurationSet;
            if isempty(hConfigurationSet)
                this.ConfigurationSet = loadedConfigurationSet;
                hConfigurationSet = loadedConfigurationSet;
                hConfigurationSet.AllowConfigEnableChangedEvent = false;
                oldEnableState = false;
            else
                oldEnableState = hConfigurationSet.AllowConfigEnableChangedEvent;
                hConfigurationSet.AllowConfigEnableChangedEvent = false;
                
                % Disable all extensions.  Allow the loaded file to set up the currently
                % enabled configurations.
                [hConfigurationSet.Children.Enable] = deal(false);
                
                % Merge loaded config set over shallow, to yield an
                % "active" config set that user sees and works with
                % Operation includes copying new config set name.
                %
                % The outcome is that we'll have a dst config defined for all extensions
                % found during registration, and hence, we'll be able to enable each one
                % during dialog interaction, etc.
                %
                % But the property-level content of each needs to be merged at a later
                % time.  That "later time" is when the config is enabled, and is done by
                % processall() which calls mergePropDb(). That is a deeper level merge and
                % considers obsolete, undefined, etc.
                %
                % No enable-listeners fire here, since this is all just instance-copy
                % operations without a change in property value
                %
                simpleMergeOver(hConfigurationSet, loadedConfigurationSet, false);
            end
            
            % Enforce type constraints 'EnableAll' and 'EnableOne'.
            imposeTypeConstraints(this);
            
            hConfigurationSet.AllowConfigEnableChangedEvent = oldEnableState;
            
            % Cache the full path to the file that was loaded.
            this.LastAccessedFile = which(cfgFile);
        end
        
        function processAll(~)
        end
                
        function [saved, cfgFile] = saveConfigSet(this, cfgFile)
            %SAVECONFIGSET Save current extension configuration properties.
            %   SAVECONFIGSET(H) saves the current configuration properties in the last
            %   saved or loaded file.  If no configuration file has been saved or
            %   loaded in the session, a dialog will open to specify the location of
            %   the configuration file.
            %
            %   SAVECONFIGSET(H, FNAME) saves the current configuration properties in
            %   the file specified by FNAME.
            
            % Saves the ConfigDb database, not the ScopeCfg
            % We don't retain scope position, docking, etc, in a config set
            % (That's the business of an instrument set!)
            
            if nargin < 2
                cfgFile = this.LastAccessedFile;
            end
            
            % If we have a file name, pass it directly to saveConfigSetAs, otherwise
            % call with no additional inputs and a dialog will be launched.
            if isempty(cfgFile)
                [saved, cfgFile] = saveConfigSetAs(this);
            else
                [saved, cfgFile] = saveConfigSetAs(this, cfgFile);
            end
        end
        
        function [saved, cfgFile] = saveConfigSetAs(this, cfgFile)
            %SAVECONFIGSETAS Save the configuration in a new file.
            %   SAVECONFIGSETAS(H) launches a dialog to specify the location of the
            %   configuration file and saves the configuration.
            %
            %   SAVECONFIGSETAS(H, FNAME) saves the configuration in the file specified
            %   by FNAME.
            
            saved = true;
            
            if nargin < 2
                
                wildExt = sprintf('*.%s', this.FileExtension);
                
                defFile = this.LastAccessedFile;
                if isempty(defFile)
                    defFile = sprintf('untitled.%s', this.FileExtension);
                    defPath = pwd;
                else
                    [defPath, defFile, defExt] = fileparts(defFile);
                    defFile = [defFile defExt];
                end
                
                oldPath = pwd;
                
                % Do not try to move if the default path is ''.
                if ~isempty(defPath)
                    cd(defPath);
                end
                
                % If no configuration file is specified, use UIPUTFILE to get
                [cfgFile, path] = uiputfile( ...
                    {wildExt, sprintf('Configuration Files (%s)', wildExt); ...
                    '*.*',   'All Files (*.*)'}, ...
                    'Save Configuration as', defFile);
                
                cd(oldPath);
                
                % If the 'Cancel' button is pressed, return early.
                if isequal(cfgFile, 0)
                    saved = false;
                    return;
                end
                
                % attach the path to cfgFile incase it differs from pwd.
                cfgFile = fullfile(path, cfgFile);
            end
            
            % Only retain enabled extensions
            hConfigDb = copyAllConfigs(this.ConfigurationSet);
            
            % Prune out properties that are still set to their defaults.
            pruneDefaultProperties(hConfigDb, this);
            
            % Serialize to file system
            save(cfgFile, 'hConfigDb');
            
            % Get the full path to the file we're about to load.
            
            this.LastAccessedFile = cfgFile;
        end
        
        function renderWidgets(~, varargin)
            % NO OP - must be overloaded, but is not required, so this
            % method is a no op and not abstract.
        end
        
        function renderMenus(~, varargin)
            % NO OP - must be overloaded, but is not required, so this
            % method is a no op and not abstract.
        end
        
        function renderToolbars(~, varargin)
            % NO OP - must be overloaded, but is not required, so this
            % method is a no op and not abstract.
        end
        
        function set.FileExtension(this, fileextension)
            
            % Make sure we remove the '.' at the beginning if it is present.
            if strncmpi(fileextension, '.', 1)
                fileextension(1) = [];
            end
            this.FileExtension = fileextension;
        end
        
        function configDb = get.ConfigDb(this)
            configDb = this.ConfigurationSet;
        end
    end
    
    methods (Access = protected)
        function imposeTypeConstraints(~)
        end
    end
    
    methods (Abstract)
        hr  = findHiddenRegistrations(this, type)
        reg = findRegistration(this, type, name)
        vr  = findVisibleRegistrations(this, type)
        c   = getConstraint(this, type)
        stn = getSortedTypeNames(this)
        b   = hasOptions(this)
    end
end

% [EOF]
