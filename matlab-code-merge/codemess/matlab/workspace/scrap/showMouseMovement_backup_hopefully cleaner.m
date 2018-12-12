function h = showMouseMovement(x,y)
% Plots the curve defined by position vectors X and Y as well as a surface
% defined by offset curves.

%% Handle Input: Look for 'movementdata.mat' file or Query User if No Inputs Given
if nargin < 1
    [x,y] = loadDataFromFile();    
end
x = x(:);
y = y(:);
z = zeros(size(x));
N = length(x);

%% Settings
roadWidth = .1;
numInterp = 9;
numExtendFuture = 40;
numExtendPast = 40;
grayLevel = .35;
camHeight = 1.5;
camTargetDist = 2;
camViewAngle = 60;
pathCurvature = pi/4; % radians
bodyAlpha = .95;

%% Define Colormap & Fade Functions
blue2gray = [linspace(0,grayLevel,128)', linspace(0,grayLevel,128)', linspace(1,grayLevel,128)'];
gray2red = [linspace(grayLevel,1,128)', linspace(grayLevel,0,128)', linspace(grayLevel,0,128)'];
cmap = [...
    blue2gray ;...
    gray2red];

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
[S,F,M] = initializeSegmentedGraphicsData();


%% Build Graphics Figure with Anonymous Function Updaters
h = buildGraphicsAndUpdateHandlers();

%%
kframe = 1;
h.setSurfData(kframe)
h.setMouseData(kframe)
h.setCamPosition(kframe)

Esum = [0 0 0];
Eprev = h.ax.CameraPosition;
K.p = .15;
K.i = .01;
K.d = .01;
%%
figClickPt = h.fig.CurrentPoint;
while (kframe<N) && all(h.fig.CurrentPoint == figClickPt)
    % Update Surfaces
    h.setSurfData(kframe)
    h.setMouseData(kframe)

    % Get New Mouse Position
    Pmouse = F.P{kframe};    
    
    % Update Camera Position -> PID
    Pcam = h.ax.CameraPosition;
    Vcm = Pmouse(1:2)-Pcam(1:2);
    d = sqrt(sum(Vcm.^2)) - camTargetDist;
    Ek = [d * makeUnitVec(Vcm) 0];
    Esum = Esum + K.i*Ek;
    Uk = K.p*Ek + Esum + K.d*(Ek-Eprev);
    Eprev = Ek;
    h.ax.CameraPosition = Pcam + Uk;
    
    h.ax.CameraTarget = Pmouse;
    camlight(h.light,'headlight')
    kframe=kframe+1;
    drawnow
    pause(0.050)
    
end


%% SUBFUNCTIONS
    function h = buildGraphicsAndUpdateHandlers()
        %% Initialize Figure and Graphics Objects
        h.fig = gcf; clf
        set(h.fig,...
            'Colormap', cmap);
        h.ax = gca;
        set(h.ax,...
            'Clipping', 'off',...
            'Projection', 'perspective');
        surfProps = {...
            'EdgeAlpha', 0.0,...
            'FaceColor', 'interp',...
            'FaceAlpha', 'interp',...
            'CDataMapping','direct'};        
        h.surfRoad = surface(h.ax, surfProps{:});        
        h.mouseBody = surface(h.ax,surfProps{:});        
        lighting gouraud
        h.light = camlight('headlight');
        axis vis3d off
        
        %% Define GraphData Update Function for Stepwise Filling
        zSlope = cos( linspace(-pathCurvature, pathCurvature, (numExtendPast + numExtendFuture + 1)*numInterp)') - 1;
        h.setSurfData = @(k) set(h.surfRoad,...
            'XData',stackGraphicsDataSegmentsPast2Future(S.X,k),...
            'YData',stackGraphicsDataSegmentsPast2Future(S.Y,k),...
            'ZData',bsxfun(@plus, stackGraphicsDataSegmentsPast2Future(S.Z,k), zSlope),...
            'CData',stackGraphicsDataSegmentsPast2Future(S.C,k),...
            'AlphaData',getPathTransparencyProfile());
        msize = size(M.X{1});
        h.setMouseData = @(k) set(h.mouseBody,...
            'XData',M.X{k},...
            'YData',M.Y{k},...
            'ZData',M.Z{k},...
            'CData',M.C{k},...
            'AlphaData', .9*ones(msize));
        h.setCamPosition = @(k) set(h.ax,...
            'CameraPosition', F.P{k} - makeUnitVec(F.dP{k})*camTargetDist + [0 0 camHeight],...
            'CameraTarget', F.P{k},...
            'CameraViewAngle',camViewAngle);

    end
    function [S,F,M] = initializeSegmentedGraphicsData()                
        %% Initialize Empty Arrays for Segmented Storage
        S.X = cell(1,N);
        S.Y = cell(1,N);
        S.Z = cell(1,N);
        S.C = cell(1,N);
        F.P = cell(1,N);
        F.dP = cell(1,N);
        F.dPq = cell(1,N);
        M.X = cell(1,N);
        M.Y = cell(1,N);
        M.Z = cell(1,N);
        M.C = cell(1,N);
        maxVelocity = 0;        
        
        %% Define Mouse Proportions
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
        
        %% Scale and Shift Sections to Concatenate along Y
        for ksection = 1:numel(sectionNameList)
            section = sectionNameList{ksection};            
            Y.(section) = (numPts.(section)./sumBodyPtsY) * Y.(section);
        end
        Y.torso = Y.torso + max(Y.head(:));
        Y.butt = Y.butt + max(Y.torso(:));
        Y.tail = Y.tail + max(Y.butt(:));
        
        Xbody = cat(1, X.head, X.torso, X.butt, X.tail);
        Ybody = cat(1, Y.head, Y.torso, Y.butt, Y.tail);
        Zbody = cat(1, Z.head, Z.torso, Z.butt, Z.tail);
        
        %         [Xhead,Zhead,Yhead] = cylinder( mouseProfile.head );
        %         [Xtorso,Ztorso,Ytorso] = cylinder( mouseProfile.torso );
        %         [Xbutt,Zbutt,Ybutt] = cylinder( mouseProfile.butt );
        %         [Xtail,Ztail,Ytail] = cylinder( mouseProfile.tail);
        %         [Xbody,Zbody,Ybody] = cylinder( [mouseProfile.head, mouseProfile.body,mouseProfile.butt]);
        
        %% Stretch Body & Tail in Y (Rostro-caudal) (inital range 0:1)
%         Ybody =  4 .* (1-Ybody);        
        
%         Ytail = -2.*Ytail;
        
        %% Flatten Z (ventro-dorsal)
        flattenZ = @(zmat) (0.5 + 0.5 .* zmat).^2;
        Zbody = flattenZ(Zbody);
        Ztail = flattenZ(Ztail);
        
        
        X = cat(1,Xbody,Xtail);
        Y = cat(1,Ybody,Ytail);
        Z = cat(1,Zbody,Ztail);
        C = uint8(255.* (.5 + .1.*randn(size(X))));
        
         %%        
        M0 = roadWidth .* cat(1, X(:)', Y(:)', Z(:)');
        mouseSurfSize = size(X);
        getRotMat = @(deg) [cosd(deg) -sind(deg) 0; sind(deg) cosd(deg) 0; 0 0 1]; % faster alternative to rotz(deg)
        applyRot = @(deg) reshape( (getRotMat(deg) * M0)', mouseSurfSize(1), mouseSurfSize(2), []);
        moveMouse = @(x,y,deg) bsxfun(@plus, cat(3, x, y, 0), applyRot(deg));
        
        %%
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
            
            % todo: ensure we're stacking interpolated points up in the
            % right order --> top->bottom past->future ???
            
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
            zrot_k = atan2d(dpk(2),dpk(1)) - 90;
            velocity_k = sqrt(sum(dpk.^2)) ./ maxVelocity;
            Mk = moveMouse(pk(1),pk(2),zrot_k);
            M.X{kseg} = Mk(:,:,1);
            M.Y{kseg} = Mk(:,:,2);
            M.Z{kseg} = Mk(:,:,3);
            M.C{kseg} = uint8( int16(C) + int16(50 * (velocity_k-0.5)));
            
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