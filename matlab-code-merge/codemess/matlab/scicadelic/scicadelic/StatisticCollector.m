classdef (CaseInsensitiveProperties = true) StatisticCollector < scicadelic.SciCaDelicSystem
	% StatisticCollector
	%			Calculates pixel statistics over time. Skewness and Kurtosis  are "Fisher's
	%			Skewness/Kurtosis" methods
	%
	%			Skewness: assymetry of deviations from the sample mean Kurtosis: "how flat the top of a
	%			symmetric distribution is when compared to a normal distribution with same variance
	%
	% REFERENCES:
	%			Timothy B. Terriberry. Computing Higher-Order Moments Online.
	%			http://www.johndcook.com/blog/skewness_kurtosis/ Philippe Pébay. SANDIA REPORT SAND2008-6212
	%			(2008). Formulas for Robust, One-Pass Parallel Computation of Co- variances and
	%			Arbitrary-Order Statistical Moments.
	%
	
	% ##################################################
	% SETTINGS
	% ##################################################
	properties (Nontunable)
		Precision = 'single'
		Mask
	end
	% OUTPUT SETTINGS
	properties (Nontunable, Logical)
		StatisticOutputPort = false
		CentralMomentOutputPort = false
		DifferentialMomentOutputPort = false
	end
	
	% ##################################################
	% STATISTICS (DEPENDENT ON CENTRAL MOMENTS)
	% ##################################################
	properties (Dependent = true)
		Mean
		StandardDeviation
		Variance
		Skewness
		Kurtosis
		JarqueBera
	end
	% STATISTICS (OTHER)
	properties (SetAccess = protected)
		Min
		Max
		N
	end
	% CENTRAL MOMENTS
	properties (Access = protected, Hidden)
		M1
		M2
		M3
		M4
	end
	
	% ##################################################
	% PRIVATE
	% ##################################################
	properties (Nontunable, Access = protected, Hidden)
		PrecisionSet = matlab.system.StringSet({'single','double'})
		pPrecision
	end
	
	
	
	
	% ##################################################
	% CONSTRUCTOR
	% ##################################################
	methods
		function obj = StatisticCollector(varargin)
			setProperties(obj,nargin,varargin{:});
			parseConstructorInput(obj,varargin(:));
		end
	end
	
	
	
	% ##################################################
	% DEPENDENT STATISTIC GET FUNCTIONS
	% ##################################################
	methods
		function X = get.Mean(obj)
			X = obj.M1;
		end
		function X = get.StandardDeviation(obj)
			if ~isempty(obj.N) && ~isempty(obj.M2) && all(obj.N(:) > 1)
				X = sqrt(obj.M2 ./ (obj.N - 1));
			else
				X = getDefaultStat(obj);				
			end
		end
		function X = get.Variance(obj)
			if ~isempty(obj.N) && ~isempty(obj.M2) && all(obj.N(:) > 1)
				X = obj.M2 ./ (obj.N - 1);
			else
				X = getDefaultStat(obj);
			end
		end
		function X = get.Skewness(obj)
			if ~isempty(obj.N) && ~isempty(obj.M2) && all(obj.N(:) > 2)
				X = sqrt(obj.N) .* obj.M3 ./ (obj.M2 .^(3/2));
			else
				X = getDefaultStat(obj);
			end
		end
		function X = get.Kurtosis(obj)
			if ~isempty(obj.N) && ~isempty(obj.M2) && all(obj.N(:) > 3)
				X = obj.N .* obj.M4 ./ (obj.M2.^2) - 3;
			else
				X = getDefaultStat(obj);
			end
		end
		function X = get.JarqueBera(obj)
			if ~isempty(obj.N) && ~isempty(obj.M2) && all(obj.N(:) > 3)
				X  = obj.N/6 * (obj.Skewness.^2 + 1/4 *(obj.Kurtosis - 3).^2);
			else
				X = getDefaultStat(obj);
			end
		end
	end
	
	
	
	% ##################################################
	% BASIC INTERNAL SYSTEM METHODS
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
			% 			F = onGpu(obj, F);
			
			% INITIAL STATS WILL DUPLICATE SAMPLING OF FIRST INPUT
			% 			obj.N = int32(zeros(1,'like',F));% NEW
			obj.N = [];
			if isempty(obj.M1)
				addSampleData(obj, F)
				% 				obj.N = obj.N*0;
			end
			%TODO->where to put, what to start with...
			
		end
		
		% ============================================================
		% STEP
		% ============================================================
		function varargout = stepImpl(obj, F)
			
			% RUN UPDATE FUNCTION OR DIFFERENTIAL GENERATING FUNCTION
			if ~isempty(F)
				F = single(F); % NEW
				
				% DIFFERENTIAL MOMENT GENERATING FUNCTION
				if obj.DifferentialMomentOutputPort && nargout
					differentialMomentStructure = getDiffMomentWithStatisticUpdate(obj, F);
					
				else
					% UPDATE ONLY FUNCTION
					differentialMomentStructure = [];
					updateStatistics(obj, F)
					
				end
			else
				differentialMomentStructure = [];
			end
			
			% STATISTIC OUTPUT
			if obj.StatisticOutputPort
				statStructure = struct(...
					'Min', obj.Min,...
					'Max', obj.Max,...
					'Mean', obj.Mean,...
					'StandardDeviation', obj.StandardDeviation,...
					'Skewness', obj.Skewness,...
					'Kurtosis', obj.Kurtosis); %TODO: inline
			else
				statStructure = [];
			end
			
			% CENTRAL MOMENT OUTPUT
			if obj.CentralMomentOutputPort || obj.DifferentialMomentOutputPort
				centralMomentStructure = struct(...
					'N', obj.N,...
					'M1', obj.M1,...
					'M2', obj.M2,...
					'M3', obj.M3,...
					'M4', obj.M4);
			else
				centralMomentStructure = [];
			end
			
			% ASSIGN OUTPUT
			if nargout
				availableOutput = {...
					statStructure,...
					centralMomentStructure,...
					differentialMomentStructure};
				specifiedOutput = [...
					obj.StatisticOutputPort,...
					obj.CentralMomentOutputPort,...
					obj.DifferentialMomentOutputPort];
				outputArgs = availableOutput(specifiedOutput);
				varargout = outputArgs(1:nargout);
			end
			
		end
		
		% ============================================================
		% I/O & RESET
		% ============================================================
		function numOutputs = getNumOutputsImpl(obj)
			numOutputs = nnz([...
				obj.StatisticOutputPort,...
				obj.CentralMomentOutputPort,...
				obj.DifferentialMomentOutputPort]);
		end
		function resetImpl(obj)
			% 			setPrivateProps(obj)
			% 			obj.N = zeros(1,'like',obj.N);
			% 			sz = size(obj.M1);
			% 			m0 = onGpu(obj, zeros(sz, obj.pPrecision));
			% 			obj.M1 = m0;
			% 			obj.M2 = m0;
			% 			obj.M3 = m0;
			% 			obj.M4 = m0;
			% 			obj.N = m0(1);
		end
		function releaseImpl(obj)
			fetchPropsFromGpu(obj)
		end
	end
	
	
	
	% ##################################################
	% RUNTIME HELPER METHODS
	% ##################################################
	methods
		function addSampleData(obj, F)
			% Function for adding initial data sample. Function will be called automatically from
			% setupImpl() unless called manually using frames from a "burn-in" period or frames from the
			% output of something like the TiffStackLoader class method, getDataSample()
			F = single(F); %NEW
			if obj.UseGpu
				idx=0;
				chunkSize = 16;
				numFrames = size(F,3);
				while idx(end) < numFrames
					idx = idx(end) + (1:chunkSize);
					idx = idx(idx<=numFrames);
					updateStatistics(obj, gpuArray(F(:,:,idx,:))); % TODO
				end
			else
				updateStatistics(obj, F);
			end
			
			
		end
	end
	methods (Access = protected)
		function updateStatistics(obj, F)
			
			if size(F,3) >= 1
				if obj.UseGpu
					
					% -----------------------------------
					% GPU VERSION
					% -----------------------------------
					
					if obj.DifferentialMomentOutputPort%NEW
						if ~isempty(obj.N)
							stat = getCurrentStatStruct(obj);
							[~, stat] = differentialMomentGeneratorRunGpuKernel(F, stat);
						else
							[~, stat] = differentialMomentGeneratorRunGpuKernel(F);
						end
					else%endNEW
						if ~isempty(obj.N) %&& all(obj.N(:)>=1)
							% CALL EXTERNAL FUNCTION WITH CUDA-KERNEL-GENERATING SUBFUNCTION
							stat = getCurrentStatStruct(obj);
							stat = statisticUpdateRunGpuKernel(F, stat);
						else
							stat = statisticUpdateRunGpuKernel(F);
						end
					end
					% STORE OUTPUT
					obj.N = stat.N;
					obj.Min = stat.Min;
					obj.Max = stat.Max;
					obj.M1 = stat.M1;
					obj.M2 = stat.M2;
					obj.M3 = stat.M3;
					obj.M4 = stat.M4;
					
				else
					
					% -----------------------------------
					% CPU VERSION
					% -----------------------------------
					na = obj.N;
					nb = size(F,3);
					n = na + nb;
					
					% CENTRAL MOMENTS
					if nb == 1
						% SINGLE SAMPLE UPDATE (% Run faster implementation if only updating with 1 frame)
						m1 = obj.M1;
						m2 = obj.M2;
						m3 = obj.M3;
						m4 = obj.M4;
						d = cast(F, 'like', m1) - m1;
						dk = d./n;
						dk2 = dk.^2;
						s = d.*dk.*(n-1);
						m1 = m1 + dk;
						m4 = m4 + s.*dk2.*(n.^2-3*n+3) + 6*dk2.*m2 - 4*dk.*m3;
						m3 = m3 + s.*dk.*(n-2) - 3*dk.*m2;
						m2 = m2 + s;
						
					else
						% MULTI-SAMPLE UPDATE (% Not optimized, but easier to follow)
						m1a = obj.M1;
						m2a = obj.M2;
						m3a = obj.M3;
						m4a = obj.M4;
						
						m1b = cast(mean(F, 3), 'like', m1a);
						m2b = moment(cast(F, 'like', m2a), 2, 3);
						m3b = moment(cast(F, 'like', m3a), 3, 3);
						m4b = moment(cast(F, 'like', m4a), 4, 3);
						
						d = bsxfun(@minus, m1b , m1a);
						m1 = m1a  +  d.*(nb./n); % 				dk = d.*(Nb/N);
						m2 = m2a  +  m2b  +  (d.^2).*(na.*nb./n); % dk2 = (d.^2).*Na.*Nb./N
						m3 = m3a  +  m3b  +  (d.^3).*(na.*nb.*(na-nb)./(n.^2))  ...
							+  3*(na.*m2b - nb.*m2a).*d./n;
						m4 = m4a  +  m4b  +  (d.^4).*((na*nb*(na-nb).^2)./(n.^3))  ...
							+  6*(m2b.*na.^2 + m2a.*nb.^2).*((d.^2)./(n.^2))  ...
							+  4*(m3b.*na  -  m3a.*nb).*(d./n);
						
						% N, MAX & MIN
						obj.N = n;
						obj.Min = min(min(F, [],3), obj.Min);
						obj.Max = max(max(F, [],3), obj.Max);
						
						% UPDATE PROPERTIES
						obj.M1 = m1;
						obj.M2 = m2;
						obj.M3 = m3;
						obj.M4 = m4;
					
					end					
				end
				
			end
		end
		function dstat = getDiffMomentWithStatisticUpdate(obj, F)
			% Returns the structure "dstat" with differential moments in the fields {M1, M2, M3, M4}
			
			if size(F,3) >= 1
				if obj.UseGpu
					
					% -----------------------------------
					% GPU VERSION
					% -----------------------------------
					if ~isempty(obj.N) %&& all(obj.N(:)>=1)
						% STRUCTURE DATA FROM PROPERTY STORAGE
						stat = getCurrentStatStruct(obj);
						
						% CALL EXTERNAL FUNCTION WITH CUDA-KERNEL-GENERATING SUBFUNCTION
						[dstat, stat] = differentialMomentGeneratorRunGpuKernel(F, stat);
						
					else
						
						[dstat, stat] = differentialMomentGeneratorRunGpuKernel(F);
					end
					
					% STORE STATISTIC-UPDATES
					obj.N = stat.N;
					obj.Min = stat.Min;
					obj.Max = stat.Max;
					obj.M1 = stat.M1;
					obj.M2 = stat.M2;
					obj.M3 = stat.M3;
					obj.M4 = stat.M4;
					
				else
					
					% -----------------------------------
					% CPU VERSION
					% -----------------------------------
					fpType = obj.pPrecision;
					n = obj.N;
					nb = size(F,3);
					m1 = obj.M1;
					m2 = obj.M2;
					m3 = obj.M3;
					m4 = obj.M4;
					% 					F = cast(F, fpType);
					dM1 = zeros(size(F),'like',m1);
					dM2 = zeros(size(F),'like',m2);
					dM3 = zeros(size(F),'like',m3);
					dM4 = zeros(size(F),'like',m4);
					
					% CENTRAL MOMENTS WITH INCREMENTAL/DIFFERENTIAL CHANGE
					k = 0;
					while k < nb
						k = k + 1;
						n = n + 1;
						d = cast(F(:,:,k,:), 'like', m1) - m1;
						dk = d./n;
						dk2 = dk.^2;
						s = d.*dk.*(n-1);
						
						% DIFFERENTIAL UPDATE
						dm1 = dk;
						dm4 = s.*dk2.*(n.^2-3*n+3) + 6*dk2.*m2 - 4.*dk.*m3;
						dm3 = s.*dk.*(n-2) - 3.*dk.*m2;
						dm2 = s;
						
						% INCREMENTAL/RUNNING UPDATE
						m1 = m1 + dm1;
						m4 = m4 + dm4;
						m3 = m3 + dm3;
						m2 = m2 + dm2;
						
						% FILL IN ARRAY FOR OUTPUT
						dM1(:,:,k,:) = dm1;
						dM2(:,:,k,:) = dm2;
						dM3(:,:,k,:) = dm3;
						dM4(:,:,k,:) = dm4;
						
					end
					
					% MAX & MIN
					obj.N = n;
					obj.Min = min(min(F, [],3), obj.Min);
					obj.Max = max(max(F, [],3), obj.Max);
					
					% UPDATE PROPERTIES
					obj.M1 = m1;
					obj.M2 = m2;
					obj.M3 = m3;
					obj.M4 = m4;
					
					% STRUCTURE OUTPUT
					dstat.M1 = dM1;
					dstat.M2 = dM2;
					dstat.M3 = dM3;
					dstat.M4 = dM4;
					
				end
			end
			
		end
		function stat = getCurrentStatStruct(obj)
			
			stat = struct(...
				'N', obj.N,...
				'Min', obj.Min,...
				'Max', obj.Max,...
				'M1', obj.M1,...
				'M2', obj.M2,...
				'M3', obj.M3,...
				'M4', obj.M4);
			
		end
		function X = getDefaultStat(obj)
			if isempty(obj.FrameSize)
				X = [];
			else
				if obj.UseGpu
					X = gpuArray.zeros(obj.FrameSize,'single');
				else
					X = zeros(obj.FrameSize,'single');
				end
			end
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
						getReport(me)
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
						getReport(me)
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
						obj.(pn) = gpuArray(obj.GpuRetrievedProps.(pn));
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
		function stat = getStatistics(obj, leaveOnGpu)
			if nargin < 2
				leaveOnGpu = false;
			end
			if leaveOnGpu || ~obj.UseGpu
				stat = struct(...
					'N', obj.N,...
					'Min', obj.Min,...
					'Max', obj.Max,...
					'Mean', obj.Mean,...
					'StandardDeviation', obj.StandardDeviation,...
					'Variance', obj.Variance,...
					'Skewness', obj.Skewness,...
					'Kurtosis', obj.Kurtosis,...
					'JarqueBera', obj.JarqueBera);
			else
				stat = struct(...
					'N', obj.N,...
					'Min', onCpu(obj, obj.Min),...
					'Max', onCpu(obj, obj.Max),...
					'Mean', onCpu(obj, obj.Mean),...
					'StandardDeviation', onCpu(obj, obj.StandardDeviation),...
					'Variance', onCpu(obj, obj.Variance),...
					'Skewness', onCpu(obj, obj.Skewness),...
					'Kurtosis', onCpu(obj, obj.Kurtosis),...
					'JarqueBera', onCpu(obj, obj.JarqueBera));
			end
		end
		function cmom = getCentralMoments(obj)
			
			cmom = struct(...
				'N', obj.N,...
				'M1', obj.M1,...
				'M2', obj.M2,...
				'M3', obj.M3,...
				'M4', obj.M4);
			
		end
		function show(obj)
			
			% REMAP STATS TO RANGE CONDUCIVE TO COMPARATIVE VISUALIZATION
			imMin = normalizeImage(obj.Min);
			imMax = normalizeImage(obj.Max);
			imMean = normalizeImage(obj.Mean);
			imStdev = normalizeImage(obj.StandardDeviation);
			imSkew = normalizeImage(sqrt(abs(obj.Skewness)).*sign(obj.Skewness)); % or log(abs(
			imKurt = normalizeImage(log(obj.Kurtosis+3));
			
			% IMAGE MONTAGE
			imStatCat = cat(2, ...
				cat(1, imMin, imMax), ...
				cat(1, imStdev , imMean), ...
				cat(1, imSkew, imKurt));
			h.im = imagesc(imStatCat);
			
			% TEXT
			[m,n] = size(imStatCat);
			y = m/50;
			dy = m/2;
			x = m/50;
			dx = n/3;
			h.tx(1) = text( x, y, 'Min');
			h.tx(2) = text( x, y+dy, 'Max');
			h.tx(3) = text( x+dx, y, 'Mean');
			h.tx(4) = text( x+dx, y+dy, 'StandardDeviation');
			h.tx(5) = text( x+2*dx, y, 'Skewness');
			h.tx(6) = text( x+2*dx, y+dy, 'Kurtosis');
			set(h.tx, 'FontSize',14)
			% 			'String', idxText,...
			% 				'FontWeight','normal',... 'BackgroundColor',[.1 .1 .1 .3],... 'Color',
			% 				otherColor,... 'FontSize',fontSize,... 'Margin',1,... 'Position',
			% 				infoTextPosition,... 'Parent', h.axCurrent));
			
			
			h.ax = handle(gca);
			h.ax.Position = [0 0 1 1];
			h.ax.DataAspectRatio = [1 1 1];
			axis off
			assignin('base','h',h)
			
			function im = normalizeImage(im)
				if isa(im, 'gpuArray')
					im = gather(im);
				end
				im = double(im);
				
				% 				im = imadjust( (im-min(im(:)))./range(im(:)), stretchlim(im, [.05 .995]));
				
				
				
				
				im = max( im, .5*(mean(min(im,[],1)) + mean(min(im,[],2),1)));
				im = min( im, .5*(mean(max(im,[],1)) + median(max(im,[],2),1)));
				im = imadjust( (im-min(im(:)))./range(im(:)), stretchlim(im, [.10 .9999]));
				im = mcclurenormfcn(im);
				
				function f = mcclurenormfcn(f)
					% Akin to Geman-McClure function
					f = bsxfun(@minus, f, min(min(f,[],1),[],2));
					f = bsxfun(@rdivide, f, max(max(f,[],1),[],2));
					a = .5*(mean(max(f,[],1),2) + mean(max(f,[],2),1));
					f = exp(1) * f.^2 ./ (1 + bsxfun(@rdivide, f.^2 , a.^2));
					
				end
				
			end
		end
	end
	
	
	
	
	
	
	
	
	
	
end






