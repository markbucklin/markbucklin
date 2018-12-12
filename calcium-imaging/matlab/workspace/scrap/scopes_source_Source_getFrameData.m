function frameData = getFrameData(this,idx)
%GETFRAMEDATA Get the frameData.
%   The derived class must override this method if it has no DataHandler
%   object or to handle it differently.
if nargin<2
    % Get data for current frame
    idx = this.Controls.CurrentFrame;  % .lastVideoFrameReadIdx
end
if ~isempty( this.Data )
    this.Data.FrameData = getFrameData( this.DataHandler, idx );
end
frameData = this.Data.FrameData;
end
