classdef (CaseInsensitiveProperties = true) RegionOfInterest < hgsetget
    % ------------------------------------------------------------------------------
    % RegionOfInterest
    % 7/30/2015
    % Mark Bucklin
    % ------------------------------------------------------------------------------
    %
    % DESCRIPTION:
    %
    %
    % USAGE:
    %
    %   >> obj = RegionOfInterest();
    %   >> obj = RegionOfInterest(bw);
    %   >> obj = RegionOfInterest(cc);
    %   >> obj = RegionOfInterest(regionProps);
    %   >> obj = RegionOfInterest(labelMatrix);
    %
    %
    % RegionOfInterest Properties:
    % 	ShowMode
    % 	MinSufficientOverlap
    % 	GroupingSizeMin
    % 	GroupingSimilarityMin
    % 	transparency
    % 	Trace
    % 	FrameSize
    % 	Overlay
    % 	Color
    % 	ColorIndex
    % 	FrameIdx
    % 	TraceType
    %
    %
    %
    % RegionOfInterest Methods:
    % 	RegionOfInterest
    % 	updateProperties
    % 	trim
    % 	hasFrame
    % 	setDistinguishableColors
    % 	showAsOverlay
    % 	showWithText
    % 	hide
    % 	show
    % 	mapOverlap
    % 	sufficientlySimilar
    % 	edgeSeparation
    % 	centroidSeparation
    % 	isInBoundingBox
    % 	fractionalOverlap
    % 	spatialOverlap
    % 	overlaps
    % 	delete
    % 	removeEmpty
    % 	unique
    % 	mostSimilar
    % 	reduceSuperRegions
    % 	partitionByLocation
    % 	partitionBySize
    % 	findGroups
    % 	reduceRegions
    % 	merge
    % 	fillPropsFromStruct
    % 	reassignIdx
    % 	makeUniquePixels
    % 	makeBoundaryTrace
    % 	makeSparseMask
    % 	createLabelMatrix
    % 	createMask
    % 	centroidImage
    % 	weightedMask
    % 	weightedMask3D
    % 	filterTrace
    % 	normalizeTrace2WindowedRange
    % 	makeTraceFromVidOld
    % 	makeTraceFromVid
    % 	vidOverlayUpdate
    % 	roiClickFcn
    % 	createShowFigure
    % 	updateCID
    % 	guessFrameSize
    %
    % See also:
    %			PROCESSFAST
    %
    % ------------------------------------------------------------------------------
    % ------------------------------------------------------------------------------
    % ------------------------------------------------------------------------------
    
    
    
    
    % SETTINGS
    properties
        ShowMode = 'image' % 'image' , 'patch'
        MinSufficientOverlap = .75				% Use in sufficientlySimilar() and reduceSuperRegion() methods as a threshold to designate ROIs to merge
        GroupingSizeMin = 2							% Used in findGroups() as terminus point for clustering. When fewer than GroupingSizeMin rois remain unclustered the algorithm finishes
        GroupingSimilarityMin = .85				%  Used in findGroups() via reduceRegions() method as an initial threshold for clustering
        transparency = .75								% Used in show___() methods to set transparency of graphic ROI marker
        MaxEdgeSeparation = 45					% Increase to cluster super-regions more leniently
        MaxCentroidSeparation = 10				% Increase to cluster super-regions by centroid proximity more leniently
    end
    
    % CONFIGURABLE PROPERTIES
    properties
        Trace								% The trace indicating ROI intensity over time. May be set/reassigned from the command-line.
        FrameSize						% Height and Width of image frame -> [numRows, numCols]
        Overlay							%  Background Image used in the showAsOverlay() method
        Color								% Color assigned to ROI when plotting in RGB format -> e.g.  [ 1 0 0]
        ColorIndex						% Color index if default color scheme is used (distinguishable_colors)
        FrameIdx						% Indices of frames in which the ROI or set of comprising ROIs were detected (set by user during construction)
        TraceType						% Structure of alternative traces formed when combined with video data using makeTraceFromVid()
    end
    
    % IDENTICAL TO 'REGIONPROPS' PROPERTIES
    properties (SetAccess = protected)
        Area
        BoundingBox
        Centroid						% Pixel-scale position of ROI Centroid (center-of-mass) -> [x, y] from upper left corner
        ConvexArea
        ConvexHull
        ConvexImage
        Eccentricity
        Extrema
        Extent
        EquivDiameter
        Image
        MaxIntensity
        MeanIntensity
        MinIntensity
        PixelValues
        WeightedCentroid
        MajorAxisLength
        MinorAxisLength
        Orientation
        Perimeter
        PixelIdxList
        PixelList
        SubarrayIdx
    end
    
    % OTHER SPATIAL & TEMPORAL CHARACTERISTICS
    properties (SetAccess = protected)
        UID							% Unique ID -> assigned when ROI is constructed
        CID							% Centroid ID -> 32-bit ID number encoding ROI centroid
        FirstFrame				%  First Frame Index in which comprising ROIs were identified
        LastFrame				%  Last Frame Index in which comprising ROIs were identified
        XLim
        YLim
        Width
        Height
        ExtraProps
    end
    properties (SetAccess = protected)
        PixelSubScripts
        PixelWeights
        PixelCounts
        UniquePixels
        UniqueArea
        BoundaryTrace
        SparseMask
        HaloPixIdx
    end
    properties (SetAccess = protected)
        NumberOfMerges = 0
        SpatialPower
    end
    
    % STATES
    properties (SetAccess = protected)
        isConfirmed = false
        isCombined = false
        isMerged = false
        isOverlapping = false
        isSubRegion = false
        isSuperRegion = false
    end
    
    % GRAPHICS HANDLES AND PROPS
    properties
        % 	 hIm
        % 	 hAx
        % 	 hFig
        % 	 hText
        % 	 hBg
    end
    properties (Constant)
        RegionPropInputs = {	...
            'Centroid', 'BoundingBox','Area',...
            'PixelIdxList',...
            'Image',...
            'EquivDiameter',...
            'MajorAxisLength', 'MinorAxisLength', 'Orientation', 'Eccentricity'}
    end
    
    
    
    
    events
    end
    
    
    
    
    methods % CONSTRUCTOR & SETUP
        function obj = RegionOfInterest(varargin)
            
            % ASSIGN UNIQUE ID
            global ROINUM
            global FRAMESIZE
            if isempty(ROINUM)
                ROINUM = 1;
            else
                ROINUM = ROINUM + 1;
            end
            obj.UID = ROINUM;
            roiDefInput = [];
            
            if nargin > 1
                % INPUT INCLUDES PROPERTY-VALUE PAIRS
                if logical(mod(nargin,2)) % odd
                    roiDefInput = varargin{1};
                    if nargin > 2
                        pvpairs = varargin(2:end);
                    else
                        pvpairs = [];
                    end
                else
                    pvpairs = varargin(1:end);
                end
                if ~isempty(pvpairs)
                    for k = 1:2:length(pvpairs)
                        obj.(pvpairs{k}) = pvpairs{k+1};
                    end
                end
                
            elseif nargin == 1
                % INPUT IS A MULTI-ROI BWFRAME STRUCTURE WITH FIELDS 'REGIONPROPS' AND 'BWMASK'
                roiDefInput = varargin{1};
            end
            
            % EMPTY INPUT -> RETURN EMPTY REGION
            if isempty(roiDefInput)
                return
            end
            
            % HANDLE DIFFERENT ROI-DEFINING INPUTS
            switch(class(roiDefInput))
                
                % REGION OF INTEREST CLASS
                case 'RegionOfInterest'
                    obj = merge(roiDefInput);
                    return
                    
                    % STRUCTURE OR STRUCTURE ARRAY
                case 'struct'
                    if isfield(roiDefInput, 'RegionProps')
                        % INPUT FROM GENERATEREGIONSOFINTEREST()
                        RP = roiDefInput.RegionProps;
                    elseif all(isfield(roiDefInput,{'Centroid','BoundingBox','PixelIdxList'}))
                        % INPUT FROM REGIONPROPS()
                        RP = roiDefInput;
                    end
                    if isfield(roiDefInput,'bwMask')
                        % STRUCT ARRAY OF FRAMES
                        [RP.FrameSize] = deal(size(roiDefInput.bwMask));
                    end
                    
                    % BW (LOGICAL) MASK IMAGE
                case 'logical'
                    if any(roiDefInput(:))
                        RP = getRegionProps(roiDefInput);
                    else
                        obj = RegionOfInterest.empty(0,1);
                        return
                    end
                    
                    % GPU-ARRAY TYPE -> LOGICAL OR LABELMATRIX
                case 'gpuArray'
                    roiDefInput = gather(roiDefInput);
                    if any(roiDefInput(:))
                        RP = getRegionProps(roiDefInput);
                    else
                        obj = RegionOfInterest.empty(0,1);
                        return
                    end
                    
                otherwise
                    % POSSIBLY A LABELMATRIX
                    try
                        RP = getRegionProps(roiDefInput);
                    catch me
                        getReport(me)
                    end
            end
            
            % CALL RECURSIVELY FOR INPUT DEFINING MULTIPLE ROIS
            if numel(RP) > 1
                for nr = size(RP,1):-1:1
                    for nc = size(RP,2):-1:1
                        obj(nr,nc) = RegionOfInterest(RP(nr,nc));
                    end
                end
                
            else
                % PROCESS INPUT FOR SINGLE ROI
                rpFields = fields(RP);
                for kField = 1:numel(rpFields)
                    fn = rpFields{kField};
                    try
                        if isprop(obj,fn)
                            obj.(fn) = RP.(fn);
                        else
                            obj.ExtraProps.(fn) = RP.(fn);
                        end
                    catch me
                        disp(getReport(me))
                    end
                end
                
            end
            
            % UPDATE GLOBAL FRAME-SIZE IF IT'S KNOWN
            if ~isempty(obj(1).FrameSize)
                FRAMESIZE = obj(1).FrameSize;
            end
            
            % SUBFUNCTION FOR CALLING REGIONPROPS() FUNCTION
            function rp = getRegionProps(rpInput)
                [numRows, numCols, numFrames] = size(rpInput);
                FRAMESIZE = [numRows, numCols];
                rp = regionprops(reshape(rpInput, numRows,[],1),...
                    'Centroid', 'BoundingBox','Area',...
                    'Eccentricity', 'PixelIdxList','Perimeter');
                [rp.FrameSize] = deal(FRAMESIZE);
                if numFrames > 1
                    numPixels = numRows * numCols;
                    cxy = cat(1,rp.Centroid);
                    bb = cat(1,rp.BoundingBox);
                    pixidx = {rp.PixelIdxList};
                    frameIdx = ceil(cxy(:,1)./numCols); % TODO: check if FrameIdx is already filled
                    cxy(:,1) = rem(cxy(:,1), numCols);
                    bb(:,1) = rem(bb(:,1), numCols);
                    for k=1:numel(rp)
                        rp(k).Centroid = cxy(k,:);
                        rp(k).BoundingBox = bb(k,:);
                        rp(k).PixelIdxList = rem(rp(k).PixelIdxList, numPixels);
                        rp(k).FrameIdx = frameIdx(k);
                    end
                end
                
            end
            
        end
        function varargout = updateProperties(obj)
            if any(cellfun(@isempty,{obj.PixelIdxList}))
                obj = removeEmpty(obj);
            end
            updateCID(obj)
            
            % ENSURE FRAME SIZE IS CONSISTENT (OR AT LEAST NON-EMPTY
            if isempty(obj(end).FrameSize)
                obj(end).guessFrameSize();
            end
            set(obj, 'FrameSize', obj(end).FrameSize);
            
            % CALCULATE SPARSE MATRICES AND OTHER VARIABLES FROM INDICES
            if any(cellfun(@isempty,{obj.PixelSubScripts}))
                imsize = obj(end).FrameSize;
                
                % PIXEL SUBSCRIPTS
                for kObj = 1:numel(obj)
                    [isubs, jsubs] = ind2sub(imsize,obj(kObj).PixelIdxList);
                    pxsub = [isubs(:) jsubs(:)];
                    obj(kObj).PixelSubScripts = pxsub;
                end
            end
            
            % WEIGHTED CENTROID
            supreg = [obj.isSuperRegion]';
            for kSup = 1:numel(supreg)
                if supreg(kSup)
                    obj(kSup).Centroid = fliplr(sum(bsxfun(@times,...
                        obj(kSup).PixelSubScripts,...
                        single(obj(kSup).PixelWeights)))...
                        / sum(obj(kSup).PixelWeights));
                end
            end
            
            % XLIM and YLIM
            if any(cellfun(@isempty,{obj.XLim}))
                bb = cat(1,obj.BoundingBox);
                xl(:,1) = floor(bb(:,1));
                xl(:,2) = ceil( bb(:,1) + bb(:,3) );
                yl(:,1) = floor(bb(:,2));
                yl(:,2) = ceil(bb(:,2)+bb(:,4));
                for kObj = 1:numel(obj)
                    obj(kObj).XLim = xl(kObj,:);
                    obj(kObj).YLim = yl(kObj,:);
                end
            end
            
            % WIDTH & HEIGHT
            if any(cellfun(@isempty,{obj.Width}))
                roiXlim = cat(1,obj.XLim);
                roiYlim = cat(1,obj.YLim);
                roiWidth = roiXlim(:,2)-roiXlim(:,1);
                roiHeight = roiYlim(:,2)-roiYlim(:,1);
                for kObj = 1:numel(obj)
                    obj(kObj).Width = roiWidth(kObj);
                    obj(kObj).Height = roiHeight(kObj);
                end
            end
            
            % FIRST FRAME and LAST FRAME
            if any(cellfun(@isempty,{obj.FirstFrame}))
                for kObj = 1:numel(obj)
                    obj(kObj).FirstFrame = min(obj(kObj).FrameIdx(:));
                    obj(kObj).LastFrame = max(obj(kObj).FrameIdx(:));
                end
            end
            
            if nargout > 0
                varargout{1} = obj;
            end
        end
        function trim(obj,freqThresh)
            if nargin < 2
                freqThresh = .25;
            end
            N = numel(obj);
            for k = 1:N
                pixFreq = obj(k).PixelWeights;
                trimPix = pixFreq > freqThresh*max(pixFreq(:));
                obj(k).PixelIdxList = obj(k).PixelIdxList(trimPix);
                obj(k).PixelSubScripts = obj(k).PixelSubScripts(find(trimPix),:);
                obj(k).PixelWeights = obj(k).PixelWeights(trimPix);
                obj(k).PixelCounts = obj(k).PixelCounts(trimPix);
                rp = regionprops(obj(k).createMask);
                obj(k).Area = rp.Area;
                obj(k).Centroid = rp.Centroid;
                obj(k).BoundingBox = rp.BoundingBox;
            end
        end
    end
    methods % SHOW/DISPLAY
        function varargout = show(obj)
            %TODO: can make compatible for HG2 with: if verLessThan('matlab','8.4.0')
            global H
            
            % FILTER AND NORMALIZE TRACES AFTER COPYING TRACE TO RAWTRACE
            if any(cellfun(@isempty, {obj.BoundaryTrace}))
                makeBoundaryTrace(obj);
            end
            
            % GET SIZES
            N = numel(obj);
            sz = obj(1).FrameSize;
            
            % SET COLORS IF NOT ALREADY ASSIGNED
            if any(cellfun(@isempty, {obj.Color}))
                setDistinguishableColors(obj);
            end
            
            % CREATE FIGURE IF ONE DOESN'T EXIST
            if isempty(H) || ~isvalid(H.im)
                H = obj.createShowFigure();
            end
            
            switch obj(1).ShowMode
                % IMAGE-TYPE SHOW MODE
                case 'image'
                    cdata = zeros([sz 3]);
                    adata = zeros(sz);
                    idxPerFrame = prod(sz);
                    for kObj = 1:N
                        nPix = numel(obj(kObj).PixelIdxList);
                        repRoiColor = repmat( obj(kObj).Color(1:3), [nPix 1]);
                        idxChan = repmat([0 idxPerFrame idxPerFrame*2], [nPix 1]);
                        pixIdx = repmat(obj(kObj).PixelIdxList(:), [1 3]) + idxChan;
                        cdata(pixIdx(:)) = repRoiColor(:);
                        if ~isempty(obj(kObj).PixelWeights)
                            adata(obj(kObj).PixelIdxList(:)) = max([ obj(kObj).PixelWeights,...
                                adata(obj(kObj).PixelIdxList(:))],[], 2) ;
                        end
                        if ~isempty(obj(kObj).BoundaryTrace);
                            H.line(kObj) = line(...
                                obj(kObj).BoundaryTrace.x, obj(kObj).BoundaryTrace.y,...
                                'Parent', H.ax,...
                                'Color', obj(kObj).Color,...
                                'PickableParts','none',...
                                'HitTest','off',...
                                'LineWidth', 1);
                        end
                    end
                    H.im.CData = cdata;
                    if any(adata(:) > 0)
                        H.im.AlphaData = adata;
                    end
                    
                case 'patch'
                    % PATCH TYPE SHOW MODE
                    for kObj=numel(obj):-1:1
                        H.hpatch(kObj) = handle(patch(obj(kObj).BoundaryTrace.x,...
                            obj(kObj).BoundaryTrace.y,...
                            obj(kObj).Color(1:3) ,...
                            'Parent',H.ax,...
                            'FaceAlpha',obj(1).Transparency,...
                            'EdgeAlpha',.8,...
                            'ButtonDownFcn', @(src,evnt)roiClickFcn(obj,src,evnt),...
                            'UserData',obj(kObj)));
                    end
                otherwise
                    set(obj,'ShowMode','patch');
                    H = show(obj);
                    
            end
            drawnow
            if nargout
                varargout{1} = H;
            end
        end
        function hide(obj)
            %(todo)
            global H
            h = H;
            
            % CLEAR ANY PREVIOUSLY DRAWN ROIs
            if ~isempty(h.ax) && isvalid(h.ax)
                cla(h.ax)
            end
        end
        function varargout = showWithText(obj,propstring)
            %TODO: fix, since removing hText property
            persistent h;
            if nargin < 2
                propstring = 'UID';
            end
            N = numel(obj);
            % 		textOffset = [-20 20]; % [dx,dy] + towards lower right
            % PROCESS AND USE DEFAULT SHOW METHOD
            obj = removeEmpty(obj);
            if any(cellfun(@isempty,{obj.XLim}))
                updateProperties(obj);
            end
            h = show(obj);
            % PROCESS TEXT COMMAND AS PROPERTY, FUNCTION, ETC.
            for kObj = 1:N
                if ischar(propstring) && isprop(obj(kObj),propstring)
                    propval = obj(kObj).(propstring);
                else
                    try
                        if isa(propstring,'function_handle')
                            propval =  feval(propstring,obj(kObj));
                        else
                            propval = evalin('caller',propstring);
                        end
                    catch me
                        error('RegionOfInterest:showWithText:InvalidProperty',...
                            me.message);
                    end
                end
                if isnumeric(propval)
                    if abs(propval-round(propval)) < eps
                        propvalstring = sprintf('%i ',propval);
                    else
                        propvalstring = sprintf('%5.2f ',propval);
                    end
                else
                    propvalstring = propval;
                end
                h.text(kObj) = handle(text(...
                    'String', propvalstring,...
                    'FontWeight','bold',...
                    'BackgroundColor',[.1 .1 .1 .3],...
                    'Margin',1,...
                    'Position',round(obj(kObj).BoundingBox(1:2)) - [0 5],...
                    'Parent', h.ax,...
                    'Color',obj(kObj).Color	));
                
            end
            drawnow
            if nargout
                varargout{1} = h;
            end
        end
        function showAsOverlay(obj, overlayInput, varargin)
            global H
            
            % INITIALIZE USING SHOW METHOD
            sz = obj(1).FrameSize;
            if nargin > 2
                txt = varargin{1};
                H = showWithText(obj,txt);
            else
                H = show(obj);
            end
            
            H.ax.NextPlot = 'add';
            % 		H.ax.ALim = inputRange;
            % 		obj(1).hIm.AlphaDataMapping = 'none';
            H.bg = handle(image(zeros([sz 3] ,'uint8'),...
                'Parent', H.ax));
            H.bg.ButtonDownFcn = @(src,evnt)roiClickFcn(obj,src,evnt);
            % 		set(obj,'hBg',hbg);
            
            if isnumeric(overlayInput)
                % IMAGE
                if ismatrix(overlayInput)
                    H.bg.AlphaData = imcomplement(overlayInput);
                    drawnow
                    return
                else
                    framePeriod = .05;%TODO: info structure
                end
                
            else
                % MOVIE
                try
                    ts = cat(1,overlayInput.timestamp);
                    framePeriod = mean(diff(cat(1,ts.seconds)));
                catch me
                    framePeriod = .05;
                end
            end
            timerData.data = overlayInput;
            timerData.hand = H;
            t = timer(...
                'ExecutionMode','fixedRate',...
                'Period',framePeriod,...
                'StartDelay',2,...
                'UserData',timerData,...
                'BusyMode', 'drop',...
                'TimerFcn', @(src,evnt)vidOverlayUpdate(obj(1),src,evnt));
            start(t)
        end
        function setDistinguishableColors(obj)
            N = numel(obj);
            allColors = distinguishable_colors( N , [1 1 1; 0 0 0] );
            for k=1:N
                obj(k).Color = [allColors(k,:) obj(k).transparency];
                obj(k).ColorIndex = k;
            end
        end
        function binVec = hasFrame(obj, qFrameIdx)
            nObj = numel(obj);
            nFrame = numel(qFrameIdx); %TODO: expand for multi frame input
            binVec = false(nObj,nFrame);
            qIdx = qFrameIdx(:)';
            roiFrameIdx = {obj.FrameIdx};
            for k=1:nObj
                rIdx = roiFrameIdx{k};
                if ~isempty(rIdx)
                    binVec(nObj,:) = any(bsxfun(@eq, rIdx(:), qIdx), 1);
                else
                    binVec(nObj,:) = false;
                end
            end
        end
    end
    methods % COMPARISON METHODS
        function doesOverlap = overlaps(r1, r2) % 300ms
            % Returns a logical scalar, vector, or matrix, depending on number of arguments (objects of
            % the ROI class) passed to the method. Calls can take any of the following forms for scalar
            % (1x1) ROI "a" and an array (e.g. 5x1) of ROI objects "b":
            %
            %		>> overlaps(a,b)      --> [5x1]
            %		>> overlaps(b,a)      --> [5x1]
            %		>> overlaps(b)        --> [5x5]
            % Note: the syntax:
            %		>> overlaps(a,b)
            % is equivalent to:
            %		>> a.overlaps(b)
            if nargin < 2
                r2 = r1;
            elseif (numel(r1) == 1) && (numel(r2) == 1)
                doesOverlap = any(any( bsxfun(@eq, r1.PixelIdxList, r2.PixelIdxList')));
                return
            end
            
            r2Area = uint32(cat(1,r2.Area));
            r2IdxIdx = cumsum(r2Area);
            r2PixIdx = uint32(cat(1, r2.PixelIdxList));
            doesOverlap = false(numel(r1), numel(r2));
            r1PixIdxCell = {r1.PixelIdxList};
            if numel(r1) > 32
                parfor k=1:numel(r1)
                    r1PixIdx = uint32(r1PixIdxCell{k});
                    pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
                    if any(pixeq1)
                        pxSum = cumsum(pixeq1);
                        doesOverlap(k,:) = logical(diff([0 ; pxSum(r2IdxIdx)]))';
                    end
                end
            else
                for k=1:numel(r1)
                    r1PixIdx = uint32(r1PixIdxCell{k});
                    pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
                    if any(pixeq1)
                        pxSum = cumsum(pixeq1);
                        doesOverlap(k,:) = logical(diff([0 ; pxSum(r2IdxIdx)]))';
                    end
                end
            end
            sz = size(doesOverlap);
            % Or convert to COLUMN VECTOR for a 1xK Query
            if (sz(1) == 1)
                doesOverlap = doesOverlap(:);
            end
        end
        function idxOverlap = spatialOverlap(r1, r2) % 1200ms
            % Returns all INDICES of OVERLAPPING PIXELS in Vector If multiple ROIs are used as INPUT, a
            % CELL array  is return with the size: [nObj x nRoi]
            if nargin < 2
                r2 = r1;
            end
            r1PixIdx = {r1.PixelIdxList};
            r2PixIdx = {r2.PixelIdxList};
            if numel(r1) > 1 || numel(r2) > 1
                idxOverlap = cell(numel(r1),numel(r2));
                for k2=1:numel(r2)
                    r2pix = r2PixIdx{k2};
                    parfor k1=1:numel(r1)
                        r1pix = r1PixIdx{k1};
                        if ~isempty(r1pix) && ~isempty(r2pix)
                            eqpix = any(bsxfun(@eq, r1pix(:), r2pix(:)'), 1);
                            idxOverlap{k1,k2} = r2pix(eqpix);
                            % 						idxOverlap{k1,k2} = fast_intersect_sorted(r1(k1).PixelIdxList, rpix)';
                        else
                            idxOverlap{k1,k2} = [];
                        end
                    end
                end
                sz = size(idxOverlap);
                % Convert to COLUMN VECTOR for a 1xK Query
                if (sz(1) == 1)
                    idxOverlap = idxOverlap(:);
                end
            else
                eqpix = any(bsxfun(@eq, r1.PixelIdxList(:), r2.PixelIdxList(:)'), 1);
                idxOverlap = r2.PixelIdxList(eqpix);
                % 				idxOverlap = fast_intersect_sorted(r1.PixelIdxList, r2.PixelIdxList);
            end
        end
        function fracOverlap = fractionalOverlap(r1, r2) % 280ms
            % >> ovr = fractionalOverlap(obj, roi) >> ovr = fractionalOverlap(roi) used to be --> [ovr,
            % rvo] = fractionalOverlap(obj, roi) returns a fractional number (or matrix) indicating
            %	0:			'no-overlap' ovr:	'fraction of OBJ that overlaps with ROI relative to total OBJ area
            %	rvo:   'fraction of ROI that overlaps with OBJ relative to total ROI area
            %
            %  --> Previously using FastStacks!
            %TODO: Check a flag to make sure indices are sorted
            if nargin < 2
                r2 = r1;
            end
            r2Area = double(cat(1,r2.Area));
            r2IdxIdx = cumsum(r2Area);
            r2PixIdx = uint32(cat(1, r2.PixelIdxList));
            fracOverlap = zeros(numel(r1), numel(r2));
            r1PixIdxCell = {r1.PixelIdxList};
            if numel(r1) > 32
                parfor k=1:numel(r1)
                    r1PixIdx = uint32(r1PixIdxCell{k});
                    pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
                    if any(pixeq1)
                        pxSum = cumsum(pixeq1);
                        fracOverlap(k,:) = diff([0 ; pxSum(r2IdxIdx)])./ r2Area;
                    end
                end
            else
                for k=1:numel(r1)
                    r1PixIdx = uint32(r1PixIdxCell{k});
                    pixeq1 = any(bsxfun(@eq, r1PixIdx, r2PixIdx'), 1)';
                    if any(pixeq1)
                        pxSum = cumsum(pixeq1);
                        fracOverlap(k,:) = diff([0 ; pxSum(r2IdxIdx)])./ r2Area;
                    end
                end
            end
            sz = size(fracOverlap);
            % Or convert to COLUMN VECTOR for a 1xK Query
            if (sz(1) == 1)
                fracOverlap = fracOverlap(:);
            end
        end
        function isWithin = isInBoundingBox(r1, r2) % 4ms
            % Returns logical vector/array (digraph) that is true at all edges where the centroid of OBJ
            % is within the rectangular box surrounding ROI (input 2, or all others in OBJ array )
            if nargin < 2
                r2 = r1;
            end
            if (numel(r1) > 1) || (numel(r2) > 1)
                r1Cxy = uint16(cat(1,r1.Centroid));
                r2BBox = cat(1,r2.BoundingBox);
                r2Xlim = uint16( [floor(r2BBox(:,1)) , ceil(r2BBox(:,1) + r2BBox(:,3)) ])';
                r2Ylim = uint16( [floor(r2BBox(:,2)) , ceil(r2BBox(:,2) + r2BBox(:,4)) ])';
                isWithin = bsxfun(@and,...
                    bsxfun(@and,...
                    bsxfun(@ge,r1Cxy(:,1),r2Xlim(1,:)),...
                    bsxfun(@le,r1Cxy(:,1),r2Xlim(2,:))) , ...
                    bsxfun(@and,...
                    bsxfun(@ge,r1Cxy(:,2),r2Ylim(1,:)),...
                    bsxfun(@le,r1Cxy(:,2),r2Ylim(2,:))));
            else
                if isempty(r1.BoundingBox) || isempty(r2.BoundingBox)
                    isWithin = false;
                    return
                end
                xc = r1.Centroid(1);
                yc = r1.Centroid(2);
                xbL = r2.BoundingBox(1);
                xbR = xbL + r2.BoundingBox(3);
                ybB = r2.BoundingBox(2);
                ybT = ybB + r2.BoundingBox(4);
                isWithin =  (xc >= xbL) & (xc <= xbR) & (yc >= ybB) & (yc <= ybT);
            end
            sz = size(isWithin);
            % Convert to COLUMN VECTOR for a 1xK Query
            if (sz(1) == 1)
                isWithin = isWithin(:);
            end
        end
        function varargout = centroidSeparation(r1, r2) % 2ms
            % Calculates the EUCLIDEAN DISTANCE between ROIs. Output depends on number of arguments. For
            % one output argument the hypotenuse between centroids is returned, while for two output
            % arguments the y-distance and x-distance are returned in two separate matrices. Usage
            % examples are below: >> csep = centroidSeparation( roi(1:100) )			--> returns [100x100]
            % matrix >> [simmat.cy,simmat.cx] = centroidSeparation(roi(1:100),roi(1:100)) --> 2
            % [100x100]matrices >> csep = centroidSeparation(roi(1), roi(2:101)) --> returns [100x1]
            % vector
            if nargin < 2
                r2 = r1;
            end
            if numel(r1) > 1 || numel(r2) > 1
                oCxy = cat(1,r1.Centroid);
                rCxy = cat(1,r2.Centroid);
                rCxy = rCxy';
                xdist = single(bsxfun(@minus, oCxy(:,1), rCxy(1,:)));
                ydist = single(bsxfun(@minus, oCxy(:,2), rCxy(2,:)));
                if nargout <= 1
                    pixDist = bsxfun(@hypot, xdist, ydist);
                end
            else
                if isempty(r1.Centroid) || isempty(r2.Centroid)
                    varargout{1:nargout} = inf;
                    return
                end
                xdist = single(r1.Centroid(1) - r2.Centroid(1));
                ydist = single(r1.Centroid(2) - r2.Centroid(2));
                if nargout <= 1
                    pixDist = hypot( xdist, ydist);
                end
            end
            if nargout <= 1
                sz = size(pixDist);
                % Convert to COLUMN VECTOR for a 1xK Query
                if (sz(1) == 1)
                    pixDist = pixDist(:);
                end
                varargout{1} = pixDist;
            elseif nargout == 2
                if (size(xdist,1) == 1) || (size(ydist,1) == 1)
                    xdist = xdist(:);
                    ydist = ydist(:);
                end
                varargout{1} = ydist;
                varargout{2} = xdist;
            end
        end
        function varargout = edgeSeparation(r1, r2) % 2ms
            % Calculates the DISTANCE between ROI LIMITS, returning a single matrix 2D or 3D matrix with
            % the last dimension carrying distances ordered TOP,BOTTOM,LEFT,RIGHT. If more than one output
            % argument is given, the edge-Displacement is broken up by edge as demonstrated below.
            %
            % USAGE:
            %		>> limDist = edgeSeparation(obj(1:100))		--> returns [100x100x4] matrix
            % 	>> limDist = edgeSeparation(obj(1),obj(1:100))			-->  [100x4] matrix
            % 	>> [verticalDist, horizontalDist] = edgeSeparation(rp(1),rpRef);
            % 	>> [topDist,botDdist,leftDist,rightDist] = edgeSeparation(rp,rpRef);
            %
            if nargin < 2
                r2 = r1;
            end
            
            % CALCULATE XLIM & YLIM (distance from bottom left corner)
            bb = cat(1,r2.BoundingBox);
            r2Xlim = int16( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]); % [LeftEdge,RightEdge] distance from left side of image
            r2Ylim = int16( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]); % [BottomEdge,TopEdge] distance from bottom of image
            bb = cat(1,r1.BoundingBox);
            r1Xlim = int16( [floor(bb(:,1)) , ceil(bb(:,1)+bb(:,3)) ]);
            r1Ylim = int16( [floor(bb(:,2)) , ceil(bb(:,2)+bb(:,4)) ]);
            
            % FOR LARGE INPUT
            if numel(r1) > 1 || numel(r2) > 1
                % Order in 3rd dimension is Top,Bottom,Left,Right
                r1Lim = cat(3, r1Ylim(:,2), r1Ylim(:,1), r1Xlim(:,1), r1Xlim(:,2));
                r2Lim = cat(3, r2Ylim(:,2), r2Ylim(:,1), r2Xlim(:,1), r2Xlim(:,2));
                limDist = bsxfun(@minus, r1Lim, permute(r2Lim, [2 1 3]));
            else
                bottomYdist = r1Ylim(1) - r2Ylim(1);
                topYdist = r1Ylim(2) - r2Ylim(2);
                leftXdist = r1Xlim(1) - r2Xlim(1);
                rightXdist = r1Xlim(2) - r2Xlim(2);
                limDist = int16(cat(1, topYdist, bottomYdist, leftXdist, rightXdist));
            end
            sz = size(limDist);
            % Convert to COLUMN VECTOR for a 1xK Query
            if (sz(1) == 1) || (sz(2) == 1)
                limDist = reshape(limDist, [], 4);
                n2cOut = 1;
            else
                n2cOut = [1 2];
            end
            
            limDist = int16(limDist);
            
            switch nargout
                case 1
                    varargout{1} = limDist;
                case 2
                    if length(n2cOut) == 1
                        varargout(1:2) = mat2cell(limDist, size(limDist,1), [2 2]);
                    else
                        varargout(1:2) = mat2cell(limDist, size(limDist,1), size(limDist,2), [2 2]);
                    end
                case 4
                    varargout = num2cell(limDist, n2cOut);
                otherwise
                    varargout{1} = limDist;
            end
            
            
        end
        function isSmlr = sufficientlySimilar(obj, roi)
            % Loose predictor of similarity between ROIs. Will return a logical
            % scalar, vector, or matrix depending on the number and dimensions of
            % the input.
            if isempty([obj.MinSufficientOverlap])
                minOverlap = .75;
            else
                minOverlap = obj.MinSufficientOverlap;
            end
            if nargin < 2
                roi = obj;
            end
            nObj = numel(obj);
            nRoi = numel(roi);
            isSmlr = false([nObj nRoi]);
            for kRoi = 1:nRoi
                R2 = roi(kRoi);
                for kObj = kRoi:nObj
                    R1 = obj(kObj);
                    % Check whether there is ANY OVERLAP
                    minProfile = min([R1.BoundingBox(3:4) R2.BoundingBox(3:4)]);
                    if centroidSeparation(R1,R2) < minProfile/2
                        % Check whether overlap is SUBSTANTIAL AND EXCLUSIVE
                        rfo = fractionalOverlap([R1 R2]);
                        if all(rfo > minOverlap)
                            isSmlr(kObj,kRoi) = true;
                        end
                    end
                end
            end
            sz = size(isSmlr);
            % Construct TRUTH-TABLE using symmetry for INTRAGROUP KxK Query
            if (sz(1) > 1) && (sz(2) > 1) && (sz(1) == sz(2))
                isSmlr = isSmlr | isSmlr';
                % Or convert to COLUMN VECTOR for a 1xK Query
            elseif (sz(1) == 1)
                isSmlr = isSmlr(:);
            end
        end
        function ovmap = mapOverlap(obj, varargin) % 50ms
            if nargin > 1
                r1 = obj;
                r2 = varargin{1};
                % CONSTRUCT MAP BETWEEN ALL OVERLAPPING UIDS
                [r1IdxMat, r1UidMat] = r1.createLabelMatrix;
                [r2IdxMat, r2UidMat] = r2.createLabelMatrix;
                pxOverlap = logical(r1IdxMat) & logical(r2IdxMat);
                uid2uidMap = [r1UidMat(pxOverlap) , r2UidMat(pxOverlap)];
                idx2idxMap = [r1IdxMat(pxOverlap) , r2IdxMat(pxOverlap)];
                [uniqueUidPairMap, uIdx, ~] = unique(uid2uidMap, 'rows');
                uniqueIdxPairMap = idx2idxMap(uIdx,:);
                
                % COUNT & SORT BY RELATIVE AREA OF OVERLAP
                pxOverlapCount = sum( all( bsxfun(@eq,...
                    reshape(uid2uidMap, size(uid2uidMap,1), 1, size(uid2uidMap,2)),...
                    shiftdim(uniqueUidPairMap, -1)), 3), 1)';
                uidxOrderedArea = [cat(1,r1(uniqueIdxPairMap(:,1)).Area) ,...
                    cat(1,r2(uniqueIdxPairMap(:,2)).Area)];
                fractionalOverlapArea = bsxfun(@rdivide, pxOverlapCount, uidxOrderedArea);
                [~, fracOvSortIdx] = sort(prod(fractionalOverlapArea,2), 1, 'descend');
                idx = uniqueIdxPairMap(fracOvSortIdx,:);
                
                % ALSO RETURN UNMAPPED REGIONS
                mappedR1 = false(numel(r1),1);
                mappedR2 = false(numel(r2),1);
                mappedR1(idx(:,1)) = true;
                mappedR2(idx(:,2)) = true;
                unMappedRegion = {r1(~mappedR1), r2(~mappedR2)};
                
                % OUTPUT IN STRUCTURE
                ovmap.uid = uniqueUidPairMap(fracOvSortIdx,:);
                ovmap.idx = idx;
                ovmap.area = uidxOrderedArea(fracOvSortIdx,:);
                ovmap.fracovarea = fractionalOverlapArea(fracOvSortIdx,:);
                ovmap.region = [r1(idx(:,1)) , r2(idx(:,2))];
                ovmap.unmapped = unMappedRegion;
                
            else
                
                % CONSTRUCT MAP BETWEEN ALL OVERLAPPING UIDS
                frameIdx = cat(1,obj.FrameIdx);
                frameIdx = frameIdx - min(frameIdx) + 1;
                N = max(frameIdx);
                rcell = cell(1,N);
                for k = 1:N
                    r = obj([frameIdx == k]);
                    rcell{k} = r;
                    [idxMat(:,:,k), uidMat(:,:,k)] = r.createLabelMatrix;
                end
                pxOverlap = all( logical(idxMat), 3);
                numPixOverlap = nnz(pxOverlap);
                uid2uidMap = reshape(uidMat(repmat(pxOverlap, 1,1,N)), numPixOverlap, N);
                idx2idxMap = reshape(idxMat(repmat(pxOverlap, 1,1,N)), numPixOverlap, N);
                [uniqueUidPairMap, uIdx, ~] = unique(uid2uidMap, 'rows');
                uniqueIdxPairMap = idx2idxMap(uIdx,:);
                
                % COUNT & SORT BY RELATIVE AREA OF OVERLAP
                uidxOrderedArea = zeros(size(uniqueIdxPairMap), 'single');
                numMatches = size(uniqueIdxPairMap,1);
                overlapCount = zeros(size(uniqueIdxPairMap), 'uint16');
                for k=1:N
                    r = rcell{k};
                    pxovc = accumarray(idx2idxMap(:,k),1);
                    overlapCount(:,k) = pxovc(uniqueIdxPairMap(:,k));
                    isMapped = false(numel(r),1);
                    isMapped(uniqueIdxPairMap(:,k)) = true;
                    rMapped(1:numMatches,k) = r(uniqueIdxPairMap(:,k));
                    unMappedRegion{k} = r(~isMapped);
                    uidxOrderedArea(:,k) = cat(1, rMapped(:,k).Area);
                end
                pxOverlapCount = min(overlapCount,[],2);
                % 				pxOverlapCount = pxovc(uniqueIdxPairMap(:,k));
                fractionalOverlapArea = bsxfun(@rdivide, pxOverlapCount, uidxOrderedArea);
                [ ~ , fracOvSortIdx] = sort(sum(fractionalOverlapArea,2), 1, 'descend');% SUM RATHER THAN PRODUCT
                idx = uniqueIdxPairMap(fracOvSortIdx,:);
                
                % OUTPUT IN STRUCTURE
                ovmap.uid = uniqueUidPairMap(fracOvSortIdx,:);
                ovmap.idx = idx;
                ovmap.area = uidxOrderedArea(fracOvSortIdx,:);
                ovmap.fracovarea = fractionalOverlapArea(fracOvSortIdx,:);
                ovmap.region = rMapped;
                ovmap.unmapped = unMappedRegion;
                
            end
        end
    end
    methods % OVERLOADED METHODS FOR BUILT-IN FUNCTIONS
        function jd = eq(obj, roi)
            % 		[ofor, rfoo] = fractionalOverlap(obj,roi);
            % 		eqThresh = .95;
            % 		jd =  (ofor >= eqThresh) & (rfoo >= eqThresh);
            if nargin < 2
                roi = obj;
            end
            oIdx = cat(1,obj.UID);
            rIdx = cat(2,roi.UID);
            jd = bsxfun(@eq, oIdx, rIdx);
            sz = size(jd);
            if (sz(1) == 1)
                jd = jd(:);
            end
        end
        function jd = ne(obj, roi)
            jd =  ~eq(obj,roi);
        end
        function jd = lt(obj, roi)
            % a larger roi that entirely encompasses a smaller (sub-)roi is deemed 'greater'
            % ... note: the roi with a fractional overlap closer to one also necessarily smaller and therefore
            % 'less-than' the roi with the smaller fractional overlap
            ofor = fractionalOverlap(obj,roi);
            rfoo = fractionalOverlap(roi,obj);
            jd = ofor > rfoo;
        end
        function jd = le(obj, roi)
            ofor = fractionalOverlap(obj,roi);
            rfoo = fractionalOverlap(roi,obj);
            jd = ofor >= rfoo;
        end
        function jd = gt(obj, roi)
            ofor = fractionalOverlap(obj,roi);
            rfoo = fractionalOverlap(roi,obj);
            jd = ofor < rfoo;
        end
        function jd = ge(obj, roi)
            ofor = fractionalOverlap(obj,roi);
            rfoo = fractionalOverlap(roi,obj);
            jd =  ofor <= rfoo;
        end
    end
    methods % COMBINATION/SUPBORDINATION METHODS
        function superRoi = merge(obj)
            % USAGE:
            % 			>> superRoi(1) = merge( subRoi(1:50) )
            % where superRoi and subRoi are both of the class 'RegionOfInterest'
            % Returns a single ROI comprising the SUBSET of pixels SHARED by SubRegions
            
            obj = obj(isvalid(obj));
            obj = removeEmpty(obj);
            if numel(obj) > 1
                N = numel(obj);
            else
                superRoi = obj;
                return
            end
            subRoi = obj;
            numMerge = mean([subRoi.NumberOfMerges]);
            bwMask = false(size(obj(1).createMask));
            %         wtMask = zeros(size(bwMask), 'uint8');
            
            % GET FRAMEIDX
            allFrames = cat(1, obj.FrameIdx);
            uFrames = unique( allFrames);
            
            % GET PIXEL INDICES AND WEIGH TOGETHER
            allPix = cat(1,obj.PixelIdxList);
            uPix = unique(allPix);
            
            % ASSIGN PIXEL WEIGHTS FROM FREQUENCY
            if any(cellfun(@isempty, {obj.PixelCounts}))
                pixFreq = double(histcounts(allPix,uPix))';
                
            else
                % OR FROM PIXEL COUNTS IF ROI IS PREVIOUSLY MERGED
                pixFreq = zeros(numel(uPix),1);
                subRoiPixIdx = {subRoi.PixelIdxList};
                for k = 1:numel(subRoi)
                    rPixIdx = subRoiPixIdx{k};
                    uBin = any( bsxfun(@eq, uPix(:), rPixIdx(:)'), 1);
                    pixFreq(uBin) = pixFreq(uBin) + subRoi(k).PixelCounts;
                end
            end
            
            freqMax = max(double(pixFreq(:)));
            normPixFreq = pixFreq / freqMax;
            
            % USE REGIONPROPS (BUILTIN FUNCTION) TO GET CONNECTED REGIONS
            keepPix = normPixFreq > .25;
            uPix = uPix(keepPix);
            normPixFreq = normPixFreq(keepPix);
            pixFreq = pixFreq(keepPix);
            bwMask(uPix) = true;
            rpMulti = regionprops(bwMask,...
                'Centroid', 'BoundingBox','Area',...
                'Eccentricity', 'PixelIdxList');
            
            % CREATE NEW REGIONS OF INTEREST
            superRoi = RegionOfInterest(...
                rpMulti,...
                'FrameIdx',uFrames,...
                'isSuperRegion',true,...
                'FrameSize',size(bwMask),...
                'PixelWeights',normPixFreq(:),...
                'PixelCounts',pixFreq(:));
            
            if numel(superRoi) > 1
                [~,idx] = max(cat(1,superRoi.Area));
                superRoi = superRoi(idx);
            elseif numel(superRoi) < 1
                
            end
            % 			delete(subRoi);
            superRoi.NumberOfMerges = numMerge + 1;
            superRoi.isMerged = true;
            updateProperties(superRoi);
            
        end
        function roiGroup = reduceRegions(obj)
            % 		 roiGroup = [];
            if numel(obj) <= 1
                return
            end
            roiSet = obj;
            nFrames = max(cat(1,obj.FrameIdx));
            % 			% PARTITION BY SIZE
            % 			partBySize = partitionBySize(roiSet);
            % 			for kSz = 1:numel(partBySize)
            % 				roiSubSet = partBySize{kSz};
            
            % PARTITION BY LOCATION
            partByLoc = partitionByLocation(roiSet);
            nyLoc = size(partByLoc,1);
            nxLoc = size(partByLoc,2);
            roiCellGroup = cell(nyLoc, nxLoc);
            parfor kxLoc = 1:nxLoc
                for kyLoc = 1:nyLoc
                    localRoi = partByLoc{kyLoc,kxLoc};
                    if isempty(localRoi), continue; end
                    localRoi = localRoi(isvalid(localRoi));
                    
                    % CALL 'FINDGROUPS' SUBFUNCTION TO CLUSTER LOCAL ROIS INTO GROUPS
                    if numel(localRoi) > 1 %max(10,nFrames/1000) % EXPERIMENTAL CHANGE !!! MAY SLOW DOWN!!!!!!!!!!!!!!!!!!!!!!!!!!
                        localGroup  = findGroups(localRoi);
                        roiCellGroup{kyLoc,kxLoc} = localGroup;
                        %                     else
                        
                    end
                end
            end
            
            % MERGE CLUSTERED ROIS INTO SUPER-ROIS
            for kLoc = 1:numel(roiCellGroup)
                if isempty(roiCellGroup(kLoc)), continue; end
                localGroup = roiCellGroup{kLoc};
                localMerge = RegionOfInterest.empty(0,1);
                parfor kGrp = 1:numel(localGroup)
                    localMerge(kGrp,1) = merge(localGroup{kGrp});
                end
                if ~isempty(localMerge)
                    roiCellGroup{kLoc} = removeEmpty(localMerge);
                end
            end
            roiGroup = cat(1, roiCellGroup{:});
            
        end
        function [groupedObj, varargout] = findGroups(obj, varargin)
            % USAGE EXAMPLE:
            %	[localGroup, localOutlier] = findGroups(localRoi);
            groupedObj = {};
            
            if nargin < 2
                groupingMin = obj.GroupingSizeMin;
            else
                groupingMin = varargin{1};
            end
            if nargin < 3
                simLim = obj.GroupingSimilarityMin;
            else
                simLim = varargin{2};
            end
            if numel(obj) <= 1
                return
            end
            
            % GET DESCRIPTIVE INFORMATION ABOUT EACH ROI
            nGroups = 0;
            obj = obj(:);
            nObj = numel(obj);
            fprintf('Finding groups for %i Regions Of Interest\n',nObj);
            if nObj > 20000
                cs1 = obj(1).centroidSeparation(obj(2:end));
                [freq, win] = histcounts(cs1((cs1 >= (mode(round(cs1)))) & (cs1 <= mode(round(cs1(cs1 > mode(round(cs1))))))));
                [~,idx] = min(freq);
                cutoff = win(idx);
                obj1 = obj(cs1 <= cutoff);
                obj2 = obj(cs1 > cutoff);
                n1 = numel(obj1);
                n2 = numel(obj2);
                splitAsymm = abs(n1-n2)./(n1+n2);
                if splitAsymm(1) > .65
                    splitIdx = ceil(nObj/2);
                    obj1 = obj(1:splitIdx-1);
                    obj2 = obj(splitIdx:end);
                end
                fprintf('Splitting  %i ROIs for processing as a group of %i and %i\n', nObj, numel(obj1), numel(obj2))
                groupedObj1 = findGroups(obj1);
                groupedObj2 = findGroups(obj2);
                groupedObj = cat(1,groupedObj1(:), groupedObj2(:));
                return
            end
            
            % GET DISTANCE MATRICES FROM DIFFERENCE OF CENTROIDS AND XY-BOUNDARIES
            [simmat.cy,simmat.cx] = centroidSeparation(obj);
            limsep = edgeSeparation(obj);
            objWidth = cat(1,obj.Width);
            objHeight = cat(1,obj.Height);
            
            % NORMALIZE CENTROID DISTANCE BY HEIGHT AND WIDTH OF EACH REGION
            hMat = 1./sqrt(objHeight * objHeight');
            wMat = 1./sqrt(objWidth * objWidth');
            simmat.cx = simmat.cx .* wMat;
            simmat.cy = simmat.cy .* hMat;
            
            % NORMALIZE LIMIT/BORDER DISTANCE BY HEIGHT AND WIDTH (Dim3:top,bottom,left,right)
            simmat.btop = double(limsep(:,:,1)) .* hMat;
            simmat.bbot = double(limsep(:,:,2)) .* hMat;
            simmat.bleft = double(limsep(:,:,3)) .* wMat;
            simmat.bright = double(limsep(:,:,4)) .* wMat;
            
            
            clearvars hMat wMat limsep
            
            % CONSTRUCT A SIMILARITY MATRIX FROM EACH DISTANCE MATRIX
            sepsigma = 1.5;
            dmatfields = fields(simmat);
            for kfld = 1:numel(dmatfields)
                fn = dmatfields{kfld};
                simmat.(fn) = exp(-((simmat.(fn) - simmat.(fn)').^2)/(2*sepsigma^2));
            end
            similarityMatrix = ...
                simmat.cx .* simmat.cy ...
                .* simmat.btop .* simmat.bbot ...
                .* simmat.bleft .* simmat.bright;%TODO: make sparse?
            
            % CHECK MEMORY
            mem = memory;
            memusedgb = mem.MemUsedMATLAB/2^30;
            if memusedgb > 64
                fprintf('Using %3.4g GB\n', memusedgb)
            end
            
            % CONSTRUCT INDEXING STRUCTURE TO REDUCE RUNTIME COMPLEXITY
            unVisitedBin = true(size(obj));
            groupedBin = false(size(obj));
            groupedIdx = [];
            unGroupedMat = similarityMatrix >= simLim;
            unGroupedBin = any(unGroupedMat,2);
            superLooping = false;
            
            % ITERATIVELY FIND GROUPS WITH REMAINING/UNGROUPED ROIS
            while sum(unGroupedBin) >= groupingMin
                unGroupedIdx = find(unGroupedBin);
                seedIdx = unGroupedIdx(1);
                unVisitedBin(seedIdx) = false;
                ngBin = unGroupedMat(:,seedIdx);
                ngBinMat = bsxfun( @or, ngBin, unGroupedMat(:,ngBin));
                ngBinMat = bsxfun( @and, ngBinMat, unGroupedMat(:,ngBin));
                ngBin = logical(round(sum(ngBinMat,2)));
                ngIdx = find(ngBin);
                unGroupedBin(ngIdx) = false;
                groupedBin(ngIdx) = true;
                groupedIdx = cat(1, groupedIdx(:), ngIdx(:));
                unGroupedMat(ngIdx, ngIdx) = false;
                
                if numel(ngIdx) > groupingMin
                    nGroups = nGroups + 1;
                    newGroup = obj(ngIdx);
                    groupedObj{nGroups,1} = newGroup;
                    superLooping = false;
                else
                    if superLooping
                        break
                    else
                        superLooping = true;
                    end
                end
            end
            if nargout > 1
                unGroupedObj = obj(~groupedBin);
                varargout{1} = unGroupedObj(:);
            end
            
        end
        function [part,varargout] = partitionBySize(obj,overlap)
            % SPLIT DATA INTO BATCHES FOR PARALLEL PROCESSING
            if nargin < 2
                % Overlap between segmentation boundaries, as a fraction of lower bound
                overlap = .15;
            end
            roiArea = cat(1, obj.Area);
            aMin = min(roiArea(:));
            aMax = max(roiArea(:));
            nPartitions = ceil(log2( aMax / aMin ));
            lowerBound = aMin * 2.^[ 0 , 1:nPartitions-1];
            upperBound = aMin * 2.^(1:nPartitions);
            lowerBound = lowerBound - lowerBound*overlap;
            upperBound = upperBound + upperBound*overlap;
            L = bsxfun(@and,...
                bsxfun(@ge, roiArea(:), lowerBound),...
                bsxfun(@le, roiArea(:), upperBound));
            for ksp = 1:nPartitions
                pRoi = obj(L(:,ksp));
                if ~isempty(pRoi)
                    part{ksp,1} = pRoi;
                end
            end
            if nargout>1
                varargout{1} = L;
            end
        end
        function [part,varargout] = partitionByLocation(obj)
            % USE R*-TREE, KD-TREE, OR OTHER SEGEMENTATION ALGORITHM TO PARTITION FRAME
            try
                frameSize = obj(end).FrameSize;
                if any(cellfun(@isempty,{obj.XLim}))
                    obj.updateProperties()
                end
                roiXlim = cat(1,obj.XLim);% could also use obj.Width and obj.Height
                roiYlim = cat(1,obj.YLim);
                roiCentroid = cat(1,obj.Centroid);
                overlap = 3;
                roiExt = [roiYlim(:,2)-roiYlim(:,1), roiXlim(:,2)-roiXlim(:,1)];
                extMax = max(roiExt(:));
                gridSpace = 1.1*extMax;
                nPartitions = floor(frameSize./gridSpace);
                xBound = linspace(0, frameSize(2), nPartitions(2)+1);
                yBound = linspace(0, frameSize(1), nPartitions(1)+1);
                xLowerBound = xBound(1:end-1);
                xUpperBound = xBound(2:end);
                yLowerBound = yBound(1:end-1);
                yUpperBound = yBound(2:end);
                % 		  L.xlim = bsxfun(@and,...
                % 			 bsxfun(@ge, roiXlim(:,2), xLowerBound),...
                % 			 bsxfun(@le, roiXlim(:,1), xUpperBound));
                % 		  L.ylim = bsxfun(@and,...
                % 			 bsxfun(@ge, roiYlim(:,2), yLowerBound),...
                % 			 bsxfun(@le, roiYlim(:,1), yUpperBound));
                L.xlim = bsxfun(@and,...
                    bsxfun(@ge, roiCentroid(:,1), xLowerBound - overlap),...
                    bsxfun(@le, roiCentroid(:,1), xUpperBound + overlap));
                L.ylim = bsxfun(@and,...
                    bsxfun(@ge, roiCentroid(:,2), yLowerBound - overlap),...
                    bsxfun(@le, roiCentroid(:,2), yUpperBound + overlap));
                % inserts dimension to expand logical array to 3 dimensions [ROIxXxY]
                LL.xylim = bsxfun(@and, L.xlim, permute(shiftdim(L.ylim,-1),[2 1 3] ));
                part = cell([nPartitions(2),nPartitions(1)]);
            catch me
                getReport(me)
            end
            for kx = 1:nPartitions(2)
                for ky = 1:nPartitions(1)
                    roiLimIn = LL.xylim(:,kx,ky);
                    if any(roiLimIn)
                        part{ky,kx} = obj(roiLimIn);
                    end
                end
            end
            if nargout>1
                varargout{1} = LL;
            end
        end
        function redObj = reduceSuperRegions(obj, maxCentroidSeparation, maxEdgeSeparation)
            if nargin < 3
                maxEdgeSeparation = [];
                if nargin < 2
                    maxCentroidSeparation = [];
                end
            end
            if isempty(maxCentroidSeparation)
                maxCentroidSeparation = obj.MaxCentroidSeparation;
            end
            if isempty(maxEdgeSeparation)
                maxEdgeSeparation = obj.MaxEdgeSeparation;
            end
            N = numel(obj);
            
            % OLD METHOD
            % 			sepMat = mean(abs(obj.edgeSeparation()),3) + obj.centroidSeparation() ;
            % 			closeMat = sepMat < sepThresh;
            
            % CLUSTER USING CENTROID- AND EDGE-SEPARATION (SEPARATELY)
            cSep = centroidSeparation(obj);
            eSep = mean(abs( edgeSeparation(obj)), 3);
            closeMat = ((cSep <= maxCentroidSeparation) & (eSep <= maxEdgeSeparation)) | ((cSep+eSep) < maxCentroidSeparation*2);
            touched = false(N,1);
            grouped = cell(N,1);
            for k=1:N
                if ~touched(k)
                    closeVec = closeMat(:,k) & ~touched;
                    grouped{k} = obj(closeVec);
                    touched = touched | closeVec;
                end
            end
            grouped = grouped(~cellfun(@isempty, grouped));
            n = cellfun(@numel, grouped);
            redObj = cat(1,grouped{n==1});
            needsMerge = grouped(n>1);
            for k=1:numel(needsMerge)
                needsMerge{k} = merge(needsMerge{k});
            end
            redObj = cat(1, redObj, needsMerge{:});
            
            % CLUSTER USING FRACTIONAL OVERLAP
            Nred = numel(redObj);
            fracOverlapMat = fractionalOverlap(redObj);
            minOverlap = [redObj.MinSufficientOverlap];
            touched = false(Nred,1);
            grouped = cell(Nred,1);
            for k=1:Nred
                ovpThresh = minOverlap(min(k,numel(minOverlap)));
                if ~touched(k)
                    ovp = fracOverlapMat(:,k) >= ovpThresh;
                    ovpVec = ovp & ~touched;
                    grouped{k} = redObj(ovpVec);
                    touched = touched | ovpVec;
                end
            end
            grouped = grouped(~cellfun(@isempty, grouped));
            n = cellfun(@numel, grouped);
            redObj = cat(1,grouped{n==1});
            needsMerge = grouped(n>1);
            for k=1:numel(needsMerge)
                needsMerge{k} = merge(needsMerge{k});
            end
            redObj = cat(1, redObj, needsMerge{:});
            
        end
        function simGroup = mostSimilar(obj)
            isSim = sufficientlySimilar(obj);
            [~,idx] = max(sum(isSim));
            simGroup = obj(isSim(idx,:));
        end
        function uObj = unique(obj)
            uObj = obj;
            k=1;
            while k<numel(uObj)% TODO: Not efficient (now that each has unique ID
                uRem = uObj(k+1:end);
                c = uObj(k) == uRem;
                uRem = uRem(~c);
                uObj = [uObj(1:k) ; uRem(:)];
                k=k+1;
            end
        end
        function obj = removeEmpty(obj)
            obj = obj(isvalid(obj));
            for k=1:numel(obj)
                notEmpty(k) = ~isempty(obj(k).PixelIdxList);
            end
            try
                obj = obj(notEmpty);
            catch me
                return
            end
        end
        function delete(obj)
            try
                if numel(obj) > 1
                    for k=1:numel(obj)
                        delete(obj(k))
                    end
                    % 		  elseif ~isempty(obj.SubRegion)
                    % 			 delete(obj.SubRegion)
                end
            catch
            end
        end
    end
    methods % DATA GENERATION, STORAGE, & RETRIEVAL
        function varargout = makeTraceFromVid(obj, data)
            
            % UPDATE UNIQUE PIXELS
            if any(cellfun(@isempty, {obj.UniquePixels}))
                makeUniquePixels(obj)
            end
            
            haloCompensationDilationFactor = ceil(sqrt(mean([obj.Area])));
            % halved to give additional inner radial pixels of halo (aka donut), doubled to give outer
            nObj = numel(obj);
            sz = size(data);
            nFrames = sz(ndims(data));
            frameSize = sz(1:(ndims(data)-1));
            set(obj, 'FrameSize', frameSize);
            x = zeros([nFrames,1],'double');
            xType = struct(...
                'min', x+1,...
                'max', x+1,...
                'mean', x+1,...
                'median', x+1,...
                'incidenceweighted', x+1,...
                'uniquepixels', x+1,...
                'halo', x+1,...
                'allpixels', repmat(x,1,50));
            set(obj,'Trace',x);
            set(obj,'TraceType', xType);
            % 		xWeighted = zeros([nFrames,nObj],'double');
            % 		xUnique = zeros([nFrames,nObj],'double');
            % 		xNonSurroundCompensated = zeros([nFrames,nObj],'double');
            
            % CONSTRUCT BINARY ARRAYS FOR SURROUND COMPENSATION
            cellMaskAll = obj.createMask;
            cellMaskAllDilated = imdilate(cellMaskAll, strel('disk',round(haloCompensationDilationFactor/2),8));
            firstFrame = data(:,:,1);
            % RESHAPE VIDEO DATA FRAMES TO COLUMNS
            data = reshape(data, [numel(firstFrame), nFrames]);
            for kRoi = 1:nObj
                try
                    pixIdx = obj(kRoi).PixelIdxList(:);
                    pixWt = obj(kRoi).PixelWeights(:);
                    if isempty(pixWt)
                        pixWt = ones(size(pixIdx));
                    end
                    uniquePixIdx = pixIdx(obj(kRoi).UniquePixels);
                    if isempty(uniquePixIdx) %TODO
                        uniquePixIdx = pixIdx;
                    end
                    cellMask = createMask(obj(kRoi));
                    haloMask = ...
                        imdilate(cellMask, strel('disk', round(haloCompensationDilationFactor*2), 8)) ...
                        & ~cellMaskAllDilated;
                    haloPixIdx = find(haloMask(:));
                    if isempty(haloPixIdx)
                        haloPixIdx = find(imdilate(cellMask, strel('disk', round(haloCompensationDilationFactor*2), 8)));
                    end
                    
                    % COMPUTE TRACE IN MULTIPLE WAYS
                    obj(kRoi).TraceType.min = min(data(pixIdx,:),[], 1)' ;
                    obj(kRoi).TraceType.max = max(data(pixIdx,:),[], 1)' ;
                    obj(kRoi).TraceType.mean = mean(data(pixIdx,:), 1)' ; % previous name: 'allPixels'
                    obj(kRoi).TraceType.median = median(data(pixIdx,:), 1)' ;
                    obj(kRoi).TraceType.incidenceweighted = double(data(pixIdx,:)') * (pixWt./sum(pixWt));
                    obj(kRoi).TraceType.uniquepixels = mean(data(uniquePixIdx,:), 1)' ;
                    obj(kRoi).TraceType.halo = mean(data(haloPixIdx, :), 1)';
                    obj(kRoi).HaloPixIdx = haloPixIdx;
                    
                    % ALL PIXELS (not reduced statistic)
                    obj(kRoi).TraceType.allpixels = data(pixIdx,:)';
                    
                    % ASSIGN TRACE FROM DEFAULT TYPE
                    % 					obj(kRoi).Trace = obj(kRoi).TraceType.uniquepixels;
                    obj(kRoi).Trace = obj(kRoi).TraceType.mean;
                catch me
                    getReport(me)
                end
            end
            normalizeTrace2WindowedRange(obj);
            filterTrace(obj);
            reassignIdx(obj);
            if nargout
                varargout{1} = cat(2, obj.Trace);
            end
        end
        function varargout = makeTraceFromVidOld(obj, vid)
            
            % UPDATE UNIQUE PIXELS
            if any(cellfun(@isempty, {obj.UniquePixels}))
                makeUniquePixels(obj)
            end
            
            nObj = numel(obj);
            % GATHER PIXEL WEIGHTS
            % 		if nObj > 1
            % 		  nIdx = cat(1,obj.Area);
            % 		  maxIdx = max(nIdx);
            % 		  idxByColumn = zeros([maxIdx,nObj],'double');
            % 		  for k=1:numel(obj)
            % 			 idxByColumn(1:nIdx(k), k) = obj(k).PixelIdxList(:);
            % 		  end
            % 		  isPixWeighted = ~cellfun(@isempty, {obj.PixelWeights});
            % 		  if any(isPixWeighted)
            % 			 pixWeightByColumn = zeros([maxIdx,nObj],'double');
            % 			 for k=1:numel(obj)
            % 				if isPixWeighted(k)
            % 				  pixWeightByColumn(1:nIdx(k), k) = double(obj(k).PixelWeights(:));
            % 				end
            % 			 end
            % 		  end
            % 		else
            % 		  nIdx = obj.Area;
            % 		end
            % GET RESHAPED VIDEO-ARRAY FROM VID INPUT
            if isstruct(vid)
                nFrames = numel(vid);
                % Preallocate Trace Array
                f = zeros([nFrames,nObj],'double');
                for kRoi = 1:nObj
                    % 			 pixIdx = idxByColumn( 1:nIdx(kRoi), kRoi);
                    % 			 nPix = nIdx(kRoi);
                    pixIdx = obj(kRoi).PixelIdxList(:);
                    pixWt = obj(kRoi).PixelWeights(:);
                    uniquePix = obj(kRoi).UniquePixels;
                    nPix = numel(pixIdx);
                    nUniquePix = sum(double(uniquePix));
                    % APPLY PIXEL WEIGHTS
                    % 			 if isPixWeighted(kRoi)
                    % 				pixWt = pixWeightByColumn( 1:nIdx(kRoi), kRoi);
                    % 				pixWt = pixWt/255;
                    % 				for kFrame = 1:nFrames
                    % 				  f(kFrame,kRoi) = sum( double(vid(kFrame).cdata(pixIdx)) .* pixWt , 1) / nPix;
                    % 				end
                    % 			 else
                    for kFrame = 1:nFrames
                        f(kFrame,kRoi) = sum( double(vid(kFrame).cdata(pixIdx)), 1) / nPix ;
                    end
                    % 			 end
                end
            elseif isnumeric(vid)  % For 3D matrix vid input
                nFrames = size(vid,ndims(vid));
                im = vid(:,:,1);
                f = zeros([nFrames,nObj],'double');
                vid = reshape(vid,[numel(im) nFrames]);
                for kRoi = 1:nObj
                    pixIdx = idxByColumn( 1:nIdx(kRoi), kRoi);
                    % APPLY PIXEL WEIGHTS
                    if isPixWeighted(kRoi)
                        pixWt = pixWeightByColumn( 1:nIdx(kRoi), kRoi);
                        pixWt = pixWt/255;
                        f(:,kRoi) = double(vid(pixIdx,:)') * pixWt ;
                    else
                        f(:,kRoi) = sum( double(vid(pixIdx,:)'), 2)./nIdx(kRoi);
                    end
                end
            end
            % DETREND AND NORMALIZE TRACE TO A BASELINE
            % 		f = detrend(f, 'linear');
            fnan = f;
            fnan( bsxfun(@ge, f, mean(f,1)+std(f,[],1))) = NaN;
            f = bsxfun(@rdivide, bsxfun(@minus, f, nanmean(fnan,1)), nanvar(fnan,1));
            % ASSIGN TRACE TO ROIs
            for kRoi = 1:nObj
                obj(kRoi).Trace = f(:,kRoi);
            end
            if nargout > 0
                varargout{1} = f;
            end
        end
        function varargout = normalizeTrace2WindowedRange(obj)
            X = [obj.Trace];
            fs=20; % TODO
            winsize = 1*fs;
            numwin = floor(size(X,1)/winsize)-1;
            xRange = zeros(numwin,size(X,2));
            xBaseline = zeros(numwin,size(X,2));
            for k=1:numwin
                windex = (winsize*(k-1)+1):(winsize*(k-1)+20);
                xRange(k,:) = range(detrend(X(windex,:)), 1);
                xBaseline(k,:) = mean(X(windex,:));
            end
            X = bsxfun(@rdivide, bsxfun(@minus, X, median(xBaseline,1)) , mean(xRange,1));
            for k=1:numel(obj)
                obj(k).Trace = X(:,k);
            end
            if nargout > 0
                varargout{1} = X;
            end
        end
        function varargout = filterTrace(obj, fcut)
            Fs = 20;
            if nargin < 2
                fcut = 2;
            end
            ws = 2 * fcut/Fs;
            [b,a] = butter(Fs/2, ws, 'low');
            X = single(filtfilt(b, a, double([obj.Trace])));
            for k = 1:numel(obj)
                obj(k).Trace = X(:,k);
            end
            if nargout
                varargout{1} = X;
            end
        end
        function wtMask = weightedMask3D(obj)
            fs = obj(1).FrameSize;
            nObj = numel(obj);
            wtMask = zeros([fs nObj]);
            for kObj = 1:nObj
                wm = zeros(fs);
                wm(obj(kObj).PixelIdxList) = obj(kObj).PixelWeights;
                wtMask(:,:,kObj) = wm;
            end
        end
        function wtMask = weightedMask(obj)
            fs = obj(1).FrameSize;
            nObj = numel(obj);
            wtMask = zeros(fs);
            wm = zeros(fs);
            for kObj = 1:nObj
                idx = obj(kObj).PixelIdxList;
                wm(idx) = obj(kObj).PixelWeights;
                wtMask(idx) = max([wm(idx), wtMask(idx)], [], 2);
            end
        end
        function cIm = centroidImage(obj)
            % TODO: Use Accumarray
            nRois = numel(obj);
            frameSize = obj(1).FrameSize;
            cIm = zeros(frameSize);
            roivec.area = cat(1,obj.Area);
            roivec.centroids = cat(1,obj.Centroid);
            for kRoi = 1:nRois
                roivec.nIdx(kRoi) = numel(obj(kRoi).PixelIdxList);
            end
            idx.roipix = cat(1,obj.PixelIdxList);
            roiFirstIdxIdx = [1 ; cumsum(roivec.area)+1];
            r1 = roiFirstIdxIdx;
            r2 = [ r1(2:end)-1 ; numel(idx.roipix)];
            for kRoi = 1:numel(r1)
                idx.roimap(r1(kRoi):r2(kRoi),1) = kRoi;
            end
            upix = unique(idx.roipix);
            [idx.maxidx, idx.maxoccur] = mode(idx.roipix);
            w = 1/idx.maxoccur;
            for kIdx = 1:numel(upix)
                thisIdx = upix(kIdx);
                %         ovlpRoiIdx = idx.roimap(idx.roipix == thisIdx);
                %         ovlpRoiN = numel(ovlpRoiIdx);
                ovlpRoiN = sum(idx.roipix == thisIdx);
                cIm(thisIdx) = w*ovlpRoiN;
            end
        end
        function mask = createMask(obj)
            % Will return BINARY IMAGE from a single ROI or Array of ROI objects
            pxIdx = cat(1,obj.PixelIdxList);
            if any(cellfun(@isempty,{obj.FrameSize}))
                obj.guessFrameSize();
            end
            mask = false(max(cat(1,obj.FrameSize),[],1));
            mask(pxIdx) = true;
            
        end
        function [labelMatrix, varargout] = createLabelMatrix(obj, imSize) % 3ms
            % Will return INTEGER LABELED IMAGE from a single ROI or Array of ROI objects with labels
            % assigned based on the order in which RegionPropagation objects are passed in (by index). A second
            % output can be specified, providing a second label matrix where the labels assigned are the
            % unique ID number for each respective object passed as input.
            
            % WILL ALLOCATE IMAGE WITH MOST EFFICIENT DATA-TYPE POSSIBLE
            N = numel(obj);
            if N <= intmax('uint8')
                outClass = 'uint8';
            elseif N <= intmax('uint16')
                outClass = 'uint16';
            elseif N <= intmax('uint32')
                outClass = 'uint32';
            else
                outClass = 'double';
            end
            
            % CONSTRUCT INDICES FOR EFFICIENT LABEL ASSIGMENT
            pxIdx = cat(1, obj.PixelIdxList);
            lastIdx = cumsum(round(cat(1, obj.Area)));
            roiIdxPxLabel = zeros(size(pxIdx), outClass);
            roiIdxPxLabel(lastIdx(1:end-1)+1) = 1;
            roiIdxPxLabel = cumsum(roiIdxPxLabel) + 1;
            
            % ASSIGN LABELS IN THE ORDER OBJECTS WERE PASSED TO THE FUNCTION
            if nargin < 2
                if isempty(obj(1).FrameSize)
                    imSize = 2^nextpow2(sqrt(double(max(pxIdx(:)))));
                else
                    imSize = max(cat(1,obj.FrameSize),[],1);
                end
            end
            labelMatrix = zeros(imSize, outClass);
            labelMatrix(pxIdx) = roiIdxPxLabel;
            
            if nargout > 1
                roiCid = cat(1, obj.CID);
                if isempty(roiCid)
                    roiCid = updateCID(obj);
                end
                roiUidPxLabel = roiCid(roiIdxPxLabel);
                uidLabelMatrix = zeros(imSize, 'like', roiCid);
                uidLabelMatrix(pxIdx) = roiUidPxLabel;
                varargout{1} = uidLabelMatrix;
            end
        end
        function varargout = makeSparseMask(obj)
            if any(cellfun(@isempty,{obj.PixelSubScripts}))
                obj = removeEmpty(obj);
            end
            imsize = obj(end).FrameSize;
            npix = cat(1,obj.Area);
            for kObj = 1:numel(obj)
                % PIXEL SUBSCRIPTS
                [isubs, jsubs] = ind2sub(imsize,obj(kObj).PixelIdxList);
                % SPARSE MASK
                obj(kObj).SparseMask = sparse(isubs,jsubs,...
                    true,imsize(1),imsize(2),npix(kObj));
            end
            if nargout
                varargout{1} = cat(3,obj.SparseMask);
            end
        end
        function varargout = makeBoundaryTrace(obj)
            for k = 1:numel(obj)
                try
                    mask = obj(k).createMask;
                    [pRow, pCol] = find(mask, 1, 'first');
                    b = bwtraceboundary(mask, [pRow, pCol], 'N');
                    obj(k).BoundaryTrace = struct(...
                        'x',b(:,2),...
                        'y',b(:,1));
                catch me
                    disp(getReport(me))
                end
            end
            if nargout
                varargout{1} = cat(1, obj.BoundaryTrace);
            end
        end
        function varargout = makeUniquePixels(obj)
            N = numel(obj);
            allPix = {obj.PixelIdxList};
            for k=1:N
                binVec = false(N,1);
                binVec(k) = true;
                thesePix = allPix{k};
                otherPix = cat(1,allPix{~binVec});
                
                uPix = all( bsxfun(@ne, thesePix(:)', otherPix(:)),1)';
                % 				uPix{k} = thesePix(uPix);
                obj(k).UniquePixels = uPix(:); %thesePix(uPix);
                obj(k).UniqueArea = sum(double(uPix));
            end
            if nargout
                varargout{1} = {obj.UniquePixels};
            end
        end
        function reassignIdx(obj,varargin)
            N = numel(obj);
            if nargin > 1
                newIdx = varargin{1};
                if numel(newIdx) == 1
                    set(obj,'UID', newIdx);
                    return
                elseif numel(newIdx) == N
                    for k=1:N
                        obj(k).UID = newIdx(k);
                    end
                    return
                end
            end
            newIdx = 1:N;
            for k=1:N
                obj(k).UID = newIdx(k);
            end
        end
        function fillPropsFromStruct(obj, structSpec)
            fn = fields(structSpec);
            for kf = 1:numel(fn)
                if isprop(obj, fn{kf})
                    set(obj, fn{kf}, structSpec.(fn{kf}));
                end
            end
        end
    end
    
    methods % PRIVATE MANAGEMENT FUNCTIONS
        function varargout = guessFrameSize(obj)
            global FRAMESIZE
            if ~isempty(FRAMESIZE)
                imSize = FRAMESIZE;
            else
                if ~isempty(obj(1).BoundingBox)
                    bb = cat(1,obj.BoundingBox);
                    extentFromZeroColMax = max(bb(:,1) + bb(:,3), [], 1);
                    extentFromZeroRowMax = max(bb(:,2) + bb(:,4), [], 1);
                    maxExtentFromZero = [extentFromZeroRowMax  , extentFromZeroColMax];
                    imSize = 2.^nextpow2(double(maxExtentFromZero));
                elseif ~isempty(obj(1).Centroid)
                    imSize = 2.^nextpow2(double(max(cat(1,obj.Centroid))));
                else
                    pxIdx = cat(1,obj.PixelIdxList);
                    imSize = max(imSize,  2.^nextpow2(sqrt(double(max(pxIdx(:))))));
                    imSize = [imSize imSize];
                end
            end
            set(obj, 'FrameSize', imSize);
            FRAMESIZE = imSize;
            if nargout
                varargout{1} = imSize;
            end
        end
        function varargout = updateCID(obj)
            cxy = cat(1,obj.Centroid);
            cRowIdx = round(cxy(:,2));
            cColIdx = round(cxy(:,1));
            cPack = bitor(uint32(cRowIdx(:)) , bitshift(uint32(cColIdx(:)), 16));
            %TODO
            
            roiCid = cPack;
            for k=1:numel(obj)
                obj(k).CID = roiCid(k);
            end
            
            if nargout
                varargout{1} = roiCid;
            end
            
        end
        function h = createShowFigure(obj)
            global H
            cdata = zeros([obj(1).FrameSize 3], 'double');
            pos = [0 0 obj(1).FrameSize];
            H.im = handle(imshow(cdata));
            H.ax = handle(gca);
            H.fig = handle(gcf);
            assignin('base','h',H);
            % SAVE ACCESS TO GRAPHICS HANDLES
            % 		set(obj,'hIm', h.im);
            % 		set(obj, 'hAx', h.ax);
            % 		set(obj, 'hFig',  h.fig);
            
            % FIGURE PROPERTIES
            set(H.fig,...
                'Color',[.2 .2 .2],...
                'NextPlot','add',...
                'Units','normalized',...
                'Color',[.25 .25 .25],...
                'MenuBar','figure',...
                'Name','Region Of Interest',...
                'NumberTitle','off',...
                'HandleVisibility', 'callback',...
                'Clipping','off')
            % AXES PROPERTIES
            if isprop(H.ax, 'SortMethod')
                set(H.ax,...
                    'xlimmode','manual',...
                    'ylimmode','manual',...
                    'zlimmode','manual',...
                    'climmode','manual',...
                    'alimmode','manual',...
                    'GridColor',[0 0 0],...
                    'GridLineStyle','none',...
                    'MinorGridColor',[0 0 0],...
                    'TickLabelInterpreter','none',...
                    'XGrid','off',...
                    'YGrid','off',...
                    'Visible','off',...
                    'Layer','top',...
                    'Clipping','off',...
                    'NextPlot','replacechildren',...
                    'TickDir','out',...
                    'YDir','reverse',...
                    'Units','normalized',...
                    'DataAspectRatio',[1 1 1]);
                H.ax.SortMethod = 'childorder';
            else
                set(H.ax,...
                    'xlimmode','manual',...
                    'ylimmode','manual',...
                    'zlimmode','manual',...
                    'climmode','manual',...
                    'alimmode','manual',...
                    'XGrid','off',...
                    'YGrid','off',...
                    'Visible','off',...
                    'Clipping','off',...
                    'YDir','reverse',...
                    'Units','normalized',...
                    'DataAspectRatio',[1 1 1]);
                H.ax.DrawMode = 'fast';
            end
            H.ax.Units = 'normalized';
            H.ax.Position = [0 0 1 1];
            
            % IMAGE PROPERTIES
            H.im.ButtonDownFcn = @(src,evnt)roiClickFcn(obj,src,evnt);
            h = H;
            
            
            % H.ax.Position([4 3]) = size(mdata);
        end
        function roiClickFcn(obj,src,evnt)
            persistent hAx
            persistent hFig
            persistent roiAx
            persistent hTx
            persistent hLine
            persistent roiShowingTrace
            persistent numCurrentRois
            if isempty(numCurrentRois)
                numCurrentRois = 0;
            end
            if numel(obj(1).Trace) < 1
                return
            end
            fps = 20; %TODO, use time vector
            sz = get(0,'ScreenSize');
            hp = .35;
            vp = .5625;
            % 		vp = sz(3)/sz(4);
            % 		textOffset = [-35 25]; % [dx dy]
            % RETRIEVE CLICK LOCATION
            cp = fliplr(evnt.IntersectionPoint(1:2));
            clickPoint = cat(3, ...
                [floor(cp(1)), floor(cp(2))],...
                [floor(cp(1)), ceil(cp(2))],...
                [ceil(cp(1)), floor(cp(2))],...
                [ceil(cp(1)), ceil(cp(2))]);
            if isempty(hFig) || ~isvalid(hFig)
                hFig = src.Parent.Parent;
                roiAx = src.Parent;
                % 		  roiAx = hFig.Children;
                if sz(4) > sz(3) % (vertical)
                    roiAx.Position = [0 0 1 vp];
                else				% (horizontal)
                    roiAx.Position = [0 0 hp 1];
                end
            end
            if isempty(hAx) || ~isvalid(hAx)
                if sz(4) > sz(3) % (vertical)
                    p = vp+.005;
                    hAx = handle(axes('Position',[.01, p, .98, .995-p],'Parent',hFig));
                else				% (horizontal)
                    p = hp;
                    hAx = handle(axes('Position',[p, .01, .99-p, .98],'Parent',hFig));
                end
            end
            if isempty(roiShowingTrace)
                roiShowingTrace = false(numel(obj),1);
            end
            switch evnt.Button
                case 1 % LEFT-BUTTON: PLOT SINGLE TRACE
                    numCurrentRois = 0;
                    if ~isempty(hLine)
                        try
                            delete(hLine)
                            hLine = gobjects(0);
                        catch me
                            hLine = gobjects(0);
                        end
                    end
                    for k = 1:numel(obj)
                        subs = obj(k).PixelSubScripts;
                        if isempty(subs)
                            [rowsub,colsub] = ind2sub(obj(k).FrameSize, obj(k).PixelIdxList);
                            subs = [rowsub , colsub];
                            obj(k).PixelSubScripts = subs;
                        end
                        if any(bsxfun(@eq,subs, clickPoint))
                            % New Plot
                            %                             if ~isempty(hLine)
                            %                                 try
                            %                                     delete(hLine)
                            %                                     hLine = gobjects(0);
                            %                                 catch me
                            %                                     hLine = gobjects(0);
                            %                                 end
                            %                             end
                            numCurrentRois = numCurrentRois + 1;
                            plotTrace(obj(k).Trace, obj(k).Color)
							add2selected(obj(k));
                            % 							hLine = handle(line((1:numel(obj(k).Trace))./fps, obj(k).Trace,...
                            % 								'Color',obj(k).Color, 'Parent',hAx,'LineWidth',1));
                            % 				  set(hAx, 'NextPlot','replace')
                            set(hFig, 'HandleVisibility', 'callback')
                            % 				  plot((1:numel(obj(k).Trace))./fps, obj(k).Trace,...
                            % 					 'Color',obj(k).Color, 'Parent',hAx);
                            % New Text
                            % 				  if ~all(cellfun('isempty',{hTx}))
                            % 				  if any(cellfun('isempty',{hTx}))
                            % 				  delete(hTx(~cellfun('isvalid',{hTx})))
                            try
                                delete(hTx)
                                hTx = [];
                            catch me
                                delete(findobj(roiAx, 'type', 'text'))
                                hTx = [];
                            end
                            hTx = handle(text(...
                                'String', sprintf('%i',obj(k).UID),...
                                'FontWeight','bold',...
                                'BackgroundColor',[.1 .1 .1 .3],...
                                'Margin',1,...
                                'Position', round(obj(k).BoundingBox(1:2)) - [0 5],...
                                'Parent', src.Parent,...
                                'Color',obj(k).Color	));%round(obj(k).Centroid+textOffset) -> previous position
                            roiShowingTrace(k) = true;
                            if rand > (k/numel(obj)), break, end
                        end
                    end
                case 2 % MIDDLE-BUTTON: RESET
                    % Remove Plot
                    if ~isempty(hAx) && isvalid(hAx)
                        cla(hAx);
                    end
                    if ~isempty(hLine)
                        try
                            delete(hLine)
                            hLine = gobjects(0);
                        catch me
                            hLine = gobjects(0);
                        end
                    end
                    %                     hLine = gobjects(0);
                    numCurrentRois = 0;
					roiAx.UserData.selected = [];
                    % Remove Text
                    try
                        delete(hTx)
                        hTx = [];
                    catch me
                        delete(findobj(roiAx, 'type', 'text'))
                        hTx = [];
                    end
                    roiShowingTrace = false(numel(obj),1);
                case 3 % RIGHT-BUTTON: PLOT MULTIPLE TRACES
                    for k = 1:numel(obj)
                        if any(bsxfun(@eq,obj(k).PixelSubScripts, clickPoint))
                            % Add Plot
                            set(hAx, 'NextPlot','add')
                            %                             numCurrentLines = numel(hLine);
                            %                             if numCurrentLines >= 1
                            numCurrentRois = numCurrentRois + 1;                            
                            plotTrace(obj(k).Trace, obj(k).Color);
							add2selected(obj(k));
                            % 							hLine(numel(hLine)+1) = handle(line((1:numel(obj(k).Trace))./fps, trace,...
                            % 								'Color',obj(k).Color, 'Parent',hAx,'LineWidth',1));
                            
                            % Add Text
                            hTx(numel(hTx)+1) = handle(text(...
                                'String', sprintf('%i',obj(k).UID),...
                                'FontWeight','bold',...
                                'Color',obj(k).Color,...
                                'BackgroundColor',[.1 .1 .1 .3],...
                                'Margin',1,...
                                'Position', round(obj(k).BoundingBox(1:2)) - [0 5],...
                                'Parent', src.Parent));
                            roiShowingTrace(k) = true;
                        end
                    end
                    % 			 legend(hAx,cellstr(sprintf('#%i\n',obj(roiShowingTrace).UID)));
            end
            hAx.YColor = [1 1 1];
            hAx.YTick = [0];
            hAx.YTickLabel = {};
            hAx.XColor = [1 1 1];
            hAx.XLim = [1 size(obj(1).Trace,1)]./fps;
            if ~isempty(hLine)
                hAx.YLim = [min(min([hLine.YData])), max(max([hLine.YData]))];
            end
            hAx.Box = 'off';
            hAx.Color = [hAx.Parent.Color .1];
            
            function plotTrace(X,C)   
                X = single(X);
                if numCurrentRois > 1
                    lastLine = hLine(end);                    
                    traceOffset = mean(lastLine.YData) + .6 * range(lastLine.YData);
                    X = X + traceOffset;                
                end
                [numTimePoints, numPixels] = size(X);                
                t = (1:numTimePoints)./fps;%fps is assuming 20 fps
                width = max( .25, 1/numPixels);
                if numel(C)>3
                    C(4) = max( .15, C(4)/numPixels);
                end
                hNewLine = gobjects(numPixels,1);
                for kPixel = 1:numPixels
                    hNewLine(kPixel) = handle(...
                        line(...
                        'XData', t,...
                        'YData', X(:,kPixel),...
                        'Color',C,...
                        'Parent',hAx,...
                        'LineWidth',width));
                end
                hLine = cat(1, hLine, hNewLine);
			end
			function add2selected(sel)
				if isempty(roiAx.UserData)
					roiAx.UserData.selected = sel;
				else
					roiAx.UserData.selected = cat(1,roiAx.UserData.selected,sel);
				end
			end
        end
        function vidOverlayUpdate(~,src,~)
            try
                drawnow
                k = get(src,'TasksExecuted')+1;
                udata = src.UserData;
                overlayInput = udata.data;
                h = udata.hand;
                if isnumeric(overlayInput)
                    N = size(overlayInput, ndims(overlayInput));
                else
                    N = numel(overlayInput);
                end
                if k > N		% Finished
                    stop(src);
                    delete(src);
                else
                    if isnumeric(overlayInput)
                        h.bg.AlphaData = imcomplement(overlayInput(:,:,k));
                    else
                        h.bg.AlphaData = imcomplement(overlayInput(k).cdata);
                    end
                    % 			 obj(1).hIm.AlphaData = vid(k).cdata;
                    % 			 hText.String = sprintf('Frame %i/%i',k,N);
                    % 					drawnow('expose')
                end
            catch me
                fprintf('Video CLOSED\n')
                stop(src)
                return
            end  % localTimer
        end
    end
    
    
    
    
end


















