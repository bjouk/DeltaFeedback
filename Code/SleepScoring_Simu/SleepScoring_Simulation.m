function SleepScoring_Simulation


global Interface
global Data
global Filter 


%Data properties 
Data.fs = 20000;              %sampling frequency
Data.dt = 1/Data.fs;          %time between 2 samples
Data.DB_duration = 60;        %duration of datablocks (s) on which we compute the mean to downsample signals
Data.S = struct;              %structure containing signals


%Filters definitions
Filter.theta = designfilt('bandpassfir','FilterOrder',332,'CutoffFrequency1', 5,'CutoffFrequency2',10,'SampleRate',Data.fs/60);
Filter.delta = designfilt('bandpassfir','FilterOrder',332,'CutoffFrequency1', 2,'CutoffFrequency2',4,'SampleRate',Data.fs/60); 
Filter.gamma = designfilt('bandpassfir','FilterOrder',332,'CutoffFrequency1', 50,'CutoffFrequency2',70,'SampleRate',Data.fs/60); 


%Interface properties
Interface.refresh_period = 3;       %refresh period for plots updates

Interface.pos.window = [0 0 1 1];

Interface.pos.panel_lecture_controls = [0.775 0.65 0.2 0.25];
Interface.pos.btn_run = [0.05 0.5 0.4 0.4];
Interface.pos.btn_stop = [0.55 0.5 0.4 0.4];
Interface.pos.slider = [0 0 1 1];

Interface.pos.panel_time_selection = [0.8 0.05 0.15 0.45];
Interface.pos.btn_t0 = [0.2 0.75 0.6 0.2];
Interface.pos.btn_t1 = [0.2 0.55 0.6 0.2];
Interface.pos.btn_time_selection = [0.2 0.35 0.6 0.2];

Interface.pos.panel_signals_plots = [0.05 0.55 0.7 0.45];
Interface.pos.gamma_plot = [0.05 0.7 0.9 0.25];
Interface.pos.theta_plot = [0.05 0.4 0.9 0.25];
Interface.pos.delta_plot = [0.05 0.1 0.9 0.25];

Interface.pos.panel_sleep_scoring = [0.05 0.05 0.7 0.45];
Interface.pos.phase_space_plot = [0.35 0.45 0.5 0.5];
Interface.pos.gamma_distribution_plot = [0.35 0.05 0.5 0.35];
Interface.pos.ratio_distribution_plot = [0.15 0.45 0.15 0.5];

Interface.pos.slider = [0.3 0.02 0.4 0.1];

Interface.window = figure('MenuBar','none','Units','normalized','Position',Interface.pos.window);


%menu
Interface.menu.files = uimenu(Interface.window,'Text','Files');
Interface.menu.load = uimenu(Interface.menu.files,'Text','Load S1','MenuSelectedFcn',@Load_S1);
Interface.menu.load = uimenu(Interface.menu.files,'Text','Load S2','MenuSelectedFcn',@Load_S2);


%make interface
Interface.panel_lecture_controls = uipanel('Parent',Interface.window,'Title','Lecture Controls','TitlePosition','centertop','Units','normalized','Position',Interface.pos.panel_lecture_controls);
Interface.btn_run = uicontrol('Parent',Interface.panel_lecture_controls,'Units','normalized','Style','PushButton','String','Run','Position',Interface.pos.btn_run,'Callback',@Btn_Run);
Interface.btn_stop = uicontrol('Parent',Interface.panel_lecture_controls,'Units','normalized','Style','PushButton','String','Stop','Position',Interface.pos.btn_stop,'Callback',@Btn_Stop);

Interface.panel_time_selection = uipanel('Parent',Interface.window,'Title','Time Selection','TitlePosition','centertop','Units','normalized','Position',Interface.pos.panel_time_selection);
Interface.btn_t0 = uicontrol('Parent',Interface.panel_time_selection,'Units','normalized','Style','edit','String','t0','Position',Interface.pos.btn_t0,'Callback',@Btn_T0);
Interface.btn_t1 = uicontrol('Parent',Interface.panel_time_selection,'Units','normalized','Style','edit','String','t1','Position',Interface.pos.btn_t1,'Callback',@Btn_T1);
Interface.btn_time_selection = uicontrol('Parent',Interface.panel_time_selection,'Units','normalized','Style','PushButton','String','Time Selection','Position',Interface.pos.btn_time_selection,'Callback',@Btn_Time_Selection);

Interface.panel_signals_plots = uipanel('Parent',Interface.window,'Title','Signals','TitlePosition','centertop','Units','normalized','Position',Interface.pos.panel_signals_plots);
Interface.gamma_plot = axes('Parent',Interface.panel_signals_plots,'Units','normalized','Position',Interface.pos.gamma_plot,'Visible','on','HandleVisibility','on');
Interface.theta_plot = axes('Parent',Interface.panel_signals_plots,'Units','normalized','Position',Interface.pos.theta_plot,'Visible','on','HandleVisibility','on');
Interface.delta_plot = axes('Parent',Interface.panel_signals_plots,'Units','normalized','Position',Interface.pos.delta_plot,'Visible','on','HandleVisibility','on');

