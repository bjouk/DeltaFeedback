function varargout = read_continuously(varargin)
% READ_CONTINUOUSLY MATLAB code for read_continuously.fig
%      Example of reading, plotting, and (optionally) saving, using GUIDE.      
%
%      READ_CONTINUOUSLY, by itself, creates a new READ_CONTINUOUSLY or raises the existing
%      singleton*.
%

%      H = READ_CONTINUOUSLY returns the handle to a new READ_CONTINUOUSLY or the handle to
%      the existing singleton*.


%
%      READ_CONTINUOUSLY('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in READ_CONTINUOUSLY.M with the given input arguments.
%
%      READ_CONTINUOUSLY('Property','Value',...) creates a new READ_CONTINUOUSLY or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before read_continuously_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application


%      stop.  All inputs are passed to read_continuously_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
%      See comments in the script for more information.
%
% See also: GUIDE, GUIDATA, GUIHANDLES

%--------------------------------------------------------------------
% Overview: we store several different data items in the handles variable,
% including a board object that handles communication to the board.
%
% When you hit 'Run', we start a timer, whose callback reads data from
% board and plots it.  Note that this strategy runs into problems if you
% have 256 channels, save, and run at 30 kHz.  This example is not
% optimized for that high a throughput.  See read_optimized for a
% non-GUIDE, optimized example.  We have successfully run the current
% script with:
%    * 256 channels at 20 kHz while saving
%    * 192 channels at 30 kHz while saving
%    * 256 channels at 30 kHz, not saving
%
% See individual callbacks for more information.


% Edit the above text to modify the response to help read_continuously

% Last Modified by GUIDE v2.5 31-Jul-2018 10:58:57

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @read_continuously_OpeningFcn, ...
                   'gui_OutputFcn',  @read_continuously_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT

%--------------------------------------------------------------------
% --- Executes just before read_continuously is made visible.
function read_continuously_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to read_continuously (see VARARGIN)

% Attach to a board
handles.COM_No=5;
handles.audio_record = 1;
handles.arduino=serial('COM200'); %with a impossibly big number to avoid all possible conflict. just to initialise the serial class
handles.driver = rhd2000.Driver;

handles.spectre_refresh_every = 1; % Jingyuan
handles.spectre_lastsave = now*24*3600; % Jingyuan the last time we collect the data in the past 3s; the value renew every 60 points
handles.spectre_lastcal = now*24*3600; % Jingyuan the last time we calculate the spectre density ; the value renew every 3s
handles.spectre_counter = 0;  % Jingyuan note relative calculation time of the spectre data
handles.fire_lastcounter = 0; % the number of detection beyond threshold from 0s to (now-3)s
handles.detection_lastcounter=0;
handles.detections=0;

handles.boardUI = BoardUI(handles.driver.create_board(), ...
                          handles.data_plot,handles.sleep_stage,handles.phase_space, handles.gamma_distribution,...
                          handles.ratio_distribution, handles.snapshot, handles.chips, handles.channels_to_display, ...
                          handles.FifoLag, handles.FifoPercentageFull,2,handles.detections,handles.meanDelta);  %Jingyuan
handles.boardUI.Plot.sound_tone = 0; % default sound is tone
  
handles.saveUI = SaveConfigUI(handles.intan, handles.file_per_signal_type, ...
                              handles.file_per_channel, handles.save_file_dialog);

% Initialize the sampling rate in the popup to the one from the board.
% Note that the board is 0-based; the popup is 1-based
set(handles.sampling_rate_popup, 'Value', handles.boardUI.Board.SamplingRate + 1);

handles.fire_counter=0;
handles.detection_counter=0;

handles.detections_exist=0;
handles.fires_exist=0;

handles.matrix_digin=0; 
handles.curseur_digin=1;

handles.filter_activated=0;
handles.coeff_filter=0;


set(handles.pushbutton6,'Enable','off');
set(handles.pushbutton8,'Enable','off');
set(handles.ArmForFireing_pushbutton,'Enable','off');
set(handles.radiobutton7,'Enable','off')
set(handles.radiobutton4,'Enable','off');
set(handles.radiobutton6,'Enable','off');
set(handles.radiobutton8,'Enable','off');
set(handles.radiobutton9,'Enable','off');
set(handles.edit14,'Enable','off');

%filter
set(handles.filter_order_edit,'Enable','off');
set(handles.filter_fmax_edit,'Enable','off');
set(handles.pushbutton_apply_filter,'Enable','off');
set(handles.checkbox11,'Enable','off');
handles.filter_order=str2num(get(handles.filter_order_edit,'String'));
handles.filter_fmax=str2num(get(handles.filter_fmax_edit,'String'));

set(handles.edit11,'Enable','off');
set(handles.edit13,'Enable','off');
handles.boardUI.Plot.sound_mode=1;
handles.boardUI.Plot.detec_status=0;
handles.boardUI.Plot.wait_status=0;
set(handles.checkbox5, 'Enable','off');
handles.boardUI.Plot.prefactors=[1 1];
handles.boardUI.webcaminit(handles.webcam);
% When running, we'll refresh the plot every three times through the timer
% callback function
handles.refresh_every = 3;
handles.refresh_count = 0;

handles.thechannels=[1 2];%Kejian defaut value for the gui.
handles.boardUI.set_thechannels([1 2]); %Kejian
handles.gamma_threshold=6.5; %Default value for the threshold
handles.ratio_threshold=1.1;% Default value for the ratio
% Clear the saving information
handles.saving = true;
handles.saveUI.BaseName = '';

% Create a timer - it's used when you click Run
handles.timer = timer(...
    'ExecutionMode', 'fixedSpacing', ...       % Run timer repeatedly
    'Period', 0.001, ...
    'TimerFcn', {@update_display,hObject}); % Specify callback

% Choose default command line output for read_continuously
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);


%--------------------------------------------------------------------

% --- Executes during object creation, after setting all properties.
% GUIDE generated this; no changes
function sampling_rate_popup_CreateFcn(hObject, eventdata, handles)
% hObject    handle to sampling_rate_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------

