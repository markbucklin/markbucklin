classdef DimensionPicker < handle
    %DimensionPicker   Graphical utility for picking a dimension
    %
    %   DimensionPicker methods:
    %      DimensionPicker - Constructor
    %      show - Show dimension picker
    %
    %   DimensionPicker properties:
    %      DefaultDimensions - Initial dimensions of picker
    %      AutoGrow - Whether picker size is allowed to grow on mouse drag
    %      MaxDimensions - Maximum dimensions for picker when AutoGrow is true
    %      Callback - Function handle to execute on dimension selection
    %      NumOccupiedTiles - Number of occupied tiles for showing row-wise preview          
    %      SelectedDimensions - Last dimensions selected by user
    %      FigureParent - MATLAB figure parent of dimension picker (read-only).
    
    %	Copyright 2011-2015 The MathWorks, Inc.
    
    properties
        
        %AutoGrow   Whether picker size is allowed to grow on mouse drag
        %   Logical to control whether dragging the mouse within the picker
        %   can cause the picker's dimensions to grow.  Default value is
        %   false.
        AutoGrow;
        
        %Callback   Function handle to execute on dimension selection
        %   Function handle to execute when the user selects a tile within
        %   the dimension picker.  The chosen tile will be available in the
        %   SelectionDimensions property of the picker.  The callback
        %   function should be defined with its two first input arguments
        %   as ignored inputs, as these are passed from a Java callback.
        %   By default, no callback is executed.
        Callback;
        
        %NumOccupiedTiles   Number of occupied tiles for showing column-wise preview
        %   Scalar number indicating the number of presently occupied
        %   tiles.  This number will be used to show a preview of the new
        %   layout as the user hovers the mouse over the picker.  The
        %   preview shows what tiles will be occupied in the new layout,
        %   assuming that tiles are filled in a row-wise fashion.  Default
        %   value is 0, where no preview is shown.
        NumOccupiedTiles;
        
        %MaxDimensions   Maximum dimensions for picker when AutoGrow is true
        %   Numeric 1-by-2 vector indicating the maximum number of rows and
        %   columns to display when the picker is shown and AutoGrow is
        %   true.  Default value is [16 16].
        MaxDimensions;
    end
    
    properties(Dependent, SetAccess = private)
        %SelectedDimensions   Last dimensions selected by user
        %   Numeric 1-by-2 vector indicating the selected number of rows
        %   and columns.  This property is read-only.
        SelectedDimensions;
    end
    
    properties(SetAccess = private)
        %DefaultDimensions   Initial dimensions of picker
        %   Numeric 1-by-2 vector indicating the default number of rows and
        %   columns to display when the picker is shown.  Default value is
        %   [4 4].  This property is read-only.
        DefaultDimensions;
        
        FigureParent; % MATLAB figure parent of dimension picker (read-only)
    end
    
    properties(Access = private)
        jPanelComponent; %Java Panel Object as a wrapper to MJDimensionPicker
        jDimPickerObject; %Java DimensionPicker object  
    end
    
    methods
        function this = DimensionPicker(hWidget, varargin)
            %DimensionPicker   Construct DimensionPicker
            %   DimensionPicker(HWIDGET) constructs a DimensionPicker
            %   object for MATLAB Handle Graphics object HWIDGET.
            %
            %   DimensionPicker(HWIDGET, PROP1, VAL1, ...) constructs a
            %   DimensionPicker with optional input arguments that are set
            %   as property values.
            
            mlock;
            % Check for Java swing support
            if ~usejava('swing')
                error(message('Spcuilib:scopes:ErrorNoJavaSwing', 'DimensionPicker'));
            end
            
            
            % Parse and validate input arguments.  Default values will be
            % returned for properties not specified as inputs.
            results = processInputs(varargin{:});
            defaultDimensions = results.DefaultDimensions;
            autoGrow = results.AutoGrow;
            callback = results.Callback;
            numOccupiedTiles = results.NumOccupiedTiles;
            maxDimensions = results.MaxDimensions;
            
            % Get parent figure as the ancestor of the widget given
            hFigure = ancestor(hWidget,'figure');
            
            % Create MJDimensionPicker with default dimensions
            dimensions = java.awt.Dimension(defaultDimensions(1), defaultDimensions(2));
            this.jDimPickerObject = javaObjectEDT(...
                com.mathworks.mwswing.MJDimensionPicker(dimensions));
            
            % Create MJMenu object to support 'KeyPressed' events for DimensionPicker
            jm = javaObjectEDT('com.mathworks.mwswing.MJMenu','label');
            this.jDimPickerObject.setInvokingMenu(jm);
            
            % Set column-major occupancy for NumOccupiedTiles
            this.jDimPickerObject.setColumnMajorOccupancy(true);
            
            %Create MJPanel object that will be wrapped around MJDimensionPicker object
            import java.awt.BorderLayout;
            jPanelObject = javaObjectEDT('com.mathworks.mwswing.MJPanel', BorderLayout);
            jPanelObject.setVisible(false);
            jPanelObject.add(this.jDimPickerObject, BorderLayout.WEST);
            
            %MJPanel is parented to the figure at location 0,0
            [this.jPanelComponent,~] = javacomponent(...
                jPanelObject, [0 0 1 1 ], hFigure);
            
            % Set object properties, which will also set properties on MJDimensionPicker
            this.MaxDimensions = maxDimensions;
            this.NumOccupiedTiles = numOccupiedTiles;
            this.AutoGrow = autoGrow;
            this.DefaultDimensions = defaultDimensions;
            this.Callback = callback;
            this.FigureParent = hFigure;
        end
        
        function show(h, XLoc, YLoc)
            %show   Show dimension picker
            
            % Location should be given with respect to the screen. XLoc and
            % YLoc should be converted to platform pixels before setting on
            % the Java object. This is done in getMouseLocationInScreen.
            if nargin < 2
                [XLoc, YLoc] = getMouseLocationInScreen(h.FigureParent);
            elseif nargin < 3
                [XLoc, YLoc] = getMouseLocationInScreen(h.FigureParent,XLoc);
            end
            h.jDimPickerObject.show(h.jPanelComponent, XLoc, YLoc);
        end
        
        function delete(this)
            % Clear callback in the associated Java object for dimension
            % picker to ensure no reference to the Visual object. This
            % avoids memory leak and clear classes warnings.
            this.Callback = [];
            this.jDimPickerObject.close();
            this.jDimPickerObject= [];
            this.jPanelComponent = []; 
        end
        
        function set.Callback(this, v)
            jDimPicObjHandle = handle(this.jDimPickerObject, 'CallbackProperties'); %#ok<*MCSUP>
            if ~isempty(v)
                set(jDimPicObjHandle,'ActionPerformedCallback', {v,this});
            else
                set(jDimPicObjHandle,'ActionPerformedCallback', '');
            end
            this.Callback = v;
        end
        
        function set.NumOccupiedTiles(this, v)
            
            validationFcn = isValidNumOccupiedTiles;
            if ~validationFcn(v)
                error(message('Spcuilib:uiservices:ErrorInvalidInputArgs'));
            else
                this.jDimPickerObject.setOccupancy(v);
                this.NumOccupiedTiles =  v;
            end
        end
        function set.AutoGrow(this, v)
            
            if ~islogical(v)
                error(message('Spcuilib:uiservices:ErrorInvalidInputArgs'));
            else
                this.jDimPickerObject.setAutoGrowEnabled(v);
                this.AutoGrow=v;
            end
        end
        
        function set.MaxDimensions(this,v)
            
            validationFcn = isValidDimensions;
            if ~validationFcn(v)
                error(message('Spcuilib:uiservices:ErrorInvalidInputArgs'));
            else
                this.jDimPickerObject.setSizeLimit(...
                    java.awt.Dimension(v(1), v(2)));
                this.MaxDimensions = v;
            end
        end
        
        function v = get.SelectedDimensions(this)
            dimensions = get(this.jDimPickerObject,'SelectedSize');
            v = [dimensions.getHeight() dimensions.getWidth()];
        end
    end
