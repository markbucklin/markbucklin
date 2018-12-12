  %% Video Display in a Custom User Interface
% This example shows how to display multiple video streams in a custom 
% graphical user interface (GUI).

%% Overview
% When working on a project involving video processing, we are often faced
% with creating a custom user interface. It may be needed for the purpose
% of visualizing and/or demonstrating the effects of our algorithms on the
% input video stream. This example illustrates how to create a figure
% window with two axes to display two video streams. It also shows how to
% set up buttons and their corresponding callbacks.

%   Copyright 2004-2014 The MathWorks, Inc.

%%
% The example is written as a function with the main body at the top and 
% helper routines in the form of 
% <matlab:helpview(fullfile(docroot,'toolbox','matlab','matlab_prog','matlab_prog.map'),'nested_functions') nested functions>
% below.
function VideoInCustomGUIModified(vidFileName, movementData)
[speed, ~, dxdy_rel, abs_direction] = getMovement(movementData);
dxdy_abs = [speed.*cos(abs_direction), speed.*sin(abs_direction)];
%%
% Initialize the video reader.
videoSrc = vision.VideoFileReader(vidFileName, 'ImageColorSpace', 'Intensity');
global INDEX
INDEX = 1;
%% 
% Create a figure window and two axes to display the input video and the
% processed video.
[hFig, hAxes] = createFigureAndAxes();

%%
% Add buttons to control video playback.
insertButtons(hFig, hAxes, videoSrc, movementData);

%% Result of Pressing the Start Button
% Now that the GUI is constructed, we trigger the play callback which
% contains the main video processing loop defined in the
% |getAndProcessFrame| function listed below. If you prefer to click on the
% |Start| button yourself, you can comment out the following line of code.
playCallback(findobj('tag','PBButton123'),[],videoSrc,hAxes, dxdy_rel, dxdy_abs);

%%
% Note that each video frame is centered in the axis box. If the axis size
% is bigger than the frame size, video frame borders are padded with
% background color. If axis size is smaller than the frame size scroll bars
% are added.

%% Create Figure, Axes, Titles
% Create a figure window and two axes with titles to display two videos.
    function [hFig, hAxes] = createFigureAndAxes()

        % Close figure opened by last run
        figTag = 'CVST_VideoOnAxis_9804532';
        close(findobj('tag',figTag));

        % Create new figure
        hFig = figure('numbertitle', 'off', ...
               'name', 'Video In Custom GUI', ...
               'menubar','none', ...
               'toolbar','none', ...
               'resize', 'on', ...
               'tag',figTag, ...
               'renderer','painters', ...
               'position',[680 678 480 240]);

        % Create axes and titles
        hAxes.axis1 = createPanelAxisTitle(hFig,[0.1 0.2 0.5 0.7],'Original Video'); % [X Y W H]
        hAxes.axis2 = createPanelAxisTitle(hFig,[0.7 0.2 0.25 0.5],'Displacement');
        hAxes.axis3 = createPanelAxisTitle(hFig, [0.7 .7 0.25 .2],'Velocity');
    end

%% Create Axis and Title
% Axis is created on uipanel container object. This allows more control
% over the layout of the GUI. Video title is created using uicontrol.
    function hAxis = createPanelAxisTitle(hFig, pos, axisTitle)

        % Create panel
        hPanel = uipanel('parent',hFig,'Position',pos,'Units','Normalized');

        % Create axis   
        hAxis = axes('position',[0 0 1 1],'Parent',hPanel); 
        hAxis.XTick = [];
        hAxis.YTick = [];
        hAxis.XColor = [1 1 1];
        hAxis.YColor = [1 1 1];
        % Set video title using uicontrol. uicontrol is used so that text
        % can be positioned in the context of the figure, not the axis.
        titlePos = [pos(1)+0.02 pos(2)+pos(3)+0.3 0.3 0.07];
        uicontrol('style','text',...
            'String', axisTitle,...
            'Units','Normalized',...
            'Parent',hFig,'Position', titlePos,...
            'BackgroundColor',hFig.Color);
    end

