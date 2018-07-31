function sleepScoring(obj)
BullFiltered = filtfilt (obj.bullFilt,obj.BullData); %filter the data between fmin and fmax
BullEnv = abs(hilbert(BullFiltered)); % hilbert transfer
obj.result(1) = mean (BullEnv);

ThetaFiltered = filtfilt (obj.ThetaFilt,obj.ThetaData); %filter the data between fmin and fmax
ThetaEnv = abs( hilbert(ThetaFiltered)); % hilbert transfer
obj.result(2) = mean(ThetaEnv);

DeltaFiltered = filtfilt (obj.DeltaFilt,obj.DeltaData); %filter the data between fmin and fmax
DeltaEnv = abs( hilbert(DeltaFiltered)); % hilbert transform
DeltaEnv(DeltaEnv<0.01)=0.01; %To avoid strange values
obj.result(3)=mean(DeltaEnv);
obj.ratioData = ThetaEnv./DeltaEnv;
obj.result(4)= mean(obj.ratioData);

DeltaPFCFiltered = filtfilt (obj.DeltaFilt,obj.DeltaPFCData); %filter the data between fmin and fmax
DeltaPFCEnv = abs( hilbert(DeltaPFCFiltered)); % hilbert transform
obj.result(5)=mean(DeltaPFCEnv);
%% Sleep scoring algorithm
if(obj.threshold_status == 1)
    if(obj.result(1)>10^(obj.gamma_threshold))
        obj.SleepState=3; %Wake
        obj.timerNREM=0;
        obj.timerREM=0;
        obj.timerWake=obj.timerWake+1;
    else
        obj.timerWake=0;
        if(obj.result(4)>10^(obj.ratio_threshold))
            obj.SleepState=2; %REM
            obj.timerNREM=0;
            obj.timerREM=obj.timerREM+1;
        else
            obj.SleepState=1; %NREM
            obj.timerNREM=obj.timerNREM+1;
            obj.timerREM=0;
        end
    end
end
%% If GMM is set
if isprop(obj.GMModel,'NumVariables')
    prob=posterior(obj.GMModel,[obj.result(1) obj.result(4)]);
    obj.probNREM=prob(1);
    obj.probREM=prob(2);
    obj.probWake=prob(3);
end
    
end