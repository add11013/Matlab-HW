clear
close all;
clc
tic

%data prepare
temp=xlsread('Data_set.csv');

%% data1
DataOfTest=temp(0.7*length(temp):length(temp),1);
DataOfTrain=temp(1:0.7*length(temp),1);

NumberOfTestPoint=length(DataOfTest);
NumberOfTrainPoint=length(DataOfTrain);
NumberOfAllPoint=NumberOfTrainPoint+NumberOfTestPoint;

x=linspace(1,NumberOfAllPoint,NumberOfAllPoint);
DATA1=[(DataOfTrain(:,1));(DataOfTest(:,1))];
yMean=mean(DATA1);
figure(1);
hold on
plot(x,DATA1);
% substractive clustering
h1OfDATA1=DATA1(1:NumberOfTrainPoint-2);
h2OfDATA1=DATA1(2:NumberOfTrainPoint-1);
h1CenterOfDATA1=subclust(h1OfDATA1,0.29);
h2CenterOfDATA1=subclust(h2OfDATA1,0.29);

%% data2
DataOfTest=temp(0.7*length(temp):length(temp),2);
DataOfTrain=temp(1:0.7*length(temp),2);

x=linspace(1,NumberOfAllPoint,NumberOfAllPoint);
DATA2=[(DataOfTrain(:,1));(DataOfTest(:,1))];
yMean=mean(DATA2);
plot(x,DATA2);
% substractive clustering
h1OfDATA2=DATA2(1:NumberOfTrainPoint-2);
h2OfDATA2=DATA2(2:NumberOfTrainPoint-1);
h1CenterOfDATA2=subclust(h1OfDATA2,0.29);
h2CenterOfDATA2=subclust(h2OfDATA2,0.29);

%% combine DATA
h1=DATA1(1:NumberOfTrainPoint-2)+j*DATA2(1:NumberOfTrainPoint-2);
h2=DATA1(2:NumberOfTrainPoint-1)+j*DATA2(2:NumberOfTrainPoint-1);
h1Center=h1CenterOfDATA1+j*h1CenterOfDATA2;
h2Center=h2CenterOfDATA1+j*h2CenterOfDATA2;
y=DATA1+j*DATA2;

%% formation matrix
count=1;
for i=1:length(h1Center)
    for ii=1:length(h2Center)
        formationMatrix(count,1)=i;
        formationMatrix(count,2)=ii;
        count=count+1;
    end
end
NumberOfPremiseParameters=(length(h1Center)+length(h2Center))*2;
NumberOfPremise=(length(h1Center)+length(h2Center));

%% firing strength
for i=1:NumberOfTrainPoint-2
    for rule=1:length(formationMatrix)
        BetaOfFormationMatrix(rule,i)=gaussmf(h1(i),[h1Center(formationMatrix(rule,1)),std(h1)])*gaussmf(h2(i),[h2Center(formationMatrix(rule,2)),std(h2)]);
    end
end

%% cube selection
bb=1;
delFor=0;
for rule=1:length(formationMatrix)
    treshold=0.3*std(reshape(BetaOfFormationMatrix,length(formationMatrix)*(NumberOfTrainPoint-2),1));
    if std(BetaOfFormationMatrix(rule,:))<treshold
        bye(bb)=rule;
        bb=bb+1;
        delFor=1;
    end
end
if delFor==1
    bb=1;
    i=bye(bb);
    formationMatrix(i,:)=[];
    bye(bb)=[];
    while length(bye)~=0
        i=bye(bb);
        formationMatrix(i-1,:)=[];
        bye(bb)=[];
    end
end


%% PSO parameters
  PSO.w=0.8;
  PSO.c1=2;
  PSO.c2=2;
  PSO.s1=rand(1);
  PSO.s2=rand(1);
  PSO.swarm_size=64;
  PSO.iterations=30;
  %initialize the particles
  for i=1:PSO.swarm_size
    for ii=1:NumberOfPremiseParameters
      swarm(i).Position(ii)=randn*yMean*1000;
    end
    swarm(i).Velocity(1:NumberOfPremiseParameters)=0;
    swarm(i).pBestPosition=swarm(i).Position;
    swarm(i).pBestDistance=1e12;
  end
  PSO.gBestPosition=swarm(1).Position;
  PSO.gBestDistance=1e12;
  
  
%% RLSE parameters
NumberOfConsParameters=3*length(formationMatrix);
for i=1:PSO.swarm_size
    swarm(i).RLSE.theta(1:NumberOfConsParameters,1)=0;
    swarm(i).RLSE.P=1e9*eye(NumberOfConsParameters);
end