Interface.panel_sleep_scoring = uipanel('Parent',Interface.window,'Title','Sleep Scoring','TitlePosition','centertop','Units','normalized','Position',Interface.pos.panel_sleep_scoring);
Interface.phase_space_plot = axes('Parent',Interface.panel_sleep_scoring,'Units','normalized','Position',Interface.pos.phase_space_plot,'Visible','on','HandleVisibility','on');
Interface.gamma_distribution_plot = axes('Parent',Interface.panel_sleep_scoring,'Units','normalized','Position',Interface.pos.gamma_distribution_plot,'Visible','on','HandleVisibility','on');
Interface.ratio_distribution_plot = axes('Parent',Interface.panel_sleep_scoring,'Units','normalized','Position',Interface.pos.ratio_distribution_plot,'Visible','on','HandleVisibility','on');


Interface.slider = uicontrol('Parent',Interface.panel_lecture_controls,'Units','normalized','Style','slider','Position',Interface.pos.slider,'Visible','on','HandleVisibility','on','Callback',@Slider);
set(Interface.slider, 'Min', 0.1);
set(Interface.slider, 'Max', 6.1);
set(Interface.slider, 'Value', 3);
set(Interface.slider, 'SliderStep', [1/7 2/7]);


%Create a timer object to fire at 3 sec intervals
%Specify function update_display for its start and run callbacks

Interface.timer = timer(...
    'ExecutionMode', 'fixedRate', ...           % Run timer repeatedly
    'Period', 3, ...                            % Initial period is 3 sec.
    'TimerFcn', {@update_display});   % Specify callback function

end


%functions

function Load_S1(~,~)
global Data

[FileName,PathName,FilterIndex] = uigetfile('.mat');


Data.S = setfield(Data.S,'S1',load(strcat(PathName,FileName)))

end


function Load_S2(~,~)
global Data

[FileName,PathName,FilterIndex] = uigetfile('.mat');
Data.S = setfield(Data.S,'S2',load(strcat(PathName,FileName)))


end


function Btn_T0(~,~)
global Interface
global Data

Data.T0 = str2double(get(Interface.btn_t0,'String'));

end


function Btn_T1(~,~)
global Interface
global Data

Data.T1 = str2double(get(Interface.btn_t1,'String'));

end


function Btn_Time_Selection(~,~)
global Data
global Interface

Data.S.S1.gamma = Data.S.S1.gamma(Data.T0:Data.T1);                       %gamma signal time selection 
Data.S.S2.thetadelta = Data.S.S2.thetadelta(Data.T0:Data.T1);             %thetadelta signal time selection

%initializations for update_display fuction
Data.stop_time = size(Data.S.S1.gamma,1)/Data.fs;                         %signal selection time length
Data.t = [0:Data.dt:Data.stop_time-Data.dt];                              %time vector
Data.N_cycles = Data.stop_time/Interface.refresh_period;                  %Total number of cycles
Data.current_cycle = 0;                                                   %Current cycle initialization
Data.subscripts = [1:Interface.refresh_period*Data.fs];                   %cycle points subscripts 
Data.t_tmp = Interface.refresh_period/2;
Data.t_tmp = [Data.t_tmp-(Interface.refresh_period/2):Data.dt:Data.t_tmp+(Interface.refresh_period/2)-Data.dt];
Data.t_tmp_plot = Data.t_tmp(1:Data.DB_duration:end);                     

end


function Btn_Run(~,~)
global Interface

if strcmp(get(Interface.timer, 'Running'), 'off')
    start(Interface.timer);
end

Interface.refresh_period = get(Interface.slider,'value') - mod(get(Interface.slider,'value'),.01);
set(Interface.timer,'Period',Interface.refresh_period);

end


function Slider(~,~)
global Interface
global Data

Interface.refresh_period = get(Interface.slider,'value') - mod(get(Interface.slider,'value'),.01);

if strcmp(get(Interface.timer, 'Running'), 'on')
    stop(Interface.timer);
    set(Interface.timer,'Period',Interface.refresh_period)
    start(Interface.timer)
else               % If timer is stopped, reset its period only.
    set(Interface.timer,'Period',Interface.refresh_period)
end

end


function update_display(~,~)

global Data 
global Interface 
global Filter

