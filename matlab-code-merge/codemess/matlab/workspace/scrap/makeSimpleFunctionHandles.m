function fh = makeSimpleFunctionHandles()
% MAKESIMPLEFUNCTIONHANDLES  makes simple function handles for testing
%
% comment section
% last line of comment section



a = 1;
b = [];


function simpleSubFunction()
a = a+ 1;
end


obj = SimpleClass();
[scfh, acfh] = getMethodHandles(obj)

sfh.builtin = @fft;
sfh.i2vo2 = @bwmorphn;
sfh.i1o2 = @parfevalEachCell;
sfh.local = @simpleLocalFunction;
sfh.sub = @simpleSubFunction;
sfh.vi3vo1 = @spmd_feval_fcn;

afh.builtin = @(aa) fft(aa, size(aa) );
afh.i2vo2 = @(ab,bb)bwmorphn(aa,bb);
afh.i1o2 = @(aa)parfevalEachCell(aa);
afh.local = @(aa)simpleLocalFunction(aa);
afh.sub = @()simpleSubFunction();
afh.vi3vo1 = @(aa,bb,varargin)spmd_feval_fcn(aa,bb);


fh.simplefunc = sfh;
fh.anonfunc = afh;
fh.simpleclassfunc = scfh;
fh.anonclassfunc = acfh;

end


function bb = simpleLocalFunction(aa)
bb = aa + 1;
end




% 
% obj = SimpleClass();
% [scfh, acfh] = getMethodHandles(obj)
% 
% sfh.builtin = @fft;
% sfh.i2vo2 = @bwmorphn;
% sfh.i1o2 = @parfevalEachCell;
% sfh.local = @simpleLocalFunction;
% sfh.sub = @simpleSubFunction;
% sfh.vi3vo1 = @spmd_feval_fcn;
% 
% afh.builtin = @(aa) fft(aa, size(aa) );
% afh.i2vo2 = @(ab,bb)bwmorphn(aa,bb);
% afh.i1o2 = @(aa)parfevalEachCell(aa);
% afh.local = @(aa)simpleLocalFunction(aa);
% afh.sub = @()simpleSubFunction();
% afh.vi3vo1 = @(aa,bb,varargin)spmd_feval_fcn(aa,bb);
% 
% 
% fh.simplefunc = sfh;
% fh.anonfunc = afh;
% fh.simpleclassfunc = scfh;
% fh.anonclassfunc = acfh;


% runsfcn = @(fcn,s) cell2struct( cellfun( fcn, struct2cell(s), 'uniformoutput',false), fields(s) )