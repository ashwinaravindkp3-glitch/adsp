clc ;
clear all;
close all;


T=0.1
fs=1000
fc=50;
t=0:1/fs:T
filter_order=4;
[b,a] = butter(filter_order,fc/(fs/2),"low");


omega = 2*pi*50; 
x1 = 10*sin(omega*t) + 3*sin(3*omega*t);
subplot(3,1,1)
plot(t,x1)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%x2=awgn(x1, -100, 'measured');
x2=0.1*rand(1,length(t))
subplot(3,1,2)
plot(t,x2)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
y=x1+x2
subplot(3,1,3)
plot(t,y)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
figure()
removed= filter(b, a, y);
plot(t,removed)

e = y-x2
