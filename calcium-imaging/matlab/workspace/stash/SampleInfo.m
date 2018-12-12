classdef SiteInfo
    properties
        cellOrigin
        mouseID
        imageLocation
        dayAfterTransplantation
    end
    methods
        function si = SiteInfo( str, format)
            %             cellOrigin, mouseID, imageLocation,...
            %                 dayAfterTransplantation)
            if nargin > 0
                si.cellOrigin = cellOrigin;
                si.mouseID = mouseID;
                si.imageLocation = imageLocation;
                si.dayAfterTransplantation = dayafterTransplantation;
            end
            
            p1 = '(?<DayAfterTransplantation>\d+DAT';
            p2 = '(?<city>[A-Z][a-z]+)';
            p3 = '(?<state>[A-Z]{2})';
            p4 = '(?<zip>\d{5})';
            
            expr = [p1 ', ' p2 ', ' p3 ', ' p4];
            
        end
    end

    