%% Insert Buttons
% Insert buttons to play, pause the videos.
    function insertButtons(hFig,hAxes,videoSrc, movementData)

        % Play button with text Start/Pause/Continue
        uicontrol(hFig,'unit','pixel','style','pushbutton','string','Start',...
                'position',[10 10 75 25], 'tag','PBButton123','callback',...
                {@playCallback,videoSrc,hAxes, movementData});

        % Exit button with text Exit
        uicontrol(hFig,'unit','pixel','style','pushbutton','string','Exit',...
                'position',[100 10 50 25],'callback', ...
                {@exitCallback,videoSrc,hFig});
            
         % step back button
         uicontrol(hFig,'unit','pixel','style','pushbutton','string','Step back',...
             'position',[10 50 100 25],'tag','sbbutton','callback',...
             {@stepBackCallback, videoSrc, hAxes, movementData});
         
         % step forward button
          uicontrol(hFig,'unit','pixel','style','pushbutton','string','Step forward',...
             'position',[120 50 100 25],'tag','sbbutton','callback',...
             {@stepForwardCallback, videoSrc, hAxes, movementData});
         
         
    end     

%% Play Button Callback
% This callback function rotates input video frame and displays original
% input video frame and rotated frame on axes. The function
% |showFrameOnAxis| is responsible for displaying a frame of the video on
% user-defined axis. This function is defined in the file
% <matlab:edit(fullfile(matlabroot,'toolbox','vision','visiondemos','showFrameOnAxis.m')) showFrameOnAxis.m>

    function stepBackCallback(hObject, ~, videoSrc, hAxes, movementData)
        try
            [frame, movementSegment] = stepBackFrame(videoSrc, movementData);
            showFrameOnAxis(hAxes.axis1, frame);
             plot((movementSegment(:,1)), (movementSegment(:,2)));  ylabel('cm/s');
        catch ME                       % Re-throw error message if it is not related to invalid handle 
           if ~strcmp(ME.identifier, 'MATLAB:class:InvalidHandle')
               rethrow(ME);
           end
        end
        
    end
    function [frame,mvmtData] = stepBackFrame(videoSrc,movementData)
        
        % Read input video frame
        frame = imadjust(step(videoSrc),[0 .4]);
        
        indices = max(1,INDEX-500):INDEX;
        mvmtData = nancumsum(movementData(indices,:));
        INDEX= INDEX-1;
    end

    function stepForwardCallback(hObject, ~, videoSrc, hAxes, movementData)
            try
                [frame, movementSegment] = getAndProcessFrame(videoSrc, movementData);
                showFrameOnAxis(hAxes.axis1, frame);
                 plot((movementSegment(:,1)), (movementSegment(:,2)));  ylabel('cm/s');
            catch ME
              if ~strcmp(ME.identifier, 'MATLAB:class:InvalidHandle')
                   rethrow(ME);
               end 
            end
    end
    
    function playCallback(hObject,~,videoSrc,hAxes, dxdy_rel,dxdy_abs)
       try
            % Check the status of play button
            isTextStart = strcmp(hObject.String,'Start');
            isTextCont  = strcmp(hObject.String,'Continue');
            if isTextStart
               % Two cases: (1) starting first time, or (2) restarting 
               % Start from first frame
               if isDone(videoSrc)
                  reset(videoSrc);
               end
            end
            if (isTextStart || isTextCont)
                hObject.String = 'Pause';
            else
                hObject.String = 'Continue';
            end
            % Rotate input video frame and display original and rotated
            % frames on figure

            v = VideoWriter('263ACSF110815_withmovement4.avi');
            open(v)
            fprintf('creating video\n');
            magMax = (max(sqrt([dxdy_rel(:,1).^2 +  dxdy_rel(:,2).^2])));
%             maxY = 0;
%             minY = 0;
%             maxX = 0;
%             minX = 0;
%             maxYDiff = findMaxDiff(dxdy_abs(:,2),200);
%             maxXDiff = findMaxDiff(dxdy_abs(:,1),200);
            pos = 0;
