function [h,f] = showMouseMovement(x,y,dtheta,dt)
% Plots the curve defined by position vectors X and Y as well as a surface
% defined by offset curves.

% load movementdata.mat
% md = load('Z:\Data\HowardMattStriatum\Construct\movementData\movement_data_263ACSF110815.mat')
% [distance, rel_direction, dxdy, dTheta] = getMovement(md.data);
% m1m2 = squeeze(md.data(1,:,:))';

% idx = 2 + (1:8192);
% idx = (1:8192);

% x = xvals(idx);
% y = yvals(idx);
% dtheta = mean(m1m2(idx, [1 3]),2) .* .001;
% dt = md.info.Dt(idx);

% dy = diff([y(1) ; y(:)]);
% dx = diff([x(1) ; x(:)]);
% dxy = dx + i*dy;
% 
% for k = 1:N, dzk = .9*dzk + .1*dxy(k); theta(k) = angle(dzk); polarplot(dzk); drawnow nocallbacks, end
% dzk = 0 + i*0
% for k = 1:N, dzk = .9*dzk + .1*dxy(k); theta(k) = angle(dzk); polarplot(dzk,'.'); drawnow nocallbacks, end
% for k = 1:N, dzkm1=dzk; dzk = .9*dzk + .1*dxy(k); dthetak = angle(dzk-dzkm1); dz(k)=dzk; end
% for k = 1:N, dzkm1=dzk; dzk = .9*dzk + .1*dxy(k); ddz(k) = dzk-dzkm1; dz(k)=dzk; end

% N = numel(idx);
% dot= polarplot(dzk,'.');
% dot.Marker = 'o'
% dot.MarkerFaceColor = 'r'
% dot.MarkerSize = 25
% dot.Parent.RLim = [0 3]
% dztrail = zeros(10,1); 
% for k = 1:N
%     dzk = .9*dzk + .1*dxy(k); dztrail = [dzk ; dztrail(1:end-1)];
%     theta(k) = angle(dzk); 
%     dot.RData = abs(dztrail);
%     dot.ThetaData = angle(dztrail); 
%     drawnow nocallbacks
% end


% [h,f] = showMouseMovement(xvals(idx),yvals(idx),dtheta(idx));


% % dtheta = mean(m1m2(:,[1 3]),2) ./ md.info.Dt .* (1/1000);
% % dtheta(isnan(dtheta)) = 0;



%% Handle Input: Look for 'movementdata.mat' file or Query User if No Inputs Given
if nargin < 1
    [x,y] = loadDataFromFile();
end
x = x(:);
y = y(:);
z = zeros(size(x));
dtheta = dtheta(:);
dt = dt(:);
t = cumsum(dt) - dt(1);
dx = gradient(x(:));
dy = gradient(y(:));
dxdt = dx./dt;
dydt = dy./dt;
dthetadt = dtheta./dt;
N = length(x);
speed = sqrt(dxdt.^2 + dydt.^2);
normalizedSpeed = min(1, speed./prctile(speed,99));


%% Settings
roadWidth = 1.0;
mouseSize = 2;
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


