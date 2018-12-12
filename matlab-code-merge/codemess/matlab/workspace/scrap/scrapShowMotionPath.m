%% Load Data (xvals & yvals)
clear
load('movementdata.mat')


%% Sizing parameters
K0 = 100;
len.tail = 20;
len.nose = 5;


%% f -> x & y position vectors, dx & dy motion vectors
f.x = xvals;
f.y = yvals;
f.dx = gradient(f.x);
f.dy = gradient(f.y);


%% Matrix of values where each column has previous LEN.TAIL motion vector components
getTail = @(dd)toeplitz(dd(K0:-1:K0-len.tail), dd(K0:end));
getNose = @(dd)toeplitz(dd((K0+len.nose):-1:K0), dd((K0+len.nose):end));

dname = fields(f);
for kfield=1:numel(dname)
    tail.(dname{kfield}) = getTail(f.(dname{kfield}));
    nose.(dname{kfield}) = getNose(f.(dname{kfield}));    
end

%% Magnitude & Direction 

cla
hsurf = surface(....
    'EdgeAlpha', 0.0,...
    'FaceAlpha', 0.5);
k = K0;
%%

while k < numel(f.x)
    %%
    idx=k-len.tail : k+len.nose;
    idx = idx(idx<=numel(f.x));
    x = f.x(idx); y = f.y(idx); z = zeros(numel(idx),1);
    dx = f.dx(idx); dy = f.dy(idx); dz = zeros(size(dy));
    
    %%
    roadWidth = .1;
    P = [x , y];
    dP = [dx , dy];
    L = P + roadWidth .* ([0 -1 ; 1 0] * ((dP./hypot(dx,dy))'))';
    R = P + roadWidth .* ([0 1 ; -1 0] * ((dP./hypot(dx,dy))'))';
    % v = [L' ; flipud(R')];
    % hRoad = patch('vertices',v, 'Faces', 1:size(v,1),...
    %     'FaceColor','blue',...
    %     'FaceAlpha',.2);
    % grid on
    
    xdata = [L(:,1) , R(:,1)];
    ydata = [L(:,2) , R(:,2)];
    
    set(hsurf,...
        'xdata',xdata,...
        'ydata',ydata,...
        'ZData',zeros(size(xdata)),...
        'CData',zeros(size(xdata)));
    k = k + 1;
    drawnow
    %%
    pause(.01)
end
%u = alld.x(idx); v = alld.y(idx); w = zeros(size(idx));


t = -pi:.1:pi;
t = [t';t'];
x = (1 + linspace(0,1,numel(t))') .* sin(t);
y = (1 + linspace(0,1,numel(t))') .* cos(t);
dx = gradient(x);
dy = gradient(y);
plot3(x,y,zeros(size(x)))
