function allresultsUpdated = recomputeHypnogram(allresults,gammaThreshold,ratioThreshold)
% Recompute the hypnogram according to new ratios
allresultsUpdated=allresults;
allresultsUpdated(find(allresults(:,3)>gammaThreshold),8)=3;
allresultsUpdated(find(allresults(:,3)<gammaThreshold & allresults(:,6)>ratioThreshold),8)=2;
allresultsUpdated(find(allresults(:,3)<gammaThreshold & allresults(:,6)<ratioThreshold),8)=1;
end

