function newGroup = roiSecondaryReduce(roiGroup)




% newGroup = roiGroup;
oldGroup = roiGroup;
rgw = cat(1,roiGroup.Width);
rgcs = centroidSeparation(roiGroup);
rgov = overlaps(roiGroup);
% rgov(tril(rgov) & triu(rgov)) = false;
N = numel(oldGroup);
k = N-1;
newGroup = roiGroup(end);
while k > 0
  ov = oldGroup(k).fractionalOverlap(newGroup);
  if any(ov > .01)
	 ovidx = find(ov > .01);
  for kovx = 1:numel(ovidx)
	 ovx = ovidx(kovx);
	 if ov(ovx) >.99 && ov(ovx) < 1.01
		newGroup(ovx) = merge(cat(1,oldGroup(k),newGroup(ovx)));
		oldGroup(k) = newGroup(ovx);
		k=k-1;
		continue
	 else
		if ov(ovx) <= .99
		  newGroup(ovx).InnerOverlap = cat(1, newGroup(ovx).InnerOverlap, oldGroup(k));
		  oldGroup(k).OuterOverlap = cat(1, oldGroup(k).OuterOverlap, newGroup(ovx));
		elseif ov(ovx) >= 1.01
		  oldGroup(k).InnerOverlap = cat(1, oldGroup(k).InnerOverlap, newGroup(ovx));
		  newGroup(ovx).OuterOverlap = cat(1, newGroup(ovx).OuterOverlap, oldGroup(k));
		end
	 end
  end
  end
  newGroup = cat(1, oldGroup(k), newGroup(:));
  k = k - 1;
  
end


%   
%   ovbin = rgov(:,k); 
%   if any(ovbin)
% 	 ovidx = find(ovbin);
% 	 rgfo = fractionalOverlap(roiGroup(ovbin));	 
% 	 rgfo(triu(rgfo) & tril(rgfo)) = 0;
% 	 rgso = rgfo > .9;
% 		if any(rgso)
% 		  for kcol = 1:size(rgso,2)
% 			 rgeq =  roiGroup(ovidx(rgfo(:,kcol) == 1));
% 			 newGroupBin = true(size(newGroup));
% 			 newGroupBin(ovidx(rgfo(:,kcol) == 1)) = false;
% 			 newGroup = newGroup(newGroupBin);
% 		  keyboard
% 		  end
% 		end
%   end
% end