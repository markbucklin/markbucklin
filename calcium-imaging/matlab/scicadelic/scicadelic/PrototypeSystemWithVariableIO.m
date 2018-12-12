classdef (CaseInsensitiveProperties = true) PrototypeSystem < scicadelic.SciCaDelicSystem
	% Prototype
	
	% ##################################################
	% SETTINGS
	% ##################################################
	properties (Nontunable)
		% 		Precision = 'single'
	end
	properties (Nontunable, Logical)
	end
	properties (Nontunable, PositiveInteger)
	end
	
	
	% ##################################################
	% I/O SETTINGS
	% ##################################################
	properties (Nontunable, Logical)		
		DataBInputPort = false;
		DataAOutputPort = false
		DataBOutputPort = false
	end
	
	
	% ##################################################
	% STATES
	% ##################################################
	properties (DiscreteState)
	end
	
	
	% ##################################################
	% BUFFERS
	% ##################################################
	properties (SetAccess = protected, Hidden)
		% 		InputBuffer					% Logical array 'Nb' frames
		% 		OutputBuffer
	end
	
	
	% ##################################################
	% PRIVATE
	% ##################################################
	properties (Nontunable, Access = protected, Hidden)
		% 		PrecisionSet = matlab.system.StringSet({'single','double'})
		% 		pPrecision
	end
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = PrototypeSystem(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
		end
	end
	
	% ##################################################
	% INTERNAL SYSTEM METHODS
	% ##################################################
	methods (Access = protected)
		% ============================================================
		% SETUP
		% ============================================================
		function setupImpl(obj, F)
			
			% INITIALIZATION (STANDARD)
			fillDefaults(obj)
			checkInput(obj, F);
			obj.TuningImageDataSet = [];
			setPrivateProps(obj)
			if ~isempty(obj.GpuRetrievedProps)
				pushGpuPropsBack(obj)
			end
			
			% INITIALIZATION (CLASS-SPECIFIC)
			
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function varargout = stepImpl(obj, F, varargin)
			
			if ~isempty(F)
				% LOCAL VARIABLES
				
				% PROCESS INPUT
				DataA = F; % (replace with specific procedure)
				if (nargin > 2)
					DataB = varargin{1};
				else
					DataB = F+1;
				end
				
				% PREPARE OUTPUT
				availableOutput = {DataA, DataB};
				
			else
				availableOutput = {[],[]};
				
			end
			
			% ASSIGN OUTPUT
			if nargout
				specifiedOutput = [...
					obj.DataAOutputPort,...
					obj.DataBOutputPort ];
				outputArgs = availableOutput(specifiedOutput);
				varargout = outputArgs(1:nargout);
			end
			
		end
		
		% ============================================================
		% I/O & RESET
		% ============================================================
		function numInputs = getNumInputsImpl(obj)
			if obj.DataBInputPort
				numInputs = 2;
			else
				numInputs = 1;
			end
		end
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.DataAOutputPort,...
				obj.DataBOutputPort]);
		end		
		function resetImpl(obj)
			setPrivateProps(obj)
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
		function s = saveObjectImpl(obj)
			s = saveObjectImpl@matlab.System(obj);
			if isLocked(obj)
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			if ~isempty(obj.ChildSystem)
				for k=1:numel(obj.ChildSystem)
					s.ChildSystem{k} = matlab.System.saveObject(obj.ChildSystem{k});
				end
			end
		end
		function loadObjectImpl(obj,s,wasLocked)
			if wasLocked
				% Load child System objects
				if ~isempty(s.ChildSystem)
					for k=1:numel(s.ChildSystem)
						obj.ChildSystem{k} = matlab.System.loadObject(s.ChildSystem{k});
					end
				end
				oMeta = metaclass(obj);
				oProps = oMeta.PropertyList(:);
				% 		 oProps = oProps(~strcmp({oProps.GetAccess},'private'));
				for k=1:numel(oProps)
					if strcmp(oProps(k).Name,'ChildSystem')
						continue
					else
						s.(oProps(k).Name) = obj.(oProps(k).Name);
					end
				end
			end
			% Call base class method to load public properties
			loadObjectImpl@matlab.System(obj,s,[]);
		end
	end
	
	% ##################################################
	% TUNING
	% ##################################################
	methods (Hidden)
		function tuneInteractive(~)
		end
		function tuneAutomated(~)
		end
	end
	
	% ##################################################
	% INITIALIZATION HELPER METHODS
	% ##################################################
	methods (Access = protected, Hidden)
		function setPrivateProps(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			for k=1:numel(oProps)
				prop = oProps(k);
				if prop.Name(1) == 'p'
					pname = prop.Name(2:end);
					try
						pval = obj.(pname);
						obj.(prop.Name) = pval;
					catch me
						msg = getReport(me);
						disp(msg)
					end
				end
			end
		end
		function fetchPropsFromGpu(obj)
			oMeta = metaclass(obj);
			oProps = oMeta.PropertyList(:);
			propSettable = ~[oProps.Dependent] & ~[oProps.Constant];
			for k=1:length(propSettable)
				if propSettable(k)
					pn = oProps(k).Name;
					try
						if isa(obj.(pn), 'gpuArray') && existsOnGPU(obj.(pn))
							obj.(pn) = gather(obj.(pn));
							obj.GpuRetrievedProps.(pn) = obj.(pn);
						end
					catch me
						msg = getReport(me);
						disp(msg)
					end
				end
			end
		end
		function pushGpuPropsBack(obj)
			fn = fields(obj.GpuRetrievedProps);
			for kf = 1:numel(fn)
				pn = fn{kf};
				if isprop(obj, pn)
					if obj.UseGpu
						if ~isa(obj.(pn), 'gpuArray')
							obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
						end
					else
						obj.(pn) = obj.GpuRetrievedProps.(pn);
					end
				end
			end
		end
	end
	
	% ##################################################
	% OUTPUT DISPLAY
	% ##################################################
	methods (Access = public)
	end
	
	
	
	
	
	
	
	
	
	
end