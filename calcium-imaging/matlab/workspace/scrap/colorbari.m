function [hax,ifcn] = colorbari(varargin)
%This function is for internal use only. It may be removed in the future.

%COLORBARI Display interactive color bar (color scale).
%   COLORBARI appends an interactive colorbar to the current axes.
%
%   COLORBARI('peer',AX) creates a colorbar associated with axes AX
%   instead of the current axes.
%
%   COLORBARI(...,LOCATION) appends a colorbar in the specified location
%   relative to the axes.  LOCATION may be any one of the following strings:
%       'North'              inside plot box near top
%       'South'              inside bottom
%       'East'               inside right
%       'West'               inside left
%       'NorthOutside'       outside plot box near top
%       'SouthOutside'       outside bottom
%       'EastOutside'        outside right
%       'WestOutside'        outside left
%
%   COLORBARI(...,'colormaps',CLIST) replaces the default list of colormap
%   names in the colorbar context menu.  CLIST must be a cell-string of
%   colormap function names, e.g., {'autumn','spring','summer','winter'},
%   or can be empty.
%
%   COLORBARI(...,'titleshort',TITLE) adds a custom title positioned at the
%   midpoint of the shorter dimension of the colorbar.
%
%   COLORBARI(...,'titlelong',TITLE) adds a custom title positioned at the
%   midpoint of the longer dimension of the colorbar.  Both titleshort and
%   titlelong may be used for the same colorbar.
%
%   COLORBARI(...,P/V Pairs) specifies additional property name/value pairs
%   for colorbar axes. If 'Position' property is specified, user is
%   prevented from changing colorbar location.
%
%   COLORBARI('off'), COLORBARI('hide'), and COLORBARI('delete') delete all
%   colorbars associated with the current axes.
%
%   COLORBARI(H,'off'), COLORBARI(H,'hide'), and COLORBARI(H,'delete')
%   delete the colorbar specified by H.
%
%   Repeated calls to COLORBARI will replace a colorbar previously created
%   by COLORBARI.
%
%   H = COLORBARI(...) returns a handle H to the colorbar axes, which is a
%   child of the current figure. If a colorbar exists, a new one is still
%   created.  H cannot be requested if 'off', 'hide' or 'delete' arguments
%   are passed.
%
%   [H,F] = COLORBARI(...) returns function handle F that displays a marker
%   on the colorbar pointing to value V, when called using F(V). V must be
%   a scalar.  If V=[], the marker is hidden from view.
%
%   See also COLORBAR, COLORMAP.

%   Copyright 2014 The MathWorks, Inc.

%   COLORBARI('parent',parent) sets the graphical parent of the colorbar to
%   the specified parent handle.  Colorbar parent may be a figure or other
%   valid axes parent that is not necessarily the same as the parent of the
%   peer axes.

% TO DO:
% - add listeners:
%    - peerAxes data range changes
%    - xaxisloc, yaxisloc, title changes (MarkedDirty?)
%    - 
% - link to colorbar button in figure menu
% - add "Delete" context menu when button ready
% - consider "control key" action

% Appdata defined on UI:
%      PeerAxes: 'ColorbariInfo'
%  ColorbarAxes: 'ColorbariCmapKey'
%                'ColorbariListeners'

if nargout>0
    [hax,ifcn] = init(varargin); % pass cell of args
else
    init(varargin);
end

end

function [hax,ifcn] = init(args)
% Get command line options.
% Initialize info struct, draw UI, install listeners and callbacks.
% Cache and return info struct.

cl = get_cmdline(args,nargout);

% Delete colorbari if an explicit colorbar axes handle was passed
if cl.deleteThis
    % deleteThis calls do not utilize peerAxes
    deleteColorbar([],cl.colorbarAxes);
    return
end

% Peer axes is known here:
peerAxes = cl.peerAxes;
if ~ishandle(peerAxes) || ~strcmpi(get(peerAxes,'type'),'axes');
    error('AX must be an axes handle.');
end

% Always delete current colorbar.
%  - we will NOT create more than one COLORBARI colorbar for a given peer
%    axes.  It doesn't make sense and adds complexity to colorbar
%    management.
%
deleteColorbar(peerAxes);

% Stop here if that's all that was requested
if cl.deleteAll
    return
end

% Determine parent to use for colorbar axes.
% If not specified, use parent of peerAxes - which could be a figure,
% uicontainer, etc.
parent = cl.parent;
if isempty(parent)
    parent = get(peerAxes,'parent');
end

% Initialize info struct
%
% Store partial cache early, so deletion, create_colorbar, etc, can
% leverage basics.
%
s.ColorbarAxes              = [];
s.ColorbarImage             = [];
s.ColorbarParent            = parent;
s.ColormapAxesLimits        = [];
s.ColormapColorStretch      = [0 1]; % normalized extent of axes range
s.ColormapCustomExpr        = '';
s.ColormapLength            = [];
s.ColormapNames             = cl.colormapNames;
s.CursorPointer             = '';
s.LastMouseBehavior         = 'none';
s.LocationIdx               = getLocationIdx(cl.locationStr);
s.PeerAxes                  = peerAxes;
s.PeerAxesOrigPos           = get(peerAxes,'Position');
s.PeerAxesOrigUnits         = get(peerAxes,'Units');
s.PeerAxesOrigCLim          = get_data_range(parent,peerAxes);
s.PositionPropertySpecified = false;
s.PVPairs                   = cl.pvPairs;
s.SelectedColormapNamesIdx  = [];
s.TitleShort                = cl.titleShort;
s.TitleLong                 = cl.titleLong;

% Set initial axes limit for colorbar
% 
% Use initial CLim of peer axes, to reflect the limits that may have
% already been chosen by caller.  These could be the original data range of
% the peer axes content, or something different.
%
s.ColormapAxesLimits = s.PeerAxesOrigCLim;
if cl.positionPropertySpecified
    s.PositionPropertySpecified = true;
end
setappdata(peerAxes,'ColorbariInfo',s);

% NOTE! Adds/changes entries in struct, updates cache
[~,s] = cacheColormapLength(peerAxes);
s = create_colorbar(s);

% Initialize state of special keys pressed while mouse is within colorbar.
%   state: [shift ctrl]
setappdata(peerAxes,'ColorbariCmapKey',[false false]);

% Create context menus
%  - turn off handle vis to decrease impact on automated tests
cbarFig = ancestor(s.ColorbarAxes,'figure');
uic = uicontextmenu('Parent',cbarFig, ...
    'HandleVisibility', 'off');
set([s.ColorbarImage s.ColorbarAxes],'UIContextMenu',uic);
install_context_menus(peerAxes);

% The following changes info struct, context menus:
s = detect_standard_colormap(peerAxes);

% If position property specified, remove Location context menu
if s.PositionPropertySpecified
    hideLocationMenu(peerAxes);
end

% Install same colormap in peer and colorbar figures, if figures are not
% the same.  We copy the colormap from the ColorbarAxes figure, and install
% it into the peerAxes figure.
%
if ~isequal(s.ColorbarAxes,peerAxes)
    cmap = get(ancestor(s.ColorbarAxes,'figure'),'Colormap');
    set(ancestor(peerAxes,'figure'),'Colormap',cmap);
end

% Install listeners and mouse behaviors
%drawnow % flush events so listeners don't fire (much)
install_listeners(peerAxes,cbarFig);
cacheWindowButtonCbFcns(peerAxes);
changeMouseBehavior(peerAxes,'cmap');

% Return args
%
hax = s.ColorbarAxes;
ifcn = @updateIndicator;
%ifcn = @(value)updateIndicator_i(peerAxes,value);

    function updateIndicator(value)
        % Show value as a marker on colorbar.
        
        % Implemented as a nested function so peerAxes is automatically
        % set from context.
        updateIndicator_i(peerAxes,value);
    end
end

function updateIndicator_i(peerAxes,v)
% Make visible and update position of value indicator.

s = getappdata(peerAxes,'ColorbariInfo');
ind = s.Indicator;
if nargin<2
    v = ind.UserData;
end
if isempty(v)
    set(s.Indicator, ...
        'UserData',v, ...
        'Visible','off');
    return
end

% Indicator marker width across colorbar, in range of [0,1].
% Equal to the altitude of the equilateral triangle indicator:
a = 0.6;

% Now convert to side length of trianglein data units.
%
% Side length of equilateral triangle, in range [0,1];
an = a/cos(30*pi/180);
hc = s.ColorbarAxes;
dar = hc.DataAspectRatio;
pbar = hc.PlotBoxAspectRatio;
scale = dar(1)/dar(2)*pbar(2)/pbar(1);
if isHorizontalCbar(s)
    % Should marker point UP or DN?
    if any(s.LocationIdx==[1 5]) % North/OutsideNorth: point UP
        ydata = [1-a 1 1-a];
    else  % south: point DN
        ydata = [a 0 a];
    end
    d = an * scale;
    xdata = [v-d/2 v v+d/2];
else
    % Should marker point LT or RT?
    if any(s.LocationIdx==[3 7]) % West/OutsideWest: point LT
        xdata = [a 0 a];
    else  % south: point DN
        xdata = [1-a 1 1-a];
    end
    d = an /scale; % * dar(2)/dar(1)*pbar(1)/pbar(2);
    ydata = [v-d/2 v v+d/2];
end

% Update indicator.
% Cache last marker value in userdata.
set(ind, ...
    'vis','on', ...
    'XData',xdata, ...
    'YData',ydata, ...
    'userdata',v);

end

function s = detect_standard_colormap(peerAxes,cmapExpr)
% Determine if custom colormap expression (string containing MATLAB
% expression that evaluates to the colormap matrix) matches a standard
% colormap function, in which case we store the shorter function form.
%
% Changes info struct.
%
% If a numeric scalar is passed as cmapExpr, we assume that one of the
% entries in the ColormapNames list was chosen via a menu, and this fcn is
% being called in reaction to that.  So we skip detection of colormap, and
% we know which one is installed via cmapIdx.

% Set .ColormapCustomExpr to current colormap,
% indicating we don't know what it is:

s = getappdata(peerAxes,'ColorbariInfo');
if nargin<2
    cmapExpr = mat2str(get(ancestor(s.ColorbarAxes,'figure'),'colormap'));
end

if ischar(cmapExpr)
    [cmapExpr,cmapIdx] = match_colormap_expr(cmapExpr,s.ColormapNames);
    s.ColormapCustomExpr = cmapExpr;
else
    % Index into .ColormapNames was passed, not a string that is the MATLAB
    % expression of the colormap matrix.  In this case, we don't need
    % auto-detection -- we know the map name explicitly.
    cmapIdx = cmapExpr;
end

if ~isempty(cmapIdx)
    % Set context menus
    %
    % Colormap name:
    % - First menu is 'Custom...', so check the idx+1'th menu
    hCCM = s.ColormapContextMenus;
    set(hCCM,'Checked','off');
    set(hCCM(cmapIdx+1),'Checked','on');
    
    % Colormap length:
    % - done for us, just need to enable the menu item
    s.ColormapLengthContextMenu.Enable = 'on';
end

setappdata(peerAxes,'ColorbariInfo',s);

end

function [cmapExpr,idx] = match_colormap_expr(cmapExpr,cmapNames)
% Return function-based expression if colormap expression (string) matches
% a built-in colormap function.
%
% Only functions listed in s.ColormapNames must be considered, since they
% have context menu enumerations.  Others can be done as desired.

% mat2str default precision: 15 digits
tol = 1e-13;

% Evaluate custom colormap
c0 = eval(cmapExpr);
N0 = size(c0,1); % # rows = colormap length

% Evaluate standard maps and compare
N = numel(cmapNames);
for idx = 1:N
    % Evaluate standard map for same length as custom map.
    % Values in range [0,1]
    ci = feval(cmapNames{idx},N0);
    d = c0-ci;
    if max(d(:)) < tol
        cmapExpr = sprintf('%s(%d)',cmapNames{idx},N0);
        return
    end
end
idx = [];

end

function install_listeners(peerAxes,cbarFig)
% Catch events in peer axes
%  - delete peer axes (i.e., clf was called on figure)
%
% NOTE: peer axes is the primary axes displaying user graphics,
%       not the colorbar axes

s = getappdata(peerAxes,'ColorbariInfo');

