classdef ColorPicker < hgsetget
    %ColorPicker   Creates a ColorPicker widget
    %
    %    ColorPicker constructor:
    %        this = ColorPicker(hParent,defaultPosition,defaultColor,buttonIcon)
    %        hParent - Figure or panel
    %        defaultPosition = [left bottom width height] in pixels
    %        defaultColor = [1 0 0]
    %        buttonIcon = 'fill', 'line', 'none'
    %
    %    ColorPicker methods:
    %        dim = getSize
    %
    %    ColorPicker properties:
    %        Color BackgroundColor, Position, Visible, Tooltip, Tag,
    %        Enable, Tag
    %
    %     Example:
    %        h = figure;
    %        obj = uiservices.ColorPicker(h,[100 100 40 40],[1 0 0],'fill');
    
    %   Copyright 2011 The MathWorks, Inc.
    
    properties (Dependent)
        Color;
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
        function dim = getSize(hfig)
            % Get size of the color picker tool in pixels
            javatemp = javaObjectEDT(...
                'com.mathworks.mlwidgets.graphics.ColorPicker',...
                com.mathworks.mlwidgets.graphics.ColorPicker.NO_OPTIONS,...
                com.mathworks.mlwidgets.graphics.ColorPicker.NO_ICON,...
                'Color');
            javasize = uiservices.getSizeInPixels(javaMethodEDT('getPreferredSize',javatemp),hfig);
            
            % Color picker dimension in pixels
            dim.colorWidth  = javasize.width;
            dim.colorHeight = javasize.height;
            
            % Dimensions of Java panel used to contain the color picker tool
            dim.Width  = dim.colorWidth + 4;
            dim.Height = dim.colorHeight + 10;
        end
    end
    
    methods
        
        function this = ColorPicker(hParent,defaultPosition,defaultColor,buttonIcon)
            %ColorPicker   Construct the ColorPicker class.
            if ~usejava('swing')
                error(message('Spcuilib:scopes:ErrorNoJavaSwing', 'ColorPicker'));
            end
            
            [this.Panel, this.Container] = javacomponent('com.mathworks.mwswing.MJPanel', ...
                defaultPosition,hParent);
            this.Parent = hParent;
            
            % Create the color picker tool with specified icon
            switch lower(buttonIcon)
                case 'fill'
                    this.Component = javaObjectEDT('com.mathworks.mlwidgets.graphics.ColorPicker',...
                        com.mathworks.mlwidgets.graphics.ColorPicker.NO_OPTIONS,...
                        com.mathworks.mlwidgets.graphics.ColorPicker.FILL_ICON,'Color');
                case 'line'
                    this.Component = javaObjectEDT('com.mathworks.mlwidgets.graphics.ColorPicker',...
                        com.mathworks.mlwidgets.graphics.ColorPicker.NO_OPTIONS,...
                        com.mathworks.mlwidgets.graphics.ColorPicker.LINE_ICON,'Color');
                case 'none'
                    this.Component = javaObjectEDT('com.mathworks.mlwidgets.graphics.ColorPicker',...
                        com.mathworks.mlwidgets.graphics.ColorPicker.NO_OPTIONS,...
                        com.mathworks.mlwidgets.graphics.ColorPicker.NO_ICON,'Color');
            end
            
            this.Color = defaultColor;
            javaMethodEDT('add', this.Panel, this.Component);
            
        end
        
        function set.Color(this,color)
            % Set color of the color picker
            javaMethodEDT('setValue', this.Component, ...
                uiservices.colorToJavaColor(color));
        end
        
        function color = get.Color(this)
            % Get color of the color picker
            color = uiservices.javaColorToColor( ...
                javaMethodEDT('getValue',this.Component));
        end
        
        function set.BackgroundColor(this,color)
            % Set background color of the color picker and container
            javaMethodEDT('setBackground', this.Component, ...
                uiservices.colorToJavaColor(color));
            javaMethodEDT('setBackground', this.Panel, ...
                uiservices.colorToJavaColor(color));
        end
        
        function color = get.BackgroundColor(this)
            % Get background color of the color picker and container
            color = uiservices.javaColorToColor( ...
                javaMethodEDT('getBackground',this.Component));
        end
        
        function set.Position(this,position)
            % Set position of the Color Picker
            set(this.Container,'Position',position);
        end
        
        function currpos = get.Position(this)
            % Get position of the Color Picker
            currpos = get(this.Container,'Position');
        end
        
        function set.Visible(this,visstate)
            % Set visibility of the color picker
            set(this.Container,'Visible',visstate);
        end
        
        function visstate = get.Visible(this)
            % Get visibility of the color picker
            visstate = get(this.Container,'Visible');
        end
        
        function set.Tooltip(this,tooltipstring)
            % Set tooltip string of the color picker
            javaMethodEDT('setToolTipText',this.Component,tooltipstring);
        end
        
        function tooltip = get.Tooltip(this)
            % Get tooltip string of the color picker
            tooltip = uiservices.javaStringToString( ...
                javaMethodEDT('getToolTipText',this.Component));
        end
        
        function set.Tag(this,tag)
            % Set tag of the color picker
            javaMethodEDT('setName',this.Component,tag);
        end
        
        function tag = get.Tag(this)
            % Get tag of the color picker
            tag = uiservices.javaStringToString( ...
                javaMethodEDT('getName',this.Component));
        end
        
        function set.Enable(this,enablestate)
            % Set enablement of the color picker
            javaMethodEDT('setEnabled', this.Component, enablestate);
        end
        
        function enablestate = get.Enable(this)
            % Get enabledness of the color picker
            enablestate = javaMethodEDT('isEnabled',this.Component);
        end
        
    end
end

% [EOF]

% LocalWords:  uiservices mwswing MJ enabledness
