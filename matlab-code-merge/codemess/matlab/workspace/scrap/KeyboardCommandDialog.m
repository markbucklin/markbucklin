classdef KeyboardCommandDialog < uiservices.BaseDialog
    %KeyboardCommandDialog   Define the KeyboardCommandDialog class.
    
    %   Copyright 2014 The MathWorks, Inc.
    
    properties
        
        %Prop1   Example property
        %   Add a complete property description here
        %
        %   See also matlabshared.scopes.KeyboardCommandDialog
        AllCommands;
    end
    
    methods
        
        function this = KeyboardCommandDialog(allCommands, hFig)
            %KeyboardCommandDialog   Construct the KeyboardCommandDialog
            %class.
            
            title = getString(message('Spcuilib:scopes:KeyCmdTitle'));
            this@uiservices.BaseDialog(title, hFig);
            
            this.AllCommands = allCommands;
        end
        
        function dlgstruct = getDialogSchema(this, ~)
            %GetDialogSchema Construct KeyMgr help dialog.
            
            % Get the key manager help dialog text
            % Concatenates all child KeyGroup help descriptions into a vector
            % of structures, converting Help to structs as it operates.
            %
            % Each struct contains the fields:
            %   .Title: title of next section of key help
            %   .Mapping: a cell-array passed to DDG2ColText
            %          {'key1', 'description1'; ...
            %           'key2', 'description2'; }
            %   Column 1 is the name of the key (keys)
            %   Column 2 is a brief description of the action take for the
            %      corresponding key (keys)
            %   Ex:
            %      s.'Title' = 'Navigation commands';
            %      s.Mapping = ...
            %          {'n',  'Go to next entry'; ...
            %           'p',  'Go to previous entry'};
            %
            
            dlgstruct = getDialogSchema@uiservices.BaseDialog(this);
            
            allCommands = this.AllCommands;
            
            allGroups = sort(unique({allCommands.group}));

            for indx = 1:numel(allGroups)
                helpStruct(indx).Title = allGroups{indx}; %#ok<*AGROW>
                                
                allKeys = allCommands(strcmp({allCommands.group}, allGroups{indx}));
                
                mapping = {};
                while ~isempty(allKeys)
                    
                    % If there are multiple keeps with the same tag, group
                    % them together.
                    sameTag = strcmp(allKeys(1).tag, {allKeys.tag});
                    keys = sprintf('%s, ', allKeys(sameTag).key);
                    keys(end-1:end) = [];
                    mapping{end+1, 1} = keys;
                    mapping{end, 2} = allKeys(1).label;
                    mapping{end, 3} = true; % Visible
                    mapping{end, 4} = true; % Enable
                    
                    % Remove keys that are already added to the mapping.
                    allKeys(sameTag) = [];
                end
                helpStruct(indx).Mapping = mapping;
            end
            
            Ngroups = numel(helpStruct);
            if Ngroups == 0
                % No help text specified
                helpStruct.Title = '';
                helpStruct.Mapping = {'','No key commands are defined.', true, true};
                Ngroups = 1;
            end
            
            % Create DDG groups from help database
            %
            overallEnable = true; %strcmpi(this.Enabled,'on');
            DDG_Group = cell(1, Ngroups);  % default group
            for i=1:Ngroups
                DDG_Group{1,i} = DDG2ColText(helpStruct(i).Title, ...
                    helpStruct(i).Mapping, i, overallEnable);
            end
            
            % add spacer for g381027
            spacer.Type = 'panel';
            spacer.RowSpan = [Ngroups+1, Ngroups+1];
            spacer.ColSpan = [1,1];
            
            % Collect all groups into a panel
            %
            cAll.Type = 'panel';
            cAll.Items = [DDG_Group,spacer];
            cAll.LayoutGrid = [Ngroups+1 1];
            
            % Return top-level DDG dialog structure
            %
            dlgstruct.Items               = {cAll};
            dlgstruct.StandaloneButtonSet = {'OK'};
            dlgstruct.DialogTag           = 'KeyboardCommandHelp';
        end
        
    end
end

%
function grp = DDG2ColText(groupName, entries, grpIdx, overallEnable)
%DDG2ColText Create a 2-column group of text widgets.
%   Creates a DDG group of text widgets in a 2-column
%   format.
%
%  groupName: visible name of the group widget
%  entries: Nx3 cell-array, [col1, col2, ena], containing two columns
%           to render using text widgets in a 2-column format
%  grpIdx: row-coordinate to assign to group

% Construct individual text widgets for
% each key binding and description
%
numEntries = size(entries,1); % # Rows
allW = cell(1, 2*numEntries);  % all widgets for this group
for indx=1:numEntries
    % Construct text widgets for next description and key
    % Store interleaved widgets,
    %  [description1, key1, description2, key2, ...]
    %
    
    % Control enable state of the text based on whether the key binding
    % is enabled or disabled and on whether the key binding is visible or
    % invisible
    itemEnabled  = entries{indx,3};
    itemVisibility = entries{indx, 4};
    if ~itemVisibility
        itemEnabled = 0;
    end
    
    ena = overallEnable && itemEnabled;
    
    % Description
    w.Type    = 'text';
    w.Name    = entries{indx,2};  % description
    w.Tag     = entries{indx,2};
    w.RowSpan = [indx indx];
    w.ColSpan = [1 1];
    %w.RowStretch = [0];
    w.Enabled = ena;
    w.Visible = itemVisibility;
    allW{2*indx-1} = w;
    
    % Key
    w.Type    = 'text';
    w.Name    = entries{indx,1};  % key
    w.Tag     = entries{indx,1};
    w.RowSpan = [indx indx];
    % w.RowStretch = [0];
    w.ColSpan = [2 2];
    w.Enabled = ena;
    w.Visible = itemVisibility;
    allW{2*indx} = w;
end
%spacer.Type = 'panel';
% Construct Group widget
%
grp.Type = 'group';
grp.Name = groupName;
grp.Tag = groupName;
%grp.Items = [allW, spacer];  % all widgets
grp.Items = allW;
grp.LayoutGrid = [numEntries 2]; % internal to group
grp.RowSpan = [grpIdx grpIdx];   % external for parent
grp.ColSpan = [1 1];

end

% [EOF]
