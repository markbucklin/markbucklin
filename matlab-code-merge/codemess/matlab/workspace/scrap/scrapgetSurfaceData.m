% function [xdata,ydata,zdata,cdata] = getSurfaceData(x,y,z,roadWidth)
% 
% 
% % Handle empty input
% if nargin < 4
%     roadWidth = [];
% end
% if nargin < 3
%     z = [];
% end
% if isempty(roadWidth)
%     roadWidth = median(abs(diff(x)));
% end
% if isempty(z)
%     z = zeros(size(x));
% end

% Make Column Vectors
x = x(:);
y = y(:);
z = z(:);
N = length(x);

% Get Position Velocity and Acceleration Vectors
P = [x , y , z];
dP = diff(P);
dPb = [zeros(1,3) ; dP];
dPf = [dP ; zeros(1,3)];

Pt = .5*dPb + .5*dPf;
Pt_norm = Pt ./ hypot(Pt(:,1),Pt(:,2));
% Pt_cross = cross(dPb,dPf); % left turn positive

Pt_left = ([0 -1 0; 1 0 0 ; 0 0 1] * Pt_norm')';
Pt_right = ([0 1 0; -1 0 0 ; 0 0 1] * Pt_norm')';

% Bezier Curve function
B = @(t,p1,p2,p3) [ones(numel(t),1) t(:) t(:).^2] * [1 0 0 ; -2 2 0 ; 1 -2 1] * [p1(:)' ; p2(:)' ; p3(:)'];

hsurf = surface(....
    'EdgeAlpha', 0.0,...
    'FaceAlpha', 0.5);
hline = line();

k = 20;
% while k < N
%     if all(Pt(k,:)) == 0
%         continue
%     end

L=P(idx,:) + roadWidth .* Pt_left(idx,:);
R=P(idx,:) + roadWidth .* Pt_right(idx,:);

Lb = B(0:.1:1, L(1,:), L(2,:), L(3,:));
Rb = B(0:.1:1, R(1,:), R(2,:), R(3,:));

xdata = [Lb(:,1) , Rb(:,1)];
ydata = [Lb(:,2) , Rb(:,2)];
zdata = [Lb(:,3) , Rb(:,3)];
cdata = zeros(size(xdata));

% xdata = [L(:,1) , R(:,1)];
% ydata = [L(:,2) , R(:,2)];
% zdata = [L(:,3) , R(:,3)];
% cdata = zeros(size(xdata));

    set(hline,'XData',P(idx,1),'YData',P(idx,2),'ZData',P(idx,3))
    set(hsurf,'XData',xdata,'YData',ydata,'ZData',zdata,'CData',cdata,...
        'EdgeAlpha',.1,'FaceAlpha',.5)
    
%     L = P + roadWidth .* Pt_left ;%- atan(Pt_cross);
% R = P + roadWidth .* Pt_right ;%+ atan(Pt_cross);
% 
% xdata = [L(:,1) , R(:,1)];
% ydata = [L(:,2) , R(:,2)];
% zdata = [L(:,3) , R(:,3)];
% cdata = zeros(size(xdata));