end

function isValid = isValidDimensions()
isValid = @(value)isequal(size(value), [1 2]);
end

function isValid = isValidNumOccupiedTiles()
isValid = @(value)isnumeric(value) && (isscalar(value) && value>=0 && value<=100);
end

function isValid = isValidFunctionHandle()
isValid = @(value) isa(value,'function_handle') || isempty(value);
end

function results = processInputs(varargin)
% Parse and validate input arguments, returning a structure of either
% default property values or the values passed as inputs.

% Create parser
validateDimension = isValidDimensions;
hParser = inputParser;

% Add parameters to parser with default value and validator function
hParser.addParameter('AutoGrow', false, @islogical);
hParser.addParameter('MaxDimensions', [16,16], validateDimension);
hParser.addParameter('DefaultDimensions', [4,4], validateDimension);
hParser.addParameter('NumOccupiedTiles', 0, isValidNumOccupiedTiles);
hParser.addParameter('Callback', [], isValidFunctionHandle);

% Parse inputs and return results
hParser.parse(varargin{:});
results = hParser.Results;
end

function [XLoc, YLoc] = getMouseLocationInScreen(hFig,varargin)
% Return the mouse coordinates with respect to the screen, assuming the
% origin is at the upper-left corner of the screen.

% PointerLocation returns mouse coordinates assuming the origin is at the
% bottom-left corner of the screen.
mousePointLocation = get(0, 'PointerLocation');

% Do math on ScreenSize to get mouse coordinates
currentScreenSize = get(0, 'ScreenSize');
if nargin > 1
    % Use the given XLoc.
    XLoc = varargin{1};
else
    XLoc = mousePointLocation(1);
end
YLoc = currentScreenSize(4) - mousePointLocation(2);

% Convert to appropriate platform pixels for high DPI support.
pos = [XLoc YLoc 100 100];
pos = matlab.ui.internal.PositionUtils.getPixelRectangleInPlatformPixels(pos, hFig);
XLoc = pos(1);
YLoc = pos(2);

end

%[EOF]

% LocalWords:  MJ HWIDGET mwswing uiservices validator
