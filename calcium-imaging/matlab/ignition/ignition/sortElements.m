function this = sortElements(this)
  % sort dataset elements
  this.Elements = loc_sortElements(this.Elements);
end  


%% -----------------------------------------------------------------------
% Sort dataset elements
function elements = loc_sortElements(elements)
    % Given two elements in the dataset, determine whether or not the first
    % is less than or equal to the second.  See:
    %   src/sl_logging/core_logging/DatasetElement.cpp and
    %   src/sl_logging/export/sl_logging/FullBlkPathToTopMdl.cpp
    % for this order
    function result = loc_FirstLessThanOrEqualToSecond(element1, element2)
        % 1) Sort by block path
        blockPath1 = element1.BlockPath;
        blockPath2 = element2.BlockPath;
        
        % 1a) Shorter block paths (by getLength) come first
        if(blockPath1.getLength() < blockPath2.getLength())
            result = true;
            return;
        elseif(blockPath1.getLength() > blockPath2.getLength())
            result = false;
            return;
        end
        
        
        % 1b) If they are the same length, sort alphabetically, element
        %     by element
        for i = 1:blockPath1.getLength()
            pathPart1 = blockPath1.getBlock(i);
            pathPart2 = blockPath2.getBlock(i);
            if(isequal(pathPart1, pathPart2))
                continue;
            else
                temp = {pathPart1, pathPart2};
                temp = sort(temp);
                if(isequal(temp{1}, pathPart1))
                    result = true;
                else
                    result = false;
                end
                return;
            end
        end
        
        % 2) Next, sort by CLASS NAME
        class1 = class(element1);
        class2 = class(element2);
        if(~isequal(class1, class2))
            temp   = {class1, class2};
            temp   = sort(temp);
            if(isequal(temp{1}, class1))
                result = true;
                return;
            else
                result = false;
                return;
            end
        end
        
        % 3) Next, sort by ELEMENT NAME
        elementName1 = element1.Name;
        elementName2 = element2.Name;
        if(~isequal(elementName1, elementName2))
            temp = {elementName1, elementName2};
            temp = sort(temp);
            if(isequal(temp{1}, elementName1))
                result = true;
                return;
            else
                result = false;
                return;
            end
        end
        
        % 4) Finally sort by port index
        port1 = element1.PortIndex;
        port2 = element2.PortIndex;
        result = (port1 <= port2);
    end
    
    
    % Swap the elements and index a and b in the given array
    function swapElements = loc_swapElements(swapElements, a, b)
        temp            = swapElements{a};
        swapElements{a} = swapElements{b};
        swapElements{b} = temp;
    end
    
    
    % Run quicksort partition on the elements from index left to right
    % (inclusive) of the given array.  When this is done, return the pivot
    % index.  All elements to the left of the pivot index will have a
    % value less than or equal to the element at the pivot index.  All
    % elements to the right of the pivot index will have a value greater
    % than or equal to the pivot index.
    function [partitionElements, storeIndex] = loc_quicksortPartition(partitionElements, left, right)
        pivotIndex = randi([left right]);
        pivotValue = partitionElements{pivotIndex};
        
        % Swap pivotIndex and right to move pivot to end
        partitionElements = loc_swapElements(partitionElements, pivotIndex, right);
        
        storeIndex = left;
        for i = left:(right - 1)
            if(loc_FirstLessThanOrEqualToSecond(partitionElements{i}, pivotValue))
                partitionElements = loc_swapElements(partitionElements, i, storeIndex);
                storeIndex = storeIndex + 1;
            end
        end
        
        % Put pivot in the correct place
        partitionElements = loc_swapElements(partitionElements, storeIndex, right);
    end
    
    
    % Run quicksort on the elements of the given array from left to right
    % inclusive.  When this finishes, the elements from index left to index
    % right will be in their final sorted positions.
    function [sortedElements] = loc_quicksort(sortedElements, left, right)
        if(right > left)
            [sortedElements, pivotIndex] = loc_quicksortPartition(sortedElements, left, right);
            sortedElements = loc_quicksort(sortedElements, left, pivotIndex - 1);
            sortedElements = loc_quicksort(sortedElements, pivotIndex+1, right);
        end
    end
    
    % Call quicksort on the entire array
    elements = loc_quicksort(elements, 1, length(elements));
end
