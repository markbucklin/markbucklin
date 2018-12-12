jo = com.mathworks.jmi.Callback
set(jo,'DelayedCallback', @(varargin)fprintf('time is %f\n',now))
jo.postCallback


then = now; 
set(jo,'DelayedCallback', @(varargin)fprintf('time passed: %f\n',now-then));
jo.postCallback