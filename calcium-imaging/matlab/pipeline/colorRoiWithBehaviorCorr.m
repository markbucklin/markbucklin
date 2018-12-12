function varargout = colorRoiWithBehaviorCorr(R, bhv)

fs = 20;
maxlag = 12*fs;
nRoi = numel(R);
X = [R.Trace];

fld = fields(bhv.sig);
   for fln = 1:numel(fld)
	  if isnumeric(bhv.sig.(fld{fln}))
		 Csig = zeros(2*maxlag+1,nRoi,'like', X);
		 behaviorSignal = bhv.sig.(fld{fln});
		 parfor kRef = 1:numel(R)
			Csig(:,kRef) =xcorr(behaviorSignal, X(:,kRef),maxlag, 'coeff');
		 end
		 bhvc.(fld{fln}) = Csig;
	  end
   end
normsig = normfunctions;
colorsource = normsig.poslt1(bhvc.long - bhvc.short);
for k=1:numel(R)
   c = colorsource(:,k);
   R(k).Color = [mean(c(end-5:end)), mean(c(1:5)), mean(c)];
end

if nargout > 0
   varargout{1} = bhvc;
end