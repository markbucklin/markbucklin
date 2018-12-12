function GraphSaveGML(Graph,FileName)
% Exports graph into GML format. 
%
% Receives:
%   Graph - structure - graph object
%   FileName - string - name of the file. 
%
% Returns:
%   nothing
%
% See Also: 
%   GraphLoadGML, GraphLoad
% Example
%{
    GraphSaveGML(Graph,'NetworkLibrary/temp.gml'); 
%}
narginchk(2,2);
nargoutchk(0,0);

hFile = fopen(FileName,'w+t'); 
fprintf(hFile,'Creator "Complex Networks Toolbox for MatLab %s"\n',datestr(now));
fprintf(hFile,'graph\n[\n'); 

% nodes
Nodes = unique([Graph.Index.Values(:); unique(Graph.Data(:,1:2))]);
Names = cell(size(Nodes)); 
[~, ai, bi] = intersect(Nodes, Graph.Index.Values);
Names(ai) = Graph.Index.Names(bi);
for i =1 : numel(Nodes)
   fprintf(hFile,'  node\n  [\n     id %d\n', Nodes(i)); 
   if ~isempty(Names{i}), fprintf(hFile,'     label "%s"\n', Names{i}); end
   fprintf(hFile,'  ]\n');
end
% edges
for i =1 : size(Graph.Data,1)
    fprintf(hFile,'  edge\n  [\n    source %d\n    target %d\n    value %f\n  ]\n', Graph.Data(i,1), Graph.Data(i,2), Graph.Data(i,3));
end

fprintf(hFile,']\n'); % graph
fclose(hFile);
end % GraphSaveGML