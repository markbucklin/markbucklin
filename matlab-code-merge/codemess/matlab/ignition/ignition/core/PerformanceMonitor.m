classdef (CaseInsensitiveProperties, TruncatedProperties) PerformanceMonitor < handle
	% PerformanceMonitor
	
	
	
	properties (SetAccess = protected)
		LastTimePerFrame
		MeanTimePerFrame = 0
		MinTimePerFrame = inf
		MaxTimePerFrame = 0
		NumFramesBenchmarkedCount = 0
	end
	
	
	
	methods
		function obj = PerformanceMonitor(varargin)
			if nargin == 0
				% TODO
			else
				% TODO
			end
		end
		function addBenchmark(obj, Tn, numFrames)
			
			if (nargin < 3)
				numFrames = 1;
			end
			
			% CONVERT GIVEN TIME TO TIME-PER-FRAME
			tk = Tn/numFrames;
			obj.LastTimePerFrame = tk;
			t0 = obj.MeanTimePerFrame;
			
			% 			if ~isempty(t0)
			% UPDATE MEAN BENCHMARK
			N = obj.NumFramesBenchmarkedCount + numFrames;
			
			obj.MeanTimePerFrame = t0  +  (tk - t0).*(numFrames./N);
			
			% UPDATE MAX & MIN BENCHMARK
			obj.MinTimePerFrame = min( tk, obj.MinTimePerFrame);
			obj.MaxTimePerFrame = max( tk, obj.MaxTimePerFrame);
			
			% 			else
			% 				obj.MeanTimePerFrame = tk;
			% 				obj.MinTimePerFrame = tk;
			% 				obj.MaxTimePerFrame = tk;
			% 			end
			
			% UPDATE COUNT OF NUMBER OF FRAMES BENCHMARKED
			obj.NumFramesBenchmarkedCount = N;
			
		end
	end
	
	
	
end



% todo -> Latency (from original timestamp)
% todo -> Queueing delay (from previous timestamp)
% todo -> Throughput
% todo -> Granularity-Throughput Function
% todo -> Granularity-Latency Function
% todo -> Segmentation Function (same thing...?)