% Deletion of PeerAxes (e.g., when "clf" is performed on figure)
lis.PeerAxesBeingReset = addlistener(peerAxes, ...
    'Reset',@PeerAxesReset);
lis.PeerAxesBeingDeleted = addlistener(peerAxes, ...
    'ObjectBeingDestroyed',@PeerAxesDeleted);
lis.ColorbarAxesBeingDeleted = addlistener(s.ColorbarAxes, ...
    'ObjectBeingDestroyed',@ColorbarAxesDeleted);

% Listen to key press and release, only enabled when mouse is over cmap, to
% determine when SHIFT is being held for a visual change to pointer shape.

lis.WindowKeyPressEvents(1) = addlistener(cbarFig, ...
    'WindowKeyPress', @(~,ev)FigKeyEvent(ev,peerAxes,true));
lis.WindowKeyPressEvents(1).Enabled=false;

lis.WindowKeyPressEvents(2) = addlistener(cbarFig, ...
    'WindowKeyRelease', @(~,ev)FigKeyEvent(ev,peerAxes,false));
lis.WindowKeyPressEvents(2).Enabled=false;

% Listen for "external" changes to the WindowButton[Down/Motion/Up]Event
% callbacks.
lis.WindowButtonCbFcns(1) = addlistener(cbarFig, ...
    'WindowButtonDownFcn','PostSet', ...    
    @(~,~)WindowButtonCallbackPropertyChange(peerAxes,'down'));
lis.WindowButtonCbFcns(2) = addlistener(cbarFig, ...
    'WindowButtonMotionFcn','PostSet', ...
    @(~,~)WindowButtonCallbackPropertyChange(peerAxes,'motion'));
lis.WindowButtonCbFcns(3) = addlistener(cbarFig, ...
    'WindowButtonUpFcn','PostSet', ...
    @(~,~)WindowButtonCallbackPropertyChange(peerAxes,'up'));
lis.WindowButtonCbFcns(4) = addlistener(cbarFig, ...
    'WindowScrollWheelFcn','PostSet', ...
    @(~,~)WindowButtonCallbackPropertyChange(peerAxes,'scroll'));

% Listen to windows button up/down/motion/scroll events for our normal
% processing. Don't use the figure callbacks, since there is only one "set"
% of these and we want multiple instances to work.
%
% Create HG listeners for window button changes.
lis.WindowButtonEvents(1) = addlistener(cbarFig,'WindowMousePress',@none);
lis.WindowButtonEvents(2) = addlistener(cbarFig,'WindowMouseMotion',@none);
lis.WindowButtonEvents(3) = addlistener(cbarFig,'WindowMouseRelease',@none);
lis.WindowButtonEvents(4) = addlistener(cbarFig,'WindowScrollWheel',@none);
lisW = lis.WindowButtonEvents;
for i = 1:numel(lisW)
    lisW(i).Enabled = false;
end

% Resize:
lis.WindowResizeEvent = addlistener(cbarFig, ...
    'SizeChanged',@(~,~)ResizeFigure(peerAxes));

% Listen for changes to peerAxes 'clim' property.
%
% This happens when changes to colordata min/max are made, typically via
% the "Color data min" and "Color data max" edit boxes in the Colormap
% Editor UI.
%
lis.PeerAxesCLim = addlistener(peerAxes, ...
    'CLim','PostSet',@(~,ev)PeerAxesCLimChange(ev,peerAxes));
lis.PeerAxesPos = addlistener(peerAxes, ...
    'Position','PostSet',@(~,ev)PeerAxesPosChange(ev,peerAxes));

% xxx TBD
%lis.PeerAxesXAxesLoc = addlistener(peerAxes, ...
%    'XAxisLocation','PostSet',@(~,ev)PeerAxesPosChange(ev,peerAxes));
%lis.PeerAxesYAxesLoc = addlistener(peerAxes, ...
%    'YAxisLocation','PostSet',@(~,ev)PeerAxesPosChange(ev,peerAxes));

% Listen for changes to figure colormap property.
%
% This happens by user calling "colormap(jet(256))" from command line, etc.
%
lis.FigureColormap = addlistener(cbarFig, ...
    'Colormap','PostSet',@(~,~)FigureColormapChange(peerAxes));

% Hold listeners on colorbar axes, not peer axes
%  (peer might be getting deleted)
%
setappdata(s.ColorbarAxes,'ColorbariListeners',lis);

end

function none(~,~)
% Empty callback.
error('Executing no-op function.');
end

function WindowButtonCallbackPropertyChange(peerAxes,typ)
% Listener callback for changes to WindowButton[Down/Motion/Up]Event
% and WindowScrollWheelFcn properties.  Filter out our own changes!
%
% typ: Type of Button event: 'down','motion','up','scroll'

cacheWindowButtonCbFcns_update(peerAxes,typ);

end

function clim = getCLimBasedOnColorbar(peerAxes)
% Compute CLim (color limits) based on current color extent and dynamic
% range of the colorbar.

% ColormapColorStretch: 2-element vector, [lo hi]
%  [0,1] is default range that exactly covers colorbar axes
%  Limits can be <0 and >1.
%
s = getappdata(peerAxes,'ColorbariInfo');
alim_1  = s.ColormapAxesLimits(1);
alim_21 = s.ColormapAxesLimits(2) - alim_1;
clim    = alim_1 + alim_21 * s.ColormapColorStretch;

end

function FigureColormapChange(peerAxes)
% A change was made to the figure Colormap property.
%
% This happens when, for example, the user types "colormap(jet(256))" from
% the command line.

% Update the colormap length
cacheColormapLength(peerAxes);

% Get new colormap size installed properly:
changeLocation(peerAxes);

s = getappdata(peerAxes,'ColorbariInfo');
change_CLim_colorbar_and_peer(s);

% Turn on "Custom" colormap context menu
set(s.ColormapContextMenus(2:end),'Checked','off');
s.ColormapContextMenus(1).Checked = 'on';
setappdata(peerAxes,'ColorbariInfo',s);

% Disable Colormap Length context menu, since we don't know how to change
% the length of a custom colormap.
s.ColormapLengthContextMenu.Enable = 'off';

if ~isempty(s.SelectedColormapNamesIdx)
    % Colormap menu choice was selected.
    %
    % Index into the .ColorbarNames list is passed, bypassing
    % auto-detection (which is not needed for this case):
    detect_standard_colormap(peerAxes,s.SelectedColormapNamesIdx);
else
    % Retain custom colormap as a numeric matrix expression, or match to one of
    % the pre-set "standard" maps and check that option (plus enable the length
    % menu).
    detect_standard_colormap(peerAxes);
end

end

function [L,s] = cacheColormapLength(peerAxes)

s = getappdata(peerAxes,'ColorbariInfo');
L = size(get(ancestor(s.ColorbarParent,'figure'),'Colormap'),1);
s.ColormapLength = L;
setappdata(peerAxes,'ColorbariInfo',s);

end

function PeerAxesCLimChange(ev,peerAxes)
% A change was made to the PeerAxes CLim property.
%
% This happens when changes to colordata min/max are made, typically via
% the "Color data min" and "Color data max" edit boxes in the Colormap
% Editor UI.

% New CLim dynamic range is in ev.AffectedObject
% Reset stretch to full bar [0,1]
reset_CLim_colorbar_and_peer(peerAxes,ev.AffectedObject.CLim);

end

function PeerAxesPosChange(~,peerAxes)
% React to an external change to PeerAxes Position property.
%
% We interpret position as a new "initial" position, and re-adjust the
% position of peerAxes and colorbar based on location, etc.

s = getappdata(peerAxes,'ColorbariInfo');
s.PeerAxesOrigPos = get(peerAxes,'Position');
s.PeerAxesOrigUnits = get(peerAxes,'Units');
setappdata(peerAxes,'ColorbariInfo',s);
setColorbarAndPeerPos(s);

end

function PeerAxesReset(peerAxes,~)
% Peer axes are being reset.
% Ex: a new graphics object (surface?) is being drawn in place of existing
% object (contour?  or perhaps a different surface?)  In that case, the
% colorbar needs to be removed and the user will need to add another
% colorbar.
%
% The mental model is that the colorbar is "attached" to the graphics
% object (surface?) itself.
%
% Delete the colorbar:

deleteColorbar(peerAxes);

end

function PeerAxesDeleted(peerAxes,~)
% Peer axes are being deleted.
% We need to delete the colorbar.
%
% Reason: colorbar uses a hiddenhandle so it is not accidentally rotated or
% changed while on-screen.  This has the side-effect of preventing colorbar
% removal when "clf" is called.  This listener deletes colorbar in that
% situation.

deleteColorbar(peerAxes);

end

function ColorbarAxesDeleted(cbarAxes,~)
% Colorbar axes are being deleted.
%
% Disable listeners by removing objects.

% Delete listeners
lis = getappdata(cbarAxes,'ColorbariListeners');
f = fieldnames(lis);
for i = 1:numel(f)
    f_i = f{i};
    lis_fi = lis.(f_i);
    for j = 1:numel(lis_fi)
        delete(lis_fi(j));
    end
end
rmappdata(cbarAxes,'ColorbariListeners');

end

function deleteColorbar(peerAxes,colorbarAxes)
% Remove colorbar associated with peerAxes.
%   - Destroy axes, appdata, etc.
%   - Restore position of peerAxes.
%
% If colorbarAxes passed, we need to determine peerAxes.

if nargin>1
    % colorbarAxes specified
    peerAxes = getappdata(colorbarAxes,'ColorbariPeerAxes');
    if isempty(peerAxes)
        error('H is not a handle to a COLORBARI colorbar.')
    end
end

% It's not an error to attempt to delete a non-existent colorbar, as long
% as colorbarAxes was not passed.
s = getappdata(peerAxes,'ColorbariInfo');
if ~isempty(s) && ~isempty(s.PeerAxesOrigPos)
    % Remove any window button callbacks
    changeMouseBehavior(peerAxes,'none');
    
    cbarAxes = s.ColorbarAxes;
    if ishandle(cbarAxes)
        lis = getappdata(cbarAxes,'ColorbariListeners');
        lis.PeerAxesPos.Enabled = false;
        lis.PeerAxesCLim.Enabled = false;
        delete(cbarAxes);
    end
    rmappdata(peerAxes,'ColorbariInfo');
    
    % Restore original properties of peerAxes
    % NOTE: listeners to peerAxes were on cbarAxes, which are now deleted.
    peerAxes.Units = s.PeerAxesOrigUnits;
    peerAxes.CLim = s.PeerAxesOrigCLim;

    % Parent of peerAxes may be in the process of being deleted.
    % Don't try to set its position in that case, it may throw warnings.
    if ~isempty(peerAxes.Parent)
        peerAxes.Position = s.PeerAxesOrigPos;
    end
end

end

function cl = get_cmdline(args,Nout)
% Return struct with command line options.
% Determine peer axes.
%
% COLORBARI
% COLORBARI(H)
% COLORBARI(H,'off')
% COLORBARI(H,'hide')
% COLORBARI(H,'delete')
% COLORBARI('off')
% COLORBARI('hide')
% COLORBARI('delete')
% COLORBARI('peer',ax)
%
% The following can be specified with or without ('peer',ax):
% COLORBARI(...,LOCATION)
% COLORBARI(...'colormaps',CLIST)
% COLORBARI(...,'parent',parentHandle)
% COLORBARI(...,'position',pos)  (specially handled)
% COLORBARI(...,'title',titleStr)
% COLORBARI(...,P/V Pairs)
%
% Notes:
%
% 1: COLORBARI(H) is "reserved" for compatibility with COLORBAR.
% 2: CLIST must be a cell-string.
% 3: P/V Pairs pertains to properties of the colorbar axes only,
%    and must be last if present.
% 4: 'Position' may be passed as property name in a P/V pair; in this case,
%    the position of the colorbar is assumed to be fixed and should not be
%    changed.  In this case, the LOCATION option is ignored, and the
%    Location context menu is removed.
%
% Returns struct:
%  cl.colorbarAxes
%  cl.colormapNames
%  cl.deleteAll
%  cl.deleteThis
%  cl.locationStr
%  cl.peerAxes
%  cl.positionPropertySpecified
%  cl.pvPairs

