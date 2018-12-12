function h = showMouseMovement(x,y)
% Plots the curve defined by position vectors X and Y as well as a surface
% defined by offset curves.

% load('movementdata.mat')
% x = xvals(17:end);
% y = yvals(17:end);

%% Make Column Vectors
x = x(:);
y = y(:);
z = zeros(size(x));
N = length(x);

%% Settings
w = .1;
numInterpPoints = 10;
numTail = 40;
numBody = 1;
numNose = 20;
cmap = [[linspace(0,1,128)',linspace(0,1,128)',ones(128,1)] ; [ones(128,1) , linspace(1,0,128)' , linspace(1,0,128)']];
bodyAlpha = .99;
alphaAtInf = 0;
alphaTailFcn = @(t) min(1,t).^2;


%% Get Position Velocity and Acceleration Vectors
% P = [x , y , z];
makeUnitVec = @(v) v ./ (hypot(v(:,1),v(:,2))+eps);

%% Bezier Curve function
bezT = @(t,p1,p2,p3) [ones(numel(t),1) t(:) t(:).^2] * [1 0 0 ; -2 2 0 ; 1 -2 1] * [p1(:)' ; p2(:)' ; p3(:)'];
bezierInterp = @(p1,p2,p3) bezT(linspace(0,1,numInterpPoints), p1, p2, p3);

%% Position and Surrounding Reference Point Functions -> Using P(k) = [xk,yk,zk]
x = x(:); y = y(:); z = z(:);
P = @(k) [x(k) , y(k) , z(k)];
idx = @(k) min(max(k,1),N);
getPriorMidPoint = @(k) 0.5 .* (P(idx(k),:) + P(idx(k-1),:));
getNextMidPoint = @(k) 0.5 .* (P(idx(k),:) + P(idx(k+1),:));

%% Initialize Figure
h = initializeGraphicsObjects();

%% Define GraphData Update Function for Stepwise Filling
tailIdx = 1:numTail;
bodyIdx = numTail + (1:numBody);
noseIdx = (numTail + numBody) + (1:numNose);
numSegmentIdx = numTail + numBody + numNose;
alphaVec = alphaTailFcn([linspace(1/numTail,bodyAlpha*(1-1/numTail),numTail) , ones(1,numBody)*bodyAlpha , linspace(bodyAlpha*(1-1/numNose), 0, numNose)]);
akm1 = alphaTailFcn(alphaAtInf);
surfAlphaMask = cell(1,numSegmentIdx);
for kseg = 1:numSegmentIdx
    ak = alphaVec(kseg);
    surfAlphaMask{kseg} = repmat( linspace(akm1,ak,numInterpPoints)', 1, 2);
    akm1 = ak;
end

%% Functions for Updating Graphics Data in Figure and Adding Newly Computed Segments to Cache
setSurfData = @(hdl,s,k) set(hdl,'XData',cat(1,s.X{k}),'YData',cat(1,s.Y{k}),'ZData',cat(1,s.Z{k}),'CData',cat(1,s.C{k}),'AlphaData',cat(1,surfAlphaMask{k}));
setLineData = @(hdl,s,k) set(hdl,'XData',cat(1,s.X{k}),'YData',cat(1,s.Y{k}),'ZData',cat(1,s.Z{k}));
appendNoseSegment = @(s,snew) [s(2:end) {snew}];

%% Initialize Empty Graph Data
[T,S,F] = initializeSegmentedGraphicsData();





%% Loop Through Frames and Draw Segmented Motion Info
maxVelocity = 0;
krender = 1;
while krender <= (N+numNose)
    if krender <=N
        % Get Current Position and Local Derivative
        pk = P(krender,:);
        if krender>1
            dpb = pk - P(krender-1,:);
        else
            dpb = zeros(1,3);
        end
        if krender<N
            dpf = P(krender+1,:) - pk;
        else
            dpf = zeros(1,3);
        end
        dpc = .5*dpb + .5*dpf;
        
        % Get 3-Point Line Segment using Current Position and Midpoints with Next and Previous
        p_trajectory{1} = pk - .5*dpb;
        p_trajectory{2} = pk;
        p_trajectory{3} = pk + .5*dpf;
        p_left{1} = pk - .5*dpb + w .* (([0 -1 0; 1 0 0 ; 0 0 1] * makeUnitVec(dpb)')');
        p_left{2} = pk + w .* (([0 -1 0; 1 0 0 ; 0 0 1] * makeUnitVec(dpc)')');
        p_left{3} = pk + .5*dpf + w .* (([0 -1 0; 1 0 0 ; 0 0 1] * makeUnitVec(dpf)')');
        p_right{1} = pk - .5*dpb + w .* (([0 1 0; -1 0 0 ; 0 0 1] * makeUnitVec(dpb)')');
        p_right{2} = pk + w .* (([0 1 0; -1 0 0 ; 0 0 1] * makeUnitVec(dpc)')');
        p_right{3} = pk + .5*dpf + w .* (([0 1 0; -1 0 0 ; 0 0 1] * makeUnitVec(dpf)')');
        
        % Interpolate using Bezier Curves
        p_trajectory_q = bezierInterp(p_trajectory{:});
        p_left_q = bezierInterp(p_left{:});
        p_right_q = bezierInterp(p_right{:});
        dp_q = bezierInterp(dpb , dpc , dpf );
        
        % Color from interpolated velocity
        velocity_q = sqrt(sum(dp_q.^2,2));
        maxVelocity = max(max(velocity_q),maxVelocity);
        
        % Shift and Append onto Segmented Structures
        T.X = appendNoseSegment(T.X, p_trajectory_q(:,1));
        T.Y = appendNoseSegment(T.Y, p_trajectory_q(:,2));
        T.Z = appendNoseSegment(T.Z, p_trajectory_q(:,3));
        
        S.X = appendNoseSegment(S.X, [p_left_q(:,1) , p_right_q(:,1)]);
        S.Y = appendNoseSegment(S.Y, [p_left_q(:,2) , p_right_q(:,2)]);
        S.Z = appendNoseSegment(S.Z, [p_left_q(:,3) , p_right_q(:,3)]);
        S.C = appendNoseSegment(S.C, repmat(1/maxVelocity .* velocity_q, 1, 2) );
        
        F.P = appendNoseSegment(F.P, pk);
        F.dP = appendNoseSegment(F.dP, dpc);
        
    end
    
    frameIdx = krender - numNose;
    if frameIdx >= 1
        
        if frameIdx <= N
            % Extract Position and First Derivative
            p = F.P{bodyIdx};
            dp = F.dP{bodyIdx};
            
            % Get Single Velocity and Orientation
            orientation = atan2(dp(2),dp(1));
            velocity = sqrt(sum(dp.^2));
            
            % Update Arrow
            %h.arrowDP.Position = [p dp];
        end
        
        % Get Valid Segment Indices
        surfIdx = [tailIdx , bodyIdx , noseIdx];
        surfIdx = surfIdx(surfIdx > (numSegmentIdx-krender));
        
        % Update Graph Data
        setSurfData(h.surfRoad,S,surfIdx);
        setLineData(h.lineNose,T,noseIdx);
        setLineData(h.lineBody,T,bodyIdx);
        setLineData(h.lineTail,T,tailIdx);
        
        pause(.01)
        %         pause
    end
    
    krender = krender + 1;
    
end



    function h = initializeGraphicsObjects()
        h.fig = gcf; clf
        set(h.fig,...
            'Colormap', cmap);
        h.ax = gca;
        surfProps = {...
            'EdgeAlpha', 0.0,...
            'FaceColor', 'interp',...
            'FaceAlpha', 'interp'};
        h.surfRoad = surface(h.ax, surfProps{:});
        h.lineNose = line();
        h.lineBody = line();
        h.lineTail = line();
        
        h.mouseBody = surface(h.ax,surfProps{:});
        h.mouseArrow = patch(h.ax);
        
        % h.arrowDP = annotation('arrow',...
        %     'HeadStyle', 'cback2',...
        %     'HeadWidth', 20,...
        %     'HeadLength', 20,...
        %     'LineWidth', 2,...
        %     'Color', 'red');
    end
    function [T,S,F] = initializeSegmentedGraphicsData()
        T.X = cell(1,numSegmentIdx);
        T.Y = cell(1,numSegmentIdx);
        T.Z = cell(1,numSegmentIdx);
        T.C = cell(1,numSegmentIdx);
        S.X = cell(1,numSegmentIdx);
        S.Y = cell(1,numSegmentIdx);
        S.Z = cell(1,numSegmentIdx);
        S.C = cell(1,numSegmentIdx);
        F.P = cell(1,numSegmentIdx);
        F.dP = cell(1,numSegmentIdx);
    end


end


%%
% dPb = [zeros(1,3) ; diff(P)];
% dPf = [diff(P) ; zeros(1,3)];
% dP = .5*dPb + .5*dPf;
%
% dPb_norm = dPb ./ hypot(dPb(:,1),dPb(:,2));
% dPf_norm = dPf ./ hypot(dPf(:,1),dPf(:,2));
% dP_norm = dP ./ hypot(dP(:,1),dP(:,2));


%    p_left{1} = ([0 -1 0; 1 0 0 ; 0 0 1] * dPb_norm(k)')';
%    p_left{2} = ([0 -1 0; 1 0 0 ; 0 0 1] * dP_norm(k)')';
%    p_left{3} = ([0 -1 0; 1 0 0 ; 0 0 1] * dPf_norm(k)')';
%    p_right{1} = ([0 1 0; -1 0 0 ; 0 0 1] * dPb_norm(k)')';
%    p_right{2} = ([0 1 0; -1 0 0 ; 0 0 1] * dP_norm(k)')';
%    p_right{3} = ([0 1 0; -1 0 0 ; 0 0 1] * dPf_norm(k)')';