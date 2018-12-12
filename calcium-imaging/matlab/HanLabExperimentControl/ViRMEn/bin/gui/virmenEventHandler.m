function virmenEventHandler(type,inp)

global virmenDragging
virmenDragging = [];

guifig = findall(0,'name','ViRMEn');
toolbar = findall(guifig,'type','uitoolbar');

switch type
    case 'shapeClick'
        %
    case 'objectClick'
        %
    case 'worldSketchClick'
        %
    case 'textureSketchClick'
        %
    otherwise
        set(guifig,'Pointer','watch');
        drawnow
end

handles = guidata(guifig);
if isempty(handles)
    return
end

wNum = handles.state.selectedWorld;
oNum = handles.state.selectedObject;
sNum = handles.state.selectedShape;

justSaved = false;

handles.exper.updateCodeText;

switch type
    case 'changeView'
        ax = findobj(handles.figs.worldDrawing,'type','axes');
        if ~isempty(ax)
            switch inp
                case 'isometric'
                    set(ax,'view',[-45 45]);
                case 'top'
                    set(ax,'view',[0 90]);
                case 'front'
                    set(ax,'view',[0 0]);
                case 'side'
                    set(ax,'view',[90 0]);
            end
        end
    case 'rotateView';
        ax = findobj(handles.figs.worldDrawing,'type','axes');
        if ~isempty(ax)
            v = get(ax,'view');
            v = round(v/(45/3))*(45/3);
            switch inp
                case 'right'
                    v(1) = v(1)-45/3;
                case 'left'
                    v(1) = v(1)+45/3;
                case 'down'
                    v(2) = v(2)+45/3;
                    if v(2)>90
                        v(2) = 90;
                    end
                case 'up'
                    v(2) = v(2)-45/3;
                    if v(2)<-90
                        v(2) = -90;
                    end
            end
            set(ax,'view',v);
        end
    case 'editCode'
        if strcmp(func2str(handles.exper.(inp)),'undefined')
            errordlg('Cannot edit undefined code.','Error');
        else
            if exist([func2str(handles.exper.(inp)) '.m'],'file')
                fname = [func2str(handles.exper.(inp)) '.m'];
            elseif exist([func2str(handles.exper.(inp)) '.c'],'file')
                fname = [func2str(handles.exper.(inp)) '.c'];
            else
                fname = [];
            end
            if ~isempty(fname)
                edit(fname);
            else
                errordlg(['Cannot edit ' func2str(handles.exper.(inp)) '.'],'Error');
            end
        end
        set(guifig,'Pointer','arrow'); return
    case 'startProgram'
        handles.figs = createFigures;
        handles.separated = setdiff(findall(guifig,'separator','on'),findall(guifig,'type','uimenu'));
        justSaved = true;   
        
        undo.param = {'startProgram'};
        redo.param = {'startProgram'};
        
        set(guifig,'resizefcn','virmenEventHandler(''resizeFigure'',''n/a'')');
    case 'shapeClick'
        if ischar(inp) && strcmp(inp,'n/a')
            inp = {sNum,'open'};
        end
        if iscell(inp)
            str = inp{2};
            inp = inp{1};
        else
            str = get(gcf,'selectiontype');
        end
        switch str
            case 'normal'
                handles.state.selectedShape = inp;
                if handles.state.selectedShape > 1 && strcmp(get(gco,'type'),'line')
                    if isempty(virmenDragging)
                        virmenDragging.type = 'shape';
                        virmenDragging.object = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp};
                        virmenDragging.backupUnitsFigure = get(gcf,'units');
                        virmenDragging.backupUnitsAxes = get(gca,'units');
                        set(gcf,'units','pixels');
                        virmenDragging.startPt = get(gcf,'currentpoint');
                        set(gcf,'units',virmenDragging.backupUnitsFigure);
                        [x, y] = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp}.coords2D;
                        virmenDragging.axes = gca;
                        virmenDragging.x = x;
                        virmenDragging.y = y;
                        virmenDragging.tempShape = [];
                        virmenDragging.marker = get(gco,'marker');
                        virmenDragging.markerSize = get(gco,'markersize');
                    else
                        virmenDragging = [];
                    end
                end
            case 'extend'
                if handles.state.selectedShape > 1 && strcmp(get(gco,'type'),'line')
                    virmenDragging.type = 'shapeLocation';
                    virmenDragging.object = copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp});
                    virmenDragging.backupUnitsFigure = get(gcf,'units');
                    virmenDragging.backupUnitsAxes = get(gca,'units');
                    pos = get(gca,'currentpoint');
                    pos = pos(1,1:2);
                    set(gcf,'units','pixels');
                    virmenDragging.startPt = get(gcf,'currentpoint');
                    set(gcf,'units',virmenDragging.backupUnitsFigure);
                    virmenDragging.axes = gca;
                    loc = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp}.locations;
                    virmenDragging.startX = loc(:,1);
                    virmenDragging.startY = loc(:,2);
                    virmenDragging.x = virmenDragging.startX;
                    virmenDragging.y = virmenDragging.startY;
                    virmenDragging.tempShape = [];
                    virmenDragging.marker = get(gco,'marker');
                    virmenDragging.markerSize = get(gco,'markersize');
                    dst = sum(bsxfun(@minus,loc,pos).^2,2);
                    [~, virmenDragging.indx] = min(dst);
                end
            case 'alt'
                if handles.state.selectedShape > 1 && strcmp(get(gco,'type'),'line')
                    virmenDragging.type = 'shapeCopy';
                    virmenDragging.object = copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp});
                    virmenDragging.backupUnitsFigure = get(gcf,'units');
                    virmenDragging.backupUnitsAxes = get(gca,'units');
                    pos = get(gca,'currentpoint');
                    pos = pos(1,1:2);
                    set(gcf,'units','pixels');
                    virmenDragging.startPt = get(gcf,'currentpoint');
                    set(gcf,'units',virmenDragging.backupUnitsFigure);
                    virmenDragging.axes = gca;
                    loc = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp}.locations;
                    virmenDragging.startX = loc(:,1);
                    virmenDragging.startY = loc(:,2);
                    virmenDragging.x = virmenDragging.startX;
                    virmenDragging.y = virmenDragging.startY;
                    virmenDragging.tempShape = [];
                    virmenDragging.marker = get(gco,'marker');
                    virmenDragging.markerSize = get(gco,'markersize');
                    dst = sum(bsxfun(@minus,loc,pos).^2,2);
                    [~, virmenDragging.indx] = min(dst);
                end
            case 'open'
                handles.state.selectedShape = inp;
                if strcmp(class(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp}),'shapeColor')
                    col = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{inp}.RGBA;
                    newcol = uisetcolor(col(1:3));
                    str = {num2str(newcol(1)); num2str(newcol(2)); num2str(newcol(3)); num2str(col(4))};
                    guidata(guifig, handles)
                    virmenEventHandler('changeShapeProperties',{{'R','G','B','Alpha'},str});
                    set(guifig,'Pointer','arrow'); return
                end
        end
    case 'addShape'
        subplot(findobj(handles.figs.textureSketch,'type','axes'))
        obj = eval(inp);
        try
            obj = getPoints(obj);
        catch %#ok<CTCH>
            errordlg('Error entering shape locations.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        if ~isempty(obj.locations)
            handles.exper.worlds{wNum}.objects{oNum}.texture = addShape(handles.exper.worlds{wNum}.objects{oNum}.texture,obj,'new');
            handles.state.selectedShape = length(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes);
            undo.param = {'deleteShape',wNum,oNum,handles.state.selectedShape};
            redo.param = {'addShape',wNum,oNum,handles.state.selectedShape,copyVirmenObject(obj)};
        else
            set(guifig,'Pointer','arrow'); return
        end
        
    case 'deleteShape'
        undo.param = {'addShape',wNum,oNum,sNum, handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}};
        redo.param = {'deleteShape',wNum,oNum,sNum};
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes(sNum) = [];
        if handles.state.selectedShape > length(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes)
            handles.state.selectedShape = handles.state.selectedShape - 1;
        end
    case 'computeTexture'
            oth = zeros(0,2);
            for w = 1:length(handles.exper.worlds)
                for o = 1:length(handles.exper.worlds{w}.objects)
                    if ~all([w o]==[wNum oNum]) && isequalwithequalnans(handles.exper.worlds{w}.objects{o}.texture.triangles, ...
                            handles.exper.worlds{wNum}.objects{oNum}.texture.triangles)
                        oth(end+1,:) = [w o]; %#ok<AGROW>
                    end
                end
            end
            undo.param = {{'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)}};
            handles.exper.worlds{wNum}.objects{oNum}.texture.compute;
            redo.param = {{'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)}};
            if ~isempty(oth)
                str = cell(1,size(oth,1));
                for ndx = 1:size(oth,1)
                    str{ndx} = handles.exper.worlds{oth(ndx,1)}.objects{oth(ndx,2)}.fullName;
                end
                [indx,ok] = listdlg('ListString',str,'InitialValue',1:length(str),'ListSize',[250 150], ...
                    'Name','Select objects','PromptString','Change other objects with identical texture:');
                if ok > 0
                    for ndx = 1:length(indx)
                        undo.param{end+1,1} = {'changeProperty',oth(indx(ndx),:),'texture',copyVirmenObject(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)}.texture)};
                        setTexture(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)},handles.exper.worlds{wNum}.objects{oNum}.texture,'copy');
                        redo.param{end+1,1} = {'changeProperty',oth(indx(ndx),:),'texture',copyVirmenObject(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)}.texture)};
                    end
                end
            end
            if size(undo.param,1)==1
                undo.param = undo.param{1};
                redo.param = redo.param{1};
            end
    case 'refineTexture'
        answer = refiningGui(handles.exper.worlds{wNum}.objects{oNum}.texture,handles.state.triangulationColor,handles.state.showTriangulation);
        if isempty(answer)
            set(guifig,'Pointer','arrow'); return
        end
        virmenEventHandler('changeTextureRefining',answer);
        set(guifig,'Pointer','arrow'); return
    case 'changeTextureRefining'
        oth = zeros(0,2);
        for w = 1:length(handles.exper.worlds)
            for o = 1:length(handles.exper.worlds{w}.objects)
                if ~all([w o]==[wNum oNum]) && isequalwithequalnans(handles.exper.worlds{w}.objects{o}.texture.triangles, ...
                        handles.exper.worlds{wNum}.objects{oNum}.texture.triangles)
                    oth(end+1,:) = [w o]; %#ok<AGROW>
                end
            end
        end
        undo.param = {{'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)}};
        handles.exper.worlds{wNum}.objects{oNum}.texture.refining = inp(1:2)';
        handles.exper.worlds{wNum}.objects{oNum}.texture.grid = inp(3:4)';
        handles.exper.worlds{wNum}.objects{oNum}.texture.tilable = inp(5:6)';
        handles.exper.worlds{wNum}.objects{oNum}.texture.compute;
        redo.param = {{'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)}};
        if ~isempty(oth)
            str = cell(1,size(oth,1));
            for ndx = 1:size(oth,1)
                str{ndx} = handles.exper.worlds{oth(ndx,1)}.objects{oth(ndx,2)}.fullName;
            end
            [indx,ok] = listdlg('ListString',str,'InitialValue',1:length(str),'ListSize',[250 150], ...
                'Name','Select objects','PromptString','Change other objects with identical texture:');
            if ok > 0
                for ndx = 1:length(indx)
                    undo.param{end+1,1} = {'changeProperty',oth(indx(ndx),:),'texture',copyVirmenObject(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)}.texture)};
                    setTexture(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)},handles.exper.worlds{wNum}.objects{oNum}.texture,'copy');
                    redo.param{end+1,1} = {'changeProperty',oth(indx(ndx),:),'texture',copyVirmenObject(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)}.texture)};
                end
            end
        end
        if size(undo.param,1)==1
            undo.param = undo.param{1};
            redo.param = redo.param{1};
        end
    case 'showTriangulation'
        if strcmp(inp{1},'on')
            handles.state.showTriangulation = 1;
        elseif strcmp(inp{1},'off')
            handles.state.showTriangulation = 0;
        else
            handles.state.showTriangulation = 1-handles.state.showTriangulation;
        end
    case 'triangulationColor'
        handles.state.triangulationColor = uisetcolor(handles.state.triangulationColor);
    case 'textureSketchClick'
        switch get(gcf,'selectiontype')
            case 'normal'
                set(gca,'units','pixels');
                set(get(gca,'parent'),'units','pixels');
                set(get(get(gca,'parent'),'parent'),'units','pixels');
                set(guifig,'Pointer','custom','PointerShapeCdata',zoomPointer);
                rect = rbbox;
                set(guifig,'Pointer','watch');
                
                pos = get(gca,'position');
                pos2 = get(get(gca,'parent'),'position');
                pos(1:2) = pos(1:2)+pos2(1:2);
                set(get(get(gca,'parent'),'parent'),'units','normalized');
                set(get(gca,'parent'),'units','normalized');
                set(gca,'units','normalized');
                xl = xlim;
                yl = ylim;
                
                rect(1) = xl(1)+(rect(1)-pos(1))/pos(3)*(xl(2)-xl(1));
                rect(3) = rect(3)/pos(3)*(xl(2)-xl(1));
                rect(2) = yl(1)+(rect(2)-pos(2))/pos(4)*(yl(2)-yl(1));
                rect(4) = rect(4)/pos(4)*(yl(2)-yl(1));
                xl = [rect(1) rect(1)+rect(3)];
                yl = [rect(2) rect(2)+rect(4)];
                if rect(3)==0 || rect(4)==0
                    set(guifig,'Pointer','arrow'); return
                end
            case 'extend'
                buff = 1.05;
                xl = [0 handles.exper.worlds{wNum}.objects{oNum}.texture.width];
                yl = [0 handles.exper.worlds{wNum}.objects{oNum}.texture.height];
                xl = [mean(xl)-buff/2*range(xl) mean(xl)+buff/2*range(xl)];
                yl = [mean(yl)-buff/2*range(yl) mean(yl)+buff/2*range(yl)];
            case 'alt'
                pos = get(gca,'currentpoint');
                pos = pos(1,1:2);
                xl = xlim;
                yl = ylim;
                buff = 2;
                xl = [pos(1)-buff/2*range(xl) pos(1)+buff/2*range(xl)];
                yl = [pos(2)-buff/2*range(yl) pos(2)+buff/2*range(yl)];
            otherwise
                set(guifig,'Pointer','arrow'); return
        end
        
        handles.state.textureXLim = xl;
        handles.state.textureYLim = yl;
    case 'worldSketchClick'
        switch get(gcf,'selectiontype')
            case 'normal'
                set(gca,'units','pixels');
                set(get(gca,'parent'),'units','pixels');
                set(get(get(gca,'parent'),'parent'),'units','pixels');
                set(guifig,'Pointer','custom','PointerShapeCdata',zoomPointer);
                rect = rbbox;
                set(guifig,'Pointer','watch');
                
                pos = get(gca,'position');
                pos2 = get(get(gca,'parent'),'position');
                pos(1:2) = pos(1:2)+pos2(1:2);
                set(get(get(gca,'parent'),'parent'),'units','normalized');
                set(get(gca,'parent'),'units','normalized');
                set(gca,'units','normalized');
                xl = xlim;
                yl = ylim;
                
                rect(1) = xl(1)+(rect(1)-pos(1))/pos(3)*(xl(2)-xl(1));
                rect(3) = rect(3)/pos(3)*(xl(2)-xl(1));
                rect(2) = yl(1)+(rect(2)-pos(2))/pos(4)*(yl(2)-yl(1));
                rect(4) = rect(4)/pos(4)*(yl(2)-yl(1));
                xl = [rect(1) rect(1)+rect(3)];
                yl = [rect(2) rect(2)+rect(4)];
                if rect(3)==0 || rect(4)==0
                    set(guifig,'Pointer','arrow'); return
                end
            case 'extend'
                if isempty(handles.exper.worlds{wNum}.objects)
                    xl = handles.defaultProperties.worldXLim;
                    yl = handles.defaultProperties.worldYLim;
                else
                    axis tight;
                    xl = xlim;
                    yl = ylim;
                    buff = 1.05;
                    xl = [mean(xl)-buff/2*range(xl) mean(xl)+buff/2*range(xl)];
                    yl = [mean(yl)-buff/2*range(yl) mean(yl)+buff/2*range(yl)];
                end
            case 'alt'
                pos = get(gca,'currentpoint');
                pos = pos(1,1:2);
                xl = xlim;
                yl = ylim;
                buff = 2;
                xl = [pos(1)-buff/2*range(xl) pos(1)+buff/2*range(xl)];
                yl = [pos(2)-buff/2*range(yl) pos(2)+buff/2*range(yl)];
            otherwise
                set(guifig,'Pointer','arrow'); return
        end

        handles.state.worldXLim = xl;
        handles.state.worldYLim = yl;

    case 'objectClick'
        handles.state.selectedObject = inp;
        handles.state.selectedShape = 1;
        if strcmp(get(gcf,'selectiontype'),'normal') && handles.state.selectedObject > 0 && get(gca,'parent')==handles.worldSketch && strcmp(get(gco,'type'),'line')
            if isempty(virmenDragging)
                virmenDragging.type = 'object';
                virmenDragging.object = handles.exper.worlds{wNum}.objects{handles.state.selectedObject};
                virmenDragging.backupUnitsFigure = get(gcf,'units');
                virmenDragging.backupUnitsAxes = get(gca,'units');
                set(gcf,'units','pixels');
                virmenDragging.startPt = get(gcf,'currentpoint');
                set(gcf,'units',virmenDragging.backupUnitsFigure);
                [x, y, ~] = handles.exper.worlds{wNum}.objects{handles.state.selectedObject}.coords2D;
                virmenDragging.axes = gca;
                virmenDragging.x = x;
                virmenDragging.y = y;
                virmenDragging.tempShape = [];
                virmenDragging.marker = get(gco,'marker');
                virmenDragging.markerSize = get(gco,'markersize');
            else
                virmenDragging = [];
            end
        elseif strcmp(get(gcf,'selectiontype'),'extend') && handles.state.selectedObject > 0 && get(gca,'parent')==handles.worldSketch && strcmp(get(gco,'type'),'line')
            virmenDragging.type = 'objectLocation';
            virmenDragging.object = copyVirmenObject(handles.exper.worlds{wNum}.objects{handles.state.selectedObject});
            virmenDragging.backupUnitsFigure = get(gcf,'units');
            virmenDragging.backupUnitsAxes = get(gca,'units');
            pos = get(gca,'currentpoint');
            pos = pos(1,1:2);
            set(gcf,'units','pixels');
            virmenDragging.startPt = get(gcf,'currentpoint');
            set(gcf,'units',virmenDragging.backupUnitsFigure);
            virmenDragging.axes = gca;
            loc = handles.exper.worlds{wNum}.objects{handles.state.selectedObject}.locations;
            virmenDragging.startX = loc(:,1);
            virmenDragging.startY = loc(:,2);
            virmenDragging.x = virmenDragging.startX;
            virmenDragging.y = virmenDragging.startY;
            virmenDragging.tempShape = [];
            virmenDragging.marker = get(gco,'marker');
            virmenDragging.markerSize = get(gco,'markersize');
            dst = sum(bsxfun(@minus,loc,pos).^2,2);
            [~, virmenDragging.indx] = min(dst);
        elseif strcmp(get(gcf,'selectiontype'),'alt') && handles.state.selectedObject > 0 && get(gca,'parent')==handles.worldSketch && strcmp(get(gco,'type'),'line')
            virmenDragging.type = 'objectCopy';
            virmenDragging.object = copyVirmenObject(handles.exper.worlds{wNum}.objects{handles.state.selectedObject});
            virmenDragging.backupUnitsFigure = get(gcf,'units');
            virmenDragging.backupUnitsAxes = get(gca,'units');
            pos = get(gca,'currentpoint');
            pos = pos(1,1:2);
            set(gcf,'units','pixels');
            virmenDragging.startPt = get(gcf,'currentpoint');
            set(gcf,'units',virmenDragging.backupUnitsFigure);
            virmenDragging.axes = gca;
            loc = handles.exper.worlds{wNum}.objects{handles.state.selectedObject}.locations;
            virmenDragging.startX = loc(:,1);
            virmenDragging.startY = loc(:,2);
            virmenDragging.x = virmenDragging.startX;
            virmenDragging.y = virmenDragging.startY;
            virmenDragging.tempShape = [];
            virmenDragging.marker = get(gco,'marker');
            virmenDragging.markerSize = get(gco,'markersize');
            dst = sum(bsxfun(@minus,loc,pos).^2,2);
            [~, virmenDragging.indx] = min(dst);
        elseif strcmp(get(gcf,'selectiontype'),'open') && handles.state.selectedObject > 0
            virmenEventHandler('builtinLayout','texture');
            set(guifig,'Pointer','arrow'); return
        end
    case 'addObject'
        subplot(findobj(handles.figs.worldSketch,'type','axes'))
        obj = eval(inp);
        try
            obj = getPoints(obj);
        catch %#ok<CTCH>
            errordlg('Error entering object locations.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        obj.tiling = handles.defaultProperties.tiling;
        obj.edgeRadius = handles.defaultProperties.edgeRadius;
        obj.texture.tilable = handles.defaultProperties.textureTilable;
        obj.texture.refining = handles.defaultProperties.triangulationRefining;
        obj.texture.grid = handles.defaultProperties.triangulationGrid;
        obj.texture.compute;
        
        if ~isempty(obj.locations)
            handles.exper.worlds{wNum} = addObject(handles.exper.worlds{wNum},obj,'new');
            handles.state.selectedObject = length(handles.exper.worlds{wNum}.objects);
            handles.state.selectedShape = 1;
            undo.param = {'deleteObject',wNum,handles.state.selectedObject};
            redo.param = {'addObject',wNum,handles.state.selectedObject,copyVirmenObject(obj)};
        else
            set(guifig,'Pointer','arrow'); return
        end
    case 'deleteObject'
        undo.param = {'addObject',wNum,oNum,handles.exper.worlds{wNum}.objects{oNum}};
        redo.param = {'deleteObject',wNum,oNum};
        handles.exper.worlds{wNum}.objects(oNum) = [];
        if handles.state.selectedObject > length(handles.exper.worlds{wNum}.objects)
            handles.state.selectedObject = handles.state.selectedObject - 1;
        end
    case 'changeWorldBackground'
        undo.param = {'changeProperty',wNum,'backgroundColor',handles.exper.worlds{wNum}.getValue.backgroundColor};
        c = uisetcolor(handles.exper.worlds{wNum}.backgroundColor);
        handles.exper.worlds{wNum}.backgroundColor = c;
        redo.param = {'changeProperty',wNum,'backgroundColor',handles.exper.worlds{wNum}.getValue.backgroundColor};
    case 'switchWireframe'
        switch inp{1}
            case 'on'
                handles.state.showWireframe = 1;
            case 'off'
                handles.state.showWireframe = 0;
            case 'switch'
                handles.state.showWireframe = 1-handles.state.showWireframe;
                
        end
    case 'changeTiling'
        undo.param = {'changeProperty',[wNum oNum],'tiling',handles.exper.worlds{wNum}.objects{oNum}.getValue.tiling};
        til = handles.exper.worlds{wNum}.objects{oNum}.getValue.tiling;
        til{inp{1}} = inp{2};
        handles.exper.worlds{wNum}.objects{oNum}.tiling = til;
        redo.param = {'changeProperty',[wNum oNum],'tiling',handles.exper.worlds{wNum}.objects{oNum}.getValue.tiling};
    case 'renameObject'
        undo.param = {{'changeProperty',[wNum oNum],'name',handles.exper.worlds{wNum}.objects{oNum}.name};
            {'changeProperty',[wNum oNum NaN],'name',handles.exper.worlds{wNum}.objects{oNum}.texture.name}};
        answer = inputdlg({['New name for object ' handles.exper.worlds{wNum}.objects{oNum}.fullName],...
            'New name for the object''s texture'}, ...
            'New name',1,{handles.exper.worlds{wNum}.objects{oNum}.name, handles.exper.worlds{wNum}.objects{oNum}.texture.name});
        if isempty(answer)
            set(guifig,'Pointer','arrow'); return
        end
        if ~isvarname(answer{1})
            errordlg(['''' answer{1} ''' is an invalid variable name.'],'Error','modal');
            set(guifig,'Pointer','arrow'); return
        end
        if ~isvarname(answer{2})
            errordlg(['''' answer{2} ''' is an invalid variable name.'],'Error','modal');
            set(guifig,'Pointer','arrow'); return
        end
        handles.exper.worlds{wNum}.objects{oNum}.name = answer{1};
        handles.exper.worlds{wNum}.objects{oNum}.texture.name = answer{2};
        redo.param = {{'changeProperty',[wNum oNum],'name',handles.exper.worlds{wNum}.objects{oNum}.name};
            {'changeProperty',[wNum oNum NaN],'name',handles.exper.worlds{wNum}.objects{oNum}.texture.name}};
    case 'sortObjects'
        if length(handles.exper.worlds{wNum}.objects)<2
            errordlg('Need at least two objects to reorder.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        fld = cell(1,length(handles.exper.worlds{wNum}.objects));
        for ndx = 1:length(fld)
            fld{ndx} = handles.exper.worlds{wNum}.objects{ndx}.fullName;
        end
        ord = reorderVariables(fld,'Objects');
        if ~all(ord==(1:length(ord)))
            [~,orig] = sort(ord);
            undo.param = {'sortObjects',wNum,orig};
            redo.param = {'sortObjects',wNum,ord};
            handles.exper.worlds{wNum}.objects = handles.exper.worlds{wNum}.objects(ord);
            if oNum > 0
                handles.state.selectedObject = find(ord==oNum);
            end
        else
            set(guifig,'Pointer','arrow'); return
        end
    case 'changeObjectProperties'
        if oNum == 0
            str = handles.exper.worlds{wNum}.getValue.startLocation;
            switch inp{1}
                case 'X'
                    str{1} = inp{2};
                case 'Y'
                    str{2} = inp{2};
                case 'Z'
                    str{3} = inp{2};
                case 'rotation'
                    str{4} = inp{2};
            end
            undo.param = {'changeProperty',wNum,'startLocation',handles.exper.worlds{wNum}.getValue.startLocation};
            handles.exper.worlds{wNum}.startLocation = str;
            redo.param = {'changeProperty',wNum,'startLocation',handles.exper.worlds{wNum}.getValue.startLocation};
        else
            undo.param = {'changeProperty',[wNum oNum],inp{1},handles.exper.worlds{wNum}.objects{oNum}.getValue.(inp{1})};
            handles.exper.worlds{wNum}.objects{oNum}.(inp{1}) = inp{2};
            redo.param = {'changeProperty',[wNum oNum],inp{1},handles.exper.worlds{wNum}.objects{oNum}.getValue.(inp{1})};
        end
    case 'changeObjectLocations'
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.symbolic.x)
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.symbolic.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.getValue.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.getValue.y}};
        end
        handles.exper.worlds{wNum}.objects{oNum}.x = inp(:,1);
        handles.exper.worlds{wNum}.objects{oNum}.y = inp(:,2);
        redo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.getValue.x};
            {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.getValue.y}};
    case 'addObjectLocation'
        val = get(handles.table_objectLocations,'data');
        val = val(:,2:end);
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.symbolic.x)
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.symbolic.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.getValue.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.getValue.y}};
        end
        handles.exper.worlds{wNum}.objects{oNum}.x = val(:,1);
        handles.exper.worlds{wNum}.objects{oNum}.y = val(:,2);
        handles.exper.worlds{wNum}.objects{oNum}.x(end+1) = 0;
        handles.exper.worlds{wNum}.objects{oNum}.y(end+1) = 0;
        redo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.getValue.x};
            {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.getValue.y}};
    case 'deleteObjectLocations'
        indx = get(handles.table_objectLocations,'userdata');
        if isempty(indx)
            errordlg('No locations selected.','Error')
            set(guifig,'Pointer','arrow'); return
        end
        val = get(handles.table_objectLocations,'data');
        val = val(:,2:end);
        if size(val,1) == 1
            errordlg('At least one location is required.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.symbolic.x)
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.symbolic.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.getValue.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.getValue.y}};
        end
        handles.exper.worlds{wNum}.objects{oNum}.x = val(:,1);
        handles.exper.worlds{wNum}.objects{oNum}.y = val(:,2);
        handles.exper.worlds{wNum}.objects{oNum}.x(indx) = [];
        handles.exper.worlds{wNum}.objects{oNum}.y(indx) = [];
        redo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.getValue.x};
            {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.getValue.y}};
    case 'changeSymbolicObjectLocations'
        str = {'',''};
        
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.symbolic.x)
            str{1} = handles.exper.worlds{wNum}.objects{oNum}.symbolic.x;
            str{2} = handles.exper.worlds{wNum}.objects{oNum}.symbolic.y;
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.symbolic.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum],'x',handles.exper.worlds{wNum}.objects{oNum}.getValue.x};
                {'changeProperty',[wNum oNum],'y',handles.exper.worlds{wNum}.objects{oNum}.getValue.y}};
        end
        
        answer = inputdlg({'Symbolic expression for object X','Symbolic expression for object Y'},'Symbolic',1,str);
        if isempty(answer)
            set(guifig,'Pointer','arrow'); return
        end
        redo.param = cell(0,1);
        if ~isempty(answer{1})
            handles.exper.worlds{wNum}.objects{oNum}.x = answer{1};
            redo.param{end+1,1} = {'changeProperty',[wNum oNum],'x',answer{1}};
        end
        if ~isempty(answer{2})
            handles.exper.worlds{wNum}.objects{oNum}.y = answer{2};
            redo.param{end+1,1} = {'changeProperty',[wNum oNum],'y',answer{2}};
        end
        if size(redo.param,1)==1
            redo.param = redo.param{1};
        end
    case 'renameShape'
        str = get(handles.pop_shape,'string');
        val = get(handles.pop_shape,'value');
        answer = inputdlg({['New name for ' str{val}]},'New name',1,str(val));
        if isempty(answer)
            set(guifig,'Pointer','arrow'); return
        end
        if ~isvarname(answer{1})
            errordlg(['''' answer{1} ''' is an invalid variable name.'],'Error');
            set(guifig,'Pointer','arrow'); return
        end
        undo.param = {'changeProperty',[wNum oNum NaN sNum],'name',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.name};
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.name = answer{1};
        redo.param = {'changeProperty',[wNum oNum NaN sNum],'name',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.name};
    case 'sortShapes'
        if length(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes)<3
            errordlg('Need at least two shapes other than the boundary to reorder.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        fld = cell(1,length(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes)-1);
        for ndx = 1:length(fld)
            fld{ndx} = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{ndx+1}.fullName;
        end
        ord = reorderVariables(fld,'Shapes');
        if ~all(ord==(1:length(ord)))
            [~,orig] = sort(ord);
            undo.param = {'sortObjects',wNum,oNum,orig};
            redo.param = {'sortObjects',wNum,oNum,ord};
            handles.exper.worlds{wNum}.objects{oNum}.texture.shapes(2:end) = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes(ord+1);
            if sNum > 1
                handles.state.selectedShape = find(ord==sNum-1)+1;
            end
        else
            set(guifig,'Pointer','arrow'); return
        end
    case 'changeShapeProperties'
        undo.param = cell(0,1);
        redo.param = cell(0,1);
        for ndx = 1:length(inp{1})
            undo.param{end+1,1} = {'changeProperty',[wNum oNum NaN sNum],inp{1}{ndx},handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.(inp{1}{ndx})};
            handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.(inp{1}{ndx}) = inp{2}{ndx};
            redo.param{end+1,1} = {'changeProperty',[wNum oNum NaN sNum],inp{1}{ndx},handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.(inp{1}{ndx})};
        end
        if size(undo.param,1)==1
            undo.param = undo.param{1};
            redo.param = redo.param{1};
        end
    case 'changeShapeLocations'
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x)
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.y}};
        end
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.x = inp(:,1);
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.y = inp(:,2);
        redo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.x};
            {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.y}};
    case 'addShapeLocation'
        val = get(handles.table_shapeLocations,'data');
        val = val(:,2:end);
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x)
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.y}};
        end
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.x = val(:,1);
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.y = val(:,2);
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.x(end+1) = 0;
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.y(end+1) = 0;
        redo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.x};
            {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.y}};
    case 'deleteShapeLocations'
        indx = get(handles.table_shapeLocations,'userdata');
        if isempty(indx)
            errordlg('No locations selected.','Error')
            set(guifig,'Pointer','arrow'); return
        end
        val = get(handles.table_shapeLocations,'data');
        val = val(:,2:end);
        if size(val,1) == 1
            errordlg('At least one location is required.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x)
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.y}};
        end
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.x = val(:,1);
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.y = val(:,2);
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.x(indx) = [];
        handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.y(indx) = [];
        redo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.x};
            {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.y}};
    case 'changeSymbolicShapeLocations'
        str = {'',''};
        if ischar(handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x)
            str{1} = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x;
            str{2} = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.y;
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.symbolic.y}};
        else
            undo.param = {{'changeProperty',[wNum oNum NaN sNum],'x',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.x};
                {'changeProperty',[wNum oNum NaN sNum],'y',handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.getValue.y}};
        end
        answer = inputdlg({'Symbolic expression for shape X','Symbolic expression for shape Y'},'Symbolic',1,str);
        if isempty(answer)
            set(guifig,'Pointer','arrow'); return
        end
        
        redo.param = cell(0,1);
        if ~isempty(answer{1})
            handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.x = answer{1};
            redo.param{end+1,1} = {'changeProperty',[wNum oNum NaN sNum],'x',answer{1}};
        end
        if ~isempty(answer{2})
            handles.exper.worlds{wNum}.objects{oNum}.texture.shapes{sNum}.y = answer{2};
            redo.param{end+1,1} = {'changeProperty',[wNum oNum NaN sNum],'y',answer{2}};
        end
        if size(redo.param,1)==1
            redo.param = redo.param{1};
        end
    case 'changeLayout'
        layout = handles.layouts{inp};
        layout = rmfield(layout,'name');
        layout = rmfield(layout,'icon');
        handles.figs = figureLayout(handles.figs,layout);
        
        f = findall(guifig,'type','uimenu','label','Layout');
        ch = get(f,'children');
        set(ch,'checked','off');
        f(1) = findall(guifig,'type','uimenu','label','Experiment layout');
        f(2) = findall(guifig,'type','uimenu','label','World layout');
        f(3) = findall(guifig,'type','uimenu','label','Texture layout');
        f(4) = findall(guifig,'type','uimenu','label','3D world view');
        set(f,'checked','off');
        set(ch(length(ch)-inp+1),'checked','on');
        if inp < 4
            set(f(inp),'checked','on');
        end
        
        set(guifig,'Pointer','arrow'); return
    case 'builtinLayout'
        f = findall(guifig,'type','uimenu','label','Layout');
        ch = get(f,'children');
        set(ch,'checked','off');
        f = findall(guifig,'type','uimenu','label','Experiment layout');
        set(f,'checked','off');
        f = findall(guifig,'type','uimenu','label','World layout');
        set(f,'checked','off');
        f = findall(guifig,'type','uimenu','label','Texture layout');
        set(f,'checked','off');
        f = findall(guifig,'type','uimenu','label','3D world view');
        set(f,'checked','off');
        
        layout = struct;
        switch inp
            case 'experiment'
                set(ch(length(ch)),'checked','on');
                f = findall(guifig,'type','uimenu','label','Experiment layout');
                set(f,'checked','on');
                layout = handles.layouts{1};
            case 'world'
                set(ch(length(ch)-1),'checked','on');
                f = findall(guifig,'type','uimenu','label','World layout');
                set(f,'checked','on');
                layout = handles.layouts{2};
            case 'texture'
                set(ch(length(ch)-2),'checked','on');
                f = findall(guifig,'type','uimenu','label','Texture layout');
                set(f,'checked','on');
                layout = handles.layouts{3};
            case '3d'
                layout.worldDrawing = [0 0 1 1];
                f = findall(guifig,'type','uimenu','label','3D world view');
                set(f,'checked','on');
        end
        if ~strcmp(inp,'3d')
            layout = rmfield(layout,'name');
            layout = rmfield(layout,'icon');
        end
        handles.figs = figureLayout(handles.figs,layout);
        if strcmp(inp,'3d')
            rotate3d on
        end
        set(guifig,'Pointer','arrow'); return
    case 'changeVariables'
        undo.param = {'changeVariables',inp{1},handles.exper.variables.(inp{1})};
        handles.exper.variables.(inp{1}) = inp{2};
        redo.param = {'changeVariables',inp{1},handles.exper.variables.(inp{1})};
    case 'saveExperiment'
        mfile = mfilename('fullpath');
        path = fileparts(mfile);
        if isempty(handles.state.fileName)
            filename = '*.mat';
        else
            filename = handles.state.fileName;
        end
        [filename, pathname] = uiputfile([path filesep '..' filesep '..' filesep 'experiments' filesep filename],'Save experiment');
        if ~ischar(filename)
            set(guifig,'Pointer','arrow'); return
        end
        if strcmp(func2str(handles.exper.experimentCode),'undefined')
            mfileName = filename;
            if ~exist([path filesep '..' filesep '..' filesep 'experiments' filesep mfileName(1:end-4) '.m'],'file')
                handles.exper.experimentCode = str2func(mfileName(1:end-4));
                fidIn = fopen([path filesep '..' filesep '..' filesep 'defaults' filesep 'defaultVirmenCode.m']);
                fidOut = fopen([path filesep '..' filesep '..' filesep 'experiments' filesep mfileName(1:end-4) '.m'],'w'); %#ok<MCMFL>
                while 1
                    tline = fgetl(fidIn);
                    if ~ischar(tline)
                        break
                    end
                    tline = strrep(tline,'defaultVirmenCode',mfileName(1:end-4));
                    tline = strrep(tline,'%','%%');
                    fprintf(fidOut,[tline '\n']);
                end
                fclose(fidIn);
                fclose(fidOut);
            end
            edit([path filesep '..' filesep '..' filesep 'experiments' filesep mfileName(1:end-4) '.m']);
        end
        handles.exper.name = filename(1:end-4);
        exper = handles.exper; %#ok<NASGU>
        save([pathname filename],'exper');
        handles.state.fileName = filename;
        justSaved = true;
    case 'openExperiment'
        f = findall(toolbar,'tooltipstring','Save experiment');
        if strcmp(get(f,'enable'),'on')
            button = questdlg('Save changes before closing?','Save','Yes','No','Cancel','Cancel');
            switch button
                case 'Yes'
                    virmenEventHandler('saveExperiment');
                    if strcmp(get(f,'enable'),'on')
                        set(guifig,'Pointer','arrow'); return
                    end
                case 'No'
                    % Do nothing
                case 'Cancel'
                    set(guifig,'Pointer','arrow'); return
            end
        end
        
        mfile = mfilename('fullpath');
        path = fileparts(mfile);
        [filename, pathname] = uigetfile([path filesep '..' filesep '..' filesep 'experiments' filesep '*.mat'],'Open experiment');
        if ~ischar(filename)
            set(guifig,'Pointer','arrow'); return
        end
        load([pathname filename],'exper');
        handles.exper = exper; %#ok<NODEF>
        handles.exper.enableCallbacks;
        
        handles.state.fileName = filename;
        handles.state.selectedWorld = 1;
        handles.state.selectedObject = 0;
        handles.state.selectedShape = 1;
        justSaved = true;
        handles.history.position = 1;
        handles.history.states{handles.history.position}.state = handles.state;
        for ndx = 2:length(handles.history.states)
            handles.history.states{ndx}.state = [];
        end
        
        mfile = mfilename('fullpath');
        path = fileparts(mfile);
        mf = dir([path filesep '..' filesep '..' filesep 'experiments' filesep '*.m']);
        isFound = false;
        for ndx = 1:length(mf)
            f = strfind(mf(ndx).name,'.');
            if strcmp(mf(ndx).name(1:f(end)-1),func2str(handles.exper.experimentCode))
                isFound = true;
            end
        end
        if ~isFound
            fid = fopen([path filesep '..' filesep '..' filesep 'experiments' filesep func2str(handles.exper.experimentCode) '.m'],'w');
            for ndx = 1:length(handles.exper.codeText)
                fprintf(fid,'%s',handles.exper.codeText{ndx});
                fprintf(fid,'\n');
            end
            fclose(fid);
            warndlg(['Associated .m file was not found. A file ''' func2str(handles.exper.experimentCode) '.m'' was created with recovered code.'],'Warning','modal');
        end
        
    case 'newExperiment'
        f = findall(toolbar,'tooltipstring','Save experiment');
        if strcmp(get(f,'enable'),'on')
            button = questdlg('Save changes before closing?','Save','Yes','No','Cancel','Cancel');
            switch button
                case 'Yes'
                    virmenEventHandler('saveExperiment');
                    if strcmp(get(f,'enable'),'on')
                        set(guifig,'Pointer','arrow'); return
                    end
                case 'No'
                    % Do nothing
                case 'Cancel'
                    set(guifig,'Pointer','arrow'); return
            end
        end
        
        handles.exper = virmenExperiment;
        handles.exper.antialiasing = handles.defaultProperties.antialiasing;
        handles.exper.worlds{1}.backgroundColor = handles.defaultProperties.worldBackgroundColor;
        handles.exper.worlds{1}.startLocation = handles.defaultProperties.startLocation;
        
        mfile = mfilename('fullpath');
        path = fileparts(mfile);
        fid = fopen([path filesep '..' filesep '..' filesep 'defaults' filesep 'defaultFunctions.txt']);
        txt = textscan(fid,'%s','delimiter','\t');
        txt = txt{1};
        for ndx = 1:2:length(txt)-1
            handles.exper.(txt{ndx}) = str2func(txt{ndx+1});
        end
        fclose(fid);
        
        handles.state = virmenGuiState(handles.defaultProperties);
        justSaved = true;
        handles.history.position = 1;
        handles.history.states{handles.history.position}.state = handles.state;
        for ndx = 2:length(handles.history.states)
            handles.history.states{ndx}.state = [];
        end
    case 'changeHistory'
        switch inp
            case 'undo'
                historyAct = handles.history.states{handles.history.position}.undo;
                handles.history.position = handles.history.position-1;
                handles.state = handles.history.states{handles.history.position}.state;
            case 'redo'
                historyAct = handles.history.states{handles.history.position}.redo;
                handles.history.position = handles.history.position+1;
                handles.state = handles.history.states{handles.history.position}.state;
        end
        if size(historyAct.param,1) == 1
            historyAct.param = {historyAct.param};
        end
        for j = 1:size(historyAct.param,1)
            switch historyAct.param{j}{1}
                case 'addShape'
                    wNum = historyAct.param{j}{2};
                    oNum = historyAct.param{j}{3};
                    sNum = historyAct.param{j}{4};
                    shape = historyAct.param{j}{5};
                    addShape(handles.exper.worlds{wNum}.objects{oNum}.texture,shape);
                    handles.exper.worlds{wNum}.objects{oNum}.texture.shapes = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes([1:sNum-1 end sNum:end-1]);
                case 'deleteShape'
                    wNum = historyAct.param{j}{2};
                    oNum = historyAct.param{j}{3};
                    sNum = historyAct.param{j}{4};
                    handles.exper.worlds{wNum}.objects{oNum}.texture.shapes(sNum) = [];
                case 'addObject'
                    wNum = historyAct.param{j}{2};
                    oNum = historyAct.param{j}{3};
                    obj = historyAct.param{j}{4};
                    addObject(handles.exper.worlds{wNum},obj);
                    handles.exper.worlds{wNum}.objects = handles.exper.worlds{wNum}.objects([1:oNum-1 end oNum:end-1]);
                case 'deleteObject'
                    wNum = historyAct.param{j}{2};
                    oNum = historyAct.param{j}{3};
                    handles.exper.worlds{wNum}.objects(oNum) = [];
                case 'changeProperty'
                    indx = historyAct.param{j}{2};
                    prop = historyAct.param{j}{3};
                    val = historyAct.param{j}{4};
                    switch length(indx)
                        case 0
                            handles.exper.(prop) = val;
                        case 1
                            handles.exper.worlds{indx(1)}.(prop) = val;
                        case 2
                            handles.exper.worlds{indx(1)}.objects{indx(2)}.(prop) = val;
                        case 3
                            handles.exper.worlds{indx(1)}.objects{indx(2)}.texture.(prop) = val;
                        case 4
                            handles.exper.worlds{indx(1)}.objects{indx(2)}.texture.shapes{indx(4)}.(prop) = val;
                    end
                case 'sortObjects'
                    wNum = historyAct.param{j}{2};
                    ord = historyAct.param{j}{3};
                    handles.exper.worlds{wNum}.objects = handles.exper.worlds{wNum}.objects(ord);
                case 'sortShapes'
                    wNum = historyAct.param{j}{2};
                    oNum = historyAct.param{j}{3};
                    ord = historyAct.param{j}{4};
                    handles.exper.worlds{wNum}.objects{oNum}.texture.shapes = handles.exper.worlds{wNum}.objects{oNum}.texture.shapes(ord);
                case 'changeVariables'
                    varb = historyAct.param{j}{2};
                    val = historyAct.param{j}{3};
                    handles.exper.variables.(varb) = val;
                case 'sortWorlds'
                    ord = historyAct.param{j}{2};
                    handles.exper.worlds = handles.exper.worlds(ord);
                case 'addWorld'
                    wNum = historyAct.param{j}{2};
                    obj = historyAct.param{j}{3};
                    addWorld(handles.exper,obj);
                    handles.exper.worlds = handles.exper.worlds([1:wNum-1 end wNum:end-1]);
                case 'deleteWorld'
                    wNum = historyAct.param{j}{2};
                    handles.exper.worlds(wNum) = [];
                case 'addVariables'
                    fld = historyAct.param{j}{4};
                    for v = 1:length(historyAct.param{j}{2})
                        varb = historyAct.param{j}{2}{v};
                        val = historyAct.param{j}{3}{v};
                        handles.exper.variables.(varb) = val;
                    end
                    ord = zeros(1,length(fld));
                    currfld = fieldnames(handles.exper.variables);
                    for f = 1:length(fld)
                        ord(f) = find(cellfun(@(x)strcmp(x,fld{f}),currfld));
                    end
                    handles.exper.variables = orderfields(handles.exper.variables,ord);
                case 'deleteVariables'
                    for v = 1:length(historyAct.param{j}{2})
                        varb = historyAct.param{j}{2}{v};
                        handles.exper.variables = rmfield(handles.exper.variables,varb);
                    end
                case 'sortVariables'
                    ord = historyAct.param{j}{2};
                    handles.exper.variables = orderfields(handles.exper.variables,ord);
            end
        end
    case 'changeExperimentProperties'
        if strcmp(class(handles.exper.(inp{1})),'function_handle')
            undo.param = {'changeProperty',[],inp{1},handles.exper.(inp{1})};
        else
            undo.param = {'changeProperty',[],inp{1},handles.exper.getValue.(inp{1})};
        end
        handles.exper.(inp{1}) = inp{2};
        if strcmp(class(handles.exper.(inp{1})),'function_handle')
            redo.param = {'changeProperty',[],inp{1},handles.exper.(inp{1})};
        else
            redo.param = {'changeProperty',[],inp{1},handles.exper.getValue.(inp{1})};
        end
    case 'clickWorld'
        if handles.state.selectedWorld ~= inp
            handles.state.selectedWorld = inp;
            handles.state.selectedObject = 0;
            handles.state.selectedShape = 1;
        end
        if strcmp(get(gcf,'selectiontype'),'open')
            virmenEventHandler('builtinLayout','world');
        end
    case 'editWorld'
        if handles.state.selectedWorld ~= inp
            handles.state.selectedWorld = inp;
            handles.state.selectedObject = 0;
            handles.state.selectedShape = 1;
        end
        guidata(guifig, handles)
        virmenEventHandler('builtinLayout','world');
    case 'renameWorld'
        if ischar(inp) && strcmp(inp,'n/a')
            inp = wNum;
        end
        answer = inputdlg({['New name for ''' handles.exper.worlds{inp}.name '''']},'New name',1,{handles.exper.worlds{inp}.name});
        if isempty(answer)
            set(guifig,'Pointer','arrow'); return
        end
        if ~isvarname(answer{1})
            errordlg(['''' answer{1} ''' is an invalid variable name.'],'Error');
            set(guifig,'Pointer','arrow'); return
        end
        undo.param = {'changeProperty',inp,'name',handles.exper.worlds{inp}.name};
        handles.exper.worlds{inp}.name = answer{1};
        redo.param = {'changeProperty',inp,'name',handles.exper.worlds{inp}.name};
    case 'sortWorlds'
        if length(handles.exper.worlds)<2
            errordlg('Need at least two worlds to reorder.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        fld = cell(1,length(handles.exper.worlds));
        for ndx = 1:length(fld)
            fld{ndx} = handles.exper.worlds{ndx}.fullName;
        end
        ord = reorderVariables(fld,'Worlds');
        if ~all(ord==(1:length(ord)))
            [~,orig] = sort(ord);
            undo.param = {'sortWorlds',orig};
            redo.param = {'sortWorlds',ord};
            handles.exper.worlds = handles.exper.worlds(ord);
            handles.state.selectedWorld = find(ord==wNum);
        else
            set(guifig,'Pointer','arrow'); return
        end
    case 'addWorld'
        world = virmenWorld;
        world.backgroundColor = handles.defaultProperties.worldBackgroundColor;
        world.startLocation = handles.defaultProperties.startLocation;
        handles.exper = addWorld(handles.exper,world,'new');
        handles.state.selectedWorld = length(handles.exper.worlds);
        handles.state.selectedObject = 0;
        handles.state.selectedShape = 1;
        undo.param = {'deleteWorld',handles.state.selectedWorld};
        redo.param = {'addWorld',handles.state.selectedWorld,copyVirmenObject(world)};
    case 'deleteWorld'
        if length(handles.exper.worlds)==1
            errordlg('At least one world is required.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        undo.param = {'addWorld',wNum,handles.exper.worlds{wNum}};
        redo.param = {'deleteWorld',wNum};
        handles.exper.worlds(wNum) = [];
        if wNum > length(handles.exper.worlds)
            handles.state.selectedWorld = handles.state.selectedWorld - 1;
        end
        handles.state.selectedObject = 0;
        handles.state.selectedShape = 1;
    case 'addVariable'
        answer = inputdlg({'New variable name','Value for the new variable'},'New variable',1,{'',''});
        if isempty(answer)
            set(guifig,'Pointer','arrow'); return
        end
        if ~isvarname(answer{1})
            errordlg([answer{1} ' is not a valid variable name.'],'Error');
            set(guifig,'Pointer','arrow'); return
        end
        undo.param = {'deleteVariables',answer(1)};
        handles.exper.variables.(answer{1}) = answer{2};
        redo.param = {'addVariables',answer(1),answer(2),fieldnames(handles.exper.variables)};
    case 'deleteVariables'
        data = get(handles.table_variables,'data');
        row = data(:,1);
        indx = get(handles.table_variables,'userdata');
        if isempty(indx)
            errordlg('No variables selected.','Error')
            set(guifig,'Pointer','arrow'); return
        end
        val = row(indx);
        varVals = cell(1,length(val));
        for ndx = 1:length(val)
            varVals{ndx} = handles.exper.variables.(val{ndx});
        end
        undo.param = {'addVariables',val,varVals,fieldnames(handles.exper.variables)};
        redo.param = {'deleteVariables',val};
        for ndx = 1:length(val)
            handles.exper.variables = rmfield(handles.exper.variables,val{ndx});
        end
    case 'sortVariables'
        fld = fieldnames(handles.exper.variables);
        if length(fld)<2
            errordlg('Need at least two variables to reorder.','Error');
            set(guifig,'Pointer','arrow'); return
        end
        ord = reorderVariables(fld,'Variables');
        if ~all(ord==(1:length(ord)))
            [~,orig] = sort(ord);
            undo.param = {'sortVariables',orig};
            redo.param = {'sortVariables',ord};
            handles.exper.variables = orderfields(handles.exper.variables,ord);
        else
            set(guifig,'Pointer','arrow'); return
        end
    case 'importWorld'
        [world vars] = chooseObjectGui(handles.exper,'virmenWorld');
        if isempty(world)
            set(guifig,'Pointer','arrow'); return
        end
        world.enableCallbacks;
        varnames = fieldnames(vars);
        undo.param{2,1} = {'changeProperty',[],'variables',handles.exper.variables};
        for ndx = 1:length(varnames)
            handles.exper.variables.(varnames{ndx}) = vars.(varnames{ndx});
        end
        redo.param{1,1} = {'changeProperty',[],'variables',handles.exper.variables};
        handles.exper = addWorld(handles.exper,world,'copy');
        handles.state.selectedWorld = length(handles.exper.worlds);
        handles.state.selectedObject = 0;
        handles.state.selectedShape = 1;
        undo.param{1,1} = {'deleteWorld',handles.state.selectedWorld};
        redo.param{2,1} = {'addWorld',handles.state.selectedWorld,copyVirmenObject(world)};
    case 'importObject'
        [obj vars] = chooseObjectGui(handles.exper,'virmenObject');
        if isempty(obj)
            set(guifig,'Pointer','arrow'); return
        end
        obj.enableCallbacks;
        varnames = fieldnames(vars);
        undo.param{2,1} = {'changeProperty',[],'variables',handles.exper.variables};
        for ndx = 1:length(varnames)
            handles.exper.variables.(varnames{ndx}) = vars.(varnames{ndx});
        end
        redo.param{1,1} = {'changeProperty',[],'variables',handles.exper.variables};
        handles.exper.worlds{wNum} = addObject(handles.exper.worlds{wNum},obj,'copy');
        handles.state.selectedObject = length(handles.exper.worlds{wNum}.objects);
        handles.state.selectedShape = 1;
        undo.param{1,1} = {'deleteObject',wNum,handles.state.selectedObject};
        redo.param{2,1} = {'addObject',wNum,handles.state.selectedObject,copyVirmenObject(obj)};
    case 'loadImage'
        [filename, pathname] = uigetfile('*.gif;*.jpg;*.png', 'Pick an image file');
        if ~ischar(filename)
            set(guifig,'Pointer','arrow'); return
        end
        [img, colorMap, errorString] = readTextureImageFile([pathname filename]);
        if ~isempty(errorString)
            errordlg(errorString,'Error');
            set(guifig,'Pointer','arrow'); return
        end
        if isempty(img)
           set(guifig,'Pointer','arrow'); return
        end
        undo.param = {'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)};
        readImage(handles.exper.worlds{wNum}.objects{oNum}.texture,img,colorMap);
        redo.param = {'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)};
    case 'importTexture'
        [texture vars] = chooseObjectGui(handles.exper,'virmenTexture');
        if isempty(texture)
            set(guifig,'Pointer','arrow'); return
        end
        texture.enableCallbacks;
        varnames = fieldnames(vars);
        undo.param{1,1} = {'changeProperty',[],'variables',handles.exper.variables};
        for ndx = 1:length(varnames)
            handles.exper.variables.(varnames{ndx}) = vars.(varnames{ndx});
        end
        redo.param{1,1} = {'changeProperty',[],'variables',handles.exper.variables};
        
        oth = zeros(0,2);
        for w = 1:length(handles.exper.worlds)
            for o = 1:length(handles.exper.worlds{w}.objects)
                if ~all([w o]==[wNum oNum]) && isequalwithequalnans(handles.exper.worlds{w}.objects{o}.texture.triangles, ...
                        handles.exper.worlds{wNum}.objects{oNum}.texture.triangles)
                    oth(end+1,:) = [w o]; %#ok<AGROW>
                end
            end
        end
        undo.param{end+1,1} = {'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)};
        handles.exper.worlds{wNum}.objects{oNum} = setTexture(handles.exper.worlds{wNum}.objects{oNum},texture,'copy');
        redo.param{end+1,1} = {'changeProperty',[wNum oNum],'texture',copyVirmenObject(handles.exper.worlds{wNum}.objects{oNum}.texture)};
        if ~isempty(oth)
            str = cell(1,size(oth,1));
            for ndx = 1:size(oth,1)
                str{ndx} = handles.exper.worlds{oth(ndx,1)}.objects{oth(ndx,2)}.fullName;
            end
            [indx,ok] = listdlg('ListString',str,'InitialValue',1:length(str),'ListSize',[250 150], ...
                'Name','Select objects','PromptString','Change other objects with identical texture:');
            if ok > 0
                for ndx = 1:length(indx)
                    undo.param{end+1,1} = {'changeProperty',oth(indx(ndx),:),'texture',copyVirmenObject(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)}.texture)};
                    setTexture(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)},handles.exper.worlds{wNum}.objects{oNum}.texture,'copy');
                    redo.param{end+1,1} = {'changeProperty',oth(indx(ndx),:),'texture',copyVirmenObject(handles.exper.worlds{oth(indx(ndx),1)}.objects{oth(indx(ndx),2)}.texture)};
                end
            end
        end
        undo.param = undo.param([2:end 1]);
        handles.state.selectedShape = 1;
    case 'run'
        figs = findall(0,'type','figure','visible','on');
        set(figs,'visible','off');
        if strcmp(func2str(handles.exper.experimentCode),'undefined')
            handles.exper.experimentCode = @defaultVirmenCode;
            isDefault = true;
        else
            isDefault = false;
        end
        err = virmenEngine(handles.exper);
        if isDefault
            handles.exper.experimentCode = @undefined;
        end
        set(figs,'visible','on');
        figure(guifig);
        set(guifig,'Pointer','arrow');
        if isstruct(err)
            if isfield(err,'net');
                errordlg('Could not load file or assembly ''OpenTK.dll'' or one of its dependencies. Most likely, you need to edit the Matlab configuration file. See "Troubleshooting" in the ViRMEn Manual for details.');
            else
                errordlg(['User function ' err.stack(1).name ' generated an error on line ' num2str(err.stack(1).line) ': ' err.message],'Error');
            end
            if length(err.stack) > 1
                err.stack(2:end) = [];
            end
            error(err);
        end
        return
    case 'closeProgram'
        f = findall(toolbar,'tooltipstring','Save experiment');
        if strcmp(get(f,'enable'),'on')
            button = questdlg('Save changes before closing?','Save','Yes','No','Cancel','Cancel');
            switch button
                case 'Yes'
                    virmenEventHandler('saveExperiment');
                    if strcmp(get(f,'enable'),'on')
                        set(guifig,'Pointer','arrow'); return
                    end
                case 'No'
                    % Do nothing
                case 'Cancel'
                    set(guifig,'Pointer','arrow'); return
            end
        end
        delete(handles.mainFigure);
        varfig = findall(0,'name','ViRMEn variables');
        delete(varfig);
        aboutfig = findall(0,'name','About ViRMEn');
        delete(aboutfig);
        return
    case 'listVariables'
        variablesGui;
    case 'export'
        switch inp
            case 'World 2D'
                world = handles.exper.worlds{wNum};
                figure('Name',world.fullName);
                world.draw2D;
                view(2)
                xl = handles.state.worldXLim;
                yl = handles.state.worldYLim;
                set(gca,'units','pixels');
                pos = get(gca,'position');
                set(gca,'units','normalized');
                ar = pos(4)/pos(3);
                if range(yl)/range(xl) > ar
                    xl = mean(xl) + (xl-mean(xl))/range(xl)*range(yl)/ar;
                else
                    yl = mean(yl) + (yl-mean(yl))/range(yl)*range(xl)*ar;
                end
                xlim(xl);
                ylim(yl);
                axis equal
            case 'World 3D'
                world = handles.exper.worlds{wNum};
                figure('Name',world.fullName);
                world.draw3D;
                axis equal
                axis tight
                set(gca,'color',world.backgroundColor);
            case 'World wireframe'
                world = handles.exper.worlds{wNum};
                figure('Name',world.fullName);
                [~, he, hp] = world.draw2D;
                delete([he hp]);
                view(3)
                axis equal
                axis tight
            case 'Texture'
                if oNum == 0
                    errordlg('No object with texture selected.','Error');
                    set(guifig,'Pointer','arrow'); return
                end
                
                texture = handles.exper.worlds{wNum}.objects{oNum}.texture;
                
                figure('name',texture.fullName);
                h = texture.draw;
                
                if handles.state.showTriangulation == 0
                    set(h,'edgecolor','none');
                else
                    set(h,'edgecolor',handles.state.triangulationColor);
                end
                
                view(2);
                
                if isempty(handles.state.textureXLim)
                    xl = [-0.1*texture.width 1.1*texture.width];
                    yl = [-0.1*texture.height 1.1*texture.height];
                else
                    xl = handles.state.textureXLim;
                    yl = handles.state.textureYLim;
                end
                xlim(xl);
                ylim(yl);
                set(gca,'units','pixels');
                pos = get(gca,'position');
                set(gca,'units','normalized');
                ar = pos(4)/pos(3);
                if range(yl)/range(xl) > ar
                    xl = mean(xl) + (xl-mean(xl))/range(xl)*range(yl)/ar;
                else
                    yl = mean(yl) + (yl-mean(yl))/range(yl)*range(xl)*ar;
                end
                xlim(xl);
                ylim(yl);
                set(gca,'color',handles.exper.worlds{wNum}.backgroundColor);
                box on;
        end
    case 'manual'
        mfile = mfilename('fullpath');
        path = fileparts(mfile);
        winopen([path filesep '..' filesep 'documentation' filesep 'ViRMEn manual.pdf'])
        set(guifig,'Pointer','arrow'); return
    case 'about'
        virmenAboutWindow;
        set(guifig,'Pointer','arrow'); return
    case 'resizeFigure'
        %
end

f = findall(guifig,'tooltipstring','Save experiment');

if handles.historyBool.(type)
    undo.string = label2string(type);
    redo.string = undo.string;
    
    if handles.history.position == length(handles.history.states)
        handles.history.states = handles.history.states([2:end 1]);
        handles.history.states{end}.state = handles.state;
        handles.history.states{end}.undo = undo;
        handles.history.states{end-1}.redo = redo;
    else
        handles.history.position = handles.history.position + 1;
        handles.history.states{handles.history.position}.state = handles.state;
        handles.history.states{handles.history.position}.undo = undo;
        if handles.history.position > 1
            handles.history.states{handles.history.position-1}.redo = redo;
        end
        for ndx = handles.history.position+1:length(handles.history.states)
            handles.history.states{ndx}.state = [];
        end
    end
    set(f,'enable','on');
end

if handles.history.position > 0
    handles.history.states{handles.history.position}.state = handles.state;
end

if strcmp(type,'changeHistory')
    set(f,'enable','on');
end

if justSaved
    set(f,'enable','off');
end

f = findall(guifig,'clickedcallback','virmenEventHandler(''changeHistory'',''undo'');');
if handles.history.position == 1
    set(f,'enable','off');
    set(f,'tooltipstring','Undo');
else
    set(f,'enable','on');
    set(f,'tooltipstring',['Undo ' handles.history.states{handles.history.position}.undo.string]);
end
g = findall(guifig,'type','uimenu','callback','virmenEventHandler(''changeHistory'',''undo'');');
set(g,'label',get(f,'tooltipstring'),'userdata',get(f,'tooltipstring'));

f = findall(guifig,'clickedcallback','virmenEventHandler(''changeHistory'',''redo'');');
if handles.history.position == length(handles.history.states) || isempty(handles.history.states{handles.history.position+1}.state)
    set(f,'enable','off');
    set(f,'tooltipstring','Redo');
else
    set(f,'enable','on');
    set(f,'tooltipstring',['Redo ' handles.history.states{handles.history.position}.redo.string]);
end
g = findall(guifig,'type','uimenu','callback','virmenEventHandler(''changeHistory'',''redo'');');
set(g,'label',get(f,'tooltipstring'),'userdata',get(f,'tooltipstring'));

guidata(guifig, handles);
updateFigures(type);

set(guifig,'Pointer','arrow');

if ~strcmp(type,'changeVariables') && ~strcmp(type,'listVariables')
    set(0,'currentfigure',guifig);
end



function str = label2string(type)

str = type;
for ndx = 65:90
    str = strrep(str,char(ndx),[' ' char(ndx+32)]);
end
f = strfind(str,' ');

if ~isempty(f)
    f = f(1);
    if strcmp(str(f-1),'e')
        str = [str(1:f-2) 'ing' str(f:end)];
    else
        str = [str(1:f-1) 'ing' str(f:end)];
    end
end


function ptr = zoomPointer

ptr = [   NaN   NaN   NaN   NaN     1     1     1     1   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN
    NaN   NaN     1     1   NaN     2   NaN     2     1     1   NaN   NaN   NaN   NaN   NaN   NaN
    NaN     1     2   NaN     2     1     1   NaN     2   NaN     1   NaN   NaN   NaN   NaN   NaN
    NaN     1   NaN     2   NaN     1     1     2   NaN     2     1   NaN   NaN   NaN   NaN   NaN
    1   NaN     2   NaN     2     1     1   NaN     2   NaN     2     1   NaN   NaN   NaN   NaN
    1     2     1     1     1     1     1     1     1     1   NaN     1   NaN   NaN   NaN   NaN
    1   NaN     1     1     1     1     1     1     1     1     2     1   NaN   NaN   NaN   NaN
    1     2   NaN     2   NaN     1     1     2   NaN     2   NaN     1   NaN   NaN   NaN   NaN
    NaN     1     2   NaN     2     1     1   NaN     2   NaN     1   NaN   NaN   NaN   NaN   NaN
    NaN     1   NaN     2   NaN     1     1     2   NaN     2     1     2   NaN   NaN   NaN   NaN
    NaN   NaN     1     1     2   NaN     2   NaN     1     1     1     1     2   NaN   NaN   NaN
    NaN   NaN   NaN   NaN     1     1     1     1   NaN     2     1     1     1     2   NaN   NaN
    NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN     2     1     1     1     2   NaN
    NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN     2     1     1     1     2
    NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN     2     1     1     1
    NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN   NaN     2     1     2];