%% main loop
for ite=1:PSO.iterations
  for i=1:PSO.swarm_size
      %move
      swarm(i).Position=swarm(i).Position+swarm(i).Velocity;
      Iteration(ite).beta=[];
        for jj=1:NumberOfTrainPoint-2
            %Firing Strength
            swarm(i).u1(jj)=;
            j1=1;
            for number=1:NumberOfPremiseParameters/4
                termSet{1}(number)={[swarm(i).Position(j1:j1+1)]};
                j1=j1+2;
            end
            for number=1:NumberOfPremiseParameters/4
                termSet{2}(number)={swarm(i).Position(j1:j1+1)};
                j1=j1+2;
            end
            for rule=1:length(formationMatrix)
                Iteration(ite).beta(rule,jj)=gaussmf(h1(jj),termSet{1}{formationMatrix(rule,1)})*gaussmf(h2(jj),termSet{2}{formationMatrix(rule,2)});
            end
        end

      %Normalization
        for rule=1:length(formationMatrix)
            g(rule)=sum(Iteration(ite).beta(rule,:))/sum(Iteration(ite).beta(:));
        end

        for jj=1:NumberOfTrainPoint-2
            TMP0=[];
            for k=1:length(formationMatrix)
                TMP=[g(k) g(k)*y(jj) g(k)*y(jj+1)];
                TMP0=[TMP0 TMP];
            end
             swarm(i).RLSE.A(jj,:)=TMP0;
        end
        b=transpose(swarm(i).RLSE.A);
        for k=0:(NumberOfTrainPoint-2)-1
            swarm(i).RLSE.P=swarm(i).RLSE.P-(swarm(i).RLSE.P*b(:,k+1)*transpose(b(:,k+1))*swarm(i).RLSE.P)/(1+transpose(b(:,k+1))*swarm(i).RLSE.P*b(:,k+1));
            swarm(i).RLSE.theta=swarm(i).RLSE.theta+swarm(i).RLSE.P*b(:,k+1)*(y(k+3)-transpose(b(:,k+1))*swarm(i).RLSE.theta);
        end
      %new_yHead(output)
        for jj=1:NumberOfTrainPoint-2
            swarm(i).yHead(jj,1)=swarm(i).RLSE.A(jj,:)*swarm(i).RLSE.theta;  %y
           %caculate error
            e(jj,1)=(y(jj+2)-swarm(i).yHead(jj,1))*conj(y(jj+2)-swarm(i).yHead(jj,1));  % target-yHead
        end
      %mse index
        swarm(i).rmse=sqrt(sum(e)/(NumberOfTrainPoint-2));
      %pbest
        if swarm(i).rmse<swarm(i).pBestDistance
            swarm(i).pBestPosition=swarm(i).Position;        %update pbest position
            swarm(i).pBestDistance=swarm(i).rmse;            %update pbest pbest mse index
        end
      %gbest
        if swarm(i).rmse<PSO.gBestDistance
            gBest=i;                             %update which one is gbest
            PSO.gBestDistance=swarm(i).rmse;         %update distance of gbest
            PSO.gBestPosition=swarm(i).Position;  
        end

      %update velocity
      swarm(i).Velocity=PSO.w*swarm(i).Velocity+PSO.c1*PSO.s1*(swarm(i).pBestPosition-swarm(i).Position)+PSO.c2*PSO.s2*(PSO.gBestPosition-swarm(i).Position);
  end
  PSO.plotRMSE(ite) = PSO.gBestDistance;
end

%% result
% OUTPUT and Target
      figure(2)
      subplot(1,2,1)
          semilogy(PSO.plotRMSE);
          legend('Learning Curve');
          xlabel('iterations');
          ylabel('semilogy(rmse)');
      subplot(1,2,2)
          plot(1:PSO.iterations,PSO.plotRMSE,'x');
          legend('Learning Curve');
          xlabel('iterations');
          ylabel('rmse');
      figure(1);
        x=linspace(x(3),x(NumberOfTrainPoint),NumberOfTrainPoint-2);
        plot(x,swarm(gBest).yHead,'--');
        plot(x,imag(swarm(gBest).yHead),'--');
%% test
        x=linspace(NumberOfTrainPoint+2,NumberOfAllPoint+1,NumberOfTestPoint);
        BetaOfTesting=[];
        testh1=y(NumberOfTrainPoint-1:NumberOfAllPoint-2);
        testh2=y(NumberOfTrainPoint:NumberOfAllPoint-1);
        for jj=1:NumberOfTestPoint
            %IFpart(Rule)
            j1=1;
            for number=1:NumberOfPremiseParameters/4
                termSet{1}(number)={[swarm(gBest).Position(j1:j1+1)]};
                j1=j1+2;
            end
            for number=1:NumberOfPremiseParameters/4
                termSet{2}(number)={swarm(gBest).Position(j1:j1+1)};
                j1=j1+2;
            end
            BetaOfTesting=[];
            for rule=1:length(formationMatrix)
                BetaOfTesting(rule,jj)=gaussmf(testh1(jj),termSet{1}{formationMatrix(rule,1)})*gaussmf(testh2(jj),termSet{2}{formationMatrix(rule,2)});
            end
        end
        
        %new_yHead(output)
        for rule=1:length(formationMatrix)
            g(rule)=sum(BetaOfTesting(rule,:))/sum(BetaOfTesting(:));
        end
        for jj=1:NumberOfTestPoint
            TMP1=[];
            for k=1:length(formationMatrix)
                TMP=[g(k) g(k)*y(NumberOfTrainPoint+jj-1) g(k)*y(NumberOfTrainPoint+jj)];
                TMP1=[TMP1 TMP];
            end
            A(jj,:)=TMP1;
            output2(jj,1)=A(jj,:)*swarm(gBest).RLSE.theta;  %y
        end
        for jj=1:NumberOfTestPoint
            PSO.test.e(jj)=(y(jj+NumberOfTrainPoint-1)-output2(jj,1))^2;
        end
            PSO.test.rmse=sqrt(sum(PSO.test.e)/(NumberOfTestPoint));
        plot(x,output2,'r--');
        plot(x,imag(output2),'r--');

toc
