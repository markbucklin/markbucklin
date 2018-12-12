function varargout = checkFluoProOptions()


global FPOPTION


% ------------------------------------------------------------------------------------------
% CHECK GPU-PROCESSING ABILITY
% ------------------------------------------------------------------------------------------
if isempty(FPOPTION) || isempty(FPOPTION.useGpu)
   try
	  gpu = gpuDevice;
	  if gpu.isCurrent() && gpu.DeviceSupported
		 FPOPTION.useGpu = true;
	  else
		 FPOPTION.useGpu = false;
	  end
   catch
	  FPOPTION.useGpu = false;
   end
end





if nargout
   varargout{1} = FPOPTION;
end

