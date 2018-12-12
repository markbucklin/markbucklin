   function playCallback(hObject,~,videoSrc,hAxes)
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
            angle = 0;
            while strcmp(hObject.String, 'Pause') && ~isDone(videoSrc)
                % Get input video frame and rotated frame
                [frame,rotatedImg,angle] = getAndProcessFrame(videoSrc,angle);
                % Display input video frame on axis
                showFrameOnAxis(hAxes.axis1, frame);
                % Display rotated video frame on axis
                showFrameOnAxis(hAxes.axis2, rotatedImg);
            end

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