% Defaults
cl.colorbarAxes  = [];
cl.colormapNames = {'bone','cool','copper','gray','hot','hsv','jet','parula','pink'};
cl.deleteAll     = false;
cl.deleteThis    = false;
cl.locationStr   = '';
cl.parent        = [];
cl.peerAxes      = [];
cl.position      = [];
cl.positionPropertySpecified = false;
cl.pvPairs       = {};
cl.titleShort    = '';
cl.titleLong     = '';
cl.keywords      = { ...
    'peer','off','hide','delete', ...
    'colormaps', ...
    'northoutside','southoutside','westoutside','eastoutside', ...
    'north','south','west','east', ...
    'parent','titleshort','titlelong'};

% COLORBARI
% COLORBARI(H,'off')
% COLORBARI(H,'hide')
% COLORBARI(H,'delete')
% COLORBARI('off')
% COLORBARI('hide')
% COLORBARI('delete')
[cl,argsRemaining] = get_cmdline_noniterative(cl,args,Nout);

if ~isempty(argsRemaining)
    % Handle remaining args
    %   - NOTE: ('peer',ax,...) has already been parsed, if present
    %
    % COLORBARI(...,LOCATION)
    % COLORBARI(...,'colormaps',CLIST)
    % COLORBARI(..,'parent',parentHandle)
    % COLORBARI(..,'peer',peerAxes)
    % COLORBARI(..,'title',titleStr)
    % COLORBARI(...,P/V Pairs)
    while 1
        Nargs = numel(argsRemaining);
        if Nargs==0
            break
        end
        a1 = argsRemaining{1};
        idx = find(strcmpi(a1,cl.keywords));
        
        if ~isempty(idx)
            if any(idx==5)
                % (...,'colormaps',CLIST)
                if Nargs<2
                    error('Colormaps not specified.');
                end
                
                % Basic checks on colormap names
                cnames = argsRemaining{2};
                if ischar(cnames)
                    % Allow a single string for the list of colormap names
                    cnames = {cnames};
                elseif ~iscellstr(cnames)
                    % Demand a cell-string for more than one name
                    error('Colormaps must be a cell-string of colormap function names.');
                end
                % Could check each name to ensure it's a function on the MATLAB
                % path - but we can only know if it's a file.  And then should we
                % also run each to be sure it returns an Nx3 matrix?  It takes too
                % much time for that.  Just rely on caller to configure with valid
                % colormap names.
                %
                % Ensure no empty strings or invalid MATLAB file names.
                N = numel(cnames);
                for i = 1:N
                    if ~any(exist(cnames{i}) == [1 2 3 5 6]) %#ok<EXIST>
                        error('Colormaps must contain names of functions on the MATLAB path.');
                    end
                end
                
                cl.colormapNames = cnames;
                argsRemaining = argsRemaining(3:end);
                continue
            end
            
            if any(idx==6:13)
                % (...,LOCATION)
                cl.locationStr = a1;
                argsRemaining = argsRemaining(2:end);
                continue
            end
            
            if idx==14
                % (...,'parent',parentHandle)
                if Nargs<2
                    error('Parent handle not specified.');
                end
                cl.parent = argsRemaining{2};
                if ~ishandle(cl.parent)
                    error('''parent'' must be followed by a valid handle.');
                end
                argsRemaining = argsRemaining(3:end);
                continue
            end
            
            if idx==15
                % (...,'titleshort',titleStr)
                if Nargs<2
                    error('TitleShort string not specified.')
                end
                cl.titleShort = argsRemaining{2};
                argsRemaining = argsRemaining(3:end);
                continue
            end
            
            if idx==16
                % (...,'titlelong',titleStr)
                if Nargs<2
                    error('TitleLong string not specified.')
                end
                cl.titleLong = argsRemaining{2};
                argsRemaining = argsRemaining(3:end);
                continue
            end
            
            if idx==1
                % (...,'peer',peerAxes)
                if Nargs<2
                    error('Unrecognized input or invalid parameter/value pair arguments.');
                end
                cl.peerAxes = argsRemaining{2};
                if ~ishandle(cl.peerAxes) || ~strcmpi(get(cl.peerAxes,'type'),'axes')
                    error('''peer'' must be followed by an axes handle.');
                end
                argsRemaining = argsRemaining(3:end);
                continue
            end
        end
        
        if Nargs>1
            % (...,P/V pairs)
            if rem(Nargs,2)~=0
                error('Invalid parameter/value pair arguments.');
            end
            cl.pvPairs = argsRemaining;
            
            % No more args to process:
            break
            %argsRemaining = {};
            %continue
        end
        error('Unrecognized option ''%s''.',a1);
    end
end

% See if any property names are 'position'.
% Allow partial property-name recognition.
pvPairs = cl.pvPairs;
if ~isempty(pvPairs)
    for k = 1:2:numel(pvPairs)
        p_k = pvPairs{k};
        if strncmpi('position',pvPairs{k},numel(p_k));
            cl.positionPropertySpecified = true;
            cl.position = pvPairs{k+1};
            break
        end
    end
end

% Check location.
% - If specified, use the location (even if position also specified)
% - If 'position' specified but no location specified,
%     use EastOutside if aspect ratio is vertical,
%     and SouthOutside if aspect ratio is horizontal.
% - Use EastOutside if no location specified and 
if isempty(cl.locationStr)
    if cl.positionPropertySpecified
        isHoriz = cl.position(3) > cl.position(4); % dx > dy?
        if isHoriz
            cl.locationStr = 'SouthOutside';
        else
            cl.locationStr = 'EastOutside';
        end
    else
        cl.locationStr = 'EastOutside';
    end
end

% Set peerAxes if not specified
if isempty(cl.peerAxes)
    cl.peerAxes = gca;
end

end

function [cl,argsRemaining] = get_cmdline_noniterative(cl,args,Nout)
% No options, or single option specified that does not accept further
% argument pairs.  These are the simplest forms to parse that do not
% require iteration.

% COLORBARI
% COLORBARI(H)
% COLORBARI(H,'off')
% COLORBARI(H,'hide')
% COLORBARI(H,'delete')
% COLORBARI('off')
% COLORBARI('hide')
% COLORBARI('delete')
% COLORBARI(P/V pairs)
%
% If no other keywords are specified, P/V pairs will be parsed in this
% function.  In general, P/V pair parsing could be deferred until a later
% parse stage.

% assume no more to do when this returns
argsRemaining = {};

Nargs = numel(args);
if Nargs==0
    % COLORBARI
    return
end

a1 = args{1};
if ~ischar(a1)
    % COLORBARI(H,'off')
    % COLORBARI(H,'hide')
    % COLORBARI(H,'delete')

    if ~ishandle(a1) || ~strcmpi(get(a1,'type'),'axes')
        error('H must be an axes handle.');
    end
    if Nargs~=2
        % COLORBARI(H)
        % COLORBARI(H,str,more)  (where str='off','hide','delete')
        error('Unrecognized input or invalid parameter/value pair arguments.');
    end
    a2 = args{2};
    opts = cl.keywords(2:4); %'off','hide','delete'
    sel = strcmpi(a2,opts);
    if ~any(sel)
        error('Unknown command option.');
    end
    cl.colorbarAxes = a1;
    cl.deleteThis = true;
    
    if Nout>0
        error(message('siglib:sigutils:internal:colorbari:TooManyOutputs'));
    end
    return
end

idx = find(strcmpi(a1,cl.keywords));
if isempty(idx)
    % COLORBARI(P/V Pairs)
    %
    % String did not match one of the defined keywords.
    % It could be the param name for a P/V pair:
    if rem(Nargs,2)~=0
        % We don't have pairs of args.
        % Can't be a valid set of P/V pairs:
        error('Unrecognized input or invalid parameter/value pair arguments.');
    end
    % pairs - assume it's valid P/V pairs:
    cl.pvPairs = args;
    return
end

if any(idx==2:4)
    % COLORBARI('off'), COLORBARI('hide'), COLORBARI('delete')
    % Ignore any remaining args for this syntax
    
    cl.deleteAll = true;
    if Nargs~=1
        error('Unrecognized input or invalid parameter/value pair arguments.');
    end
    
    if Nout>0
        error(message('siglib:sigutils:internal:colorbari:TooManyOutputs'));
    end
    return
end

% Args to parse:
argsRemaining = args;

end

function locIdx = getLocationIdx(locIdxOrStr)

% These strings must match enum order:
locs = {'NorthOutside','SouthOutside','WestOutside','EastOutside', ...
    'North','South','West','East'};
Nlocs = numel(locs);

if ischar(locIdxOrStr)
    % Location string passed
    locIdx = find(strcmpi(locIdxOrStr,locs));
    if isempty(locIdx)
        error('Location not recognized: "%s".',locIdxOrStr);
    end
else
    % locationIdx passed
    if (locIdxOrStr<1) || (locIdxOrStr>Nlocs) || ...
            (locIdxOrStr ~= fix(locIdxOrStr))
        error('Invalid location index (%d).',loIdxOrStr);
    end
    locIdx = locIdxOrStr;
end

end

function setColorbarAndPeerPos(s)
% Return new position of colorbar axes and peer axes, based on locationIdx.

% Abandon automatic position changes if position manually specified
if s.PositionPropertySpecified
    return
end

% Disable peerAxes Position property listeners before changing position
%
lis = getappdata(s.ColorbarAxes,'ColorbariListeners');
if ~isempty(lis)
    lis.PeerAxesPos.Enabled = false;
end

% Restore peer axes to original position.
peerAxes = s.PeerAxes;
peerUnits_orig = get(peerAxes,'Units'); % before making changes to units
colorbarUnits_orig = get(s.ColorbarAxes,'Units');
set(peerAxes, ...
    'Units',s.PeerAxesOrigUnits, ...
    'Position',s.PeerAxesOrigPos);

% Get peer axes attribs, get pixel position:
set(peerAxes,'Units','pixels');
set(s.ColorbarAxes,'Units','pixels');

% Use TightInset to make room for tick labels, etc.
% Returns [dx_left dy_bottom dx_right dy_top]
pti = get(peerAxes,'TightInset');

% Choose # pixels across color image.
%
% A smaller peer axes is best served with smaller colorbar breadth,
% and vice-versa.  Maybe compute
%
d = 28; % fixed # of pixels across colorbar image
b = 6;  % # pixels additional gutter size for 'outside' locations
p = get(peerAxes,'Position');

% Compute position of new colormap axes
switch s.LocationIdx
    case 1 % northoutside
        % Horizontal colorbar @ top
        %    add colorbar at top
        %    shrink peer at top
        g = pti(4)+b;
        peerPos_new = [p(1) p(2) p(3) p(4)-d-g];
        cbarPos_new = [p(1) p(2)+p(4)-d p(3) d];
        
    case 2 % southoutside
        % Horizontal colorbar
        %  add colorbar to bottom
        %  shrink peer at bottom
        g = pti(2)+b;
        peerPos_new = [p(1) p(2)+g+d p(3) p(4)-d-g];
        cbarPos_new = [p(1:3) d];
        
    case 3 % westoutside
        % Vertical colorbar on left
        %   add colorbar to left
        %   shrink peer width on left
        g = pti(1)+b;
        peerPos_new = [p(1)+d+g p(2) p(3)-d-g p(4)];
        cbarPos_new = [p(1) p(2) d p(4)];
        
    case 4 % eastoutside
        % Vertical colorbar on right
        %   shrink peer width on right
        %   append colorbar to right
        g = pti(3)+b;
        peerPos_new = [p(1) p(2) p(3)-d-g p(4)];
        cbarPos_new = [p(1)+p(3)-d p(2) d p(4)];
        
    case 5 % north inside
        % Inside means maintain original peerAxes position:
        %    add colorbar at top
        %    shrink peer at top
        peerPos_new = p;
        cbarPos_new = [p(1) p(2)+p(4)-d p(3) d];
        
    case 6 % south inside
        % Inside means maintain original peerAxes position.
        % Colorbar overlays bottom of peerAxes position.
        peerPos_new = p;
        cbarPos_new = [p(1:3) d];

    case 7 % west inside
        % Inside means maintain original peerAxes position.
        % Vertical colorbar on left
        %   add colorbar to left
        peerPos_new = p;
        cbarPos_new = [p(1) p(2) d p(4)];

    case 8 % east inside
        % Inside means maintain original peerAxes position:
        % Colorbar overlays right of peerAxes position:
        peerPos_new = p;
        cbarPos_new = [p(1)+p(3)-d p(2) d p(4)];

    otherwise
        error('Unsupported location index %d',locationIdx);
end

set(s.ColorbarAxes,'Position',cbarPos_new);
set(peerAxes,'Position',peerPos_new);
set(peerAxes,'Units',peerUnits_orig);
set(s.ColorbarAxes,'Units',colorbarUnits_orig);

if ~isempty(lis)
    lis.PeerAxesPos.Enabled = true;
end

end

function ResizeFigure(peerAxes)

s = getappdata(peerAxes,'ColorbariInfo');
setColorbarAndPeerPos(s);

% Resize the indicator (if visible)
updateIndicator_i(peerAxes);

end

function changeLocationCB(~,~,hThisMenu)
% Callback for location change.

% Reset checks on all location menu items:
if nargin<3
    hThisMenu = gcbo; % context menu handle
end
hAllMenus = get(hThisMenu,'UserData');
set(hAllMenus,'Checked','off');
set(hThisMenu,'Checked','on');

% Update figure location:
peerAxes = getappdata(hThisMenu,'ColorbariPeerAxes');

% Translate menu label to enum string
str = lower(get(hThisMenu,'Label'));
switch str
    case 'outside north'
        enum = 'northoutside';
    case 'outside south'
        enum = 'southoutside';
    case 'outside west'
        enum = 'westoutside';
    case 'outside east'
        enum = 'eastoutside';
    case {'north','south','west','east'}
        enum = str;
end
changeLocation(peerAxes, enum);

end

function changeLocation(peerAxes,locStrOrIdx)
% Change location of colorbar.
%
% Also used to update colorbar after an external change in colormap.

% Update .LocationIdx in cache, if needed
s = getappdata(peerAxes,'ColorbariInfo');
if nargin>1
    s.LocationIdx = getLocationIdx(locStrOrIdx);
    setappdata(peerAxes,'ColorbariInfo',s);
end

% Update axes ticks (visibility, location, direction)
%
% Do this BEFORE setting new positions, as TightInset is being used and is
% affected by tick mark locations.

axisTitlePresent = ~isempty(get(get(peerAxes,'title'),'string'));
cbarAxes = s.ColorbarAxes;
switch s.LocationIdx
    case 1 % northoutside
        % Set x-axis location for primary (long-side) tickmarks.
        % Set y-axis location for title string, if specified.
        yloc = get(peerAxes,'YAxisLocation');
        set(cbarAxes,'XAxisLocation','top','YAxisLocation',yloc);
        isHoriz = true;
        
    case 5 % north (inside)
        % Set x-axis location for primary (long-side) tickmarks.
        % Set y-axis location for title string, if specified.
        yloc = get(peerAxes,'YAxisLocation');
        if strcmpi(get(peerAxes,'vis'),'off')
            xloc = 'bottom'; % inside the box
        else
            % A title could be visible, in which case we prevent overlap of
            % colorbar axis ticks and the title by switching sides, just as
            % if the peeraxis ticks were on top.
            if axisTitlePresent || strcmpi(get(peerAxes,'XAxisLocation'),'top')
                xloc = 'bottom'; % deep inside
            else
                xloc = 'top';
            end
        end
        set(cbarAxes,'XAxisLocation',xloc,'YAxisLocation',yloc);
        isHoriz = true;
        
    case 2 % southoutside
        yloc = get(peerAxes,'YAxisLocation');
        set(cbarAxes,'XAxisLocation','bottom','YAxisLocation',yloc);
        isHoriz = true;
        
    case 6 % south (inside)
        yloc = get(peerAxes,'YAxisLocation');
        if strcmpi(get(peerAxes,'vis'),'off')
            xloc = 'top'; % inside the box
        else
            if strcmpi(get(peerAxes,'XAxisLocation'),'top')
                xloc = 'bottom';
            else
                xloc = 'top'; % deep inside
            end
        end
        set(cbarAxes,'XAxisLocation',xloc,'YAxisLocation',yloc);
        isHoriz = true;
        
    case 3 % westoutside
        xloc = get(peerAxes,'XAxisLocation');
        set(cbarAxes,'YAxisLocation','left','XAxisLocation',xloc);
        isHoriz = false;
        
    case 7 % west (inside)
        xloc = get(peerAxes,'XAxisLocation');
        if strcmpi(get(peerAxes,'vis'),'off')
            yloc = 'right'; % inside the box
        else
            if strcmpi(get(peerAxes,'YAxisLocation'),'left')
                yloc = 'right'; % deep inside
            else
                yloc = 'left';
            end
        end
        set(cbarAxes,'YAxisLocation',yloc,'XAxisLocation',xloc);
        isHoriz = false;
        
    case 4 % eastoutside
        xloc = get(peerAxes,'XAxisLocation');
        set(cbarAxes,'YAxisLocation','right','XAxisLocation',xloc);
        isHoriz = false;
        
    case 8 % east (inside)
        xloc = get(peerAxes,'XAxisLocation');
        if strcmpi(get(peerAxes,'vis'),'off')
            yloc = 'left'; % inside the box
        else
            if strcmpi(get(peerAxes,'YAxisLocation'),'right')
                yloc = 'left';  % deep inside
            else
                yloc = 'right';
            end
        end
        set(cbarAxes,'YAxisLocation',yloc,'XAxisLocation',xloc);
        isHoriz = false;
end

% Change colorbar axes and image
%  - Preserve range of colormap axes.
%    (Do NOT rescale to the "stretch" range.)
dr = s.ColormapAxesLimits;
if isHoriz
    set(cbarAxes, ...
        'XTickLabelMode','auto', ...
        'XTickMode','auto', ...
        'XDir','normal', ...
        'YTickLabel','', ...
        'YTick',[], ...
        'YLim',[0 1], ...
        'XLim',dr);
    set(s.ColorbarImage, ...
        'XData',dr, ...
        'CData',1:s.ColormapLength);
else % vertical colorbar
    set(cbarAxes, ...
        'YTickLabelMode','auto', ...
        'YTickMode','auto', ....
        'YDir','normal', ...
        'XTickLabel','', ...
        'XTick',[], ...
        'XLim',[0 1], ...
        'YLim',dr);
    set(s.ColorbarImage, ...
        'YData',dr, ...
        'CData',(1:s.ColormapLength)');
end

% Now change colorbar position:
setColorbarAndPeerPos(s);

% Install user P/V pairs on colorbar axes.
% Conditions:
%  - Axes are in place, as well as menus.
%  - No listeners or mouse behaviors are installed.
%
% NOTE: This can fail due to user-specified param names and values.
% NOTE: Do not execute the "set" if .pvPairs is empty.  It's not an error,
% but it will cause "set" to display the current properties in the command
% window.
if ~isempty(s.PVPairs)
    try
        set(s.ColorbarAxes,s.PVPairs{:});
    catch me
        deleteColorbar(peerAxes); % Remove colorbar due to failure
        throwAsCaller(me);
    end
end

% Render title strings in center tick of x- or y-axis
%
if isHorizontalCbar(s)
    % Put short title as a single yticklabel in the middle of the y axis
    set(cbarAxes,'ytick',sum(get(cbarAxes,'ylim'))/2,'yticklabel',s.TitleShort);
    
    % Put long title as a label
    set(get(cbarAxes,'xlabel'),'string',s.TitleLong);
    set(get(cbarAxes,'ylabel'),'string','');
    
else
    % Put short title as a single xticklabel in the middle of the x axis
    set(cbarAxes,'xtick',sum(get(cbarAxes,'xlim'))/2,'xticklabel',s.TitleShort);
    
    % Put long title as a lablel
    set(get(cbarAxes,'ylabel'),'string',s.TitleLong);
    set(get(cbarAxes,'xlabel'),'string','');
end

% If an optional indicator is being displayed, update it for the new
% location/orientation
updateIndicator_i(peerAxes);

% Manually execute resize to get consistent dimensioning
%ResizeFigure(peerAxes); % xxx

end

function enableModeManagerListeners(hfig,en)
% Enable or disable the mode manager listeners for rotate3d, zoom, pan and
% edit. Without this, rotate3d will warn if it is enabled and the callbacks
% change.

    if isactiveuimode(hfig,'Exploration.Rotate3d') || ...
            isactiveuimode(hfig,'Exploration.Zoom') || ...
            isactiveuimode(hfig,'Exploration.Pan') || ...
            isactiveuimode(hfig,'Standard.EditPlot') 
        mm = uigetmodemanager(hfig);
        for k=1:length(mm.WindowListenerHandles)
            mm.WindowListenerHandles(k).Enabled = en;
        end    
    end 
end

function s = create_colorbar(s)
% Create colorbar

peerAxes = s.PeerAxes;
if isHorizontalCbar(s)
    data = 1:s.ColormapLength;
else
    data = (1:s.ColormapLength)';
end

% Create colorbar widgets
%
% NOTES:
%   - Set HiddenHandle so mouse interactions for rotation (via
%   cameratoolbar, for example) will not accidentally be applied to the
%   colorbar itself.
%   - Set Tag to 'Colorbar' for compatibility with standard colorbar fcn.
%
% - Axes:
default_cbarPos = [10 10 24 200]; % anything valid is fine
hax_cbar = axes( ...
    'Parent',s.ColorbarParent, ...
    'Units',get(ancestor(s.ColorbarParent,'figure'),'Units'), ...
    'Position',default_cbarPos, ...
    'FontName',get(peerAxes,'FontName'), ...
    'FontSize',get(peerAxes,'FontSize'), ...
    'xlim',[0 1], ...
    'ylim',[0 1], ...
    'Box','on', ...
    'Tag','Colorbar', ...
    'Tickdir','in', ...
    'Layer','top', ...
    'HitTest','off', ...
    'HandleVisibility','off', ...
    'Interruptible','off', ...
    'vis','off');

% Leave breadcrumb that allows navigation from hax_cbar back to peerAxes,
% where all the ColorbariInfo is stored.
setappdata(hax_cbar,'ColorbariPeerAxes',peerAxes);

% - Image:
%   Don't disable HitTest on image, as it disables context menu that we
%   want to support on the colorbar image
%
himage_cbar = image(...
    'Parent',hax_cbar, ...
    'xdata',[0 1],...
    'ydata',[0 1], ...
    'cdata', data, ...
    'CDataMapping','scaled', ...
    'Interruptible','off', ...
    'vis','off', ...
    'HandleVisibility','off');

% Create indicator patch.
%
% UserData is last value displayed, empty=not displayed
%
s.Indicator = patch( ...
    'Parent',hax_cbar, ...
    'FaceColor','w', ...
    'FaceAlpha',0.5, ...
    'EdgeAlpha',1, ...
    'EdgeColor','k', ...
    'vis','off', ...
    'UserData',[]);

% Store new axes into struct:
s.ColorbarAxes = hax_cbar;
s.ColorbarImage = himage_cbar;
setappdata(peerAxes,'ColorbariInfo',s);

changeLocation(peerAxes);

% Show colorbar axes and image.
%
% Do this after P/V pair handling (done in changeLocation), so we guarantee
% visibility.
set([hax_cbar himage_cbar],'vis','on');

end

function cb = getCachedWindowButtonCbFcns(peerAxes)

s = getappdata(peerAxes,'ColorbariInfo');
cb = s.PrevWindowButtonFcns;

end

function cacheWindowButtonCbFcns(peerAxes)
% Retain the current window button (down/motion/up/scroll) callbacks. We
% change/reinstall these based on mode changes to colorbar.

s = getappdata(peerAxes,'ColorbariInfo');
hfig = ancestor(s.ColorbarAxes,'figure');

s.dn     = get(hfig,'WindowButtonDownFcn');
s.motion = get(hfig,'WindowButtonMotionFcn');
s.up     = get(hfig,'WindowButtonUpFcn');
s.scroll = get(hfig,'WindowScrollWheelFcn');
s.PrevWindowButtonFcns = s;
setappdata(peerAxes,'ColorbariInfo',s);

end

function cacheWindowButtonCbFcns_update(peerAxes,typ)
% Update cache based on changed window button callback functions

% Update cache:
s = getappdata(peerAxes,'ColorbariInfo');
hfig = ancestor(s.ColorbarAxes,'figure');
fcns = s.PrevWindowButtonFcns;
switch typ
    case 'down'
        fcns.dn     = get(hfig,'WindowButtonDownFcn');
    case 'motion'
        fcns.motion = get(hfig,'WindowButtonMotionFcn');
    case 'up'
        fcns.up     = get(hfig,'WindowButtonUpFcn');
    case 'scroll'
        fcns.scroll = get(hfig,'WindowScrollWheelFcn');
end
s.PrevWindowButtonFcns = fcns;
setappdata(peerAxes,'ColorbariInfo',s);

end

function changeMouseBehavior(peerAxes,mouseBehavior)
% Change mouse behavior by installing callbacks/events based on selected
% mode.

% Update which mouse behavior we are installing, so we can repeat it if
% button callbacks change behind our backs.
s = getappdata(peerAxes,'ColorbariInfo');
if nargin<2
    mouseBehavior = s.LastMouseBehavior;
else
    s.LastMouseBehavior = mouseBehavior;
    setappdata(peerAxes,'ColorbariInfo',s);
end

if strcmpi(mouseBehavior,'none') && strcmpi(mouseBehavior,s.LastMouseBehavior)
    % No change, minor optimization.
    %
    % However, if both strings are 'init', this is likely to be the
    % startup/init sequence.  In that case, we must return early to prevent
    % access to un-initialized states such as getCached<blah>.
    return
end

% Install new behavior
switch lower(mouseBehavior)
    case 'none'
        % Disable all of our mouse event listeners.
        % Enable all user mouse callback fcns.
        
        dnEvent     = [];
        motionEvent = [];
        upEvent     = [];
        scrollEvent = [];
        
        s = getCachedWindowButtonCbFcns(peerAxes);
        dnFcn       = s.dn;
        motionFcn   = s.motion;
        upFcn       = s.up;
        scrollFcn   = s.scroll;
        
    case 'general'
        % Enable only our motion event listener.
        % Enable the remaining user's mouse callback fcns.
        
        dnEvent     = [];
        motionEvent = @(src,ev)wbmotion_general(src,ev,peerAxes);
        upEvent     = [];
        scrollEvent = [];
        
        s = getCachedWindowButtonCbFcns(peerAxes);
        dnFcn     = s.dn;
        motionFcn = [];
        upFcn     = s.up;
        scrollFcn = s.scroll;
        
    case 'cmap'
        % Enable our down/motion event listeners.
        % Disable all of user's mouse callback fcns.
         
        dnEvent     = @(src,ev)wbdown_cmap(src,ev,peerAxes);
        motionEvent = @(src,ev)wbmotion_cmap(src,ev,peerAxes);
        upEvent     = [];
        scrollEvent = @(src,ev)wbscroll_cmap(src,ev,peerAxes);
        
        dnFcn     = [];
        motionFcn = [];
        upFcn     = [];
        scrollFcn = [];
        
    case 'cmap_buttondown'
        % Enable our motion/up event listeners.
        % Disable all user mouse callback fcns.
        
        dnEvent     = [];
        motionEvent = @(fig,ev)wbdrag_cmap(fig,ev,peerAxes);
        upEvent     = @(fig,ev)wbup_cmap(fig,ev,peerAxes);
        scrollEvent = [];
        
        dnFcn     = [];
        motionFcn = [];
        upFcn     = [];
        scrollFcn = [];
        
    otherwise
        error('Unrecognized cursor type');
end

% Install window button callback fcns
%
% Disable listeners on these properties, since this is "us" making the
% change and we don't need/want to track our own modifications.  Only
% "external" changes are to be tracked.
lis = getappdata(s.ColorbarAxes,'ColorbariListeners');
lisW = lis.WindowButtonCbFcns;
for i = 1:numel(lisW)
    lisW(i).Enabled = false; % disable listeners
end

enableModeManagerListeners(ancestor(peerAxes,'figure'),false);

%warning('off','MATLAB:modes:mode:InvalidPropertySet')
hfig = ancestor(s.ColorbarAxes,'figure');
hfig.WindowButtonDownFcn   = dnFcn;
hfig.WindowButtonMotionFcn = motionFcn;
hfig.WindowButtonUpFcn     = upFcn;
hfig.WindowScrollWheelFcn  = scrollFcn;
%warning('on','MATLAB:modes:mode:InvalidPropertySet')

enableModeManagerListeners(ancestor(peerAxes,'figure'),true);

for i = 1:numel(lisW)
    lisW(i).Enabled = true;  % re-enable listeners
end

% Install window button events
if isempty(dnEvent)
    lis.WindowButtonEvents(1).Enabled = false;
else
    lis.WindowButtonEvents(1).Callback = dnEvent;
    lis.WindowButtonEvents(1).Enabled = true;
end
if isempty(motionEvent)
    lis.WindowButtonEvents(2).Enabled = false;
else
    lis.WindowButtonEvents(2).Callback = motionEvent;
    lis.WindowButtonEvents(2).Enabled = true;
end
if isempty(upEvent)
    lis.WindowButtonEvents(3).Enabled = false;
else
    lis.WindowButtonEvents(3).Callback = upEvent;
    lis.WindowButtonEvents(3).Enabled = true;
end
if isempty(scrollEvent)
    lis.WindowButtonEvents(4).Enabled = false;
else
    lis.WindowButtonEvents(4).Callback = scrollEvent;
    lis.WindowButtonEvents(4).Enabled = true;
end

end

function isChange = changePtr(peerAxes, newPtr)

% See if current pointer is same as requested:
s = getappdata(peerAxes,'ColorbariInfo');
isChange = ~strcmp(s.CursorPointer,newPtr);
if isChange
    setptr(ancestor(s.ColorbarAxes,'figure'),newPtr);
    s.CursorPointer = newPtr;
    setappdata(peerAxes,'ColorbariInfo',s);
end

end

function ret = over_cmap(peerAxes)
% Is pointer hovering over colorbar axes?

s = getappdata(peerAxes,'ColorbariInfo');
cbax = s.ColorbarAxes;

% Bounds around data, inner box:
oldunits = cbax.Units;
cbax.Units = 'Normalized';
posBar = get(cbax,'Position'); % Always get normalized position
cbax.Units = oldunits;
% Bounds around data plus ticks, labels:
%   [dx_left dy_bottom dx_right dy_top]
ti = get(cbax,'TightInset');

% Add TightInset to include hovering only the tick labels,
% only the one side on which they appear.
switch s.LocationIdx
    case {1,2,5,6}
        % north, northoutside
        % south, southoutside
        isHoriz = true;
        
        % P/V pair could have been specified that forced axis location to a
        % certain side.
        if strcmpi(get(cbax,'XAxisLocation'),'top')
            % Include tight inset on top
            posWhole = posBar + [0 0 0 ti(4)];
        else
            % Include tight inset on bottom
            posWhole = posBar + [0 -ti(2) 0 ti(2)];
        end
        
    otherwise % {3,4,7,8}
        % west, westoutside
        % east, eastoutside
        isHoriz = false;
        if strcmpi(get(cbax,'YAxisLocation'),'right')
            % Include tight inset on right
            posWhole = posBar + [0 0 ti(3) 0];
        else
            % Include tight inset on left
            posWhole = posBar + [-ti(1) 0 ti(1) 0];
        end
end

% Get mouse location relative to figure
f = ancestor(s.ColorbarAxes,'figure');

% Get mouse pointer in normalized units, then compare to pos limits
oldunits = f.Units;
f.Units = 'Normalized';
cp = f.CurrentPoint; % up-to-date via code in mouse handler event
f.Units = oldunits;
xrel = cp(1,1);
yrel = cp(1,2);

% True if over the colormap image (smaller region, just the colors)
isOverCbar = (xrel>=posBar(1)) && (yrel>=posBar(2)) ...
    && (xrel<=posBar(1)+posBar(3)) && (yrel<=posBar(2)+posBar(4));

% True if over the the colormap image or axes ticks (larger region)
isOverWhole = (xrel>=posWhole(1)) && (yrel>=posWhole(2)) ...
    && (xrel<=posWhole(1)+posWhole(3)) && (yrel<=posWhole(2)+posWhole(4));

isOverTicks = isOverWhole & ~isOverCbar;

if isOverWhole
    % Use PointerLocation to determine relative pos within colorbar axes.
    % xrel and yrel are normalized coords.
    %
    % isFarHalfCmap is true if ptr exceeds midpt of mapped color range
    
    % Linear interpolation of axes limits, based on frac
    %   - relies on .ColormapAxesLimits being a row vector
    if isHoriz
        frac_pos = (xrel-posBar(1))/posBar(3);
    else
        frac_pos = (yrel-posBar(2))/posBar(4);
    end
    cp = s.ColormapAxesLimits * [1-frac_pos; frac_pos];    
    
    if isOverTicks
        isFarHalfCmap = frac_pos > 0.5;
        orig_dr = [];
    else
        % Over colorbar
        %
        % Use current colobar limits --- that' what "half" means to
        % the customer who is hovering over the colorbar.
        isFarHalfCmap = frac_pos > sum(s.ColormapColorStretch)/2;
        orig_dr = getCLimBasedOnColorbar(peerAxes);
    end
else
    % Mouse not within colorbar axes
    frac_pos = [];
    cp = [];
    orig_dr = [];
    isFarHalfCmap = false;
end
ret.colorbarAxes  = cbax;
ret.isFarHalfCmap = isFarHalfCmap;
ret.isHoriz       = isHoriz;
ret.isOverTicks   = isOverTicks;
ret.isOverWhole   = isOverWhole;
ret.orig_dr       = orig_dr;
ret.orig_frac     = frac_pos;
ret.relPoint      = cp;

end

function change_CLim_colorbar(s)
% Install new colormap color range.
%   - new_dr: new range for color region, [low high],
%             in data units of peerAxes.
%   - Assumes peerAxes has had its 'CLim' value updated.
%   - We react to the new dynamic range for the colorbar itself.
%
% Use change_CLim_colorbar_and_peer() if peerAxes also needs to be changed.

% How to change the colormap:
% For peerAxes,
% - CLim of peerAxes is new range limit, expressed in data units
%   * done in change_CLim_colorbar_and_peer(), not here
% For colorbar,
% - CLim of colorbar is more complicated
%    * colorbar image has values 1:N
%    * new_dr is data range over which colors should span
%    * CLim scaling on colorbar uses 1:N as default,
%      but varies from 1:N in proportion to the "squeeze"
%      being requested by user

if ~isstruct(s)
    s = getappdata(s,'ColorbariInfo');
end
set(s.ColorbarAxes,'CLim', ...
    1 + s.ColormapColorStretch.*(s.ColormapLength-1));

end

function change_CLim_colorbar_and_peer(peerAxes)
% Set new colormap limits to dynamic range [lo hi], specified in data
% units for the peerAxes.

if isstruct(peerAxes)
    s = peerAxes;
    peerAxes = s.PeerAxes;
else
    s = getappdata(peerAxes,'ColorbariInfo');
end

% Disable "external" PeerAxes CLim listener (listening for cmap editor)
lis = getappdata(s.ColorbarAxes,'ColorbariListeners');
lis.PeerAxesCLim.Enabled = false;
%
% Set new dynamic range limits into main image
peerAxes.CLim = getCLimBasedOnColorbar(peerAxes);
%
% Restore PeerAxes CLim listener:
lis.PeerAxesCLim.Enabled = true;

change_CLim_colorbar(s); % can pass s instead of peerAxes

end

function reset_CLim_colorbar_and_peer(peerAxes,axLim)
% Reset colormap based on specified dynamic range of data in peer axes.
% - Resets both colorbar tick range and color stretch
% - Computes data range if axLim is not specified

s = getappdata(peerAxes,'ColorbariInfo');
if nargin < 2
    % Get data limits from content within peer axes
    %axLim = get_data_range(ancestor(peerAxes,'figure'),peerAxes);
    axLim = s.PeerAxesOrigCLim;
end
s.ColormapAxesLimits = axLim;
s.ColormapColorStretch = [0 1];
setappdata(peerAxes,'ColorbariInfo',s);

change_colorbar_tickrange(peerAxes);
change_CLim_colorbar_and_peer(peerAxes);

end

function change_colorbar_tickrange(peerAxes,range)
% Change ticks on colorbar, not colorbar image.

s = getappdata(peerAxes,'ColorbariInfo');
if nargin<2
    range = s.ColormapAxesLimits;
else
    % Basic protection from out-of-bounds ranges.
    % These can be caused by mouse drags gone to extremes.
    if any(isinf(range)) || ~ismatrix(range)
        return
    end
    s.ColormapAxesLimits = range;
    setappdata(peerAxes,'ColorbariInfo',s);
end

% Update colorbar axes limits
if isHorizontalCbar(s)
    s.ColorbarAxes.XLim = range;
    s.ColorbarImage.XData = range;
else
    s.ColorbarAxes.YLim = range;
    s.ColorbarImage.YData = range;
end

change_CLim_colorbar_and_peer(peerAxes);

% update to preserve aspect ratio of indicator triangle
updateIndicator_i(peerAxes);

end

function FigKeyEvent(ev,peerAxes,isKeyPressed)
% Called while a key is pressed AND the mouse is over the colorbar.
% At no other time should this get invoked.

if isKeyPressed
    isShiftPressed = strcmpi(ev.Key,'shift');
    %isCtrlPressed = strcmpi(ev.Key,'control');
    isCtrlPressed  = false; % disable control-key usage
else
    isShiftPressed = false;
    isCtrlPressed  = false;
end

s = getappdata(peerAxes,'ColorbariInfo');
isHoriz = isHorizontalCbar(s);

if isShiftPressed
    if isHoriz
        ptr = 'lrdrag';
    else
        ptr = 'uddrag';
    end
else
    ret = over_cmap(peerAxes);
    if isHoriz
        if ret.isFarHalfCmap
            ptr = 'rdrag';
        else
            ptr = 'ldrag';
        end
    else
        if ret.isFarHalfCmap
            ptr = 'udrag';
        else
            ptr = 'ddrag';
        end
    end
end

changePtr(peerAxes,ptr);
setappdata(peerAxes,'ColorbariCmapKey',[isShiftPressed isCtrlPressed]);

end

function y = isHorizontalCbar(s)
% True if colorbar has horizontal orientation.
% s is the info struct.

% Colorbar is horizontal for:
%    northoutside, southoutside, north, south
y = any(s.LocationIdx == [1 2 5 6]);

end

function wbmotion_general(src,ev,peerAxes)
% General button motion over non-colorbar region
%
% Determines if cursor is over colorbar.
% - If so, changes pointer and mouse callbacks.
% - If not, changes to normal cursor and general callbacks, and
%   executes cached motion callback from underlying figure (if any).

% Force axis CurrentPoint to update:
src.CurrentPoint = ev.Point;

ret = over_cmap(peerAxes);
if ret.isOverWhole
    % Just moved over the colormap axes.
    % We enter here once, then change to wbmotion_cmap.
    
    % Enable key listeners for SHIFT detection
    s = getappdata(peerAxes,'ColorbariInfo');
    lis = getappdata(s.ColorbarAxes,'ColorbariListeners');
    lisW = lis.WindowKeyPressEvents;
    for i = 1:numel(lisW)
        lisW(i).Enabled = true;
    end
    
    % Just change the mouse behavior, engaging wbmotion_cmap on the next
    % movement.  That function will change the pointer, etc.
    
    enableModeManagerListeners(src,false);

    changeMouseBehavior(peerAxes,'cmap');
    
    % We don't know if shift is being held.
    %
    % Key-state ('ColorbariCmapKey') will show retain state of last special
    % key before mouse last left the colorbar region.
    %
    % So key-state could be stale.  Worst case: it could indicate
    % "shift/control key held", but shift/control key was actually dropped
    % before returning mouse to the cmap region. So we assume shift/control
    % were dropped now, just for safety. If we're wrong, key-repetition
    % will quickly update that state.
    FigKeyEvent([],peerAxes,false); % false->force "no special keys"

    % Kick it manually once, to get cursor to change shape, etc
    wbmotion_cmap(peerAxes);
else
    % Invoke cached motion fcn
    s = getCachedWindowButtonCbFcns(peerAxes);
    motionFcn = s.motion;
    if ~isempty(motionFcn)
        if iscell(motionFcn)
            feval(motionFcn{1},src,ev,motionFcn{2:end});
        else
            feval(motionFcn,src,ev);
        end
    end
    
    enableModeManagerListeners(src,true);
end

end

function wbmotion_cmap(src,ev,peerAxes)
% Mouse motion over colorbar.
% No mouse button pressed (yet).

if nargin==1
    % Called from some other local function
    peerAxes = src;
else
    % Called from event handler
    %
    % Force axis CurrentPoint to update:
    src.CurrentPoint = ev.Point;
end

ret = over_cmap(peerAxes);
cbax = ret.colorbarAxes;
if ret.isOverWhole
    % Over colorbar axes
    
    % Use bold font when over ticks
    isBold = strcmpi(get(cbax,'fontweight'),'bold');
    if ret.isOverTicks
        if ~isBold
            cbax.FontWeight = 'bold';
        end
    else
        if isBold
            cbax.FontWeight = 'normal';
        end
    end
    
    % Handle pointer
    isSpecialKey = getappdata(peerAxes,'ColorbariCmapKey');
    isShiftPressed = isSpecialKey(1);
    if ret.isHoriz
        if isShiftPressed
            newPtr = 'lrdrag';
        elseif ret.isFarHalfCmap
            newPtr = 'rdrag';
        else
            newPtr = 'ldrag';
        end
    else % vertical cmap
        if isShiftPressed
            newPtr = 'uddrag';
        elseif ret.isFarHalfCmap
            newPtr = 'udrag';
        else
            newPtr = 'ddrag';
        end
    end
    if changePtr(peerAxes,newPtr)
        changeMouseBehavior(peerAxes,'cmap');
    end
else
    % Not over colorbar
    if changePtr(peerAxes,'arrow') % should always be true here
        % Install new mouse behaviors
        changeMouseBehavior(peerAxes,'general');

        % Reset graphical depiction of hover over ticks,
        % if it was last set:
        cbax.FontWeight = 'normal';

        % Disable listeners for SHIFT KEY detection
        lis = getappdata(cbax,'ColorbariListeners');
        lisW = lis.WindowKeyPressEvents;
        for i = 1:numel(lisW)
            lisW(i).Enabled = false;
        end
        
        % Make peerAxes the current axes.
        %
        % This prevents accidental focus on colorbar axes, which should be
        % "invisible" to external application code running in the figure.
        %
        % Example failure: rotation of the colorbar itself can occur
        %   when cameratoolbar rotation re-engages.
        set(ancestor(peerAxes,'figure'),'CurrentAxes',peerAxes);
    end
end

end

function wbdown_cmap(fig,ev,peerAxes)
% Mouse button is down over the colormap.

% Right-click on context menu can send a "button down" event or
% callback.  We need to filter out the "right click" that is
% received by wbdown_cmap to remedy this.
%
% However, a right-click should look like a SelectionType of "alt",
% enabling us to filter it out, but the Event call shows a
% SelectionType of 'normal'.  Only the Fcn call shows the correct
% 'alt' attribute.
%
% Therefore:
%    use dnFcn, not dnEvent
%    filter out calls with SelectionType='alt'
%
% See corresponding changes in changeMouseBehavior().
if strcmpi(get(fig,'SelectionType'),'alt')
    return
end

% Force axis CurrentPoint to update:
fig.CurrentPoint = ev.Point;

ret = over_cmap(peerAxes);
s = getappdata(peerAxes,'ColorbariInfo');
specialKeyState = getappdata(peerAxes,'ColorbariCmapKey');

s.cbar.isOverWhole       = ret.isOverWhole;
s.cbar.isOverTicks       = ret.isOverTicks;
s.cbar.StartInTop        = ret.isFarHalfCmap;
s.cbar.ShiftWasPressed   = specialKeyState(1);
s.cbar.ControlWasPressed = specialKeyState(2);
s.cbar.tickRange         = s.ColormapAxesLimits;
s.cbar.origPt            = ret.relPoint;
s.cbar.origFrac          = ret.orig_frac;
s.cbar.origStretch       = s.ColormapColorStretch;

setappdata(peerAxes,'ColorbariInfo',s);

changeMouseBehavior(peerAxes,'cmap_buttondown');

end

function wbdrag_cmap(fig,ev,peerAxes)
% WBDRAG_CMAP Graphical change to colormap dynamic range limits
%  Drag on colormap image.

% Force axis CurrentPoint to update:
fig.CurrentPoint = ev.Point;

% If shift state changed during drag, restart drag as if mouse button was
% just pressed:
s = getappdata(peerAxes,'ColorbariInfo');
specialKeyPressed = getappdata(peerAxes,'ColorbariCmapKey');
isShiftPressed = specialKeyPressed(1);
isControlPressed = specialKeyPressed(2);

if xor(isShiftPressed,s.cbar.ShiftWasPressed) ...
        || xor(isControlPressed,s.cbar.ControlWasPressed)
    % Special key changed state while dragging.
    %
    % Emulate button releasing while old key-state continued, then button
    % going back down with new button-state.
    %
    % No need to explicitly change shift/control state here since
    % wbdown_cmap will do that for us:
    
    wbdown_cmap(fig,ev,peerAxes);
    return
end

% Determine cursor starting and current points ASAP:
hax_cbar = s.ColorbarAxes;
cp = fig.CurrentPoint;
x_fig_norm = cp(1,1);
y_fig_norm = cp(1,2);

% Workaround potential HG bug in ev.Point:
% - when docked, units for ev.Point appear to not respect
%   units of colormap axes
% force colorbar axes units to same as figure
origFigUnit = fig.Units;
origCbarUnit = hax_cbar.Units;
hax_cbar.Units = origFigUnit;
axpos = get(hax_cbar,'Position');
hax_cbar.Units = origCbarUnit;

isHoriz = isHorizontalCbar(s);

if ~s.PositionPropertySpecified
    % Determine "orthogonal" mouse drag
    %  - that is, along the short-axis of the colorbar
    %  - this tells us whether to begin colorbar relocation
    %
    % Only do this if 'position' not specified, since when specified, we
    % disable the ability to change colorbar location.
    if isHoriz
        frac = (y_fig_norm-axpos(2))./axpos(4); % y norm, relative to axes
    else
        frac = (x_fig_norm-axpos(1))./axpos(3); % x norm, relative to axes
    end
    if frac < -1.0 || frac > 2.0
        % Dragged more than one "width" left or right, beyond short-axis of
        % colorbar.  This is no longer a misaligned stretch/translate. This is
        % a relocation event.
        wbdrag_cmap_relocate(s);
        return
    end
end

% Determine "aligned" mouse drag
%  - that is, along the long-axis of the colorbar
%  - this tells us colormap stretch or translate
%
if isHoriz
    frac = (x_fig_norm-axpos(1))./axpos(3); % x norm, relative to axes
else
    frac = (y_fig_norm-axpos(2))./axpos(4); % y norm, relative to axes
end
% Protect frac and 1-frac from becoming an excessive stretch factor.
frac = max(min(abs(frac),0.99),.01);

if s.cbar.isOverTicks || isControlPressed
    % Tick drag, or sync'd tick/colorbar drag
    wbdrag_cmap_tickOnly(s,frac,isShiftPressed);
end

if s.cbar.isOverWhole && ~s.cbar.isOverTicks  || isControlPressed
    % i.e., .isOverColor if it was cached
    
    % Color drag, or sync'd tick/colorbar drag
    %
    % Protected in case mouse wanders out then back in,
    % and we are already in "drag"
    wbdrag_cmap_colorOnly(s,frac,isShiftPressed);
end

end

function wbdrag_cmap_relocate(s)
    % Depending on how close mouse is to axes limits, change pointer or
    % relocate colorbar.
    
    % Get coords:
    peerAxes = s.PeerAxes;
    fig = ancestor(peerAxes,'figure');
    
    cp = fig.CurrentPoint;
    figPos = fig.Position;
    x_fig_norm = cp(1,1)./figPos(3);
    y_fig_norm = cp(1,2)./figPos(4);

    paPos = get(peerAxes,'Position');
    
    % Is current colorbar location "outside" or "regular"?
    isOutside = (s.LocationIdx <= 4);
    
    x0 = paPos(1);
    y0 = paPos(2);
    dx = paPos(3);
    dy = paPos(4);
    % Adjust threshholds based on outside or inside locations:
    if isOutside
        xmin = x0;
        xmax = x0+dx;
        ymin = y0;
        ymax = y0+dy;
    else
        xmin = x0+0.05*dx;
        xmax = x0+0.95*dx;
        ymin = y0+0.05*dy;
        ymax = y0+0.95*dy;
    end
    dN = ymax - y_fig_norm;
    dS = y_fig_norm - ymin;
    dW = x_fig_norm - xmin;
    dE = xmax - x_fig_norm;
    [val,idx] = min([dN dS dW dE]);
    if val<0
        % In drop-zone: change location
        % Need to change location AND check the right context menu
        
        % Get all location context menus
        ch = get(s.LocationContextMenu,'children');
        allLoc = get(ch(1),'userdata');
        
        % Get this particular location context menu
        % Outside locations in first 4 slots, non-outside in last 4:
        if ~isOutside, idx=idx+4; end
        hThisMenu = allLoc(idx);
        
        % Select this context menu, then make the location change:
        changeLocationCB([],[],hThisMenu);
    else
        % Close to drop-zone: just signal the impending change
        switch idx
            case 1, ptr = 'top';
            case 2, ptr = 'bottom';
            case 3, ptr = 'left';
            otherwise, ptr = 'right';
        end
        changePtr(peerAxes,ptr);
    end
end

function wbdrag_cmap_tickOnly(s,frac,isShiftPressed)
% Execute drag action for mouse over colorbar tick region only.
% - Only to be called by wbdrag_cmap()

% Tick drag
dr = s.cbar.tickRange; % cached .ColormapAxesLimits at start of drag
pt = s.cbar.origPt;
if isShiftPressed
    % Range stays, bottom and top move
    newPt = frac*dr(2) + (1-frac)*dr(1);
    dd = newPt - pt; % dx or dy
    new_tickrange = dr - [dd dd];
else
    if s.cbar.StartInTop
        % Bottom stays put, origPt moved to frac, top is computed:
        new_top = dr(1) + (pt-dr(1))/frac;
        new_tickrange = [dr(1) new_top];
    else
        % Top stays put, origPt moved to frac, bottom is computed:
        new_bot = dr(2) - (dr(2)-pt)/(1-frac);
        new_tickrange = [new_bot dr(2)];
    end
end
change_colorbar_tickrange(s.PeerAxes,new_tickrange);

end

function wbdrag_cmap_colorOnly(s,frac,isShiftPressed)
% Execute drag action for mouse over colorbar image only.
% - Only to be called by wbdrag_cmap()

% if no shift pressed,
%   stretch top or bottom of colorbar, only,
%   depending on whether user started drag
%   in the top or bottom of bar, respectively.
% if shift pressed,
%   stretch both top AND bottom of bar simultaneously,
%   translating colormap region.
dd = frac - s.cbar.origFrac;  % mouse change, fraction units [0 1]
if isShiftPressed
    proposed_delta = [dd dd];
else
    if s.cbar.StartInTop
        proposed_delta = [0 dd];
    else
        proposed_delta = [dd 0];
    end
end
origStretch = s.cbar.origStretch;
curr_delta = abs(diff(origStretch));
newStretch = origStretch + proposed_delta;

% Don't let band of color get too "far away"
%  - allow bottom of color range to get to top of bar
%  - allow top of color range to get to bottom of bar
if newStretch(2) < 0
    newStretch = [-curr_delta 0];
elseif newStretch(1) > 1
    newStretch = [1 1+curr_delta];
end
% Prevent vector element-order issues which can occur when a very small
% delta distance between stretch factors is used:
if newStretch(2) > newStretch(1)
    % Accept newStretch:
    s.ColormapColorStretch = newStretch;
    setappdata(s.PeerAxes,'ColorbariInfo',s);
    change_CLim_colorbar_and_peer(s);
end

end

function wbup_cmap(fig,ev,peerAxes)
% window button up in colormap mode

% Force axis CurrentPoint to update:
fig.CurrentPoint = ev.Point;

changeMouseBehavior(peerAxes,'cmap');

% Set new status msg, since it doesn't update
% in the changeMouseBehavior fcn for cmap callbacks
% Do this by calling the general mouse-motion fcn:
%
% Call wbmotion_cmap, not wbmotion_general, to address the following:
%  - mouse button pressed while over colorbar
%  - mouse dragged outside of colorbar, button still depressed
%  - mouse button released outside of cbar
%  - ensure mouse pointer goes back to "normal"
wbmotion_cmap(peerAxes);

end

function wbscroll_cmap(fig,ev,peerAxes)
% Scroll wheel is equivalent of shift+down+drag, either up or down.

% VerticalScrollCount:
%   +ve -> upward scroll
%   -ve -> downward scroll
%   value = 1 to 16, depending on "strength" of scroll
%         = +/- 1 for a mouse wheel, larger for a laptop "joystick"
frac = double(ev.VerticalScrollCount)/32;
ret = over_cmap(peerAxes);
s = getappdata(peerAxes,'ColorbariInfo');

%specialKeyPressed = getappdata(peerAxes,'ColorbariCmapKey');
%isControlPressed = specialKeyPressed(2);

% Proceed as if shift is pressed.
if ret.isOverTicks
    curr_tr = s.ColormapAxesLimits;
    curr_delta = abs(diff(curr_tr));
    proposed_delta = frac*curr_delta;  % better to use an "orig_tr"
    proposed_tr = curr_tr + proposed_delta;
    if proposed_tr(1) > curr_tr(2)
        new_tickrange = [curr_tr(2) curr_tr(2)+curr_delta];
    elseif proposed_tr(2) < curr_tr(1)
        new_tickrange = [curr_tr(1)-curr_delta curr_tr(1)];
    else
        new_tickrange = proposed_tr;
    end
    change_colorbar_tickrange(peerAxes,new_tickrange);
else
    %   stretch both top AND bottom of CLim simultaneously,
    %   effectively "translating" the color segments along the colorbar.
    
    s = getappdata(peerAxes,'ColorbariInfo'); % in case state changed above
    cs = s.ColormapColorStretch;
    cs = cs - frac;
    if cs(1) > 1
        cs = [1 1+abs(diff(s.ColormapColorStretch))];
    elseif cs(2) < 0
        cs = [-abs(diff(s.ColormapColorStretch)) 0];
    end
    s.ColormapColorStretch = cs;
    setappdata(peerAxes,'ColorbariInfo',s);
    
    change_CLim_colorbar_and_peer(s);
end

end

function hideLocationMenu(peerAxes)

% First hide the Location context menu
s = getappdata(peerAxes,'ColorbariInfo');
set(s.LocationContextMenu,'Visible','off');

% Next remove the separator from the Colormap menu, which appears next in
% the context menu
set(s.ColormapContextMenu,'Separator','off')

end

function install_context_menus(peerAxes)
% Add items to colorbar context menu.

s = getappdata(peerAxes,'ColorbariInfo');
hc = get(s.ColorbarImage,'UIContextMenu');  % ud.PeerAxes also?

% ---------------
% Delete
%
% xxx enable once a toolbar button is linked to turn colorbar back on!
%opts={hc,'Delete','','Enable','off'};
%hLoc = createContext(opts);
nextSep = 'off'; % 'on' if above code used

% ---------------
% Location
%
opts={hc,'Location','','separator',nextSep};
hLoc = createContext(opts);

locStrs = {'Outside North','Outside South','Outside West','Outside East', ...
    'North','South','West','East'};

% Determine which location menu to "check" initially.
%
% .LocationIdx: index into locStr
checkStr = repmat({'off'},numel(locStrs),1);
checkStr{s.LocationIdx} = 'on';

hEntry = [];  % handles to each location menu
for i = 1:numel(locStrs)
    h_i = createContext( ...
        {hLoc,locStrs{i},@changeLocationCB,'Checked',checkStr{i}});
    
    % Give them each the peerAxes as appdata
    setappdata(h_i,'ColorbariPeerAxes',peerAxes);
    
    hEntry(i) = h_i; %#ok<AGROW>
end
% Give each Location menu entry the full vector of handles to all Location
% menu entries:
set(hEntry,'UserData',hEntry);
s.LocationContextMenu = hLoc; % retain parent context menu entry

% --------------
% Colormap
%
opts = {hc,'Colormap','','Separator','on'};
hCmap = createContext(opts);
s.ColormapContextMenu = hCmap; % singular -> main menu

% hEntry holds handles to each colormap menu item
% hEntry(1) must be "Custom..."
%
% Custom is checked by default, since we inherit the figure's current
% colormap when initializing, and we don't know the function used to create
% it.
opts = {hCmap,'Custom...',@changeCMap_Custom,'checked','on'};
hEntry = createContext(opts);

% Add list of colormap names next.
%
% The first name has a separator above it, to separate the colormap name
% list from the "Custom..." entry.
%
names = s.ColormapNames;
for i = 1:numel(names)
    opts ={hCmap,names{i},@changeCMap_Standard};
    if i == 1
        opts = [opts {'separator','on'}]; %#ok<AGROW>
    end
    hEntry(end+1) = createContext(opts); %#ok<AGROW>
end

% Give each Colormap menu item a vector of handles to all peer menus
% -- Set after ColormapLengthContextMenu is created
%
%ud.ColormapContextMenus = hEntry;
%set(hEntry,'UserData',ud);

% Retain the vector of colormap menu handles
hCCM = hEntry;
s.ColormapContextMenus = hCCM; % plural -> submenus
setappdata(peerAxes,'ColorbariInfo',s);

% --------------
% Colormap Length
%
opts={hc,'Length...',@changeCMap_Length};
hCLCM = createContext(opts);

% Give each Colormap Length menu item a vector of handles to all peer menus
ud.PeerAxes = peerAxes;
ud.ColormapContextMenus = hCCM;
ud.ColormapLengthContextMenu = hCLCM;

set(hCLCM,'UserData',ud,'Enable','off');
set(hCCM,'UserData',ud);

% Retain the vector of colormap menu handles
s.ColormapLengthContextMenu = hCLCM;
setappdata(peerAxes,'ColorbariInfo',s);

% --------------
% Colormap Reset
opts={hc,'Reset Limits',@(~,~)reset_CLim_colorbar_and_peer(peerAxes)};
createContext(opts);

% ---------------
% Colormap Editor
opts={hc,'Colormap Editor',{@colormapEditor,peerAxes}};
createContext(opts);

end

function colormapEditor(~,~,peerAxes)
% Open the colormap editor UI and point it to this axis.

colormapeditor(peerAxes);

end

function changeCMap_Standard(~,~)
% Change colormap, callback from context menu for a STANDARD map.
%
% Because there is a listener on the colormap property, and we want it to
% run, we do things order-dependent here.  The reason is that the callback
% resets the context menu checks, in case an "external" event caused the
% change.  But we know which menu we want checked.  So we do that AFTER the
% colormap value is changed.

% Get menu label
hco = gcbo; % callback menu handle
cmapStr = lower(get(hco,'Label'));

% Get custom cmap expr before changing.
% Side-effect of setting figure colormap will be to change the expr to the
% mat2str version of the current figure colormap.
ud = get(hco,'UserData');
s = getappdata(ud.PeerAxes,'ColorbariInfo');
orig_cmapExpr = s.ColormapCustomExpr;

% Set the SelectedColormapNamesIdx so that the event-listener functions
% will know not to auto-detect colormap, and instead use the explicit entry
% into ColormapNames.
s.SelectedColormapNamesIdx = find(strcmpi(cmapStr,s.ColormapNames));
setappdata(ud.PeerAxes,'ColorbariInfo',s);

% Update figure colormap
% - both in colorbar figure
% - and in peer figure (which is typically same but could be different)
% Side-effect updates colormap context menus (color, length)
cmap = feval(cmapStr);
set(ancestor(s.ColorbarAxes,'figure'),'Colormap',cmap);
if ~isequal(s.ColorbarAxes,s.PeerAxes)
    set(ancestor(s.PeerAxes,'figure'),'Colormap',cmap);
end

% Put back original custom string.
% Choosing a standard entry shouldn't change the custom entry.
%
s = getappdata(ud.PeerAxes,'ColorbariInfo'); % side-effect can change this
s.ColormapCustomExpr = orig_cmapExpr;
s.SelectedColormapNamesIdx = []; % reset for next time
setappdata(ud.PeerAxes,'ColorbariInfo',s);

end

function changeCMap_Custom(~,~)
% Change colormap, callback from context menu for a CUSTOM map.
%
% Because there is a listener on the colormap property, and we want it to
% run, we do things order-dependent here.  The reason is that the callback
% resets the context menu checks, in case an "external" event caused the
% change.  But we know which menu we want checked.  So we do that AFTER the
% colormap value is changed.

hco = gcbo; % callback menu handle
ud = get(hco,'UserData');
peerAxes = ud.PeerAxes;
s = getappdata(peerAxes,'ColorbariInfo');

% Bring up interactive dialog.
% Show current custom colormap expression.
[cmapExpr,cancel] = specifyCustomColormapExpr(s);
if cancel
    return  % No change
end

% Update figure colormap
%
% The colormap listener will change context menu checkmarks to "custom"
% since it doesn't know who changed the colormap (and doesn't know what it
% is).  We want that here!
%
% We need to support expressions such as [1 2 3; 4 5 6]/6, etc, which are
% Nx3 matrices.  Especially for custom.  So we use eval.
%
try
    cmap = eval(cmapExpr);
catch me
    % user-specified custom expression failed to execute
    errordlg(me.message,'Custom Colormap Error','modal');
    return
end

% Check size:
if isempty(cmap) || ~isreal(cmap) || issparse(cmap) ...
        || ~ismatrix(cmap) || size(cmap,2)~=3
    msg = 'Colormap must be a real-valued Nx3 matrix.';
    errordlg(msg,'Custom Colormap Error','modal');
    return
end

% Set colormap before storing expression, setting context menus, etc
%
% Side-effect is to execute detect_standard_colormap
try
    set(ancestor(s.ColorbarAxes,'figure'),'Colormap',cmap);
    if ~isequal(s.ColorbarAxes,peerAxes)
        set(ancestor(peerAxes,'figure'),'Colormap',cmap);
    end

catch me
    errordlg(removeHTML(me.message),'Custom Colormap Error','modal');
    return
end

end

function s = removeHTML(s)
% Remove inlined HTML tags from error message, so it can be displayed in a
% non-HTML widget.
%
% We are looking for expressions with the syntax:
%    <a href="matlab:abc>xyz</a>
% where "abc" and "xyz" can be just about any characters.
%
% There can be zero or more of these present.

% Look for opening:
%pat = '(<a href="matlab:[^(">)]">)*';

pat = '(<a href="matlab:)*';
[i1,i2] = regexp(s,pat);
Ni = numel(i1);
if Ni==0
    return
end

% Look for </a>, helping us delineate each HTML region.
% NOTE: We can't reliably find the "> matching the opening, since " and >
% could each be in the text individually, and regexp won't allow us to
% stipulate [^(">)], meaning any chars except the pairing ">
pat = '(</a>)*';
[j1,j2] = regexp(s,pat);
Nj = numel(j1);
if Ni ~= Nj
    % Don't even try if there's not a clear match-up
    return
end
% Each </a> should appear AFTER an i2(p) and before an i1(p+1)
for p = 1:Ni
    a = j1(p); % next start of </a>
    if (a <= i2(p)) || ((p<Nj) && (a >= i1(p+1)))
        return
    end
end
% We have matching '<a href="matlab:' and '</a>' strings - great!
%
% Now the hard part: find the ">" that closes the first pattern.
% First scan for a closing quotation ("), ignoring any chars (including
% ">") until after that closing quotation.
%
% Find closing quotation mark for each HTML tag set.
removeIdx = []; % col1=start, col2=end
for q=1:Nj
    % Find closing quotation.
    iStart = i2(q)+1; % after ":" in '<a href="matlab:'
    iEnd = j1(q)-1;   % before "<" in '</a>'
    tmp = s(iStart:iEnd);
    idx = find(tmp=='"',1);
    if isempty(idx)  % No closing quote?  Abort all strings.
        return
    end
    % Found closing quote.
    % Now find closing ">".  Typically it's the char after the quote.
    iStart = iStart+idx;  % idx points to closing quote, 1-based offsets cancel
    tmp = s(iStart:iEnd);
    idx = find(tmp=='>',1);
    if isempty(idx)  % No closing quote?  Abort all strings.
        return
    end
    % Found closing ">"
    % We want to remove the two HTML tags and leave all the rest.
    % So we record the two regions to remove.
    removeIdx = [removeIdx; i1(q) iStart-1+idx; j1(q) j2(q)]; %#ok<AGROW>
end
% Expand regions to full set of indices
idx = [];
for q = 1:size(removeIdx,1)
    idx = [idx removeIdx(q,1):removeIdx(q,2)]; %#ok<AGROW>
end

% Remove each expression from the string
s(idx) = '';

end

function changeCMap_Length(~,~)
% Change colormap length, callback from context menu.
%
% Because there is a listener on the colormap property, and we want it to
% run, we do things order-dependent here.  The reason is that the callback
% resets the context menu checks, in case an "external" event caused the
% change.  But we know which menu we want checked.  So we do that AFTER the
% colormap value is changed.

% Give each Colormap Length menu item a vector of handles to all peer menus
hco = gcbo;  % .ColormapLengthContextMenu
ud = get(hco,'UserData');
peerAxes = ud.PeerAxes;
s = getappdata(peerAxes,'ColorbariInfo');

% Bring up interactive dialog.
% Show current custom colormap expression.
str = sprintf('%d',s.ColormapLength);
[cmapLenExpr,cancel] = specifyColormapLengthExpr(str);
if cancel
    return % No change
end

% Evaluate colormap length
%
% We need to use eval, not feval, since length is generally an expression
% and not a function name
try
    N = eval(cmapLenExpr);
catch me
    % user-specified custom expression failed to execute
    errordlg(me.message,'Colormap Length Error','modal');
    return
end
if ~isnumeric(N) || ~isscalar(N) ...
        || ~isreal(N) || issparse(N) || isinf(N) ...
        || N<2 || N~=fix(N)
    msg = 'Colormap length must be an integer > 0.';
    errordlg(msg,'Colormap Length Error','modal');
    return
end

% Don't do unnecessary work:
if N == s.ColormapLength
    return
end

% Update figure colormap:
allCheck = get(ud.ColormapContextMenus,'Checked');
sel = strcmpi(allCheck,'on');
if any(sel)
    cmapStr = get(ud.ColormapContextMenus(sel),'Label');
    expr = sprintf('%s(%d)',cmapStr,N);
    cmap = eval(expr);
    
    % Calls FigureColormapChange as a side-effect:
    set(gcbf,'Colormap',cmap);
    
    % Listener fires, and removes checkbox on colormap
    % Reinstate it
    set(ud.ColormapContextMenus(1),'checked','off');
    set(ud.ColormapContextMenus(sel),'checked','on');
    set(hco,'Enable','on');
end

end

function [cmapExpr,cancel] = specifyColormapLengthExpr(last_expr)
% Bring up modal dialog for user to specify a custom colormap length.
% This will be a string that evaluates to a scalar integer value.

name = 'Specify Colormap Length';
prompt = 'Length:';
numlines = [1 40];
defaultanswer = {last_expr};
options.Resize='on';
options.WindowStyle='modal';

ret = inputdlg(prompt,name,numlines,defaultanswer,options);
cancel = isempty(ret) && iscell(ret);
if cancel
    cmapExpr = last_expr;
else
    cmapExpr = ret{1};
end

end

function checkedLabel = getCheckedColormapMenuLabel(s)

h = s.ColormapContextMenus;
sel = strcmpi(get(h,'Checked'),'on');
checkedLabel = get(h(sel),'Label');

end

function [cmapExpr,cancel] = specifyCustomColormapExpr(s)
% Bring up modal dialog for user to specify a custom colormap function
% name or expression.

name = 'Custom Colormap';
last_cmapExpr = s.ColormapCustomExpr;
N = s.ColormapLength;
checkedLabel = getCheckedColormapMenuLabel(s);
if strcmpi(checkedLabel,'Custom...')
    str = sprintf('Custom %dx%d',N,3);
else
    str = sprintf('%s(%d)',checkedLabel,N);
end
prompt = sprintf([ ...
    'Current colormap: %s\n' ...
    '\n' ...
    'New colormap:'], str);

numlines = [1 40];
defaultanswer = {last_cmapExpr};
options.Resize = 'on';
options.WindowStyle = 'modal';

ret = inputdlg(prompt,name,numlines,defaultanswer,options);
cancel = isempty(ret) && iscell(ret);
if cancel
    cmapExpr = last_cmapExpr;
else
    cmapExpr = ret{1};
end

end

function [t,d] = get_data_range(parent,ax)
% Create child image and set up initial properties
%
% Derived from @scribe/@colorbar/methods.m

% Determine color limits by context.  If any axes child is an image
% use scale based on size of colormap, otherwise use current CAXIS.
ch = findobj(get_current_data_axes(parent,ax));
hasimage = 0;
t = [];
isLogicalOrNumeric = false;
cdatamapping = 'direct';
mapsize = size(colormap(ax),1);
for i = 1:length(ch)
    typ = get(ch(i),'type');
    if strcmp(typ,'image'),
        hasimage = 1;
        cdataClass = class(get(ch(i),'CData'));
        isLogicalOrNumeric = ismember(cdataClass,{'logical','uint8','uint16'});
        cdatamapping = get(ch(i), 'CDataMapping');
    elseif strcmp(class(handle(ch(i))),'specgraph.contourgroup') %#ok<STISA>
        % long-term should give the contourplot enough control over
        % clim to avoid this explicit check
        cdatamapping = 'scaled';
        llist = get(ch(i),'LevelList');
        if length(llist) > 1 && strcmp(get(ax,'CLimMode'),'auto')
            t2 = caxis(ax);
            t = [min(llist(:)) max(llist(:))];
            t = [max(t2(1),t(1)) min(t2(2),t(2))];
            if t(1) >= t(2), t = t2; end
            break
        end
    elseif strcmp(typ,'hggroup') && isprop(ch(i),'CDataMapping')
        % charting objects set their own cdata mapping mode
        cdatamapping = get(handle(ch(i)),'CDataMapping');
    elseif strcmp(typ,'surface') && ...
            strcmp(get(ch(i),'FaceColor'),'texturemap') % Texturemapped surf
        hasimage = 2;
        cdatamapping = get(ch(i), 'CDataMapping');
    elseif strcmp(typ,'patch') || strcmp(typ,'surface')
        cdatamapping = get(ch(i), 'CDataMapping');
    end
end

if mapsize == 0
    t = caxis(ax);
elseif strcmp(cdatamapping, 'scaled')
    % Treat images and surfaces alike if cdatamapping == 'scaled'
    % Make sure there are at least two entries into the color map:
    if mapsize < 2
        mapsize = 2;
    end
    if isempty(t), t = caxis(ax); end
    d = (t(2) - t(1))/mapsize;
    
    %t = [t(1)+d/2  t(2)-d/2];
else
    % Make sure there are at least two entries into the color map:
    if mapsize < 2
        mapsize = 2;
    end
    if hasimage
        % handle zero-based indexing into colormap for logical, uint8,
        % uint16
        if isLogicalOrNumeric
            t = [0, mapsize - 1];
        else
            t = [1, mapsize];
        end
    else
        if isempty(t), t = caxis(ax); end
        %{
        if all(t == [0 1]) && strcmp(get(ax,'CLimMode'),'auto')
            t = [1.5, mapsize+.5];
        else
            d = (t(2) - t(1))/mapsize;
            t = [t(1)+d/2  t(2)-d/2];
        end
        %}
    end
end

end

function h = get_current_data_axes(parent, haxes)
% Given a figure and candidate axes, get an axes that colorbar can
% attach to.

h = datachildren(parent);
if isempty(h) || any(h == haxes)
    h = haxes;
else
    h = h(1);
end

end

function hMenu = createContext(opts)
% Helper function to append additional context menus

args = {'Parent',opts{1}, ...
    'Tag',opts{2}, ...
    'Label',opts{2}, ...
    'Callback',opts{3:end}};
hMenu = uimenu(args{:});

end

% [EOF]