%% Define Colormap & Fade Functions
blue2gray = [linspace(0,grayLevel,128)', linspace(0,grayLevel,128)', linspace(1,grayLevel,128)'];
gray2red = [linspace(grayLevel,1,128)', linspace(grayLevel,0,128)', linspace(grayLevel,0,128)'];
red2gray = [linspace(1,grayLevel,128)', linspace(0,grayLevel,128)', linspace(0,grayLevel,128)'];
gray2green = [linspace(grayLevel,0,128)', linspace(grayLevel,1,128)', linspace(grayLevel,0,128)'];
cmap = [...
    red2gray ;...
    gray2green];

%% Useful Functions -> Made Anonymous for Readability
futureFadeFcn = @(a) min(1,a).^2;
pastFadeFcn = @(a) min(1,a).^2;
makeUnitVec = @(v) v ./ (hypot(v(:,1),v(:,2))+eps);
% Bezier Curve Interpolation
bezT = @(t,p1,p2,p3) [ones(numel(t),1) t(:) t(:).^2] * [1 0 0 ; -2 2 0 ; 1 -2 1] * [p1(:)' ; p2(:)' ; p3(:)'];
bezierInterp = @(p1,p2,p3) bezT(linspace(0,1,numInterp+1), p1, p2, p3);
% Position and Surrounding Reference Point Functions -> Using P(k) = [xk,yk,zk]
P = @(k) [x(k) , y(k) , z(k)];
validIdx = @(k) min(max(k,1),N);
getPriorMidPoint = @(k) 0.5 .* (P(validIdx(k)) + P(validIdx(k-1)));
getNextMidPoint = @(k) 0.5 .* (P(validIdx(k)) + P(validIdx(k+1)));
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
[S,F] = initializeSegmentedGraphicsData();


%% Build Graphics Figure with Anonymous Function Updaters
h = buildGraphicsAndUpdateHandlers();
h.gdata.S = S;
h.gdata.F = F;


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

Etkm1 = 0;
Itk = 0;
rotZmouse = 0 ; % from positive y axis %[0 1 0];%-90;
Vmouse_prev = [0 0 0];

%%
figClickPt = h.fig.CurrentPoint;
% Kstop = 2048*2;
Kstop = N;
f(Kstop) = struct('cdata',[],'colormap',[]);
while (kframe < Kstop) && all(h.fig.CurrentPoint == figClickPt)
    % Update Road Surface from Cached Vertices
    h.setRoadData(h.ax, kframe)
    
    %h.setMouseData(h.ax, kframe)
    
    % Get New Mouse Position
    Pmouse = F.P{kframe};
    Pcam = h.ax.CameraPosition;
    Ptarg  = h.ax.CameraTarget;
        
    % Update Mouse (Rotate and Shift Surface Vertices)
%     Vmouse = F.dP{kframe};%atan2d(dpk(2),dpk(1)) - 90;
%     rotZmouse = rotZmouse + dtheta(kframe);
    
%     uvRot = [cosd(rotZmouse+90) sind(rotZmouse+90)];
%     uvLin = makeUnitVec( 0.2*Vmouse(1:2) + 0.01*Vmouse_prev(1:2));
%     Vmouse_prev = 0.65*Vmouse_prev + 0.3*Vmouse;
%     uvLin = makeUnitVec
    
    
    %     Etk = tand(Vmouse - );
    %     Itk = Itk + 0.015*Etk;
    %     Utk = 0.20*Etk + Itk + 0.01*(Etk - Etkm1);
    %     Etkm1 = Etk;
    %     Utk = uvRot - uvLin;
    %     rotZmouse = rotZmouse + atan2d(Utk(2),Utk(1));
    uvFuse = makeUnitVec( uvRot + uvLin);
    rotZmouse = atan2d( uvFuse(2), uvFuse(1)) - 90;
    
    Mk = num2cell( moveMouse(Pmouse(1),Pmouse(2), rotZmouse ), [1 2]);    
    msize = size(Mk{1});
    set(findobj(h.ax.Children,'tag','mouse'),...
        'Xdata',Mk{1},...
        'YData',Mk{2},...
        'ZData',Mk{3},...
        'CData',Cmouse,....
        'AlphaData', ones(msize))
    
     
        %                 set(hmouse,...
        %                     'XData',M.X{k},...
        %                     'YData',M.Y{k},...
        %                     'ZData',M.Z{k},...
        %                     'CData',M.C{k},...
        %                     'AlphaData', .9*ones(msize),...
    
    %     velocity_k = sqrt(sum(dpk.^2)) ./ maxVelocity;
    %     M.C{kframe} = uint8( int16(Cmouse) + int16(50 * (velocity_k-0.5)));
    
    % Update Camera Position -> PID
    Vcm = Pmouse(1:2)-Pcam(1:2);
    d = sqrt(sum(Vcm.^2)) - camTargetDist;
    Ek_campos = [d * makeUnitVec(Vcm) 0];
    Esum_campos = Esum_campos + K_campos.i*Ek_campos;
    Uk_campos = K_campos.p*Ek_campos + Esum_campos + K_campos.d*(Ek_campos-Eprev_campos);
    Eprev_campos = Ek_campos;
    h.ax.CameraPosition = Pcam + Uk_campos;
    
    % Update Camera Target -> PID
    Ek_camtarg = [Pmouse(1:2) - Ptarg(1:2), 0];
    Esum_camtarg = Esum_camtarg + K_camtarg.i*Ek_camtarg;
    Uk_camtarg = K_camtarg.p*Ek_camtarg + Esum_camtarg + K_camtarg.d*(Ek_camtarg-Eprev_camtarg);
    Eprev_camtarg = Ek_camtarg;
    h.ax.CameraTarget = [Ptarg(1:2) 0] + Uk_camtarg;
%     h.light.Position = Pmouse + [0 0 5];
    %     h.ax.CameraTarget = Pmouse;
%     camlight(h.light)    
        camlight(h.light,'headlight')
    %     fprintf('Ek: %3.2g %3.2g\tUk:%3.2g %3.2g\n',Ek_camtarg(1),Ek_camtarg(2),Uk_camtarg(1),Uk_camtarg(2))
    drawnow nocallbacks
%         pause(0.050)
    
    % Zoom Out if Too Close to Edge
    xl = h.ax.XLim;
    yl = h.ax.YLim;
    zoomAng = h.ax.CameraViewAngle;
    if (min(abs(xl-Pmouse(1))) < .25*abs(diff(xl))) || ...
            (min(abs(yl-Pmouse(2))) < .25*abs(diff(yl)))
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




%% SUBFUNCTIONS
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
                    'XData',stackGraphicsDataSegmentsPast2Future(S.X,k),...
                    'YData',stackGraphicsDataSegmentsPast2Future(S.Y,k),...
                    'ZData',bsxfun(@plus, stackGraphicsDataSegmentsPast2Future(S.Z,k), zSlope),...
                    'CData',stackGraphicsDataSegmentsPast2Future(S.C,k),...
                    'AlphaData',getPathTransparencyProfile(),...
                    'Parent',hax);
            catch
                [~,hroad,~,~] = initGraphics(hax);
                set(hroad,...
                    'XData',stackGraphicsDataSegmentsPast2Future(S.X,k),...
                    'YData',stackGraphicsDataSegmentsPast2Future(S.Y,k),...
                    'ZData',bsxfun(@plus, stackGraphicsDataSegmentsPast2Future(S.Z,k), zSlope),...
                    'CData',stackGraphicsDataSegmentsPast2Future(S.C,k),...
                    'AlphaData',getPathTransparencyProfile(),...
                    'Parent',hax);
            end
        end
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
        function setCam(hax,k)
            try
                set(hax,...
                    'CameraPosition', F.P{k} - makeUnitVec(F.dP{k})*camTargetDist + [0 0 camHeight],...
                    'CameraTarget', F.P{k},...
                    'CameraViewAngle',camViewAngle);
            catch
                hax = gca;
                set(hax,...
                    'CameraPosition', F.P{k} - makeUnitVec(F.dP{k})*camTargetDist + [0 0 camHeight],...
                    'CameraTarget', F.P{k},...
                    'CameraViewAngle',camViewAngle);
             end
        end        
        
    end
    function [S,F] = initializeSegmentedGraphicsData()
        %% Initialize Empty Arrays for Segmented Storage
        S.X = cell(1,N);
        S.Y = cell(1,N);
        S.Z = cell(1,N);
        S.C = cell(1,N);
        F.P = cell(1,N);
        F.dP = cell(1,N);
        F.dPq = cell(1,N);
        %         M.X = cell(1,N);
        %         M.Y = cell(1,N);
        %         M.Z = cell(1,N);
        %         M.C = cell(1,N);
        
        
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
        M.vert = mouseVert;                
        mouseSurfSize = size(Xmouse);
        getRotMat = @(deg) [cosd(deg) -sind(deg) 0; sind(deg) cosd(deg) 0; 0 0 1]; % faster alternative to rotz(deg)
        applyRot = @(deg) reshape( (getRotMat(deg) * mouseVert)', mouseSurfSize(1), mouseSurfSize(2), []);
        moveMouse = @(x,y,deg) bsxfun(@plus, cat(3, x, y, 0), applyRot(deg));
        % deg -> num degrees rotation around Z axis from the positive Y axis
        % (may correspond to theta-90 or [0 1 0]
        
        
        %%
        %         Etkm1 = 0;
        %         Itk = 0;
        %         mouseOrientation = [0 1 0];%-90;        
        maxVelocity = max( sqrt(diff(x).^2 + diff(y).^2));
        for kseg = 1:N
            
            % Get Current Position and Local Derivative
            pk = P(kseg);
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
            p_q = bezierInterp(pk_prev, pk, pk_next);
            p_left_q = bezierInterp(p_left{:});
            p_right_q = bezierInterp(p_right{:});
            dp_q = bezierInterp(dpk_prev , dpk , dpk_next );
            
            % Color from interpolated velocity
            velocity_q = sqrt(sum(dp_q.^2,2));
            maxVelocity = max(max(velocity_q),maxVelocity);
            
            % Add to segmented Graphics Data -> remove common point
            L.X{kseg} = p_q(1:end-1,1);
            L.Y{kseg} = p_q(1:end-1,2);
            L.Z{kseg} = p_q(1:end-1,3);
            
            S.X{kseg} = [p_left_q(1:end-1,1) , p_right_q(1:end-1,1)];
            S.Y{kseg} = [p_left_q(1:end-1,2) , p_right_q(1:end-1,2)];
            S.Z{kseg} = [p_left_q(1:end-1,3) , p_right_q(1:end-1,3)];
            S.C{kseg} = uint8(255.*repmat(1/maxVelocity .* velocity_q(1:end-1), 1, 2)) ;
            
            F.P{kseg} = pk;
            F.dP{kseg} = dpk;
            F.dPq{kseg} = dp_q(1:end-1,:);
            
            % Mouse at Current Position
                        
            %             mouseTrajectory = atan2d(dpk(2),dpk(1)) - 90;
            %             mouseOrientation = mouseOrientation + dtheta(kseg);
            %
            %             Etk = atand(tand(mouseTrajectory - mouseOrientation));
            %             Itk = Itk + 0.015*Etk;
            %             Utk = 0.20*Etk + Itk + 0.01*(Etk - Etkm1);
            %             Etkm1 = Etk;
            %             mouseOrientation = mouseOrientation + atand(Utk);
            %
            %
            %             Mk = num2cell( moveMouse(pk(1),pk(2), mouseOrientation ), [1 2]);
            %             M.X(kseg) = Mk(1);
            %             M.Y(kseg) = Mk(2);
            %             M.Z(kseg) = Mk(3);
            %
            %             velocity_k = sqrt(sum(dpk.^2)) ./ maxVelocity;
            %             M.C{kseg} = uint8( int16(Cmouse) + int16(50 * (velocity_k-0.5)));
            
            % Shrink Max Velocity to Continue Filling Color Range
            maxVelocity = maxVelocity * .98;
            
        end
        
    end


end



function [x,y] = loadDataFromFile()
if ~exist('movementdata.mat','file')
    [movementdata.fileName, movementdata.fileDirectory] = uigetfile('*.mat');
    movementdata.contents = load(fullfile(movementdata.fileDirectory,movementdata.fileName));
else
    movementdata.contents = load('movementdata.mat');
end
x = movementdata.contents.xvals;
y = movementdata.contents.yvals;
end