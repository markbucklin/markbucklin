function [h,f] = showMouseMovement(M)
% Plots the curve defined by position vectors X and Y as well as a surface
% defined by offset curves.
% [tifName,tifDir] = uigetfile('*.tif','Select Tiff Files to Read Timestamps','MultiSelect','on')
% videoTimeStamp = readAllHamamatsuTimestamps( fullfile(tifDir,tifName));

%% Handle Input: Look for 'movementdata.mat' file or Query User if No Inputs Given
if nargin < 1
    M = loadDataFromFile();
end
assignin('base','M',M);

%% Settings
% colorRedGreen = false;
roadWidth = 1.0;
mouseSize = 1.6;
numInterp = 9;
numExtendFuture = 60;
numExtendPast = 60;
grayLevel = .35;
camHeight = roadWidth*10;
camTargetDist = camHeight*3;
camViewAngle = 70;
pathCurvature = pi/6; % radians
bodyAlpha = 1;
imageSize = [1024 1024];
N = numel(M.x);

%% Define Colormap & Fade Functions
lowOn = @() linspace(1,grayLevel,128)';
lowOff = @() linspace(0,grayLevel,128)';
highOn = @() linspace(grayLevel,1,128)';
highOff = @() linspace(grayLevel,0,128)';
% chanGrad = repmat( {lowOff() ; highOff()}, 1, 3);
% colorScheme = [...
%     1 0 1 ;...
%     1 1 0 ];
cmap = cat(1,...
    cat(2, lowOn(), lowOff(), lowOn()),...
    cat(2, highOn(), highOn(), highOff()));

