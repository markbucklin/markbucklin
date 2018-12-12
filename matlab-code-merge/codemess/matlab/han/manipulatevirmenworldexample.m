load('PondChase.mat')
w = exper.worlds{1};
xLocations = eval(exper.variables.xPond);
yLocations = eval(exper.variables.yPond);
% w.variables.targetLocation = [xLocations(1) yLocations(1)];
w.name = sprintf('PondWorld_%g',1);
numTotalWorlds = numel(eval(exper.variables.xPond));
for k = 2:numTotalWorlds
    w(k) = copyVirmenObject(w(1));
    w(k).name = sprintf('PondWorld_%g',k);
    xLoc = xLocations(k);
    yLoc = yLocations(k);
    xSymbolic = sprintf('xPond(%g)',k);
    ySymbolic = sprintf('yPond(%g)',k);

    objects = w(k).objects(1,:);
    for ok = 1:numel(objects)
        oname{ok} = objects{ok}.name;
    end
    namedPond = find(~cellfun('isempty',strfind(oname,'pond')));
    pondobjects = objects(1,namedPond);
    for po = 1:numel(pondobjects)
        pondobjects{po}.x = xLoc;
        pondobjects{po}.y = yLoc;
        pondobjects{po}.symbolic.x = {xSymbolic};
        pondobjects{po}.symbolic.y = {ySymbolic};
    end
    exper.addWorld(w(k));
end

exper = updateCode(exper);
% virmenExperimentsPath = 'C:\VirtualRealityLocal\ViRMEn\experiments';
save(fullfile(virmenExperimentPath,...
    'MultiPondLarger.mat'),'exper');

% err = run(exper);
% ve = virmenEngine(exper)










%     w(k).variables.targetLocation = [xLoc yLoc];

%     w.variables.worldNum = k;   


 % for k = 1:numel(pondobjects)
    %     pondobjects{k}.variables.worldNum = 1;
    % end
    % for k = 1:numel(pondobjects)
    %     pondobjects{k}.symbolic.x = {'xPond(worldNum)'};
    %     pondobjects{k}.symbolic.y = {'yPond(worldNum)'};
    % end