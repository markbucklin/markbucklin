classdef (HandleCompatible) SimpleSuperClass
	
	properties
		A
		B
	end
	properties (Constant)
		C = 1
	end
	
	
	methods
		function obj = SimpleSuperClass()
			obj.A = 1;
			obj.B = 0;
		end
		function sharedSuperMethod(obj)
			obj.B = obj.A;
		end
		function overriddenMethod(obj)
			obj.B = obj.A;
			disp('SimpleSuperClass:overriddenMethod')
		end
		function simpleInternalMethod(obj)
			obj.B = obj.A;
		end
		function obj = simpleInternalReturnMethod(obj)
			obj.B = obj.A;
		end
		function a = simpleGetMethod(obj)
			a = obj.A;
		end
		function obj = simpleSetMethod(obj, b)
			obj.B = b;
		end
	end
	methods (Access = protected)
		function obj = protectedAccessMethod(obj)
			obj.B = obj.B + 1;
		end
	end
	methods (Access = private)
		function obj = privateAccessMethod(obj, a)
			obj.B = obj.B + a;
			disp('SimpleSuperClass:privateAccessMethod')
		end
	end
	methods (Access = {?NumArgs, ?SimpleSuperClass})
		function obj = specificAccessMethod(obj)
			obj.B = obj.B + 1;
		end
	end
	methods (Static)
		function a = simpleStaticMethod(a)
			a = a + SimpleSuperClass.C;
		end
	end
	
	methods
		function fcn = getPrivateMethodHandle(obj)
			fcn = @privateAccessMethod;
		end
		function fcn = getOverriddenMethodHandle(obj)
			fcn = @overriddenMethod;
		end
		function [simplefh, anonfh] = getMethodHandles(obj)
			simplefh.constructor = @SimpleSuperClass.SimpleSuperClass;
			simplefh.internal = @simpleInternalMethod;
			simplefh.internalret = @simpleInternalReturnMethod;
			simplefh.get = @simpleGetMethod;
			simplefh.set = @simpleSetMethod;
			simplefh.prot = @protectedAccessMethod;
			simplefh.priv = @privateAccessMethod;
			simplefh.spec = @specificAccessMethod;
			simplefh.stat = @SimpleSuperClass.simpleStaticMethod;
			simplefh.classfcn = @simpleClassFunction;
			
			anonfh.constructor = @()SimpleSuperClass();
			anonfh.internal = @()simpleInternalMethod(obj);
			anonfh.internalret = @()simpleInternalReturnMethod(obj);
			anonfh.get = @()simpleGetMethod(obj);
			anonfh.set = @(b)simpleSetMethod(obj,b);
			anonfh.prot = @()protectedAccessMethod(obj);
			anonfh.priv = @()privateAccessMethod(obj);
			anonfh.spec = @()specificAccessMethod(obj);
			anonfh.stat = @(a)SimpleSuperClass.simpleStaticMethod;
			anonfh.classfcn = @(b)simpleClassFunction(b);
			
		end
	end
	
	
end

function b = simpleClassFunction(b)
if isempty(b)
	b = 0;
end
end
