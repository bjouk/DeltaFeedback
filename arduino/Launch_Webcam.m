
clear all
%Connect to arduino hardware
a=arduino('/dev/cu.usbmodem1421','Uno');

%Configure 
configurePin(a,'D2','DigitalInput');
value = readDigitalPin(a,'D2');

cam = ipcam('http://192.168.24.221/mjpg/video.mjpg','mobs','mobs2013');
cam;
img=snapshot(cam);
figure();
image(img);
axis image

p=ginput(2);
% Get the x and y corner coordinates as integers
sp(1) = min(floor(p(1)), floor(p(2))); %xmin
sp(2) = min(floor(p(3)), floor(p(4))); %ymin
sp(3) = max(ceil(p(1)), ceil(p(2)));   %xmax
sp(4) = max(ceil(p(3)), ceil(p(4)));   %ymax
imshow(img(sp(2):sp(4), sp(1): sp(3),:));
selpath=uigetdir('Select video save path');

%Launch Webcam when trig is detected
while value == 0
    value = readDigitalPin(a,'D2');
end
recording=true;
vidWriter=VideoWriter(strcat('recording',now,'.avi'));
open(vidWriter);








    
