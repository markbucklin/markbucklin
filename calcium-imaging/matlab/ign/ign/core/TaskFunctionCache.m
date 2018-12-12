
%   Copyright 2013 The MathWorks, Inc.

classdef TaskFunctionCache < handle

    properties ( Access = private )
        TaskFunctionDependencyMap;
    end

    methods
        function obj = TaskFunctionCache()
            obj.TaskFunctionDependencyMap = containers.Map();
        end

        function put( obj, taskFcn, dependencies )
            assert(iscellstr(dependencies), 'Task dependencies must be a cellstr')
            obj.TaskFunctionDependencyMap( taskFcn ) = dependencies;
        end

        function deps = get( obj, taskFcn )
            deps = obj.TaskFunctionDependencyMap( taskFcn );
        end

        function tf = contains( obj, taskFcn )
            tf = obj.TaskFunctionDependencyMap.isKey( taskFcn );
        end

        function clear( obj )
            allKeys = obj.TaskFunctionDependencyMap.keys();
            obj.TaskFunctionDependencyMap.remove( allKeys );
        end
    end
end
