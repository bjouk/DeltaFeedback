clear all
%Connect to arduino hardware
a=arduino('/dev/cu.usbmodem1421','Uno');

%Configure 
configurePin(a,'D2','DigitalInput');
value = readDigitalPin(a,'D2');

cam = ipcam('http://192.168.24.221/mjpg/1/video.mjpg','mobs','mobs2013');
preview(cam);

%Launch Webcam when trig is detected
while value == 0
    value = readDigitalPin(a,'D2');
end






    
