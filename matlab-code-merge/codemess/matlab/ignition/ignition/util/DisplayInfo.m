%DisplayInfo Structure holding information required to display a tall array
%   Also includes underlying implementations of display methods.

% Copyright 2016 The MathWorks, Inc.
classdef DisplayInfo
    properties (SetAccess = immutable, GetAccess = private)
        % Function to emit a blank line if necessary (tied to 'format loose')
        BlankLineFcn
    end
    properties (SetAccess = immutable)
        % Does the destination support hyperlinks
        IsHot
        % Do we have preview data
        IsPreviewAvailable
        % The actual preview data
        PreviewData
        % Is the preview data truncated in the first dimension
        IsPreviewTruncated
        % Name of the array we're displaying
        Name
    end
    
    methods (Access = private)
        function [arrayType, showSize, emptyStr] = calculateArrayType(~, dataClass, dataNDims, dataSize)
        % Calculate a word to describe the array. Same logic also works out whether the
        % size needs to be shown.
            
            arrayType = 'array';
            showSize  = true;
            emptyStr  = '';
            if any(dataSize == 0)
                emptyStr = 'empty';
            end
            if dataNDims == 2
                if all(dataSize ~= 1)
                    arrayType = 'matrix';
                elseif all(dataSize == 1)
                    arrayType = ''; % scalar - nothing printed for that though.
                    showSize  = false;
                elseif dataSize(1) == 1
                    arrayType = 'row vector';
                else
                    arrayType = 'column vector';
                end
            end
            
            % Override type for 'table' - never show an array type.
            if strcmp(dataClass, 'table')
                arrayType = '';
            elseif isempty(dataClass) || ~ismember(dataClass, iNumericTypeClasses())
                % Unknown or non-numeric arrays always show simply as 'array'
                arrayType = 'array';
            end
        end
        
        function szStr = calculateSizeStr(~, dataNDims, dataSize)
        % Calculate a MxNx... or similar size string.
            
            if isnan(dataNDims)
                % No size information at all, MxNx...
                dimStrs = {'M', 'N', '...'};
            else
                % Known number of dimensions
                
                % unknownDimLetters are the placeholders we'll use in the size specification
                unknownDimLetters = 'M':'Z';
                
                dimStrs = cell(1, dataNDims);
                for idx = 1:dataNDims
                    if isnan(dataSize(idx))
                        if idx > numel(unknownDimLetters)
                            % Array known to be 15-dimensional, but 15th (or higher) dimension is not
                            % known. Not sure how you'd ever hit this.
                            dimStrs{idx} = '?';
                        else
                            dimStrs{idx} = unknownDimLetters(idx);
                        end
                    else
                        dimStrs{idx} = matlab.bigdata.internal.util.formatBigSize(dataSize(idx));
                    end
                end
            end

            % Join together dimensions using the TIMES character.
            szStr = strjoin(dimStrs, getTimesCharacter());
        end
        
        function printXEqualsLine(obj, dataClass, dataNDims, dataSize)
        % Print the "x = " line and also the array type/size line as appropriate.
            
            [arrayType, showSize, emptyStr] = calculateArrayType(obj, dataClass, dataNDims, dataSize);
            if showSize
                sizeStr = calculateSizeStr(obj, dataNDims, dataSize);
            else
                sizeStr = '';
            end
            
            obj.blankLine();
            fprintf('%s =\n', obj.Name);
            obj.blankLine();

            % Prepend a space to dataClass if it is non-empty.
            dataClassWithSpace = regexprep(dataClass, '(.+)', ' $0');
            
            % Prepend a space to emptyStr if it is non-empty
            emptyStrWithSpace = regexprep(emptyStr, '(.+)', ' $0');
            
            if obj.IsHot
                fprintf('  %s%s <a href="matlab:helpPopup tall" style="font-weight:bold">tall</a>%s %s\n', ...
                        sizeStr, emptyStrWithSpace, dataClassWithSpace, arrayType);
            else
                fprintf('  %s%s tall%s %s\n', ...
                        sizeStr, emptyStrWithSpace, dataClassWithSpace, arrayType);
            end
            obj.blankLine();
        end
        
        function displayPreviewData(obj, previewData, isTruncated)
        % Print out the preview data, adding the continuation characters as required.

            if isempty(previewData)
                return
            end
            
            % Start with the builtin DISP version
            previewText = evalc('disp(previewData)');

            % Keep from the first to the last non-empty lines
            previewLines  = strsplit(previewText, sprintf('\n'), ...
                'CollapseDelimiters', false);
            nonEmptyLines = ~cellfun(@isempty, previewLines);
            previewLines  = previewLines(find(nonEmptyLines, 1, 'first'):find(nonEmptyLines, 1, 'last'));
           
            % Remove any <strong></strong> tags from the display 
            if ~obj.IsHot
                previewLines = regexprep(previewLines, '</?strong>', '');
            end
            
            if ~ismatrix(previewData) && ~ischar(previewData)
                % For >2D data, prepend the variable name to the lines like "x(:,:,1) =" - but
                % not for CHAR data as a perverse string could foil us.
                previewLines = regexprep(previewLines, '^(\(.*\)) =$', [obj.Name, '$0']);
            end

            fprintf('%s\n', previewLines{:});
                
            % Finally, add the continuation indicators
            if isTruncated
                % We want to find a line of text that tells us where to add the trailing
                % continuation indicators. We're going to add continuation
                % indicators at word-start.
                if istable(previewData)
                    % We're looking for the table display '___' lines, here
                    % we always need to remove the <strong> tags first
                    previewLines  = regexprep(previewLines, '</?strong>', '');
                    linesMatch    = regexp(previewLines, '^(_|\s)+$');
                    lineIdx       = find(~cellfun(@isempty, linesMatch), 1, 'first');
                    txtLine       = previewLines{lineIdx};
                else
                    txtLine       = previewLines{end};
                end
                % Find starts of words - i.e. change from space character to non-space. Note
                % this is easily foiled by e.g. strings containing spaces.
                firstNonSpaces = regexp(txtLine, '(^|(?<=\s))\S');
                if isempty(firstNonSpaces)
                    % Get here if txtLine is completely empty (don't think that can happen) or
                    % contains only whitespace (can happen for char
                    % display). Either way, treat first column as
                    % non-whitespace.
                    firstNonSpaces = 1;
                end
                
                txtLine = repmat(' ', 1, max(firstNonSpaces));
                % Place continuation indicators in those places
                txtLine(firstNonSpaces) = ':';
                fprintf('%s\n%s\n', txtLine, txtLine);
            end
            obj.blankLine();
        end
        
        function displayQueries(obj, dataNDims, dataSize)
        % Print a matrix of ? characters to indicate we don't know what's going on.
            if isnan(dataNDims) || dataNDims > 2 || all(isnan(dataSize)) || all(dataSize > 3)
                % Print a matrix of ? for cases:
                % 1. NDims unknown
                % 2. NDims > 2
                % 3. NDims known, but all sizes unknown
                % 4. All dims > 3
                txt = [repmat(sprintf('    ?    ?    ?    ...\n'), 1, 3), ...
                       repmat(sprintf('    :    :    :\n'), 1, 2)];
                fprintf('%s', txt);
            else
                % Try and make the shape of the matrix reflect the known dimensions. Here, we
                % can assume 2-D. Treat unknown sizes as Inf, and then clamp to 3.
                dataSize(isnan(dataSize)) = Inf;
                numQueries = min(3, dataSize);
                extend = dataSize > 3;
                
                normalRow = repmat('    ?', 1, numQueries(2));
                if extend(2)
                    normalRow = [normalRow, '   ...'];
                end
                textRows = repmat({normalRow}, numQueries(1), 1);
                fprintf('%s\n', textRows{:});
                if extend(1)
                    extendRow = repmat('    :', 1, numQueries(2));
                    fprintf('%s\n%s\n', extendRow, extendRow);
                end
            end
            obj.blankLine();
        end
        
        function displayHint(obj)
            if obj.IsHot
                % Only display the hint in 'hot' mode where the hyperlink can function.
                fprintf('%s\n', getString(message('MATLAB:bigdata:array:UnevaluatedArrayDisplayFooter')));
                obj.blankLine();
            end
        end
    end
    
    methods
        function obj = DisplayInfo(name, gotPreview, previewData, isPreviewTruncated)
            obj.Name = name;
            formatSpacing = get(0,'FormatSpacing');
            obj.IsHot = matlab.internal.display.isHot;
            if isequal(formatSpacing,'compact')
                obj.BlankLineFcn = @()[];
            else
                obj.BlankLineFcn = @() fprintf('\n');
            end
            obj.IsPreviewAvailable = gotPreview;
            obj.PreviewData = previewData;
            obj.IsPreviewTruncated = isPreviewTruncated;
        end
        function blankLine(obj)
            feval(obj.BlankLineFcn);
        end
        function displayPreview(obj, tallSize)
            assert(obj.IsPreviewAvailable);
            
            % Only apply the tallSize if the preview has been truncated - otherwise the
            % preview is the full size.
            sizeForXEquals = size(obj.PreviewData);
            if obj.IsPreviewTruncated
                sizeForXEquals(1) = tallSize;
            end
            printXEqualsLine(obj, class(obj.PreviewData), ndims(obj.PreviewData), sizeForXEquals);
            displayPreviewData(obj, obj.PreviewData, obj.IsPreviewTruncated);
        end
        function displayWithNoPreview(obj, dataClass, dataNDims, dataSize)
            printXEqualsLine(obj, dataClass, dataNDims, dataSize);
            displayQueries(obj, dataNDims, dataSize);
            displayHint(obj);
        end
        function displayWithFabricatedPreview(obj, fabricatedPreview, dataNDims, dataSize)
        % Call this to apply a fabricated preview array. The fabricated preview is
        % presumed to be truncated.
            printXEqualsLine(obj, class(fabricatedPreview), dataNDims, dataSize);
            isPreviewTruncated = isnan(dataNDims) || size(fabricatedPreview, 1) ~= dataSize(1);
            displayPreviewData(obj, fabricatedPreview, isPreviewTruncated);
            displayHint(obj);
        end
    end
end

function vals = iNumericTypeClasses()
    integerTypeNames = strsplit(strtrim(sprintf('int%d uint%d ', ...
                                                repmat([8, 16, 32, 64], 2, 1))));
    vals  = ['single', 'double', 'logical', integerTypeNames];
end
