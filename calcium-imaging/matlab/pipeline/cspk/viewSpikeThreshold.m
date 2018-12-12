function viewSpikeThreshold(x, met, thresh)
if nargin < 3
   thresh = 0;
end
t = (1:size(x,1))./20;


hold off
h(1) = plot(t, x, 'LineWidth',1.00, 'Color','b');
legstring{1} = 'x(k)';
hold on
[nmet, mindim] = min(size(met));
if mindim == 1
   met = met';
end
metcolor = distinguishable_colors(nmet,{'w','b'});
for k = 1:nmet
   xmet = x;
   if islogical(met)
	  xmet(~met(:,k)) = nan;
   else
	  xmet(met(:,k) < thresh) = nan;
   end
   xmet = xmet + k*std(x)/100; % adds a jitter
   %    plot(t, xmet, 'LineWidth',2, 'Color',[metcolor(k,:), .5]);
   h(k+1) = plot(t, xmet,...
	  'Color', [metcolor(k,:), .5],...
	  'LineStyle','-',...
	  'LineWidth',1.25,...
	  'Marker','o',...
	  'MarkerSize',4);
   legstring{k+1} = sprintf('metric %i',k);
end
legend(h,legstring);