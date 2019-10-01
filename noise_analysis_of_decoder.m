[y,Fs1]=audioread('Safe Mode HDSDR_20141223_230915Z_145980kHz_AF.wav');
amp=0.06; %By changing this we can change the noise amplitude added to the set
noise =amp*randn(size(y));
y9=y+noise;
frame_sync='0011111010';
u=lowpass(y9,200,48000);
y1=u(557207:1026196);
Ts=1/Fs1;
sample_window_length=1800;
sample_bucket_length=240;
maxValue=zeros(1,sample_window_length);
minValue=zeros(1,sample_window_length);
[ZeroValue,datavalues,averageMax,averageMin,maxValue,minValue]=bucketData(y1);
[averageTransition,threshold,transitionPoint]=recoverClockOffset(averageMax,averageMin,ZeroValue,datavalues);
clockAdvance=recoverClock(averageTransition);
y2=u((557207+clockAdvance):1026196+clockAdvance);
[ZeroValue1,datavalues1,averageMax1,averageMin1]=bucketData(y2);
[middleSample1,b1]=sampleBuckets(datavalues1,averageMax1,averageMin1,ZeroValue1);
str='9'; %This is simply an initialization.
for i=1:length(middleSample1)
    s(i)=string(middleSample1(i));
    str=strcat(str,s(i));
end
str1=convertStringsToChars(str);
k=strfind(str1,'0011111010');
%[ZeroValue2,datavalues2,averageMax2,averageMin2]=bucketData(p);
%[middleSample2,b2]=sampleBuckets(datavalues2,averageMax2,averageMin2,ZeroValue2);
% subplot(2,1,1);
% plot(y1);
% subplot(2,1,2);
% plot(y2);
% for i=1:length(y)
%     if(y(i)>0)
%         y(i)=1;
%     else
%         y(i)=0;
%     end
% end
function [ZeroValue,datavalues,averageMax,averageMin,maxValue,minValue] = bucketData(dataValue)
k=1;
sample_window_length=1800;
sample_bucket_length=240;
maxValue=zeros(1,sample_window_length);
minValue=zeros(1,sample_window_length);
averageMax=0;
averageMin=0;
for i=1:sample_window_length
    minValue(i)=10;
    for j=1:sample_bucket_length
        datavalues(i,j)=dataValue(k);
        if(dataValue(k)> maxValue(i))
            maxValue(i)=dataValue(k); 
        end
        if(dataValue(k)<minValue(i))
            minValue(i)=dataValue(k);
        end 
        k=k+1;
    end
    averageMax=averageMax+maxValue(i);
    averageMin=averageMin+minValue(i);
    
end
averageMax=averageMax/sample_window_length;
averageMin=averageMin/sample_window_length;
ZeroValue=(averageMax+averageMin)/2;
end
function [averageTransition,threshold,transitionPoint] = recoverClockOffset(averageMax,averageMin,zeroValue,datavalues)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
sample_window_length=1800;
sample_bucket_length=240;
transitionPoint=zeros(1,sample_window_length);
averageTransition=0;
numberOfTransitions=0;
initialValue=0;
foundTransition=boolean(false);
clock_recovery_zero_threshold=20;
threshold=(averageMax-averageMin)/clock_recovery_zero_threshold;
for i=1:sample_window_length
    %Defining Initial value based on the sample of previous bucket
if(i>1)
    if(datavalues(i-1,sample_bucket_length-1)>=zeroValue+threshold)
        initialValue=1;
    else
        initialValue=0;
    end
end
foundTransition=boolean(false);
for j=1:sample_bucket_length
    if(datavalues(i,j)>(zeroValue+threshold) && initialValue==0)
      if(~foundTransition)  
          transitionPoint(i)=j;
          initialValue=1;
          foundTransition=boolean(true);
          numberOfTransitions=numberOfTransitions+1;
      end
    end
    
    if(datavalues(i,j)<(zeroValue-threshold) && initialValue==1)
        if(~foundTransition)  
          transitionPoint(i)=j;
          initialValue=0;
          foundTransition=boolean(true);
          numberOfTransitions=numberOfTransitions+1;
        end
    end

end
averageTransition=averageTransition+transitionPoint(i);
       
end
averageTransition=averageTransition/numberOfTransitions;
end
function [clockAdvance] = recoverClock(averageTransition)
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here
sample_bucket_length=240;
clock_tolerance=20;
if(averageTransition>sample_bucket_length/clock_tolerance && averageTransition<sample_bucket_length-sample_bucket_length/clock_tolerance)
    clockAdvance=(averageTransition-sample_bucket_length/clock_tolerance);
else
    clockAdvance=0;
end
end
function [middleSample,b] = sampleBuckets(datavalues,averageMax,averageMin,ZeroValue)
%UNTITLED3 Summary of this function goes here
%   Detailed explanation goes here
sample_width=2;
sample_window_length=1800;
sample_bucket_length=240;
lastBitValue=0;
sample_number=0;
bit_distance_threshold_percent=15;
middleSample=zeros(1,sample_window_length);
lastbit=boolean(false); 
for i=1:sample_window_length
    sample_number=sample_number+1;
    sample_sum=0;
    samples=0;
    e=1;
    for s=((sample_bucket_length/2)-sample_width):1:((sample_bucket_length/2)+sample_width)
        sample_sum=sample_sum+datavalues(i,s);
        samples=samples+1;
        b(i,e)=datavalues(i,s);
        e=e+1;
    end
    sample_sum=sample_sum/samples;
    bit_distance=abs(lastBitValue-sample_sum);
    bitheight=averageMax-averageMin;
    if(bitheight==0)
        bitheight=1;
    end
    movePercent=bit_distance*100/bitheight;
    if(sample_sum>=ZeroValue)
        middleSample(i)=boolean(true);
    else
        middleSample(i)=boolean(false);
    end
    lastBitValue=sample_sum;
    lastBit=middleSample(i);
end
end