% --- Executes during object creation, after setting all properties.
% GUIDE generated this; no changes
function chips_CreateFcn(hObject, eventdata, handles)
% hObject    handle to chips (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------

% --- Executes during object creation, after setting all properties.
% GUIDE generated this; no changes
function channels_to_display_CreateFcn(hObject, eventdata, handles)
% hObject    handle to channels_to_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: popupmenu controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

%--------------------------------------------------------------------

% --- Executes on selection change in channels_to_display.
% GUIDE generated this; no changes
function channels_to_display_Callback(hObject, eventdata, handles)
% hObject    handle to channels_to_display (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: contents = cellstr(get(hObject,'String')) returns channels_to_display contents as cell array
%        contents{get(hObject,'Value')} returns selected item from channels_to_display

%--------------------------------------------------------------------

% --- Outputs from this function are returned to the command line.
% GUIDE generated this; no changes
function varargout = read_continuously_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;

%--------------------------------------------------------------------

% --- Executes on button press in run_button.
function run_button_Callback(hObject, eventdata, handles)
% hObject    handle to run_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Enable/disable UI elements as appropriate
%initialise the counters
handles.boardUI.Plot.counter=ceil(handles.boardUI.Plot.countermax)+1;
handles.boardUI.Plot.counter_detection=ceil(handles.boardUI.Plot.countermax_detection)+1;

%UI set up
set(handles.sampling_rate_popup, 'Enable', 'off');
set(handles.stop_button, 'Enable', 'on');
handles.saveUI.Enable = 'off';
set(hObject, 'Enable', 'off');
set(handles.checkbox5, 'Enable','on');
set(handles.save_box,'Enable','off');
set(handles.chips,'Enable','off');
set(handles.channels_to_display,'Enable','off');


if handles.saving==1
    handles=start_saving(handles);
    handles.matrix_digin=0; %initialise the matrix_digin for every run
end

% Set the chunk_size; this is used in the timer callback function
config_params = handles.boardUI.Board.get_configuration_parameters();
handles.chunk_size = config_params.Driver.NumBlocksToRead;

% Create a datablock for reuse
handles.datablock = rhd2000.datablock.DataBlock(handles.boardUI.Board);

% Tell the board to run continuously
handles.boardUI.Board.run_continuously();
%handles.boardUI.Board.DigitalOutputs=zeros(1,16);
handles.last_status=0;

handles.boardUI.set_channels_chips();

handles.fires=0;
handles.last_db_digin=zeros(1,60);

handles.allresult = [];%Jingyuan

% Update handles structure
guidata(hObject, handles);   
            
% Start the timer
start(handles.timer);

%--------------------------------------------------------------------

% --- Executes on button press in stop_button.
% This is mostly the opposite of run_button_Callback, in reverse order
function stop_button_Callback(hObject, eventdata, handles)
% hObject    handle to stop_button (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Stop the timer; it's important to do this first so we don't call the
% timer callback while we're in the middle of doing the rest of the
% operations in this function
stop(handles.timer);

% Stop and flush the board
handles.boardUI.Board.stop();
handles.boardUI.Board.flush();

% Free the datablock
if isfield(handles, 'datablock')
    delete(handles.datablock);
    handles.datablock = [];
end

if handles.saving==1
    handles=stop_saving(handles);
end

% save the data concerning spectre plot Jingyuan
if handles.saving
    allresult = handles.allresult;
    if handles.saveUI.Format==0 %if intan format
        save([handles.pathandname, '_sleepstage.mat'],'allresult');
    else
        save([handles.pathandname, '\sleepstage.mat'],'allresult');
    end
    clear allresult;
end

%save the detection matrix
if handles.detections_exist==1 && handles.saving
    detections=handles.detections;
    if handles.saveUI.Format==0 %if intan format
        save([handles.pathandname, '_detections_matrix.mat'],'detections');
    else
        save([handles.pathandname, '\detections_matrix.mat'],'detections');
    end
    clear detection
end

if handles.fires_exist==1 && handles.saving
    fires=handles.fires;
    if handles.saveUI.Format==0 %if intan format
        save([handles.pathandname, '_fires_matrix.mat'],'fires');
    else
        save([handles.pathandname, '\fires_matrix.mat'],'fires');
    end
    %clear fires
end

% save the digin matrix
if handles.saving
    digin=handles.matrix_digin;
    
    if length(digin)>1
        if handles.saveUI.Format==0 %if intan format
            save([handles.pathandname, '_digin_matrix.mat'],'digin');
        else
            save([handles.pathandname, '\digin_matrix.mat'],'digin');
        end
        index_montant=find(diff(digin)>1)+1;
        matrix_montant=(digin(index_montant))/frequency(handles.boardUI.Board.SamplingRate)*10000; %en 0.1ms
        fires_actual_time=matrix_montant';
        
        if handles.saveUI.Format==0 %if intan format
            save([handles.pathandname, '_fires_actual_time.mat'],'fires_actual_time');
        else
            save([handles.pathandname, '\fires_actual_time.mat'],'fires_actual_time');
        end
    end
    
    fires=handles.fires;
    fires=fires(2:end,1);
    if exist('fires_actual_time','var')
        if length(fires)==length(fires_actual_time)
            fires_delay = fires_actual_time-fires;
            if handles.saveUI.Format==0 %if intan format
                save([handles.pathandname, '_fires_delay.mat'],'fires_delay');
            else
                save([handles.pathandname, '\fires_delay.mat'],'fires_delay');
            end
        end
    end
    clear digin fires;    
end

% Enable/disable UI elements as appropriate
if ~isempty(handles.saveUI.BaseName)
    set(handles.save_box,'Enable','on');
end
set(handles.sampling_rate_popup, 'Enable', 'on');
set(handles.run_button, 'Enable', 'on');
handles.saveUI.Enable = 'on';
set(handles.checkbox5,'Value',0);
handles.boardUI.Plot.detec_status=0;
pushbutton8_Callback(hObject,[],handles);  %button detection

set(handles.checkbox5,'Enable','off');
set(handles.pushbutton6,'Enable','off');
set(handles.pushbutton8,'Enable','off');
set(handles.ArmForFireing_pushbutton,'Enable','off');
    set(handles.pushbutton6,'Enable','off');
    set(handles.pushbutton8,'Enable','off');
    set(handles.ArmForFireing_pushbutton,'Enable','off');
    set(handles.radiobutton7,'Enable','off');
    set(handles.radiobutton4,'Enable','off');
    set(handles.radiobutton6,'Enable','off');
    set(handles.radiobutton8,'Enable','off');
    set(handles.radiobutton9,'Enable','off');
    set(handles.edit14,'Enable','off');
set(handles.edit10,'Enable','off');



set(hObject, 'Enable', 'off');


%--------------------------------------------------------------------

% --- Executes on selection change in sampling_rate_popup.
function sampling_rate_popup_Callback(hObject, eventdata, handles)
% hObject    handle to sampling_rate_popup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Set the board's sampling rate to the one the user selected
selection = get(hObject, 'Value');
handles.boardUI.Board.SamplingRate = rhd2000.SamplingRate(selection - 1);

%--------------------------------------------------------------------

% --- Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Delete the timer
if isfield(handles, 'timer')
    delete(handles.timer);
end

if strcmp(handles.arduino.Status,'open')
fclose(handles.arduino);
end

% Hint: delete(hObject) closes the figure
delete(hObject);

%--------------------------------------------------------------------

% --- Timer callback
% This function reads one chunk of data and adds it to the
% handles.boardUI.Amplifiers matrix.  Every third time through, it updates the plot
% on the screen.  It saves data to disk if appropriate.
function update_display(hObject,eventdata,hfigure)  

handles = guidata(hfigure);

% The API's chunk size is about 1/30th of a second's worth of data.  When
% we read from the API, we get that amount of data from the board into
% memory; we just go ahead and plot all the in-memory data.
for i=1:handles.chunk_size
    % Get data from the API.
    handles.datablock.read_next(handles.boardUI.Board);  
    handles.boardUI.process_data_block(handles.datablock,handles.arduino,handles.filter_activated);  
    handles.boardUI.Spectre_data_block(handles.datablock);
    
    %write to detection matrix in workspace 
    if handles.boardUI.Plot.detected==1       
        %write to detection matrix
        handles.detection_counter=handles.detection_counter+1;
        handles.detections(handles.detection_counter,1)=double(handles.datablock.Timestamps(end))/frequency(handles.boardUI.Board.SamplingRate)*10000; % en 0.1ms, attention, time stamps is a uint32 number, should be tranformed to double to avoid saturation
        handles.detections(handles.detection_counter,2)=double(handles.boardUI.Plot.timeStartDelta*20000)/frequency(handles.boardUI.Board.SamplingRate)*10000;
        handles.detections(handles.detection_counter,3)=sum(handles.detections(handles.detections(:,1)>(handles.detections(end,1)-4E4),1)-handles.detections(handles.detections(:,1)>(handles.detections(end,1)-4E4),2))/4E4;
        handles.detections(handles.detection_counter,4)=handles.boardUI.Plot.sound_mode;
        handles.detections(handles.detection_counter,5)=handles.boardUI.Plot.detec_seuil;
        handles.detections(handles.detection_counter,6)=handles.boardUI.Plot.prefactors(1);
        handles.detections(handles.detection_counter,7)=handles.boardUI.Plot.Channels(1);
        handles.detections(handles.detection_counter,8)=handles.boardUI.Plot.prefactors(2);
        handles.detections(handles.detection_counter,9)=handles.boardUI.Plot.Channels(2);
        if handles.filter_activated==1
            handles.detections(handles.detection_counter,10)=0;
            handles.detections(handles.detection_counter,11)=handles.filter_fmax;
            handles.detections(handles.detection_counter,12)=handles.filter_order;
        else
            handles.detections(handles.detection_counter,10)=0;
            handles.detections(handles.detection_counter,11)=0;
            handles.detections(handles.detection_counter,12)=0;
        end
        handles.detections_exist=1;
    end
    %filterF_fmax=handles.filter_fmax;    %default value in frequency
    
    %write to fires matrix in workspace 
    if handles.boardUI.Plot.fired==1
        handles.fire_counter=handles.fire_counter+1;
        handles.fires(handles.fire_counter,1)=double(handles.datablock.Timestamps(1))/frequency(handles.boardUI.Board.SamplingRate)*10000; % en 0.1ms
        handles.fires(handles.fire_counter,2)=handles.boardUI.Plot.sound_mode;
        handles.fires(handles.fire_counter,3)=handles.boardUI.Plot.detec_seuil;
        handles.fires(handles.fire_counter,4)=handles.boardUI.Plot.prefactors(1);
        handles.fires(handles.fire_counter,5)=handles.boardUI.Plot.Channels(1);
        handles.fires(handles.fire_counter,6)=handles.boardUI.Plot.prefactors(2);
        handles.fires(handles.fire_counter,7)=handles.boardUI.Plot.Channels(2);
        if handles.filter_activated==1
            handles.fires(handles.fire_counter,8)=0;
            handles.fires(handles.fire_counter,9)=handles.filter_fmax;
            handles.fires(handles.fire_counter,10)=2000/(2*pi*handles.filter_fmax);
        else
            handles.fires(handles.fire_counter,8)=0;
            handles.fires(handles.fire_counter,9)=0;
            handles.fires(handles.fire_counter,10)=0;
        end
        handles.fires_exist=1;   
    end
  
    % Save to disk if appropriate  
    % the diginsave
    if handles.saving
        handles.datablock.save(); 
        index=find(sum(handles.datablock.Board.DigitalInputs(1:4,:),1));
        len=length(index);
        if len~=0
            handles.matrix_digin(handles.curseur_digin:handles.curseur_digin+len-1)=...
                handles.datablock.Timestamps(index); 
            handles.curseur_digin=handles.curseur_digin+len;
        end
    end
    
    %snapshot
    if (handles.boardUI.Plot.counter==handles.boardUI.Plot.nbrdbaft) | (handles.boardUI.Plot.counter_detection==handles.boardUI.Plot.nbrdbaft)  %wait until sufficient datablock after the event
        handles.boardUI.Plot.refresh_snapshot();
    end
    
    
    %GUI Control
    if handles.boardUI.Plot.detec_status==0
        set(handles.ArmForFireing_pushbutton,'String','Arm for firing');
        set(handles.ArmForFireing_pushbutton,'Enable','off');
        
    else    %detec_status==1
        if handles.boardUI.Plot.fired==1
            set(handles.ArmForFireing_pushbutton,'Enable','off');
            set(handles.ArmForFireing_pushbutton,'String',['fired,mode',num2str(handles.boardUI.Plot.sound_mode)]);
            set(handles.text32,'String',num2str(handles.fire_counter));
        else  %detect=1, fired=0
            if handles.boardUI.Plot.wait_status==0 %virgin
                set(handles.ArmForFireing_pushbutton,'Enable','on');
                set(handles.ArmForFireing_pushbutton,'String','Arm for firing!');
            else % waiting
                set(handles.ArmForFireing_pushbutton,'String','waiting for a trigger!');
                set(handles.ArmForFireing_pushbutton,'Enable','off');
            end

        end
    end
    
    
%reset the fired status to be ready for next detection
    handles.boardUI.Plot.fired=0;  %fired is just a var to pass out the information of fired 
    handles.boardUI.Plot.detected=0; 
    
    if handles.boardUI.Plot.armed==1
        handles.boardUI.Plot.wait_status=1;
    end
end

% Every third time through, update the plot in the UI.  The UI becomes
% unresponsive if we try to do this every time through, so we update 10
% times a second instead.
if (handles.refresh_count == 0)
    handles.refresh_count = handles.refresh_every;
    handles.boardUI.refresh_display(handles.filter_activated);
    handles.boardUI.refresh_fifo();
end
handles.refresh_count = handles.refresh_count - 1;
    handles.boardUI.refresh_fifo();

   
    handles.spectre_nowtime = now*24*3600;
    
if (handles.spectre_nowtime >= (handles.spectre_lastcal + handles.spectre_refresh_every ))
    
    
    handles.boardUI.hilbert_process(); 
    handles.boardUI.refreshWebcam(handles.webcam);
    handles.allresult = [handles.allresult;handles.spectre_counter,...
                           double(handles.datablock.Timestamps(end))/20000,handles.boardUI.Plot.result,-1,-1];
                       % add the calcualation reslut to the matrices
                       % the last -1 separately means no setting of detection threshold
     handles.boardUI.refresh_phasespace(handles.allresult(:,1),handles.allresult(:,3),handles.allresult(:,6)); 
     %Jingyuan refresh  2D phase space and distribution the 3rd and 7rd column is gamma and theta/delta ratio
        
    if (handles.boardUI.Plot.armed==1) % save the number pf detection beyond the threshold in the past 3s
        handles.allresult(end,7) = handles.detection_counter-handles.detection_lastcounter;
        handles.boardUI.detection_number(handles.allresult(:,1),handles.allresult(:,7),handles.detections);
        handles.fire_lastcounter = handles.fire_counter;
        handles.detection_lastcounter=handles.detection_counter;
    end
    
    
    if (handles.boardUI.Plot.threshold_status == 1)
        if handles.boardUI.Plot.SleepState==3% show the sleepstage on screen
            set (handles.sleepStage,'string','Wake');
            set (handles.sleepStage,'ForegroundColor',[0.7 0 0]);
            set (handles.timerNREM,'string',strcat(num2str(handles.boardUI.Plot.timerWake),'s'));
            handles.allresult (end,9) = 3; % 3 means Wake
            handles.boardUI.setDigitalOutput(3);
        elseif handles.boardUI.Plot.SleepState==2%
            set (handles.sleepStage,'string','REM');
            set (handles.sleepStage,'ForegroundColor',[0 0 0.5]);
            set (handles.timerNREM,'string',strcat(num2str(handles.boardUI.Plot.timerREM),'s'));
            handles.allresult(end,9) = 2; % 2 means REM
            handles.boardUI.setDigitalOutput(2);
        elseif handles.boardUI.Plot.SleepState==1%
            set (handles.sleepStage,'string','NREM');
            set (handles.sleepStage,'ForegroundColor',[0 0.7 0]);
            handles.allresult (end,9) = 1;% 1 means SWS
            set (handles.timerNREM,'string',strcat(num2str(handles.boardUI.Plot.timerNREM),'s'));
            handles.boardUI.setDigitalOutput(1);
        end
        set(handles.slider2,'Max',handles.boardUI.Plot.recordingTime);
        if get(handles.slider2,'Value')>handles.boardUI.Plot.recordingTime*0.9
            set(handles.slider2,'Value',handles.boardUI.Plot.recordingTime);
        end
        handles.boardUI.Plot.maxSleepstages = get(handles.slider2, 'Value');
        if(handles.boardUI.Plot.recordingTime<3600)
            set(handles.slider2,'SliderStep', [1, 1]);
        else
            set(handles.slider2,'SliderStep', [3600/handles.boardUI.Plot.recordingTime, 3600/handles.boardUI.Plot.recordingTime]);
        end
        handles.boardUI.refresh_sleepstage(handles.allresult(:,1),handles.allresult(:,9)); % draw the hyponogram
        set(handles.deltaDensity,'string',num2str(handles.boardUI.Plot.deltaDensity));
        if isprop(handles.boardUI.Plot.GMModel,'NumVariables')
            set(handles.wakeProb,'String',strcat('Wake: ',num2str(handles.boardUI.Plot.probWake*100,'%.1f'),'%'));
            set(handles.REMprob,'String',strcat('REM: ',num2str(handles.boardUI.Plot.probREM*100,'%.1f'),'%'));
            set(handles.NREMprob,'String',strcat('NREM: ',num2str(handles.boardUI.Plot.probNREM*100,'%.1f'),'%'));
        end
        
        
        %% Sleeping statistics
        set (handles.text75,'string',num2str(sum(handles.allresult(:,9)==1)/60,'%.2f'   ));
        set (handles.text77,'string',num2str( 100 * sum(handles.allresult(:,9)==1) / nnz(handles.allresult(:,9)+1),'%.2f' ) );
        set (handles.numberNREM,'string',num2str(sum(diff([1 handles.allresult(:,9)'==1 1])>0)-1) );
        set (handles.meanNREM,'string',num2str((sum(handles.allresult(:,9)==1))/(sum(diff([1 handles.allresult(:,9)'==1 1])>0)-1)) );
        set (handles.text80,'string',num2str(sum(handles.allresult(:,9)==2)/60,'%.2f'));
        set (handles.text81,'string',num2str( 100 * sum(handles.allresult(:,9)==2) / nnz(handles.allresult(:,9)+1),'%.2f' ) );
        set (handles.numberREM,'string',num2str(sum(diff([1 handles.allresult(:,9)'==2 1])>0)-1) );
        set (handles.meanREM,'string',num2str((sum(handles.allresult(:,9)==2))/(sum(diff([1 handles.allresult(:,9)'==2 1])>0)-1)) );
        set (handles.text82,'string',num2str(sum(handles.allresult(:,9)==3)/60,'%.2f'));
        set (handles.text83,'string',num2str( 100 * sum(handles.allresult(:,9)==3) / nnz(handles.allresult(:,9)+1),'%.2f' ) );
        set (handles.numberWake,'string',num2str(sum(diff([1 handles.allresult(:,9)'==3 1])>0)-1) );
        set (handles.meanWake,'string',num2str((sum(handles.allresult(:,9)==3))/(sum(diff([1 handles.allresult(:,9)'==3 1])>0)-1)) );


    end

    
    handles.spectre_lastcal = handles.spectre_nowtime;
    handles.spectre_counter = handles.spectre_counter + handles.spectre_refresh_every;
    handles.boardUI.Plot.result=[];
    
end
% Update handles structure
guidata(hfigure, handles);

%--------------------------------------------------------------------

% --- Executes on selection change in chips.
% Called when you pick a new chip from the popup.  See set_chip for
% details.
function chips_Callback(hObject, eventdata, handles)
% hObject    handle to chips (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.boardUI.set_chip();

% Update handles structure
guidata(hObject, handles);

%--------------------------------------------------------------------

% --- Executes when you click Set Base Path...
function save_file_dialog_Callback(hObject, eventdata, handles)
% hObject    handle to save_file_dialog (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

handles.saveUI.save_dialog();

if ~isempty(handles.saveUI.BaseName)
    % Enable the Save checkbox.
    set(handles.save_box, 'Enable', 'on');
    % Update handles structure
    guidata(hObject, handles);
end

%--------------------------------------------------------------------

% --- Executes when you check/uncheck the Save checkbox
function save_box_Callback(hObject, eventdata, handles)
% hObject    handle to save_box (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

if get(hObject, 'Value') == 1
    if ~handles.saving
        % If were not saving, and someone clicks the checkbox, start saving

        %start_saving(hObject, handles);
        handles.saving = true;
    end
else
    if handles.saving
        % If we're saving, and someone turns off the Save checkbox, stop
        % saving
        
        %stop_saving(hObject, handles);
        handles.saving = false;
    end
    
end
guidata(hObject,handles);

%--------------------------------------------------------------------

function handles = start_saving(handles)
% hObject    handle to save_box (see GCBO)
% handles    structure with handles and user data (see GUIDATA)

% Get format
format = handles.saveUI.Format;

% Get path of the form <directory><name>_<timestamp><extension>
[pathstr, name, ext] = fileparts(handles.saveUI.BaseName);
% Add timestamp
name = strcat(name, '_', datestr(now, 'yyyymmdd_HHMMSS'));
path = fullfile(pathstr,[name ext]);
handles.pathandname=fullfile(pathstr,name);%Kejian

% Open the save file and set the 'saving' variable
sigr = handles.boardUI.Board.SaveFile.SignalGroups;
sigr{5,1}.Channels{1,1}.Enabled = 1; %audio file
sigr{5,1}.Channels{2,1}.Enabled = 1; %audio file - envelope
sigr{5,1}.Channels{3,1}.Enabled = 1; %audio file - gating
sigr{5,1}.Channels{4,1}.Enabled = 1; %REM Trigger
sigr{6,1}.Channels{1,1}.Enabled=1; %Save digin
sigr{6,1}.Channels{2,1}.Enabled=1;
sigr{6,1}.Channels{3,1}.Enabled=1;
sigr{6,1}.Channels{4,1}.Enabled=1;
sigr{6,1}.Channels{5,1}.Enabled=1;
sigr{6,1}.Channels{6,1}.Enabled=1;
sigr{6,1}.Channels{7,1}.Enabled=1;
sigr{6,1}.Channels{8,1}.Enabled=1;
sigr{6,1}.Channels{9,1}.Enabled=1;
sigr{6,1}.Channels{10,1}.Enabled=1;
sigr{6,1}.Channels{11,1}.Enabled=1;
sigr{6,1}.Channels{12,1}.Enabled=1;
sigr{6,1}.Channels{13,1}.Enabled=1;
sigr{6,1}.Channels{14,1}.Enabled=1;
sigr{6,1}.Channels{15,1}.Enabled=1;
sigr{6,1}.Channels{16,1}.Enabled=1;
handles.boardUI.Board.SaveFile.SignalGroups = sigr;
handles.boardUI.Board.SaveFile.open(format, path);

% Update handles structure
%guidata(hObject, handles);

%--------------------------------------------------------------------

function handles = stop_saving(handles)
% hObject    handle to save_box (see GCBO)
% handles    structure with handles and user data (see GUIDATA)

        
% Turn the 'saving' variable off.  We need to do this (including 
% the update) before closing the save file to be safe if the timer 
% callback function executes.
%handles.saving = false;
% Update handles structure.  
%guidata(hObject, handles);

% Now tell the API to close the save file
handles.boardUI.Board.SaveFile.close();





% --- Executes on button press in pushbutton4.
function pushbutton4_Callback(hObject, eventdata, handles)  %channels selection OK button
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.set_thechannels(handles.thechannels);  %Kejian pass into the boradUI class!
handles.boardUI.set_channels();  %valide the channels selection with the original function
guidata(hObject, handles);


function edit5_Callback(hObject, eventdata, handles) %channels selection
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit5 as text
%        str2double(get(hObject,'String')) returns contents of edit5 as a double
handles.thechannels(1)=str2double(get(hObject,'String'))+1;
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function edit5_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit6_Callback(hObject, eventdata, handles) %channels selection
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit6 as text
%        str2double(get(hObject,'String')) returns contents of edit6 as a double
handles.thechannels(2)=str2double(get(hObject,'String'))+1;
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit6_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white')
end





% --- Executes on button press in checkbox2.
function checkbox2_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox2
visiblevalue=get(hObject,'Value');
if visiblevalue==0
    handles.boardUI.Plot.DataPlotLines(1).Visible='off';
else
    handles.boardUI.Plot.DataPlotLines(1).Visible='on';
end


% --- Executes on button press in checkbox3.
function checkbox3_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox3
visiblevalue=get(hObject,'Value');
if visiblevalue==0
    handles.boardUI.Plot.DataPlotLines(2).Visible='off';
else
    handles.boardUI.Plot.DataPlotLines(2).Visible='on';
end

% --- Executes on button press in checkbox4.
function checkbox4_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox4
visiblevalue=get(hObject,'Value');
if visiblevalue==0
    handles.boardUI.Plot.DataPlotLines(3).Visible='off';
else
    handles.boardUI.Plot.DataPlotLines(3).Visible='on';
end
% --- Executes on button press in checkbox6.
function checkbox6_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox6
visiblevalue=get(hObject,'Value');
if visiblevalue==0
    handles.boardUI.Plot.DataPlotLines(4).Visible='off';
else
    handles.boardUI.Plot.DataPlotLines(4).Visible='on';
end
% --- Executes on button press in checkbox8.
function checkbox8_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox8
visiblevalue=get(hObject,'Value');
if visiblevalue==0
    handles.boardUI.Plot.DataPlotLines(5).Visible='off';
else
    handles.boardUI.Plot.DataPlotLines(5).Visible='on';
end

% --- Executes on button press in checkbox11.
function checkbox11_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox11
visiblevalue=get(hObject,'Value');
if visiblevalue==0
    handles.boardUI.Plot.DataPlotLines(6).Visible='off';
else
    handles.boardUI.Plot.DataPlotLines(6).Visible='on';
end
% --- Executes on button press in checkbox5.
function checkbox5_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox5
value=get(hObject,'Value');
if value==0
    set(handles.pushbutton6,'Enable','off');
    set(handles.pushbutton8,'Enable','off');
    set(handles.ArmForFireing_pushbutton,'Enable','off');
    set(handles.radiobutton7,'Enable','off');
    set(handles.radiobutton4,'Enable','off');
    set(handles.radiobutton6,'Enable','off');
    set(handles.radiobutton8,'Enable','off');
    set(handles.radiobutton9,'Enable','off');
    set(handles.edit10,'Enable','off');
    set(handles.edit14,'Enable','off');
    handles.boardUI.Plot.detec_status=0;
    handles.boardUI.Plot.armed=0;
    handles.boardUI.Plot.fired=0;
    handles.boardUI.Plot.wait_status=0;
else
    set(handles.pushbutton6,'Enable','on');
    set(handles.pushbutton8,'Enable','on');
    set(handles.ArmForFireing_pushbutton,'Enable','on');
    set(handles.radiobutton7,'Enable','on');
    set(handles.radiobutton4,'Enable','on');
    set(handles.radiobutton6,'Enable','on');
    set(handles.radiobutton8,'Enable','on');
    set(handles.radiobutton9,'Enable','on');
    set(handles.edit14,'Enable','on');
    set(handles.edit10,'Enable','on');
    handles.boardUI.Plot.detec_status=1; 
end
guidata(hObject,handles);





function edit10_Callback(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit10 as text
%        str2double(get(hObject,'String')) returns contents of edit10 as a double
handles.seuil=str2double(get(hObject,'String'));
handles.boardUI.Plot.detec_seuil=str2double(get(hObject,'String'));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function edit10_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit10 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in pushbutton6.
function pushbutton6_Callback(hObject, eventdata, handles) %apply
% hObject    handle to pushbutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.detec_seuil=handles.seuil;
guidata(hObject, handles);



% --- Executes on button press in pushbutton8. 
function pushbutton8_Callback(hObject, eventdata, handles) %reset unarm
% hObject    handle to pushbutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.armed=0;
handles.boardUI.Plot.fired=0;
handles.boardUI.Plot.wait_status=0;
handles.fire_counter=0;
handles.detection_counter=0;
%handles.boardUI.Board.DigitalOutputs=zeros(1,16);
%stop(handles.boardUI.Plot.timer1);
%stop(handles.boardUI.Plot.timer2);
guidata(hObject, handles);


% --- Executes on button press in ArmForFireing_pushbutton.
function ArmForFireing_pushbutton_Callback(hObject, eventdata, handles) %fire arm
% hObject    handle to ArmForFireing_pushbutton (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.armed=1;
% set(hObject,'Enable','off');
% set(hObject,'String','Armed,waiting for a trigger');
guidata(hObject, handles);



% --- Executes on button press in radiobutton7.
function radiobutton7_Callback(hObject, eventdata, handles)  %mode 0
% hObject    handle to radiobutton7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton7
handles.boardUI.Plot.sound_mode=0;
guidata(hObject, handles);

% --- Executes on button press in radiobutton4.
function radiobutton4_Callback(hObject, eventdata, handles)  %mode 1
% hObject    handle to radiobutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton4
handles.boardUI.Plot.sound_mode=1;
guidata(hObject, handles);


% --- Executes on button press in radiobutton6.
function radiobutton6_Callback(hObject, eventdata, handles)  %mode 2
% hObject    handle to radiobutton6 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton6
handles.boardUI.Plot.sound_mode=2;
guidata(hObject, handles);

% --- Executes on button press in radiobutton8.
function radiobutton8_Callback(hObject, eventdata, handles) %mode 3
% hObject    handle to radiobutton8 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton8
handles.boardUI.Plot.sound_mode=3;
guidata(hObject, handles);

% --- Executes on button press in radiobutton9.
function radiobutton9_Callback(hObject, eventdata, handles) %mode 4
% hObject    handle to radiobutton9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of radiobutton9
handles.boardUI.Plot.sound_mode=4;
guidata(hObject, handles);



function edit11_Callback(hObject, eventdata, handles) %prefactor1 
% hObject    handle to edit11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit11 as text
%        str2double(get(hObject,'String')) returns contents of edit11 as a double
handles.boardUI.Plot.prefactors(1)=str2double(get(hObject,'String'));
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit11_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit11 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function edit13_Callback(hObject, eventdata, handles) %prefactor2
% hObject    handle to edit13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit13 as text
%        str2double(get(hObject,'String')) returns contents of edit13 as a double
handles.boardUI.Plot.prefactors(2)=str2double(get(hObject,'String'));
guidata(hObject, handles);

% --- Executes during object creation, after setting all properties.
function edit13_CreateFcn(hObject, eventdata, handles)   
% hObject    handle to edit13 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in checkbox7.
function checkbox7_Callback(hObject, eventdata, handles)  %prefactor
% hObject    handle to checkbox7 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox7
if get(hObject,'Value')==0
    set(handles.edit11,'Enable','off');
    set(handles.edit13,'Enable','off');
    set(handles.edit11,'String','1');
    set(handles.edit13,'String','1');
    handles.boardUI.Plot.prefactors=[1 1];
else
    set(handles.edit11,'Enable','on');
    set(handles.edit13,'Enable','on');
end
guidata(hObject, handles);




% --- Executes when selected object is changed in uibuttongroup2.
function uibuttongroup2_SelectionChangedFcn(hObject, eventdata, handles)
% hObject    handle to the selected object in uibuttongroup2 
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.fire_counter=0;
handles.detection_counter=0;
guidata(hObject,handles);



function edit14_Callback(hObject, eventdata, handles)
% hObject    handle to edit14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit14 as text
%        str2double(get(hObject,'String')) returns contents of edit14 as a double
handles.boardUI.Plot.countermax=str2double(get(hObject,'String'))/(1/frequency(handles.boardUI.Board.SamplingRate))/60;
guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function edit14_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit14 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end





% --- Executes on button press in checkbox9.
function checkbox9_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox9 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: get(hObject,'Value') returns toggle state of checkbox9



function arduinoCOM_Callback(hObject, eventdata, handles)
% hObject    handle to arduinoCOM (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of arduinoCOM as text
%        str2double(get(hObject,'String')) returns contents of arduinoCOM as a double
handles.COM_No=get(hObject,'String');
guidata(hObject,handles);



% --- Executes during object creation, after setting all properties.
function arduinoCOM_CreateFcn(hObject, eventdata, handles)
% hObject    handle to arduinoCOM (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in arduinoOk.
function arduinoOk_Callback(hObject, eventdata, handles)
% hObject    handle to arduinoOk (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
name=['COM',handles.COM_No];
if ~strcmp(handles.arduino.Status,'open')
handles.arduino=serial(name);
    try
        fopen(handles.arduino);
    catch err
        rethrow(err);
    end
else
    disp('Already connected to arduino');
end

guidata(hObject,handles);




% --- Executes on button press in checkbox_online_filter.
function checkbox_online_filter_Callback(hObject, eventdata, handles)
% hObject    handle to checkbox_online_filter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if get(hObject,'Value')==1
    set(handles.filter_order_edit,'Enable','on');
    set(handles.filter_fmax_edit,'Enable','on');
    set(handles.pushbutton_apply_filter,'Enable','on');
else
    handles.filter_activated=0;
    set(handles.filter_order_edit,'Enable','off');
    set(handles.filter_fmax_edit,'Enable','off');
    set(handles.pushbutton_apply_filter,'Enable','off');
    set(handles.checkbox11,'Enable','off');
    handles.boardUI.Plot.DataPlotLines(6).Visible='off';
end
guidata(hObject,handles);
% Hint: get(hObject,'Value') returns toggle state of checkbox_online_filter


function filter_order_edit_Callback(hObject, eventdata, handles)
% hObject    handle to filter_order_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of filter_order_edit as text
%        str2double(get(hObject,'String')) returns contents of filter_order_edit as a double
handles.filter_order=str2double(get(hObject,'String'));
guidata(hObject,handles);

% --- Executes during object creation, after setting all properties.
function filter_order_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to filter_order_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


function filter_fmax_edit_Callback(hObject, eventdata, handles)
% hObject    handle to filter_fmax_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of filter_fmax_edit as text
%        str2double(get(hObject,'String')) returns contents of filter_fmax_edit as a double
handles.filter_fmax=str2double(get(hObject,'String'));
guidata(hObject,handles);


% --- Executes during object creation, after setting all properties.
function filter_fmax_edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to filter_fmax_edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



% --- Executes on button press in pushbutton_apply_filter.
function pushbutton_apply_filter_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton_apply_filter (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


filterF_fmax=handles.filter_fmax;    %default value in frequency
filterF_order=handles.filter_order;    %default value in frequency
handles.filter_activated=1;
handles.boardUI.Plot.DeltaPFC_filterdesign(filterF_order,filterF_fmax);
set(handles.checkbox11,'Enable','on');
set(handles.checkbox11,'Value',1);
handles.boardUI.Plot.DataPlotLines(6).Visible='on';
guidata(hObject,handles);


function gammaThreshold_Callback(hObject, eventdata, handles)
% hObject    handle to gammaThreshold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of gammaThreshold as text
%        str2double(get(hObject,'String')) returns contents of gammaThreshold as a double
handles.gamma_threshold=(str2double(get(hObject,'String')));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function gammaThreshold_CreateFcn(hObject, eventdata, handles)
% hObject    handle to gammaThreshold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function thetaDeltaThreshold_Callback(hObject, eventdata, handles)
% hObject    handle to thetaDeltaThreshold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of thetaDeltaThreshold as text
%        str2double(get(hObject,'String')) returns contents of thetaDeltaThreshold as a double
handles.ratio_threshold=(str2double(get(hObject,'String')));
guidata(hObject, handles);


% --- Executes during object creation, after setting all properties.
function thetaDeltaThreshold_CreateFcn(hObject, eventdata, handles)
% hObject    handle to thetaDeltaThreshold (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in pushbutton18.
function pushbutton18_Callback(hObject, eventdata, handles) %Jingyuan OK button for set the threshold
% hObject    handle to pushbutton18 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.ratio_threshold=(str2double(get(handles.thetaDeltaThreshold,'String')));
handles.gamma_threshold=(str2double(get(handles.gammaThreshold,'String')));
handles.boardUI.Plot.threshold_status = 1;
handles.boardUI.set_thethreshold(handles.gamma_threshold,handles.ratio_threshold);




% --- Executes on button press in tone.
function tone_Callback(hObject, eventdata, handles)
% hObject    handle to tone (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.sound_tone = 0;
% Hint: get(hObject,'Value') returns toggle state of tone


% --- Executes on button press in Gaussian.
function Gaussian_Callback(hObject, eventdata, handles)
% hObject    handle to Gaussian (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.sound_tone=1;
% Hint: get(hObject,'Value') returns toggle state of Gaussian


% --- Executes on button press in loadChannel.
function loadChannel_Callback(hObject, eventdata, handles)
% hObject    handle to loadChannel (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
[filename1,filepath1]=uigetfile({'*.*','All Files'},'Select Data File 1');
file=strcat(filepath1,filename1);
handles.boardUI.setChannelsSpectre(file);
set(handles.bullChannelText,'String',handles.boardUI.Plot.bullchannel-1);
set(handles.thetaChannelText,'String',handles.boardUI.Plot.Thetachannel-1);
set(handles.edit5,'String',handles.boardUI.Plot.Channels(1)-1);
set(handles.edit6,'String',handles.boardUI.Plot.Channels(2)-1);
set(handles.thetaDeltaThreshold,'String',handles.boardUI.Plot.ratio_threshold);
set(handles.gammaThreshold,'String',handles.boardUI.Plot.gamma_threshold);
handles.boardUI.Plot.set_thethreshold_now(handles.boardUI.Plot.gamma_threshold,handles.boardUI.Plot.ratio_threshold);








function bullChannelText_Callback(hObject, eventdata, handles)
% hObject    handle to bullChannelText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of bullChannelText as text
%        str2double(get(hObject,'String')) returns contents of bullChannelText as a double


% --- Executes during object creation, after setting all properties.
function bullChannelText_CreateFcn(hObject, eventdata, handles)
% hObject    handle to bullChannelText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function thetaChannelText_Callback(hObject, eventdata, handles)
% hObject    handle to thetaChannelText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of thetaChannelText as text
%        str2double(get(hObject,'String')) returns contents of thetaChannelText as a double


% --- Executes during object creation, after setting all properties.
function thetaChannelText_CreateFcn(hObject, eventdata, handles)
% hObject    handle to thetaChannelText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end



function deltaChannelText_Callback(hObject, eventdata, handles)
% hObject    handle to deltaChannelText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of deltaChannelText as text
%        str2double(get(hObject,'String')) returns contents of deltaChannelText as a double


% --- Executes during object creation, after setting all properties.
function deltaChannelText_CreateFcn(hObject, eventdata, handles)
% hObject    handle to deltaChannelText (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in testArduino.
function testArduino_Callback(hObject, eventdata, handles)
% hObject    handle to testArduino (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.testArduino();


% --- Executes on button press in stimulateDuringNREM.
function stimulateDuringNREM_Callback(hObject, eventdata, handles)
% hObject    handle to stimulateDuringNREM (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(handles.boardUI.Plot.stimulateDuringNREM== false)
    handles.boardUI.Plot.stimulateDuringNREM= true;
else 
    handles.boardUI.Plot.stimulateDuringNREM= false;
end
% Hint: get(hObject,'Value') returns toggle state of stimulateDuringNREM


% --- Executes on button press in stimulateDuringREM.
function stimulateDuringREM_Callback(hObject, eventdata, handles)
% hObject    handle to stimulateDuringREM (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(handles.boardUI.Plot.stimulateDuringREM== false)
    handles.boardUI.Plot.stimulateDuringREM= true;
else 
    handles.boardUI.Plot.stimulateDuringREM= false;
end



% Hint: get(hObject,'Value') returns toggle state of stimulateDuringREM


% --- Executes on button press in stimulateDuringWake.
function stimulateDuringWake_Callback(hObject, eventdata, handles)
% hObject    handle to stimulateDuringWake (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
if(handles.boardUI.Plot.stimulateDuringWake== false)
    handles.boardUI.Plot.stimulateDuringWake= true;
else 
    handles.boardUI.Plot.stimulateDuringWake= false;
end


% Hint: get(hObject,'Value') returns toggle state of stimulateDuringWake


% --- Executes on button press in stimulateAtRandom.
function stimulateAtRandom_Callback(hObject, eventdata, handles)
% hObject    handle to stimulateAtRandom (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and uif(handles.boardUI.Plot.stimulateDuringWake== false)
if(handles.boardUI.Plot.stimulateAtRandom== false)
    handles.boardUI.Plot.stimulateAtRandom= true;
else 
    handles.boardUI.Plot.stimulateAtRandom= false;
end


% Hint: get(hObject,'Value') returns toggle state of stimulateAtRandom


% --- Executes on button press in openNeuroscope.
function openNeuroscope_Callback(hObject, eventdata, handles)
% hObject    handle to openNeuroscope (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
try
    path=strsplit(handles.boardUI.paramsFile,filesep);
    mouseName=strsplit(path{end},'.');
    mouseName=mouseName{1};
    path=fullfile(path{1:end-1},'Neuroscope',mouseName);
    copyfile(path,handles.pathandname);
end
winopen(handles.pathandname);



% --- Executes on button press in offsetUpSup.
function offsetUpSup_Callback(hObject, eventdata, handles)
% hObject    handle to offsetUpSup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.OffsetAdjustSup=handles.boardUI.Plot.OffsetAdjustSup+1E-5;





% --- Executes on button press in offsetDownSup.
function offsetDownSup_Callback(hObject, eventdata, handles)
% hObject    handle to offsetDownSup (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.OffsetAdjustSup=handles.boardUI.Plot.OffsetAdjustSup-1E-5;
 


% --- Executes on button press in recomputeHypnogram.
function recomputeHypnogram_Callback(hObject, eventdata, handles)
% hObject    handle to recomputeHypnogram (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
allresultUp=recomputeHypnogram(handles.allresult,10^handles.gamma_threshold,10^handles.ratio_threshold);
handles.allresult=allresultUp;
guidata(hObject,handles);




% --- Executes on slider movement.
function slider2_Callback(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'Value') returns position of slider
%        get(hObject,'Min') and get(hObject,'Max') to determine range of slider

handles.boardUI.Plot.maxSleepstages = get(hObject, 'Value'); 


% --- Executes during object creation, after setting all properties.
function slider2_CreateFcn(hObject, eventdata, handles)
% hObject    handle to slider2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
set(hObject,'Max',eps);
set(hObject,'SliderStep', [eps, eps]);
% Hint: slider controls usually have a light gray background.
if isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor',[.9 .9 .9]);
end


% --- Executes on button press in changeChannels.
function changeChannels_Callback(hObject, eventdata, handles)
% hObject    handle to changeChannels (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.bullchannel=str2num(get(handles.bullChannelText,'String'))+1;
handles.boardUI.Plot.Thetachannel=str2num(get(handles.thetaChannelText,'String'))+1;


% --- Executes on button press in offsetUpDeep.
function offsetUpDeep_Callback(hObject, eventdata, handles)
handles.boardUI.Plot.OffsetAdjustDeep=handles.boardUI.Plot.OffsetAdjustDeep+1E-5;
% hObject    handle to offsetUpDeep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in offsetDownDeep.
function offsetDownDeep_Callback(hObject, eventdata, handles)
handles.boardUI.Plot.OffsetAdjustDeep=handles.boardUI.Plot.OffsetAdjustDeep-1E-5;
% hObject    handle to offsetDownDeep (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)


% --- Executes on button press in computeTransitions.
function computeTransitions_Callback(hObject, eventdata, handles)
% hObject    handle to computeTransitions (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
computeTransitions(handles.allresult(:,9));

% --- Executes during object creation, after setting all properties.
function Min_Delta_Duration_Edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Min_Delta_Duration_Edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes during object creation, after setting all properties.
function Max_Delta_Duration_Edit_CreateFcn(hObject, eventdata, handles)
% hObject    handle to Max_Delta_Duration_Edit (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% --- Executes on button press in Apply_Delta_Duration_push.
function Apply_Delta_Duration_push_Callback(hObject, eventdata, handles)
% hObject    handle to Apply_Delta_Duration_push (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.minDuration = str2num(get(handles.Min_Delta_Duration_Edit,'String'))/1000;
handles.boardUI.Plot.maxDuration = str2num(get(handles.Max_Delta_Duration_Edit,'String'))/1000;

function Max_Delta_Duration_Edit_Callback(hObject, eventdata, handles)

function Min_Delta_Duration_Edit_Callback(hObject, eventdata, handles)


% --- Executes on button press in createEvt.
function createEvt_Callback(hObject, eventdata, handles)
% hObject    handle to createEvt (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
%extension evt
extens = 'det'; %detection

%filename
filename = 'onlinedelta';

%evt
evt.time = handles.detections(:,1)/1E4; %in sec
for i=1:length(evt.time)
    evt.description{i}= 'online_delta';
end

%create file
CreateEvent(evt, filename, extens);
movefile('onlinedelta.evt.det',handles.pathandname);





function refractoryTimeDetection_Callback(hObject, eventdata, handles)
% hObject    handle to refractoryTimeDetection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
handles.boardUI.Plot.countermax_detection=str2num(get(hObject,'String'))/(1/20000)/60;
% Hints: get(hObject,'String') returns contents of refractoryTimeDetection as text
%        str2double(get(hObject,'String')) returns contents of refractoryTimeDetection as a double


% --- Executes during object creation, after setting all properties.
function refractoryTimeDetection_CreateFcn(hObject, eventdata, handles)
% hObject    handle to refractoryTimeDetection (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end


% --- Executes on button press in clearMeanDelta.
function clearMeanDelta_Callback(hObject, eventdata, handles)
% hObject    handle to clearMeanDelta (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
 handles.boardUI.Plot.meanDelta=zeros(2,handles.boardUI.Plot.nbrptbf+handles.boardUI.Plot.nbrptaft+1);
 handles.boardUI.Plot.numberDetection=0;
 

% --- Executes on button press in enableGM.
function fitGM_Callback(hObject, eventdata, handles)
% hObject    handle to fitGM (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called
fitGMM(handles.allresult,handles.boardUI.Plot);
