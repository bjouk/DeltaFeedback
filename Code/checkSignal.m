function goodSignal=checkSignal(signal,pointStart,pointEnd,threshold)
if sum(signal(pointStart:pointEnd-1)<threshold)>0 | length(signal(pointStart:pointEnd-1))==0
    goodSignal= false;
else
    goodSignal= true;
end
end