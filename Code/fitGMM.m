function fitGMM(allresult,obj)
allresult=allresult(allresult(:,9)>0,:);
obj.GMModel=fitgmdist([allresult(:,3),allresult(:,6)],3,'Start',allresult(:,9));
end