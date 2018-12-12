function x = sslog(x)
warning('sslog.m being called from scrap directory: Z:\Files\MATLAB\toolbox\ignition\scrap')
x = reallog(abs(x)) .* sign(x);
