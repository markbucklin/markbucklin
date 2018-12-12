classdef SessionInfo < matlab.mixin.SetGet
    
    properties
        MouseId
        CellOrigin
        TransplantationDate
        ImageLocation
        DayAfterTransplantation
        ImagingDate
        FrameRate
        Hemisphere
        Root
        Run
    end
    properties (Constant, Hidden)
        MouseIdTags = {'SC','GE','Ctx','LC'}
    end
    
    
    methods
        function si = SessionInfo(str)
            
            % Allow empty construction
            if nargin
                
                assert( isdir(str), 'Must pass a directory name to create Session Info');
                
                % Root Session Directory
                si.Root = str;
                
                % Separate directory name and parent path
                [parentPath, sessionDir] = fileparts(str);
                
                % Get Potential Metadata Tags from Directory Tree
                if isempty(parentPath)
                    taggableStrings = {};
                else
                    taggableStrings = strsplit(parentPath,...
                        ['[',filesep,'\\-\]\[]'],'DelimiterType','RegularExpression');
                end
                taggableStrings = [taggableStrings ,...
                    strsplit(sessionDir,'[\[\]\-]','DelimiterType','RegularExpression')];
                taggableStrings = taggableStrings(~cellfun(@isempty, taggableStrings));
                taggableStrings = strtrim(taggableStrings);
                
                % Get Mouse-ID
                allIdMatches = cellfun( @getTaggedString, si.MouseIdTags, 'UniformOutput',false);
                batchStr = allIdMatches{ find(~cellfun(@isempty, allIdMatches), 1, 'last')};
                mouseStr = getTaggedString('M');
                si.MouseId = [batchStr,'_',mouseStr];
                
                % Get Cell-Origin
                if startsWith(batchStr,'SC')
                    si.CellOrigin = 'unspecified';
                elseif ~isempty(batchStr)
                    si.CellOrigin = batchStr( isstrprop(batchStr,'alpha'));
                end
                
                % Get Transplantation-Date
                if ~isempty(batchStr)
                    transplantDateStr = batchStr(isstrprop(batchStr,'digit'));
                    switch length(transplantDateStr)
                        case 4
                            transplantDateNum = datenum( ['2017',transplantDateStr], 'yyyymmdd');
                        case 6
                            transplantDateNum = datenum( ['20',transplantDateStr], 'yyyymmdd');
                        case 8
                            transplantDateNum = datenum( transplantDateStr, 'yyyymmdd');
                        otherwise
                            transplantDateNum = datenum(datetime('now'));
                    end
                    si.TransplantationDate = datestr(transplantDateNum);
                end
                
                % Get Hemisphere
                if ~isempty(mouseStr) && endsWith(mouseStr,'H')
                    si.Hemisphere = mouseStr(end-1);
                end
                
                % Get Image Location %TODO
                
                % Get Day After Transplantation
                si.DayAfterTransplantation = getNumberFromTaggedString('DAT');
                
                % Get Imaging-Date
                imgDate = cellfun( @getTaggedString, {'I'}, 'UniformOutput',false);
                imgStr = imgDate{ find(~cellfun(@isempty, imgDate), 1, 'last')};
                
                if ~isempty(imgStr)
                    imagingDateStr = imgStr(isstrprop(imgStr,'digit'));
                    switch length(imagingDateStr)
                        case 4
                            imagingDateNum = datenum( ['2017',imagingDateStr], 'yyyymmdd');
                        case 6
                            imagingDateNum = datenum( ['20',imagingDateStr], 'yyyymmdd');
                        case 8
                            imagingDateNum = datenum( imagingDateStr, 'yyyymmdd');
                        otherwise
                            imagingDateNum = datenum(datetime('now'));
                    end
                    si.ImagingDate = datestr(imagingDateNum);
                end
                
                % Get Frame-Rate
                fps = getNumberFromTaggedString('fps');
                si.FrameRate = fps;
                if isempty(fps)
                    si.FrameRate = getNumberFromTaggedString('Hz');
                end
                
                
                % Get Run
                run = getNumberFromTaggedString('run');
                if ~isempty(run)
                    si.Run = run;
                else
                    si.Run = 1;
                end
            end
            
            
            function tagNum = getNumberFromTaggedString(tag)
                tagStr = getTaggedString(tag);
                if ~isempty(tagStr)
                    tagNum = str2num( tagStr( isstrprop(tagStr, 'digit')));
                else
                    tagNum = [];
                end
            end
            function tagWithString = getTaggedString(tag)
                tagWithString = '';
                strMatch = ~cellfun(@isempty, strfind(taggableStrings, tag));
                if any(strMatch)
                    tagWithString = taggableStrings{ find(strMatch, 1, 'last')};
                end
            end
            
        end
    end
    
    
end

