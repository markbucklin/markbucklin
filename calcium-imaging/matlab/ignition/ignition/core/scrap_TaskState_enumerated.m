classdef TaskState
	
	% check out parallel.internal.types.States
	
	enumeration
		PreConfigure
		Configuring
		PreInit
		Initializing
		Ready
		Queued
		Running
		Paused
		Stopped
		Finished
		Failed
	end
	
	%
	% 	 enumeration
	%         Pending     ( 'pending'     , 0  )
	%         Paused      ( 'paused'      , 1  )
	%         Queued      ( 'queued'      , 2  )
	%         Running     ( 'running'     , 3  )
	%         Finished    ( 'finished'    , 4  )
	%         % The following states are all >= Finished to ensure that "wait"s
	%         % terminate if the job fails or becomes unavailable.
	%         Failed      ( 'failed'      , 101 )
	%         Unavailable ( 'unavailable' , 102 )
	%         Destroyed   ( 'deleted'     , 103 )
	%         % State unknown is used internally to indicate that a cluster
	%         % does not know anything about a job or task state.  It is
	%         % never exposed to users for built-in integration, but is used
	%         % with the generic cluster interface.
	%         Unknown     ( 'unknown'     , 104 )
	% 	 end
	%
	%     properties ( SetAccess = immutable )
	%         Name    % The user-visible name of the State
	%     end
	%
	%     properties ( SetAccess = immutable, GetAccess = private )
	%         Ordinal % For comparisons
	%     end
	%
	%     methods ( Static )
	%         function e = fromName( name )
	%         % Return a State from a user-visible name.
	%             validateattributes( name, {'char'}, {} );
	%             map = iStateMaps();
	%             if ~map.isKey( name )
	%                 error(message('parallel:cluster:InvalidStateName', name));
	%             end
	%             e   = map(name);
	%         end
	%         function e = fromJavaString( name )
	%         % Return a State from a java.lang.String directly to avoid
	%         % too many calls to "char(...)".
	%             [~, ord2enum, jstr2ord] = iStateMaps();
	%             if ~jstr2ord.containsKey(name)
	%                 error(message('parallel:cluster:InvalidStateName', char(name)));
	%             end
	%             ord = double(jstr2ord.get(name));
	%             e = ord2enum(ord);
	%         end
	%         function tf = isValidState( nameOrState )
	%         % Is this State a "valid" state - i.e. not
	%         % unavailable/destroyed. Parameter can be specified as a States
	%         % enumeration or the Name of a States.
	%             import parallel.internal.types.States;
	%             if ischar( nameOrState )
	%                 state = States.fromName( nameOrState );
	%             else
	%                 validateattributes( nameOrState, ...
	%                                     {'parallel.internal.types.States'}, ...
	%                                     {'scalar'} );
	%                 state = nameOrState;
	%             end
	%             tf = ~ ( state == States.Unavailable || state == States.Destroyed );
	%         end
	%     end
	%
	%     methods ( Access = private )
	%         function tf = compare( o1, o2, fh )
	%         % Supports comparison of State objects
	%             %{
	%             validateattributes( o1, {'parallel.internal.types.States'}, {'scalar'} );
	%             validateattributes( o2, {'parallel.internal.types.States'}, {'scalar'} );
	%             validateattributes( fh, {'function_handle'}, {} );
	%             %}
	%             tf = fh( o1.Ordinal, o2.Ordinal );
	%         end
	%     end
	%
	%     methods
	%         function obj = States( name, ordinal )
	%             obj.Name    = name;
	%             obj.Ordinal = ordinal;
	%         end
	%         function tf = lt( obj1, obj2 ), tf = compare( obj1, obj2, @lt ); end
	%         function tf = gt( obj1, obj2 ), tf = compare( obj1, obj2, @gt ); end
	%         function tf = le( obj1, obj2 ), tf = compare( obj1, obj2, @le ); end
	%         function tf = ge( obj1, obj2 ), tf = compare( obj1, obj2, @ge ); end
	%
	%         function tf = isTerminal( obj )
	%         %Is this State a "terminal" State - i.e. one from which no progress is
	%         %ever expected.
	%             import parallel.internal.types.States;
	%             tf = ( obj == States.Finished || obj == States.Failed );
	%         end
	%     end
	%
	% end
	%
	% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	% % Return a mapping from State name to State
	% function [nameToEnum, ordinalToEnum, jstringToOrdinal] = iStateMaps()
	%     persistent NAME_MAP ORDINAL_TO_ENUM JSTRING_TO_ORDINAL
	%     if isempty( NAME_MAP )
	%         NAME_MAP = containers.Map();
	%         ORDINAL_TO_ENUM = containers.Map('KeyType', 'double', 'ValueType', 'any');
	%         JSTRING_TO_ORDINAL = java.util.HashMap();
	%         members  = enumeration( 'parallel.internal.types.States' );
	%         for ii = 1:length( members )
	%             NAME_MAP(members(ii).Name) = members(ii);
	%             ORDINAL_TO_ENUM(members(ii).Ordinal) = members(ii);
	%             JSTRING_TO_ORDINAL.put(java.lang.String(members(ii).Name), members(ii).Ordinal);
	%         end
	%     end
	%     nameToEnum = NAME_MAP;
	%     ordinalToEnum = ORDINAL_TO_ENUM;
	%     jstringToOrdinal = JSTRING_TO_ORDINAL;
	% end
	
	
	
	
	
end