if Data.current_cycle < Data.N_cycles
    
    %Update Data 
    Data.S.S1.gamma_temp = Data.S.S1.gamma(Data.subscripts);                                 %signal selection
    Data.S.S2.thetadelta_temp = Data.S.S2.thetadelta(Data.subscripts);                       %signal selection
    
    Data.S.S1.gamma_temp = movmean(Data.S.S1.gamma_temp,Data.DB_duration);              %mean on the DataBlock duration
    Data.S.S2.thetadelta_temp = movmean(Data.S.S2.thetadelta_temp,Data.DB_duration);    %mean on the DataBlock duration
    
    Data.S.S1.gamma_temp = Data.S.S1.gamma_temp(1:Data.DB_duration:end);                %down sampling to replace each DataBlock by one point
    Data.S.S2.thetadelta_temp = Data.S.S2.thetadelta_temp(1:Data.DB_duration:end);      %down sampling to replace each DataBlock by one point
  
    %filtering 
    Data.S.S1.gamma_temp_filtered = filtfilt(Filter.gamma,Data.S.S1.gamma_temp);
    Data.S.S2.theta_temp_filtered = filtfilt(Filter.theta,Data.S.S2.thetadelta_temp);
    Data.S.S2.delta_temp_filtered = filtfilt(Filter.delta,Data.S.S2.thetadelta_temp);
    
    %hilebert transforms
    Data.S.S1.hilbert_gamma = abs(hilbert(Data.S.S1.gamma_temp_filtered));
    Data.S.S1.gamma_power(Data.current_cycle+1) = abs(mean(Data.S.S1.hilbert_gamma));
    
    Data.S.S2.hilbert_theta = abs(hilbert(Data.S.S2.theta_temp_filtered));
    Data.S.S2.theta_power(Data.current_cycle+1) = abs(mean(Data.S.S2.hilbert_theta));
    
    Data.S.S2.hilbert_delta = abs(hilbert(Data.S.S2.delta_temp_filtered));
    Data.S.S2.delta_power(Data.current_cycle+1) = abs(mean(Data.S.S2.hilbert_delta));
    
    %update plots 
    
    %update signal plots
    axes(Interface.gamma_plot);
    plot(Data.t_tmp_plot,Data.S.S1.gamma_temp,'b',Data.t_tmp_plot,Data.S.S1.gamma_temp_filtered,'b');
    ylabel('Gamma Signal');
    set(gca,'xtick',[])
    
    axes(Interface.theta_plot);
    plot(Data.t_tmp_plot,Data.S.S2.thetadelta_temp,'r',Data.t_tmp_plot,Data.S.S2.theta_temp_filtered,'r');
    ylabel('Theta Signal');
    set(gca,'xtick',[])
    
    axes(Interface.delta_plot);
    plot(Data.t_tmp_plot,Data.S.S2.thetadelta_temp,'g',Data.t_tmp_plot,Data.S.S2.delta_temp_filtered,'g');
    xlabel('time (s)');
    ylabel('Delta Signal');
    
    
    %update phase space 
    Data.S.S1.gamma_power = log10(abs(Data.S.S1.gamma_power));
    Data.S.S2.ratio_power = log10(abs(Data.S.S2.theta_power./Data.S.S2.delta_power));
    
    axes(Interface.phase_space_plot);
    plot(Data.S.S1.gamma_power,Data.S.S2.ratio_power,'*');
    xlabel('Gamma Power');
    ylabel('Theta/Delta Ratio');
    xlim([(min(Data.S.S1.gamma_power)-1) (max(Data.S.S1.gamma_power)+1)]);
    ylim([(min(Data.S.S2.ratio_power)-1) (max(Data.S.S2.ratio_power)+1)]);
    
    %update distributions
    [Data.S.S1.gamma_prob,Data.S.S1.gamma_value] = ksdensity (Data.S.S1.gamma_power);
    [Data.S.S2.ratio_prob,Data.S.S2.ratio_value] = ksdensity (Data.S.S2.ratio_power); 

    axes(Interface.gamma_distribution_plot);
    plot(Data.S.S1.gamma_value,Data.S.S1.gamma_prob);
    xlim([(min(Data.S.S1.gamma_power)-1) (max(Data.S.S1.gamma_power)+1)]);
    
    axes(Interface.ratio_distribution_plot);
    plot(Data.S.S2.ratio_prob,Data.S.S2.ratio_value);
    ylim([(min(Data.S.S2.ratio_power)-1) (max(Data.S.S2.ratio_power)+1)]);
    
    
    %implement new cycle
    Data.current_cycle=Data.current_cycle+1;
    Data.t_tmp_plot=Data.t_tmp_plot+Interface.refresh_period;
    Data.subscripts=Data.subscripts+(Interface.refresh_period*Data.fs);
    
    disp(Data.current_cycle);
    
end


end


function Btn_Stop(~,~)
global Interface
if strcmp(get(Interface.timer, 'Running'), 'on')
    stop(Interface.timer);
end

end


