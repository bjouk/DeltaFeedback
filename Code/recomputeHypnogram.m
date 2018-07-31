function allresultsUpdated = recomputeHypnogram(allresults,gammaThreshold,ratioThreshold)
% Recompute the hypnogram according to new ratios
allresultsUpdated=allresults;
allresultsUpdated(find(allresults(:,3)>gammaThreshold),9)=3;
allresultsUpdated(find(allresults(:,3)<gammaThreshold & allresults(:,6)>ratioThreshold),9)=2;
allresultsUpdated(find(allresults(:,3)<gammaThreshold & allresults(:,6)<ratioThreshold),9)=1;
end