maxY = max(nancumsum(dxdy_abs(1:4000,2)));
minY = min(nancumsum(dxdy_abs(1:4000,2)));
maxX = max(nancumsum(dxdy_abs(1:4000,1)));
minX = min(nancumsum(dxdy_abs(1:4000,1)));
%    
%             overlayROIs(hAxes.axis1, R);
%             figure('units','normalized','outerposition',[0 0 1 1])
            while strcmp(hObject.String, 'Pause') && ~isDone(videoSrc)  
                % Get input video frame and rotated frame
                pos = pos + 1;
                [frame,movementSegment] = getAndProcessFrame(videoSrc,dxdy_abs);  

                % Display input video frame on axis
                showFrameOnAxis(hAxes.axis1, frame);

                % Display rotated video frame on axis

                 plot(hAxes.axis2,(movementSegment(:,1)), (movementSegment(:,2)),'b');  ylabel('cm/s');
                  hold(hAxes.axis2,'on');
                 plot(hAxes.axis2,movementSegment(end,1),movementSegment(end,2),'.r','MarkerSize',15);
                 
                 ylim(hAxes.axis2,[minY, maxY]);
                 xlim(hAxes.axis2,[minX, maxX]);
%                 currYLim = ylim(hAxes.axis2);
%                 currXLim = xlim(hAxes.axis2);
%                  if currYLim(1) < minY
%                      minY = currYLim(1);
%                  end
%                  if currYLim(2) > maxY
%                      maxY = currYLim(2);
%                  end
%                  if currXLim(1) < minX
%                      minX = currXLim(1);
%                  end
%                  if currXLim(2) > maxX
%                      maxX = currXLim(2);
%                  end

% 
%                  if abs(diff(currYLim)) < maxYDiff
%                      diffYDiff = maxYDiff - diff(currYLim);
%                    ylim(hAxes.axis2,[currYLim(1)-diffYDiff/2 currYLim(1)+diffYDiff/2]);
%                  end
%                  if abs(diff(currXLim)) < maxXDiff
%                      diffXDiff = maxXDiff - diff(currXLim);
%                       xlim(hAxes.axis2,[currXLim(1)-diffXDiff/2 currXLim(1)+diffXDiff/2]);
% 
%                  end
                 hold(hAxes.axis2,'off');

                 axis(hAxes.axis3);
                 hiddenArrow = compass(hAxes.axis3,magMax,0); % from https://www.mathworks.com/matlabcentral/answers/215033-rescaling-and-extending-the-axes-of-compass-plots
                 hiddenArrow.Color = 'none';
                 hold on;
                 currSegmentx = dxdy_rel(pos,1);
                 currSegmenty = dxdy_rel(pos,2);
                 
                 try
                     compass(hAxes.axis3, currSegmentx(end),currSegmenty(end));
                 catch
                 end
                 hold off;
                % to view properties you can use get(H)
                 try
                    writeVideo(v,getframe(gcf));
                 catch
                     fprintf('skipping %d\n',INDEX);
                 end
                 
            end
            close(v)
            % When video reaches the end of file, display "Start" on the
            % play button.
            if isDone(videoSrc)
               hObject.String = 'Start';
            end
       catch ME
           % Re-throw error message if it is not related to invalid handle 
           if ~strcmp(ME.identifier, 'MATLAB:class:InvalidHandle')
               rethrow(ME);
           end
       end
    end
    function maxDiff = findMaxDiff(movementData, lag)
    cs = nancumsum(movementData);
    maxDiff = 0;
    for i=1:length(movementData)-lag
        for j=1:lag
            currDiff = movementData(i+j)-movementData(i);
            if currDiff > maxDiff
                maxDiff = currDiff;
            end
        end
    end
    end
%% Video Processing Algorithm
% This function defines the main algorithm that is invoked when play button
% is activated.
    function [frame,mvmtData] = getAndProcessFrame(videoSrc,movementData)
        
        % Read input video frame
        frame = imadjust(step(videoSrc),[0 .4]);
        
        indices = 1:INDEX;
        mvmtData = nancumsum(movementData(indices,:));
        INDEX= INDEX+1;
    end

%% Exit Button Callback
% This callback function releases system objects and closes figure window.
    function exitCallback(~,~,videoSrc,hFig)
        
        % Close the video file
        release(videoSrc); 
        % Close the figure window
        close(hFig);
    end

displayEndOfDemoMessage(mfilename)

end