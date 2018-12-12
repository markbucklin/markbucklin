%%
clear
clc
M = 8;
N = 128;
itype = 'int16';
frange = int16(double(intmax(itype))./(N));
Fin = randi(frange, [M,N], itype) - randi(frange, [M,N], itype);
Fout = Fin([]);

%%
cell2multiarg = @(cOut) cOut{:};

%%
% Generate Idx
a = ignition.core.Task( @(varargin) max([0,varargin{:}]) + (1:M) );
% Print Status
b = ignition.core.Task( @(idx) fprintf('Task B: Retrieving Idx->%d\n',idx));
% Retrieve Values From Array
c = ignition.core.Task( @(idx) Fin(idx(idx<=numel(Fin))) );
% Accumulate
d = ignition.core.Task( @(f,flast) cell2multiarg({f(:)-([flast ; f(1:end-1)]) , f(end) }) );
dinit = ignition.core.Task( @(f) cast(0,'like',f));
dupdate = ignition.core.Task( @(flast) flast ); % double link
% Convert to Single
e = ignition.core.Task( @(f) single(f)./single(intmax(class(f)) ));
% Plot
p = ignition.core.Task( @(f) [Fout(:) ; f ]);
pinit = ignition.core.Task( @(f) cast([],'like',f)); % -> flast

pupdate = ignition.core.Task( @(flast) flast );

%%

% a.Output -> idx
link(a.Output(1), b.Input(1))
link(a.Output(1), c.Input(1))

% c.Output -> f
link(c.Output(1), d.Input(1))

% init(d) -> flast
link(c.Output(1), dinit.Input(1))
link(dinit.Output(1), d.Input(2))
link(d.Output(2), dupdate.Input(1))
link(dupdate.Output(1), d.Input(2))

link(d.Output(1), e.Input(1))

link(e.Output(1), p.Input(1))




%pinit = ignition.core.Task( @(f) {true, cast([],'like',f)});
%pisinit = ignition.core.Task( @(pinitout) pinitout{1});




