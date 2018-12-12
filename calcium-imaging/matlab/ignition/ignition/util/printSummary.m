function printSummary( summaryInfo )
% Print out some previously collected variable summary info

%   Copyright 2016 The MathWorks, Inc.

import matlab.bigdata.internal.util.formatBigSize

isLoose = strcmp(matlab.internal.display.formatSpacing,'loose');
if isLoose
    sep = sprintf('\n');
else
    sep = '';
end

fprintf('%sVariables:\n%s', sep, sep);

min_label = getString(message('MATLAB:table:uistrings:SummaryMin'));
max_label = getString(message('MATLAB:table:uistrings:SummaryMax'));


for idx = 1:numel(summaryInfo)
    thisInfo = summaryInfo{idx};
    szStr = formatBigSize(thisInfo.Size);
    fprintf('    %s: %s %s\n', ....
            matlab.bigdata.internal.util.emphasizeText(thisInfo.Name), ...
            szStr, thisInfo.Class);
    if prod(thisInfo.Size) ~= 0
        labelsStr = {};
        valuesStr = {};
        if isfield(thisInfo, 'NumMissing')
            % numeric-ish
            missingLabel = [thisInfo.MissingStr, 's'];
            labelsStr = { min_label, max_label };
            valuesStr = { iFormat(thisInfo.MinVal), iFormat(thisInfo.MaxVal) };
            if thisInfo.NumMissing > 0
                labelsStr{end+1} = missingLabel;
                valuesStr{end+1} = formatBigSize(thisInfo.NumMissing);
            end
        elseif isfield(thisInfo, 'true')
            labelsStr = {'true', 'false'};
            valuesStr = {formatBigSize(thisInfo.true), ...
                         formatBigSize(thisInfo.false)};
        elseif isfield(thisInfo, 'CategoricalInfo')
            labelsStr = thisInfo.CategoricalInfo{1};
            valuesStr = arrayfun(@formatBigSize, thisInfo.CategoricalInfo{2}, 'UniformOutput', false);
        end
        if ~isempty(labelsStr)
            maxLabelLen = max(cellfun(@length, labelsStr));
            maxValueLen = max(cellfun(@length, valuesStr));
            formatStr   = sprintf('            %%-%ds    %%%ds\\n', maxLabelLen, maxValueLen);
            fprintf('        Values:\n%s', sep);
            for lidx = 1:numel(labelsStr)
                fprintf(formatStr, labelsStr{lidx}, valuesStr{lidx});
            end
        end
    end
    fprintf('%s', sep);
end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function t = iFormat(v)
if isnumeric(v)
    t = num2str(v);
elseif isdatetime(v) || isduration(v)
    t = char(v);
elseif islogical(v)
    if v
        t = 'true';
    else
        t = 'false';
    end
end
end
