    function [frame,rotatedImg,angle] = getAndProcessFrame(videoSrc,angle)

        % Read input video frame
        frame = step(videoSrc);

        % Pad and rotate input video frame
        paddedFrame = padarray(frame, [30 30], 0, 'both');
        rotatedImg  = imrotate(paddedFrame, angle, 'bilinear', 'crop');
        angle       = angle + 1;
    end