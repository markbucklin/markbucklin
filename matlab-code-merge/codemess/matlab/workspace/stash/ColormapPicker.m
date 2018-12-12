classdef ColormapPicker < hgsetget
    %ColormapPicker   Creates a ColormapPicker widget
    
    %   Copyright 2015 The MathWorks, Inc.
    
    properties (Dependent)
        Colormap;
        BackgroundColor;
        Position;
        Visible;
        Tooltip;
        Tag;
        Enable;
    end
    
    properties (SetAccess = private)
        Parent;
        Panel;
        Component;
        Container;
    end
    
    methods (Static)
    end
    
    methods
        
        function this = ColormapPicker(hParent, defaultPosition, colormap)
            %ColormapPicker   Construct the ColormapPicker class.
            if ~usejava('swing')
                error(message('Spcuilib:scopes:ErrorNoJavaSwing', 'ColormapPicker'));
            end
            
            [this.Panel, this.Container] = javacomponent('com.mathworks.mwswing.MJPanel', ...
                defaultPosition,hParent);
            this.Parent = hParent;
            
            % Create the colormap picker tool:
            this.Component = javaObjectEDT('com.mathworks.page.plottool.propertyeditor.controls.ColormapControl',...
                getString(message('Spcuilib:scopes:ColormapPickerTT')), [], 'Colormap');
            this.Colormap = colormap;
            javaMethodEDT('add', this.Panel, this.Component);
        end
        
        function set.Colormap(this,colormap)
            % Set colormap of the colormap picker            
            javaMethodEDT('setDisplayedValue',this.Component, colormap);
        end
        
        function colormap = get.Colormap(this)
            % Get colormap of the colormap picker
            colormap = javaMethodEDT('getDisplayedValue',this.Component);
        end
        
        function set.BackgroundColor(this,color)
            % Set background color of the colormap picker and container
            javaMethodEDT('setBackground', this.Component, ...
                uiservices.colorToJavaColor(color));
            javaMethodEDT('setBackground', this.Panel, ...
                uiservices.colorToJavaColor(color));
        end
        
        function color = get.BackgroundColor(this)
            % Get background color of the colormap picker and container
            color = uiservices.javaColorToColor( ...
                javaMethodEDT('getBackground',this.Component));
        end
        
        function set.Position(this,position)
            % Set position of the colormap picker
            set(this.Container,'Position',position);
        end
        
        function currpos = get.Position(this)
            % Get position of the colormap picker
            currpos = get(this.Container,'Position');
        end
        
        function set.Visible(this,visstate)
            % Set visibility of the colormap picker
            set(this.Container,'Visible',visstate);
        end
        
        function visstate = get.Visible(this)
            % Get visibility of the colormap picker
            visstate = get(this.Container,'Visible');
        end
        
        function set.Tag(this,tag)
            % Set tag of the colormap picker
            javaMethodEDT('setName',this.Component,tag);
        end
        
        function tag = get.Tag(this)
            % Get tag of the colormap picker
            tag = uiservices.javaStringToString( ...
                javaMethodEDT('getName',this.Component));
        end
        
        function set.Enable(this,enablestate)
            % Set enablement of the colormap picker
            javaMethodEDT('setEditorEnabled', this.Component, enablestate);
        end
        
        function enablestate = get.Enable(this)
            % Get enabledness of the colormap picker
            enablestate = javaMethodEDT('isEnabled',this.Component);
        end
        
    end
end

% [EOF]
