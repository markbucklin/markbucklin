
%
% for k=1:7, scatter(xdxPos(:,1), xdxPos(:,k), 10, [postgmm, pgmm], 'filled'), colorbar, pause, end

for kd = 1:numel(md)
   R = md(kd).roi;
   bhv = md(kd).bhv;
   t = bhv.t;
   Xs = getActivationState(R,t);
   % TRANSFER ENTROPY PARAMETERS
   for k=1:12
	  mdte(kd).fteDelay{k} = fastTE(circshift(Xs,1+5*(k-1),1), Xs, 5, 1);
   end
   for k=1:10
	  mdte(kd).fteLag{k} = fastTE(Xs, Xs, k, 1);
	  disp(k)
   end
   
   % TRIAL BY TRIAL
   M = size(Xs,1);
   fpre = 3*20;
   fpost = 12*20;
   for k=1:numel(bhv.frameidx.alltrials)
	  f1 = max(bhv.frameidx.alltrials(k) - fpre, 1);
	  f2 = min(bhv.frameidx.alltrials(k) + fpost, M);
	  mdte(kd).fteSingleTrial{k} = fastTE(Xs(f1:f2,:), Xs(f1:f2,:), 5, 5);
	  disp(k)
   end
   mdte(kd).xs = Xs;
end






% for k=1:numel(bhv.frameidx.alltrials)
%    fn = bhv.frameidx.alltrials(k)+20*6;
%    fteTrial{k} = fastTE(Xs(1:fn,:), Xs(1:fn,:), 5, 1);
%    disp(k)
% end