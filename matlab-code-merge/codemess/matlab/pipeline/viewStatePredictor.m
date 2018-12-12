function viewStatePredictor(X, Xsp, thresh)
if nargin < 3
   thresh = 0;
end
% REDUCE SIZE TO PLOT IF LARGE ARRAYS ARE PASSED IN
if numel(X) > 100000;
   idxSample = @(x,dim,n) unique(ceil( size(x,dim).*rand(n,1)));
   idx = idxSample(X,2,10);
   idxt = 1:min(size(X,1),10000);
   if all(size(Xsp) == size(X))
	  Xsp = Xsp(idxt,idx);
   else
	  Xsp = Xsp(idxt,:);
   end
   X = X(idxt,idx);
end
% CONSTANTS
t = (1:size(X,1))./20;
Nx = size(X,2);
stripoffset = [ 0 , cumsum(range(X,1))];
[Nsp, mindim] = min(size(Xsp));
if mindim == 1
   Xsp = Xsp';
end
spColor = distinguishable_colors(Nsp,{'w','b'});
% PLOT X, MAKE A NAN-COPY OF X, WHERE X(Xsp<THRESH) = NAN
hold off
for kx = 1:Nx
   x = X(:,kx) + stripoffset(kx);
   h(1) = plot(t, x, 'LineWidth',1.00, 'Color','b');
   legstring{1} = 'x(k)';
   hold on
   % FOR COMPARING MULTIPLE STATE PREDICTORS ON ONE SIGNAL
   if Nsp > Nx
	  for k = 1:Nsp
		 xsp = x;
		 if islogical(Xsp)
			xsp(~Xsp(:,k)) = nan;
		 else
			xsp(Xsp(:,k) < thresh) = nan;
		 end
		 xsp = xsp + k*std(x)/100; % adds a jitter
		 h(k+1) = plot(t, xsp,...
			'Color', [spColor(k,:), .5],...
			'LineStyle','-',...
			'LineWidth',1.75,...
			'Marker','*',...
			'MarkerSize',2);
		 legstring{k+1} = sprintf('State-Predictor %i',k);
	  end
   else
	  % FOR CORRESPONDING STATE-PREDICTORS AND SIGNALS
	  k=kx;
	  xsp = x;
	  if islogical(Xsp)
		 xsp(~Xsp(:,k)) = nan;
	  else
		 xsp(Xsp(:,k) < thresh) = nan;
	  end
	  xsp = xsp + k*std(x)/100; % adds a jitter
	  h(k+1) = plot(t, xsp,...
		 'Color', [spColor(k,:), .5],...
		 'LineStyle','-',...
		 'LineWidth',1.75,...
		 'Marker','*',...
		 'MarkerSize',2);
	  legstring{k+1} = sprintf('State-Predictor %i',k);
   end
end
legend(h,legstring);
title('State Prediction Overlay'), xlabel('Time (s)')
xlim([t(1) t(end)]);