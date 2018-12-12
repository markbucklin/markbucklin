classdef SiteInfo
    properties
        cellOrigin
        mouseID
        imageLocation
        dayAfterTransplantation
    end
    methods
        function si = SiteInfo(cellOrigin, mouseID, imageLocation,...
                dayAfterTransplantation)
            if nargin > 0
                si.cellOrigin = cellOrigin;
                si.mouseID = mouseID;
                si.imageLocation = imageLocation;
                si.dayAfterTransplantation = dayafterTransplantation;
            end
        end
    end

    