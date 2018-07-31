function [newdata_sound,newdata_deltaStart,newdata_deltaEnd]=deltaDetection(arduino,newdata_sound,newdata_deltaStart,newdata_deltaEnd,obj,newdata_math,filter_activated)
if(obj.stimulateAtRandom & obj.detec_status==1) %stimulate at random
                p=0.0001;
                if (obj.counter_detection>obj.countermax_detection)
                    if strcmp(arduino.Status,'open')
                        fwrite(arduino,00); %% Indicate stimulation
                    end
                    if (obj.wait_status==1)&&(obj.fired==0)
                        if(rand()>(1-p) & obj.counter>obj.countermax) %% launch sound if refractory time is over
                            if strcmp(arduino.Status,'open')
                                fwrite(arduino,obj.sound_mode*10+obj.sound_tone);%the mode and the sound are sent to the arduino as an integer AB => A is the mode and B is the sound type
                            end
                            newdata_sound=3*ones(1,obj.ptperdb); %% indicate sound stim
                            obj.fired=1;
                            obj.counter=0;
                            
                            obj.detected=1;
                            obj.counter_detection=0;
                        end
                    end
                end
            end
            
            if (obj.detec_status==1) %If detectioon is triggered
                obj.counter=obj.counter+1;  %in initialization it was 0
                obj.counter_detection=obj.counter_detection+1;
                % the refractory time of the detection
                
                if (obj.Math_filtered>=obj.detec_seuil*1e-3 & filter_activated==1) | (newdata_math(end)>=obj.detec_seuil*1e-3 & filter_activated==0) %Filtered or unfiltered signal above threshold
                    if  obj.DeltaPoints_counter==0
                        obj.timerDeltaStart=tic(); %Start time of the delta detection
                        obj.timeStartDelta=double(obj.Time(end))/20000; %Start timestamp of the delta detection
                        newdata_deltaStart=3*ones(1,obj.ptperdb); %For snapshot display
                        obj.saveIndexStartDelta=obj.SaveIndex;
                    end
                    obj.DeltaPoints_counter = obj.DeltaPoints_counter + 1; %increment counter
                    
                elseif (toc(obj.timerDeltaStart)> obj.minDuration && toc(obj.timerDeltaStart) <obj.maxDuration) && ((double(obj.Time(end))/20000-obj.timeStartDelta)>obj.minDuration && (double(obj.Time(end))/20000-obj.timeStartDelta)<obj.maxDuration)
                    %% signal is now below the threshold => We check the duration
                    if (checkSignal(obj.Math_filtered_display,obj.saveIndexStartDelta,obj.SaveIndex,obj.detec_seuil) & filter_activated==1) |(checkSignal(obj.Math,obj.saveIndexStartDelta,obj.SaveIndex,obj.detec_seuil) & filter_activated==0)
                        if (obj.counter>obj.countermax) && (obj.wait_status==1)&&(obj.fired==0)
                            % Delta is detected after refractory time
                            disp('good delta wave fired (50ms < duration < 150ms)');
                            obj.detected=1;
                            obj.counter=0;
                            obj.counter_detection=0;
                            obj.DeltaPoints_counter = 0;
                            if (~obj.stimulateDuringNREM & ~obj.stimulateDuringREM & ~obj.stimulateDuringWake) | (obj.SleepState==1 & obj.stimulateDuringNREM) | (obj.SleepState==2 & obj.stimulateDuringREM) | (obj.SleepState==3 & obj.stimulateDuringWake )
                                if strcmp(arduino.Status,'open')
                                    fwrite(arduino,obj.sound_mode*10+obj.sound_tone); %If we are in the right sleep state=>trigger
                                end
                                newdata_sound=3*ones(1,obj.ptperdb);%show sound stimulation in interface
                            else
                                if strcmp(arduino.Status,'open')
                                    fwrite(arduino,00); %Else => sham
                                end
                            end
                            
                            newdata_deltaEnd=3*ones(1,obj.ptperdb);
                            obj.fired=1;
                            toc(obj.timerDeltaStart)
                            obj.saveIndexEndDelta=obj.SaveIndex;
                        elseif (obj.counter_detection>obj.countermax_detection) && (obj.wait_status==1) && (obj.detected==0)
                            %Delta is detected inside refractory time
                            disp('good delta wave (50ms < duration < 150ms)');
                            obj.detected=1;
                            obj.counter_detection=0;
                            obj.DeltaPoints_counter = 0;
                            toc(obj.timerDeltaStart)
                            if strcmp(arduino.Status,'open')
                                fwrite(arduino,00); %Sham => no sound emitted
                            end
                            newdata_deltaEnd=3*ones(1,obj.ptperdb);
                            
                        end
                    end
                else
                    obj.DeltaPoints_counter = 0; %reset the counter if detection is over
                end
            end
end