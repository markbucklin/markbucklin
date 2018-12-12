classdef TypeDescriptionSet < extmgr.AbstractSet
    %TypeDescriptionSet   Define the TypeDescriptionSet class.
    
    %   Copyright 2012 The MathWorks, Inc.
    
    methods
        
        function this = TypeDescriptionSet(varargin)
            %TypeDescriptionSet   Construct the TypeDescriptionSet class.
            mlock;
            this@extmgr.AbstractSet;
            add(this, varargin{:});
        end
        
        function add(this, varargin)
            %ADD Add extension type to type database.
            %  ADD(hRegisterDb,T1,T2,...) adds RegisterType objects T1, T2, ...,
            %  to extension database with handle hRegisterDb.
            if nargin < 2
                return;
            end
            
            if ~isa(varargin{1}, 'extmgr.TypeDescription')
                varargin = {extmgr.TypeDescription(varargin{:})};
            end
            
            % One or more RegisterType objects passed
            for i=1:numel(varargin)
                hRegisterType = varargin{i};
                
                % See if type is already present in database
                % If so, remove the old and use the newer.
                if ~isempty(findType(this, hRegisterType.Type))
                    remove(this, 'Type', hRegisterType.Type);
                end
                
                add@extmgr.AbstractSet(this, hRegisterType);
            end
        end
        
        function hRegisterType = findType(this,theType)
            %FINDTYPE Find extension type in type database.
            %  FINDTYPE(H,'theType') returns specified extension type in database.
            %  If not found, empty is returned.
            
            % hRegisterType = iterator.findImmediateChild(this, ...
            %     @(hRegisterType)strcmpi(hRegisterType.Type,theType));
            
            % This is faster, still case-independent since UDD offers that
            % service via find implicitly:
            hRegisterType = findobj(this.Children, 'Type', theType);
        end
        
        function o = getOrder(this, type)
            hType = findobj(this.Children, 'Type', type);
            if isempty(hType)
                o = 0;
            else
                o = hType.Order;
            end
        end
        
        function c = getConstraint(this,theType)
            %GETCONSTRAINT Return constraint corresponding to extension type.
            %  GETCONSTRAINT(H,'theType') returns specified extension constraint
            %  specified in database.  If type not found, the default constraint
            %  'EnableAny' is returned.
            
            hRegisterType = findobj(this.Children, 'Type', theType);
            if isempty(hRegisterType)
                c = extmgr.EnableAny(theType);
            else
                c = hRegisterType.Constraint;
            end
        end
    end
    methods (Hidden)
        function node = getTreeNode(this)
            %GETTREENODE Get the treeNode.
            
            hChildren = this.Children;
            node = {uiscopes.message('TextRegisterTypes'), {}};
            
            for description = hChildren
                node{2}{end+1} = description.getTreeNode;
            end
        end
        
        function nodeInfo = getNodeInfo(this)
            %GETNODEINFO Get the nodeInfo.
            
            nodeInfo.Title = uiscopes.message('TextTypeDescriptionDBNodeInfo');
            nodeInfo.Widgets = {uiscopes.message('TextNumberOfRegistrateredTypes') sprintf('%d', this.numChild)};
        end
        
        function hObject = getObjectFromPath(this, path)
            %GETOBJECTFROMPATH Get the objectFromPath.
            
            hObject = this.findType(path);
        end
    end
    
    methods (Access = protected, Static)
        function c = getChildClass
            c = 'extmgr.TypeDescription';
        end
    end
end

% [EOF]
