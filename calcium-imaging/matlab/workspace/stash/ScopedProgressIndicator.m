
%   Copyright 2014 The MathWorks, Inc.

classdef ScopedProgressIndicator < handle
    %SCOPEDPROGRESSBAR Displays a progress indicator and automatically
    % disposes of the indicator when the object is deleted
    
    properties(Access=private)
        progressBar = []
    end
    
    methods
        function obj = ScopedProgressIndicator(title_id)
            try
                pbar_edt = javaObjectEDT('com.mathworks.toolbox.simulink.progressbar.SLProgressBar','');
                obj.progressBar = pbar_edt.CreateProgressBar(getString(message(title_id)));
                obj.progressBar.setProgressStatusLabel(DAStudio.message('Simulink:tools:MAPleaseWait'));
                obj.progressBar.setCircularProgressBar(true);
                obj.progressBar.show;
            catch Mex    %#ok<NASGU>
                obj.progressBar = [];
            end
        end
        
        function delete(obj)
            if ~isempty(obj.progressBar)
                obj.progressBar.dispose();
            end
        end
        
        function updateTitle(obj, new_title)
             obj.progressBar.setProgressStatusLabel(getString(message(new_title)));
        end
    end
    
end