% cgrad.blue2gray = [linspace(0,grayLevel,128)', linspace(0,grayLevel,128)', linspace(1,grayLevel,128)'];
% cgrad.gray2red = [linspace(grayLevel,1,128)', linspace(grayLevel,0,128)', linspace(grayLevel,0,128)'];
% cgrad.red2gray = [linspace(1,grayLevel,128)', linspace(0,grayLevel,128)', linspace(0,grayLevel,128)'];
% cgrad.gray2green = [linspace(grayLevel,0,128)', linspace(grayLevel,1,128)', linspace(grayLevel,0,128)'];
% if colorRedGreen
%     cmap = [...
%         cgrad.red2gray ;...
%         cgrad.gray2green];
% else
%     cmap = [...
%         cgrad.blue2gray ;...
%         cgrad.gray2red];
% end

%% Useful Functions -> Made Anonymous for Readability
futureFadeFcn = @(a) a;
pastFadeFcn = @(a) min(1,a).^2;
makeUnitVec = @(v) v ./ (hypot(v(:,1),v(:,2))+eps);
% Bezier Curve Interpolation
bezT = @(t,p1,p2,p3) [ones(numel(t),1) t(:) t(:).^2] * [1 0 0 ; -2 2 0 ; 1 -2 1] * [p1(:)' ; p2(:)' ; p3(:)'];
bezierInterp = @(p1,p2,p3) bezT(linspace(0,1,numInterp+1), p1, p2, p3);
% Position and Surrounding Reference Point Functions -> Using P(k) = [xk,yk,zk]
getPosition = @(k) [M.x(k) , M.y(k) , 0];
getVelocity = @(k) [M.dx(k), M.dy(k), 0] .* (1/M.dt(k));
getOrientation = @(k) M.theta(k);
validIdx = @(k) min(max(k,1),N);
getPriorMidPoint = @(k) 0.5 .* (getPosition(validIdx(k)) + getPosition(validIdx(k-1)));
getNextMidPoint = @(k) 0.5 .* (getPosition(validIdx(k)) + getPosition(validIdx(k+1)));
% Graphics Object Data Selection/Formation: stack top->bottom = past->future
stackGraphicsDataSegmentsPast2Future = @(gdataC,k) cat(1, gdataC{validIdx((k-numExtendPast):(k+numExtendFuture))});
getPathTransparencyProfile = @() repmat(cat(1,...
    pastFadeFcn( linspace(0, bodyAlpha, numExtendPast*numInterp))',...
    bodyAlpha.*ones(numInterp,1),...
    futureFadeFcn( linspace(bodyAlpha, 0, numExtendFuture*numInterp))'),...
    1,2);

%% Precompute Graphics Data for Each Frame
Cmouse = [];
moveMouse = @() [];
[roadData,mouseMovementData] = initializeSegmentedGraphicsData();


%% Build Graphics Figure with Anonymous Function Updaters
h = buildGraphicsAndUpdateHandlers();
h.gdata.roadData = roadData;
h.gdata.mouseMovementData = mouseMovementData;


%% Set PID Coefficients (for smoothing camera tracking motion)
kframe = 1;
h.setRoadData(h.ax,kframe)
% h.setMouseData(h.ax,kframe)
h.setCamPosition(h.ax,kframe)

Esum_campos = [0 0 0];
Eprev_campos = h.ax.CameraPosition;
K_campos.p = .15;
K_campos.i = .01;
K_campos.d = .01;

Esum_camtarg = [0 0 0];
Eprev_camtarg = h.ax.CameraPosition;
K_camtarg.p = .20;
K_camtarg.i = .025;
K_camtarg.d = .010;

%%
figClickPt = h.fig.CurrentPoint;
% Kstop = 2048*2;
Kstop = N;
f(Kstop) = struct('cdata',[],'colormap',[]);
while (kframe < Kstop)
    
    if ~all(h.fig.CurrentPoint == figClickPt)
       if strcmpi('No', questdlg('Continue generating Frames?'))
           break
       end
    end
    
    % Update Road Surface from Cached Vertices
    h.setRoadData(h.ax, kframe)
    %h.setMouseData(h.ax, kframe)
    
    % Get Next Mouse Position [x, y, z]
    mousePosition = getPosition(kframe); %     Pmouse = mouseMovementData.P{kframe};
    mouseTheta = getOrientation(kframe);
    
    % Get Current Camera location and target
    camPosition = h.ax.CameraPosition;
    camTargetPosition  = h.ax.CameraTarget;
    
    mouseVertexData = num2cell( moveMouse(mousePosition(1),mousePosition(2), mouseTheta ), [1 2]);
    msize = size(mouseVertexData{1});
    set(findobj(h.ax.Children,'tag','mouse'),...
        'Xdata',mouseVertexData{1},...
        'YData',mouseVertexData{2},...
        'ZData',mouseVertexData{3},...
        'CData',Cmouse,....
        'AlphaData', ones(msize))
    
    % Update Camera Position -> PID
    Vcm = mousePosition(1:2)-camPosition(1:2);
    d = sqrt(sum(Vcm.^2)) - camTargetDist;
    Ek_campos = [d * makeUnitVec(Vcm) 0];
    Esum_campos = Esum_campos + K_campos.i*Ek_campos;
    Uk_campos = K_campos.p*Ek_campos + Esum_campos + K_campos.d*(Ek_campos-Eprev_campos);
    Eprev_campos = Ek_campos;
    h.ax.CameraPosition = camPosition + Uk_campos;
    
    % Update Camera Target -> PID
    Ek_camtarg = [mousePosition(1:2) - camTargetPosition(1:2), 0];
    Esum_camtarg = Esum_camtarg + K_camtarg.i*Ek_camtarg;
    Uk_camtarg = K_camtarg.p*Ek_camtarg + Esum_camtarg + K_camtarg.d*(Ek_camtarg-Eprev_camtarg);
    Eprev_camtarg = Ek_camtarg;
    h.ax.CameraTarget = [camTargetPosition(1:2) 0] + Uk_camtarg;
    camlight(h.light,'headlight')
    drawnow nocallbacks
    %         pause(0.050)
    
    % Zoom Out if Too Close to Edge
    xl = h.ax.XLim;
    yl = h.ax.YLim;
    zoomAng = h.ax.CameraViewAngle;
    if (min(abs(xl-mousePosition(1))) < .25*abs(diff(xl))) || ...
            (min(abs(yl-mousePosition(2))) < .25*abs(diff(yl)))
        h.ax.CameraViewAngle = min(90,zoomAng + 1);
    else
        a = .95;
        h.ax.CameraViewAngle = max(camViewAngle, fix(a*zoomAng + camViewAngle*(1-a)));
    end
    
    % Get Frame -> RGB Array
    f(kframe) = getframe(h.fig);
    kframe=kframe+1;
end





%%
% =====================================================
% #####################################################
% =====================================================
% SUBFUNCTIONS
% =====================================================
% #####################################################
% =====================================================
    function h = buildGraphicsAndUpdateHandlers()
        
        % Init Graphics Objects & Define GraphData Update Function for Stepwise Filling
        h.ax = gca;
        set(h.ax,...
            'Clipping', 'off',...
            'Projection', 'perspective',...
            'Position',[0 0 1 1]);
        [h.fig,h.road,h.mouse,h.light] = initGraphics(h.ax);
        h.setRoadData = @(hax,k) setRoad(hax,k);
        %         h.setMouseData = @(hax,k) setMouse(hax,k);
        h.setCamPosition = @(hax,k) setCam(hax,k);
        
        
        function [hfig,hroad,hmouse,hlight] = initGraphics(hax)
            %% Initialize Figure and Graphics Objects
            if ~isvalid(hax)
                hax = gca;
            end
            axes(hax)
            hfig = gcf;
            set(hfig,...
                'Colormap', cmap,...
                'Position', [100 100 0 0] + [0 0 imageSize(2) imageSize(1)]);
            whitebg(hfig, [0 0 0])
            surfProps = {...
                'EdgeAlpha', 0.0,...
                'FaceColor', 'interp',...
                'FaceAlpha', 'interp',...
                'CDataMapping','direct'};
            hroad = surface(hax, surfProps{:},'tag','road');
            hmouse = surface(hax,surfProps{:},'tag','mouse');
            lighting gouraud
            %             hlight = light();
            %             hlight = camlight();
            hlight = camlight('headlight');
            axis vis3d off
            
            %% Fix Figure Size for Target Image Size Returned By getframe()
            tFix = tic;
            fixAttempTimeout = 5;
            while (toc(tFix) < fixAttempTimeout)
                frameTest = getframe(hfig);
                testSize = size(frameTest.cdata);
                sizeFix = [0 0 imageSize([2 1])-testSize([2 1])];
                if all(abs(sizeFix) < 1)
                    fprintf('Size Correctly Set\n')
                    break
                end
                hfig.Position = round(hfig.Position) + sizeFix;
            end
            hfig.Color = [0 0 0];
        end
        function setRoad(hax,k)
            zSlope = cos( linspace(-pathCurvature, pathCurvature, (numExtendPast + numExtendFuture + 1)*numInterp)') - 1;
            try
                hroad = findobj(hax.Children,'tag','road');
                set(hroad,...
                    'XData',stackGraphicsDataSegmentsPast2Future(roadData.X,k),...
                    'YData',stackGraphicsDataSegmentsPast2Future(roadData.Y,k),...
                    'ZData',bsxfun(@plus, stackGraphicsDataSegmentsPast2Future(roadData.Z,k), zSlope),...
                    'CData',stackGraphicsDataSegmentsPast2Future(roadData.C,k),...
                    'AlphaData',getPathTransparencyProfile(),...
                    'Parent',hax);
            catch
                [~,hroad,~,~] = initGraphics(hax);
                set(hroad,...
                    'XData',stackGraphicsDataSegmentsPast2Future(roadData.X,k),...
                    'YData',stackGraphicsDataSegmentsPast2Future(roadData.Y,k),...
                    'ZData',bsxfun(@plus, stackGraphicsDataSegmentsPast2Future(roadData.Z,k), zSlope),...
                    'CData',stackGraphicsDataSegmentsPast2Future(roadData.C,k),...
                    'AlphaData',getPathTransparencyProfile(),...
                    'Parent',hax);
            end
        end
        function setCam(hax,k)
            try
                set(hax,...
                    'CameraPosition', mouseMovementData.P{k} - makeUnitVec(mouseMovementData.dP{k})*camTargetDist + [0 0 camHeight],...
                    'CameraTarget', mouseMovementData.P{k},...
                    'CameraViewAngle',camViewAngle);
            catch
                hax = gca;
                set(hax,...
                    'CameraPosition', mouseMovementData.P{k} - makeUnitVec(mouseMovementData.dP{k})*camTargetDist + [0 0 camHeight],...
                    'CameraTarget', mouseMovementData.P{k},...
                    'CameraViewAngle',camViewAngle);
            end
        end
        
    end
    function [segmentedRoadSurfaceData,segmentedMousePosition] = initializeSegmentedGraphicsData()
        %% Initialize Empty Arrays for Segmented Storage
        segmentedRoadSurfaceData.X = cell(1,N);
        segmentedRoadSurfaceData.Y = cell(1,N);
        segmentedRoadSurfaceData.Z = cell(1,N);
        segmentedRoadSurfaceData.C = cell(1,N);
        segmentedMousePosition.P = cell(1,N);
        segmentedMousePosition.dP = cell(1,N);
        segmentedMousePosition.dPq = cell(1,N);
        
        %% Define Mouse Proportions
        rostroCaudalStretch = 8;
        noseWidth = .05;
        headWidth = .8;
        tailWidth = .15;
        numPts.head = 20;
        numPts.torso = 30;
        numPts.butt = 5;
        numPts.tail = 45;
        sumBodyPtsY = numPts.head + numPts.torso + numPts.butt + numPts.tail;
        mouseProfile.head = [linspace(noseWidth, headWidth, numPts.head), headWidth.*[1 1 1]];
        mouseProfile.torso = cos(linspace(-3*pi/16, 3*pi/16,numPts.torso));
        mouseProfile.butt = cos(linspace(3*pi/16+.2, pi/2-.2, numPts.butt));
        mouseProfile.tail = tailWidth .* ones(numPts.tail,1);
        
        %% Loft Profiles to Cylinder to get Surface Vertices
        sectionNameList = fields(mouseProfile);
        for ksection = 1:numel(sectionNameList)
            section = sectionNameList{ksection};
            [X.(section),Z.(section),Y.(section)] = cylinder(mouseProfile.(section));
        end
        
        %% Add Wiggle to Tail
        X.tail = X.tail + tailWidth.*sin((4*pi) .* Y.tail);
        
        %% Scale and Shift Sections then Concatenate along Y
        for ksection = 1:numel(sectionNameList)
            section = sectionNameList{ksection};
            Y.(section) = (numPts.(section)./sumBodyPtsY) * Y.(section);
        end
        Y.torso = Y.torso + max(Y.head(:));
        Y.butt = Y.butt + max(Y.torso(:));
        Y.tail = Y.tail + max(Y.butt(:));
        
        Xmouse = cat(1, X.head, X.torso, X.butt, X.tail);
        Ymouse = cat(1, Y.head, Y.torso, Y.butt, Y.tail);
        Zmouse = cat(1, Z.head, Z.torso, Z.butt, Z.tail);
        
        %% Flip & Stretch Body Y (Rostro-caudal) (inital range 0:1)
        Ymouse =  (0.1 - Ymouse) .* rostroCaudalStretch;
        
        %% Flatten Z (ventro-dorsal)
        flattenZ = @(zmat) (0.5 + 0.5 .* zmat).^2;
        Zmouse = flattenZ(Zmouse);
        
        %% Give Random Texture Color to Surface
        %         Cmouse = uint8(255.* (.5 + .1.*randn(size(Xmouse))));
        Cmouse = uint8(255.* (.3 + .05*randn([size(Xmouse),3])));
        mouseVert = mouseSize * roadWidth .* cat(1, Xmouse(:)', Ymouse(:)', Zmouse(:)');
        %         M.vert = mouseVert;
        mouseSurfSize = size(Xmouse);
        %         getRotMat = @(theta) [cos(theta) -sin(theta) 0; sin(theta) cos(theta) 0; 0 0 1]; % faster alternative to rotz(deg)
        getRotMat = @(theta) [cos(theta) sin(theta) 0; -sin(theta) cos(theta) 0; 0 0 1]; %clockwise positive
        applyRot = @(theta) reshape( (getRotMat(theta) * mouseVert)', mouseSurfSize(1), mouseSurfSize(2), []);
        moveMouse = @(x,y,theta) bsxfun(@plus, cat(3, x, y, 0), applyRot(theta));
        
        %%
        maxSpeed = max(M.speed);
        for kseg = 1:N
            
            % Get Current Position and Local Derivative
            pk = getPosition(kseg);
            pk_prev = getPriorMidPoint(kseg);
            pk_next = getNextMidPoint(kseg);
            dpk_prev = pk - pk_prev;
            dpk_next = pk_next - pk;
            dpk = .5 .* (dpk_prev + dpk_next);
            
            p_left{1} = pk_prev + roadWidth .* (([0 -1 0; 1 0 0 ; 0 0 1] * makeUnitVec(dpk_prev)')');
            p_left{2} = pk + roadWidth .* (([0 -1 0; 1 0 0 ; 0 0 1] * makeUnitVec(dpk)')');
            p_left{3} = pk_next + roadWidth .* (([0 -1 0; 1 0 0 ; 0 0 1] * makeUnitVec(dpk_next)')');
            p_right{1} = pk_prev + roadWidth .* (([0 1 0; -1 0 0 ; 0 0 1] * makeUnitVec(dpk_prev)')');
            p_right{2} = pk + roadWidth .* (([0 1 0; -1 0 0 ; 0 0 1] * makeUnitVec(dpk)')');
            p_right{3} = pk_next + roadWidth .* (([0 1 0; -1 0 0 ; 0 0 1] * makeUnitVec(dpk_next)')');
            
            % Interpolate using Bezier Curves
            %             p_q = bezierInterp(pk_prev, pk, pk_next);
            p_left_q = bezierInterp(p_left{:});
            p_right_q = bezierInterp(p_right{:});
            dp_q = bezierInterp(dpk_prev , dpk , dpk_next );
            
            % Color from interpolated velocity
            velocity_q = sqrt(sum(dp_q.^2,2));
            %             vk = getVelocity(max(1,min(N, (kseg-1):(kseg+1))));
            maxSpeed = max(max(velocity_q),maxSpeed);
            
            % Add to segmented Graphics Data -> remove common point
            %             L.X{kseg} = p_q(1:end-1,1);
            %             L.Y{kseg} = p_q(1:end-1,2);
            %             L.Z{kseg} = p_q(1:end-1,3);
            
            segmentedRoadSurfaceData.X{kseg} = [p_left_q(1:end-1,1) , p_right_q(1:end-1,1)];
            segmentedRoadSurfaceData.Y{kseg} = [p_left_q(1:end-1,2) , p_right_q(1:end-1,2)];
            segmentedRoadSurfaceData.Z{kseg} = [p_left_q(1:end-1,3) , p_right_q(1:end-1,3)];
            segmentedRoadSurfaceData.C{kseg} = uint8(255.*repmat(1/maxSpeed .* velocity_q(1:end-1), 1, 2)) ;
            
            segmentedMousePosition.P{kseg} = pk;
            segmentedMousePosition.dP{kseg} = dpk;
            segmentedMousePosition.dPq{kseg} = dp_q(1:end-1,:);
            
            % Shrink Max Velocity to Continue Filling Color Range
            maxSpeed = maxSpeed * .98;
            
        end
        
    end


end

function [M] = loadDataFromFile()
[fname,fdir] = uigetfile('*.mat','Select movement data file');
md = load(fullfile(fdir,fname));
% md=load('Z:\Data\HowardMattStriatum\Construct\movementData\movement_data_263ACSF110815.mat')
% [distance, rel_direction, dxdy, dTheta] = getMovement(md.data);
% (from getMovement)
% dTheta is rotation in radians, distance is distance travelled in cm,
% dxdy is delta in x and y directions, and direction is the net direction
% of the distance vector. Also, positive dTheta = rotating clockwise!
% positive dxdy are rightward and forward, respectively

% Get Movement Data from Mike's Fcn -> Projects to Mouse-Reference-Space
[M.speed, ~, dxdy, dzrot] = getMovement(md.data);
dxdy(isnan(dxdy)) = 0;
dzrot(isnan(dzrot)) = 0;
dxM = dxdy(:,1);
dyM = dxdy(:,2);
dt = md.info.Dt(:);

% Calculate Position and Orientation in Virtual-Space
pk = [0 0];
ok = 0;
n = numel(dxM);
x(n,1) = 0;
y(n,1) = 0;
o(n,1) = 0;
for k = 1:n
    % Get Rotation matrix for prior orientation in virtual ref-frame
    rotMVk = [cos(ok) sin(ok) ; -sin(ok) cos(ok)];
    % Apply Rk to current linear-motion vector (dpos) -> dpos in Virtual
    dposMk = [dxM(k) ; dyM(k)];
    dposVk = rotMVk * dposMk;
    % Add displacement vector (in V-space) to current position
    pk = pk + dposVk';
    % Add rotation around Z-Axis to update Orientation in V-space
    ok = ok + dzrot(k);
    % Collect updates to Position and Orientation
    x(k) = pk(1);
    y(k) = pk(2);
    o(k) = ok;
end


% Fill Mouse Space Info
M.dtheta = dzrot(:);
M.dpos = dxM + 1i.*dyM;
M.dx = dxM;
M.dy = dyM;
M.dt = dt;
M.x = x;
M.y = y;
M.theta = o;
M.t = cumsum(dt(:));



% md = load('Z:\Data\HowardMattStriatum\Construct\movementData\movement_data_263ACSF110815.mat')
% [distance, rel_direction, dxdy, dTheta] = getMovement(md.data);
% m1m2 = squeeze(md.data(1,:,:))';

end



%%
% keyboard
% % Update Camera Position -> PID
%     Vcm = Pmouse(1:2)-Pcam(1:2);
%     d = sqrt(sum(Vcm.^2)) - camTargetDist;
%     Ek = [d * makeUnitVec(Vcm) 0];
%     Esum = Esum + K.i*Ek;
%     Uk = K.p*Ek + Esum + K.d*(Ek-Eprev);
%     Eprev = Ek;
%     h.ax.CameraPosition = Pcam + Uk;
%
%     h.ax.CameraTarget = Pmouse;
%     camlight(h.light,'headlight')
%     kframe=kframe+1;
%     drawnow
%     pause(0.050)



%                 set(hmouse,...
%                     'XData',M.X{k},...
%                     'YData',M.Y{k},...
%                     'ZData',M.Z{k},...
%                     'CData',M.C{k},...
%                     'AlphaData', .9*ones(msize),...

%     velocity_k = sqrt(sum(dpk.^2)) ./ maxVelocity;
%     M.C{kframe} = uint8( int16(Cmouse) + int16(50 * (velocity_k-0.5)));


%         function setMouse(hax,k)
%             msize = size(M.X{1});
%             try
%                 hmouse = findobj(hax.Children,'tag','mouse');
%                 set(hmouse,...
%                     'XData',M.X{k},...
%                     'YData',M.Y{k},...
%                     'ZData',M.Z{k},...
%                     'CData',M.C{k},...
%                     'AlphaData', .9*ones(msize),...
%                     'Parent',hax);
%             catch
%                 [~,~,hmouse,~] = initGraphics(hax);
%                 set(hmouse,...
%                     'XData',M.X{k},...
%                     'YData',M.Y{k},...
%                     'ZData',M.Z{k},...
%                     'CData',M.C{k},...
%                     'AlphaData', .9*ones(msize),...
%                     'Parent',hax);
%             end
%         end



%     % Update Mouse (Rotate and Shift Surface Vertices)
%     %     Vmouse = mouseMovementData.dP{kframe};%atan2d(dpk(2),dpk(1)) - 90;
%     %     rotZmouse = rotZmouse + dtheta(kframe);
%
%     %     uvRot = [cosd(rotZmouse+90) sind(rotZmouse+90)];
%     %     uvLin = makeUnitVec( 0.2*Vmouse(1:2) + 0.01*Vmouse_prev(1:2));
%     %     Vmouse_prev = 0.65*Vmouse_prev + 0.3*Vmouse;
%     %     uvLin = makeUnitVec
%
%
%     %     Etk = tand(Vmouse - );
%     %     Itk = Itk + 0.015*Etk;
%     %     Utk = 0.20*Etk + Itk + 0.01*(Etk - Etkm1);
%     %     Etkm1 = Etk;
%     %     Utk = uvRot - uvLin;
%     %     rotZmouse = rotZmouse + atan2d(Utk(2),Utk(1));
%     uvFuse = makeUnitVec( uvRot + uvLin);
%     rotZmouse = atan2d( uvFuse(2), uvFuse(1)) - 90;