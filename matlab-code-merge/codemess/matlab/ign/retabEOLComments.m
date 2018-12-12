function sout = retabEOLComments(s)
%RETABEOLCOMMENTS - retabs comments at end of line to be vertically aligned
%  This function takes a string s as input and finds all executable lines
%  which have a comment (a line which is entirely a comment is not
%  included) and verically aligns all comments to the leftmost % in s.
%
%  Illustration of input and output:
%     If s is this string:
%       'o = step(h,x); %foo
%        % note
%        setup(h1); %bar'
%
%      sout will be this string:
%       'o = step(h,x); %foo
%        % note
%        setup(h1);     %bar'
   
% Copyright 2014 The MathWorks, Inc.

clines = strsplit(s, '\n'); %split up by line.

%Find end position of tokens of all lines with a comment char
% '%' that follow some executable code (\w will suffice). This ignores full
% line comments. Looking for just an '=' sign is not sufficient. 

[~,e] = regexp(clines, '(?=\w).*%');

%find the farthest right '%'
mx = max([e{:}]);

%find how many spaces to add
d = cellfun(@(x) mx-x, e, 'UniformOutput', false);

%Create new strings
cnew = cell(size(clines));

for ii=1:numel(clines)
    if ~isempty(e{ii}) %don't pad unmatched lines
        cnew{ii} = [clines{ii}(1:e{ii} - 1), ...
            blanks(d{ii}), ...
            clines{ii}(e{ii}:end) char(10)];
    else
        
        cnew{ii} = [clines{ii} char(10)];
    end
end

sout = [cnew{:}];
sout(end) = []; %remove last char(10). The above adds and extra one.
