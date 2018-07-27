function CreateEvent(evt,basename,eventname)

% CreateEvent(evt,basename,eventname)
%       evt must be a structure
%       evt.time is a vector of times (in sec)
%       evt.description is a cell array with the description corresponding to each time in the vector evt.description for each
%
%    Usage: Exemple of generation of evt.description (note that the descritpion
%    can be different for instance : start, peak, end ... of ripples
%
%
%%
% EXAMPLE
%       basename = 'manipe_yyyymmdd';
%       evt.time = tmp_ripples;
%       for i=1:length(evt.time)
%           evt.description{i}='ripples';
%       end
%       CreateEvent(evt,basename,'ripples');
%


if length(eventname)~=3
    disp('eventname must be 3 letters/digits')
    
else
    
    SaveEvents(strcat(basename,'.evt.', eventname),evt)
    %save(strcat(basename,'.mat'), 'evt');
    
end

