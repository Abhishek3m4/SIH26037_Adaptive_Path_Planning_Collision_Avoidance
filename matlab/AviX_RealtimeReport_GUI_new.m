function AviX_RealtimeReport_GUI
% AVIX_REALTIME_REPORT_GUI
% Legacy-compatible standalone AviX real-time simulation report GUI.
%
% Run:
%   AviX_RealtimeReport_GUI
%
% IMPORTANT:
% This version intentionally uses classic MATLAB graphics
% (figure/uicontrol/axes) instead of uifigure/uilabel/uigridlayout.
% It therefore works in MATLAB installations where App Designer UI
% functions such as uilabel are unavailable.
%
% The current version generates realistic demonstration telemetry for:
%   Ego vehicle + Lead vehicle + Merging vehicle.
% Replace updateSimulationData() later with RoadRunner runtime data.
%
% The values are engineering-style demonstration values, NOT measured
% RoadRunner results.

clc;

% ========================= CONFIG =============================
DT = 0.10;
TMAX = 30;

% ========================= STATE ===============================
t = 0;
running = false;
timerObj = [];

egoSpeed = 7.8;       % m/s
egoAccel = 0;
steering = 0;

leadDist = 38;
leadRelV = -0.4;

mergeDist = 28;
mergeRelV = -0.8;
mergeLat = 5.0;

state = 'CRUISE';
risk = 'LOW';
decision = 'MAINTAIN';
replanning = false;

egoX = 0;
egoY = 0;
leadX = 38;
leadY = 0;
mergeX = 28;
mergeY = 5;

H = struct( ...
    't',[],'speed',[],'accel',[],'steer',[], ...
    'leadDist',[],'leadRelV',[],'leadTTC',[], ...
    'mergeDist',[],'mergeLat',[],'mergeTTC',[], ...
    'riskNum',[],'stateNum',[], ...
    'egoX',[],'egoY',[], ...
    'leadX',[],'leadY',[], ...
    'mergeX',[],'mergeY',[]);

% ========================= MAIN FIGURE ========================
fig = figure( ...
    'Name','AviX | Adaptive Road Intelligence - Simulation Report', ...
    'NumberTitle','off', ...
    'Color',[0.035 0.045 0.065], ...
    'Position',[30 30 1500 900], ...
    'MenuBar','none', ...
    'ToolBar','none', ...
    'Resize','on', ...
    'CloseRequestFcn',@closeFigure);

% Header
uicontrol(fig,'Style','text', ...
    'String','AVIX  |  ADAPTIVE ROAD INTELLIGENCE', ...
    'Units','normalized','Position',[0.015 0.945 0.62 0.045], ...
    'BackgroundColor',[0.045 0.065 0.095], ...
    'ForegroundColor',[0.94 0.97 1], ...
    'FontSize',20,'FontWeight','bold', ...
    'HorizontalAlignment','left');

uicontrol(fig,'Style','text', ...
    'String','Indian Urban Junction  |  Ego + Lead + Merging Vehicle  |  Closed-Loop Simulation Report', ...
    'Units','normalized','Position',[0.015 0.915 0.70 0.028], ...
    'BackgroundColor',[0.045 0.065 0.095], ...
    'ForegroundColor',[0.60 0.72 0.84], ...
    'FontSize',10,'HorizontalAlignment','left');

startBtn = uicontrol(fig,'Style','pushbutton', ...
    'String','START SIMULATION', ...
    'Units','normalized','Position',[0.78 0.925 0.09 0.045], ...
    'FontSize',10,'FontWeight','bold','Callback',@startSimulation);

resetBtn = uicontrol(fig,'Style','pushbutton', ...
    'String','RESET', ...
    'Units','normalized','Position',[0.88 0.925 0.07 0.045], ...
    'FontSize',10,'FontWeight','bold','Callback',@resetSimulation);

% KPI panels
kpi1 = makeKPI([0.015 0.825 0.13 0.075],'DRIVE MODE','CRUISE');
kpi2 = makeKPI([0.155 0.825 0.13 0.075],'EGO SPEED','28.1 km/h');
kpi3 = makeKPI([0.295 0.825 0.13 0.075],'LEAD DISTANCE','38.0 m');
kpi4 = makeKPI([0.435 0.825 0.13 0.075],'MIN TTC','INF');
kpi5 = makeKPI([0.575 0.825 0.13 0.075],'MERGE RISK','LOW');
kpi6 = makeKPI([0.715 0.825 0.13 0.075],'PLANNING','READY');
kpi7 = makeKPI([0.855 0.825 0.13 0.075],'SAFETY INDEX','96 / 100');

% Main axes
axSpeed = axes('Parent',fig,'Position',[0.03 0.56 0.22 0.23]);
axDist  = axes('Parent',fig,'Position',[0.28 0.56 0.22 0.23]);
axTTC   = axes('Parent',fig,'Position',[0.53 0.56 0.22 0.23]);
axRisk  = axes('Parent',fig,'Position',[0.78 0.56 0.19 0.23]);

axBEV   = axes('Parent',fig,'Position',[0.04 0.15 0.45 0.32]);
axState = axes('Parent',fig,'Position',[0.54 0.15 0.43 0.14]);
axLat   = axes('Parent',fig,'Position',[0.54 0.33 0.43 0.14]);

styleAxes(axSpeed,'EGO SPEED');
styleAxes(axDist,'RELATIVE DISTANCE');
styleAxes(axTTC,'TTC / COLLISION RISK');
styleAxes(axRisk,'RISK LEVEL');
styleAxes(axBEV,'TOP VIEW - DRIVABLE SPACE / ACTORS');
styleAxes(axState,'DECISION STATE');
styleAxes(axLat,'MERGING VEHICLE LATERAL MOTION');

% Status text area
statusPanel = uipanel(fig,'Title','LIVE HOST VEHICLE STATUS', ...
    'Units','normalized','Position',[0.015 0.02 0.30 0.105], ...
    'BackgroundColor',[0.055 0.07 0.10], ...
    'ForegroundColor',[0.88 0.93 1], ...
    'FontWeight','bold');

statusText = uicontrol(statusPanel,'Style','text', ...
    'String',sprintf(['Drive Mode: CRUISE     Replanning: STANDBY     Path Valid: YES\n' ...
                      'Steering: 0.0 deg     Acceleration: 0.00 m/s^2     Gear: D\n' ...
                      'Decision: MAINTAIN']), ...
    'Units','normalized','Position',[0.03 0.08 0.94 0.84], ...
    'BackgroundColor',[0.055 0.07 0.10], ...
    'ForegroundColor',[0.82 0.90 1], ...
    'FontSize',10,'HorizontalAlignment','left');

riskPanel = uipanel(fig,'Title','RISK ASSESSMENT', ...
    'Units','normalized','Position',[0.33 0.02 0.30 0.105], ...
    'BackgroundColor',[0.055 0.07 0.10], ...
    'ForegroundColor',[0.88 0.93 1], ...
    'FontWeight','bold');

riskText = uicontrol(riskPanel,'Style','text', ...
    'String',sprintf(['Lead TTC: INF     Lead Risk: LOW\n' ...
                      'Merge TTC: 35.0 s     Merge Risk: LOW\n' ...
                      'Predicted Occupancy: FREE CORRIDOR     Overall Risk: LOW']), ...
    'Units','normalized','Position',[0.03 0.08 0.94 0.84], ...
    'BackgroundColor',[0.055 0.07 0.10], ...
    'ForegroundColor',[0.82 0.90 1], ...
    'FontSize',10,'HorizontalAlignment','left');

paramPanel = uipanel(fig,'Title','SIMULATION PARAMETERS', ...
    'Units','normalized','Position',[0.65 0.02 0.335 0.105], ...
    'BackgroundColor',[0.055 0.07 0.10], ...
    'ForegroundColor',[0.88 0.93 1], ...
    'FontWeight','bold');

paramText = uicontrol(paramPanel,'Style','text', ...
    'String',sprintf(['Scenario: Indian Urban Junction   |   Ego: JCB_Ego\n' ...
                      'Lead: Sedan/Lead-01   |   Merge: Auto/Merge-01   |   Step: %.2f s\n' ...
                      'Controller: Adaptive Cruise + Avoidance   |   Risk: Distance + Rel.Vel + TTC'],DT), ...
    'Units','normalized','Position',[0.03 0.08 0.94 0.84], ...
    'BackgroundColor',[0.055 0.07 0.10], ...
    'ForegroundColor',[0.72 0.82 0.93], ...
    'FontSize',9,'HorizontalAlignment','left');

% Initial render
drawEverything();

% ========================== CALLBACKS ==========================
    function startSimulation(~,~)
        if running
            return;
        end

        running = true;
        set(startBtn,'String','RUNNING...','Enable','off');
        set(resetBtn,'Enable','off');

        if isempty(timerObj) || ~isvalid(timerObj)
            timerObj = timer( ...
                'ExecutionMode','fixedRate', ...
                'Period',DT, ...
                'BusyMode','drop', ...
                'TimerFcn',@(~,~)tick());
        end
        start(timerObj);
    end

    function tick()
        if ~ishandle(fig)
            stopSimulation();
            return;
        end

        if t >= TMAX
            stopSimulation();
            return;
        end

        t = t + DT;
        updateSimulationData();
        drawEverything();
        drawnow limitrate;
    end

    function stopSimulation()
        running = false;

        if ~isempty(timerObj) && isvalid(timerObj)
            stop(timerObj);
        end

        if ishandle(startBtn)
            set(startBtn,'String','START SIMULATION','Enable','on');
        end
        if ishandle(resetBtn)
            set(resetBtn,'Enable','on');
        end
    end

    function resetSimulation(~,~)
        stopSimulation();

        t=0;
        egoSpeed=7.8;
        egoAccel=0;
        steering=0;
        leadDist=38;
        leadRelV=-0.4;
        mergeDist=28;
        mergeRelV=-0.8;
        mergeLat=5.0;
        state='CRUISE';
        risk='LOW';
        decision='MAINTAIN';
        replanning=false;
        egoX=0; egoY=0;
        leadX=38; leadY=0;
        mergeX=28; mergeY=5;

        H=struct('t',[],'speed',[],'accel',[],'steer',[], ...
            'leadDist',[],'leadRelV',[],'leadTTC',[], ...
            'mergeDist',[],'mergeLat',[],'mergeTTC',[], ...
            'riskNum',[],'stateNum',[], ...
            'egoX',[],'egoY',[],'leadX',[],'leadY',[], ...
            'mergeX',[],'mergeY',[]);

        drawEverything();
    end

% ====================== SIMULATION MODEL ======================
    function updateSimulationData()
        % Demonstration sequence:
        % 0-8   normal cruise
        % 8-13  merge vehicle approaches
        % 13-18 higher risk -> yield
        % 18-22 gap recovery
        % 22-30 resume cruise

        if t < 8
            egoAccel=0.15;
            egoSpeed=min(8.0,egoSpeed+egoAccel*DT);
            leadRelV=-0.25;
            leadDist=max(leadDist+leadRelV*DT,34);
            mergeRelV=-0.9;
            mergeDist=max(mergeDist+mergeRelV*DT,20);
            mergeLat=max(mergeLat-0.22*DT,3.2);
            state='CRUISE';
            risk='LOW';
            decision='MAINTAIN';
            replanning=false;

        elseif t < 13
            egoAccel=-0.05;
            egoSpeed=max(7.6,egoSpeed+egoAccel*DT);
            leadRelV=-0.4;
            leadDist=max(leadDist+leadRelV*DT,31);
            mergeRelV=-1.2;
            mergeDist=max(mergeDist+mergeRelV*DT,14);
            mergeLat=max(mergeLat-0.45*DT,0.8);
            state='FOLLOW';
            risk='MEDIUM';
            decision='MONITOR MERGE';
            replanning=true;

        elseif t < 18
            egoAccel=-0.65;
            egoSpeed=max(5.8,egoSpeed+egoAccel*DT);
            leadRelV=0.15;
            leadDist=leadDist+leadRelV*DT;
            mergeRelV=-0.1;
            mergeDist=max(mergeDist+mergeRelV*DT,9.5);
            mergeLat=max(mergeLat-0.05*DT,-0.3);
            state='YIELD';
            risk='HIGH';
            decision='SLOW / YIELD';
            replanning=true;

        elseif t < 22
            egoAccel=0.45;
            egoSpeed=min(7.0,egoSpeed+egoAccel*DT);
            leadRelV=0.1;
            leadDist=leadDist+leadRelV*DT;
            mergeRelV=0.8;
            mergeDist=mergeDist+mergeRelV*DT;
            mergeLat=min(mergeLat+0.65*DT,5.0);
            state='RESUME';
            risk='MEDIUM';
            decision='RECHECK GAP';
            replanning=true;

        else
            egoAccel=0.20;
            egoSpeed=min(8.1,egoSpeed+egoAccel*DT);
            leadRelV=-0.15;
            leadDist=max(leadDist+leadRelV*DT,25);
            mergeRelV=0.7;
            mergeDist=min(mergeDist+mergeRelV*DT,28);
            mergeLat=min(mergeLat+0.18*DT,5.0);
            state='CRUISE';
            risk='LOW';
            decision='MAINTAIN';
            replanning=false;
        end

        steering=max(-8,min(8,-2.5*(mergeLat/5)));

        egoX=egoX+egoSpeed*DT;
        leadX=egoX+leadDist;
        mergeX=egoX+mergeDist;

        egoY=0;
        leadY=0;
        mergeY=mergeLat;

        leadTTC=computeTTC(leadDist,leadRelV);
        mergeTTC=computeTTC(mergeDist,mergeRelV);

        H.t(end+1)=t;
        H.speed(end+1)=egoSpeed;
        H.accel(end+1)=egoAccel;
        H.steer(end+1)=steering;
        H.leadDist(end+1)=leadDist;
        H.leadRelV(end+1)=leadRelV;
        H.leadTTC(end+1)=leadTTC;
        H.mergeDist(end+1)=mergeDist;
        H.mergeLat(end+1)=mergeLat;
        H.mergeTTC(end+1)=mergeTTC;
        H.riskNum(end+1)=riskNumber(risk);
        H.stateNum(end+1)=stateNumber(state);
        H.egoX(end+1)=egoX;
        H.egoY(end+1)=egoY;
        H.leadX(end+1)=leadX;
        H.leadY(end+1)=leadY;
        H.mergeX(end+1)=mergeX;
        H.mergeY(end+1)=mergeY;
    end

% =========================== DRAW ==============================
    function drawEverything()

        curLeadTTC=computeTTC(leadDist,leadRelV);
        curMergeTTC=computeTTC(mergeDist,mergeRelV);
        curTTC=min(curLeadTTC,curMergeTTC);

        set(kpi1.Value,'String',state);
        set(kpi2.Value,'String',sprintf('%.1f km/h',egoSpeed*3.6));
        set(kpi3.Value,'String',sprintf('%.1f m',leadDist));
        set(kpi4.Value,'String',fmtTTC(curTTC));
        set(kpi5.Value,'String',risk);
        set(kpi6.Value,'String',decision);
        set(kpi7.Value,'String',sprintf('%d / 100',currentSafetyIndex()));

        set(statusText,'String',sprintf([ ...
            'Drive Mode: %s     Replanning: %s     Path Valid: YES\n' ...
            'Steering: %.1f deg     Acceleration: %.2f m/s^2     Gear: D\n' ...
            'Decision: %s'], ...
            state,ternary(replanning,'ACTIVE','STANDBY'), ...
            steering,egoAccel,decision));

        set(riskText,'String',sprintf([ ...
            'Lead TTC: %s     Lead Risk: %s\n' ...
            'Merge TTC: %s     Merge Risk: %s\n' ...
            'Predicted Occupancy: %s     Overall Risk: %s'], ...
            fmtTTC(curLeadTTC),riskFromTTC(curLeadTTC), ...
            fmtTTC(curMergeTTC),riskFromTTC(curMergeTTC), ...
            predictedOccupancy(),risk));

        % Speed
        cla(axSpeed);
        if ~isempty(H.t)
            plot(axSpeed,H.t,H.speed*3.6,'LineWidth',2.4);
            hold(axSpeed,'on');
            plot(axSpeed,H.t,ones(size(H.t))*30,'--','LineWidth',1);
            hold(axSpeed,'off');
        end
        styleAxes(axSpeed,'EGO SPEED');
        xlabel(axSpeed,'Time (s)');
        ylabel(axSpeed,'km/h');
        grid(axSpeed,'on');

        % Distance
        cla(axDist);
        if ~isempty(H.t)
            plot(axDist,H.t,H.leadDist,'LineWidth',2.2);
            hold(axDist,'on');
            plot(axDist,H.t,H.mergeDist,'LineWidth',2.2);
            plot(axDist,H.t,ones(size(H.t))*6,'--','LineWidth',1);
            hold(axDist,'off');
            legend(axDist,{'Lead','Merge','Safety threshold'}, ...
                'TextColor',[0.8 0.85 0.9],'Color',[0.055 0.07 0.10], ...
                'Location','best');
        end
        styleAxes(axDist,'RELATIVE DISTANCE');
        xlabel(axDist,'Time (s)');
        ylabel(axDist,'m');
        grid(axDist,'on');

        % TTC
        cla(axTTC);
        if ~isempty(H.t)
            plot(axTTC,H.t,H.leadTTC,'LineWidth',2.2);
            hold(axTTC,'on');
            plot(axTTC,H.t,H.mergeTTC,'LineWidth',2.2);
            plot(axTTC,H.t,ones(size(H.t))*1.5,'--','LineWidth',1);
            plot(axTTC,H.t,ones(size(H.t))*4,'--','LineWidth',1);
            hold(axTTC,'off');
            legend(axTTC,{'Lead TTC','Merge TTC','Critical','Caution'}, ...
                'TextColor',[0.8 0.85 0.9],'Color',[0.055 0.07 0.10], ...
                'Location','best');
        end
        styleAxes(axTTC,'TTC / COLLISION RISK');
        xlabel(axTTC,'Time (s)');
        ylabel(axTTC,'TTC (s)');
        ylim(axTTC,[0 40]);
        grid(axTTC,'on');

        % Risk
        cla(axRisk);
        if ~isempty(H.t)
            stairs(axRisk,H.t,H.riskNum,'LineWidth',2.5);
        end
        styleAxes(axRisk,'RISK LEVEL');
        set(axRisk,'YTick',[1 2 3], ...
            'YTickLabel',{'LOW','MEDIUM','HIGH'}, ...
            'YLim',[0.7 3.3]);
        xlabel(axRisk,'Time (s)');
        grid(axRisk,'on');

        % BEV
        cla(axBEV);
        hold(axBEV,'on');
        fill(axBEV,[-5 70 70 -5],[-4 -4 4 4],[0.12 0.14 0.17], ...
            'EdgeColor','none');
        plot(axBEV,[-5 70],[0 0],'--','LineWidth',1);

        if isempty(H.t)
            plot(axBEV,0,0,'o','MarkerSize',12,'LineWidth',2);
            plot(axBEV,38,0,'s','MarkerSize',12,'LineWidth',2);
            plot(axBEV,28,5,'d','MarkerSize',12,'LineWidth',2);
        else
            plot(axBEV,H.egoX,H.egoY,'LineWidth',2.8);
            plot(axBEV,H.leadX,H.leadY,'LineWidth',2.4);
            plot(axBEV,H.mergeX,H.mergeY,'LineWidth',2.4);
            plot(axBEV,H.egoX(end),H.egoY(end),'o','MarkerSize',10,'LineWidth',2);
            plot(axBEV,H.leadX(end),H.leadY(end),'s','MarkerSize',10,'LineWidth',2);
            plot(axBEV,H.mergeX(end),H.mergeY(end),'d','MarkerSize',10,'LineWidth',2);
        end

        hold(axBEV,'off');
        styleAxes(axBEV,'TOP VIEW - DRIVABLE SPACE / ACTORS');
        xlabel(axBEV,'Longitudinal position (m)');
        ylabel(axBEV,'Lateral position (m)');
        xlim(axBEV,[-5 max(70,egoX+40)]);
        ylim(axBEV,[-8 8]);
        grid(axBEV,'on');

        % State
        cla(axState);
        if ~isempty(H.t)
            stairs(axState,H.t,H.stateNum,'LineWidth',2.5);
        end
        styleAxes(axState,'DECISION STATE');
        set(axState,'YTick',1:6, ...
            'YTickLabel',{'CRUISE','FOLLOW','YIELD','MERGE','AVOID','RESUME'}, ...
            'YLim',[0.5 6.5]);
        xlabel(axState,'Time (s)');
        grid(axState,'on');

        % Lateral motion
        cla(axLat);
        if ~isempty(H.t)
            plot(axLat,H.t,H.mergeLat,'LineWidth',2.5);
            hold(axLat,'on');
            plot(axLat,H.t,zeros(size(H.t)),'--','LineWidth',1);
            hold(axLat,'off');
            legend(axLat,{'Merging vehicle','Ego corridor'}, ...
                'TextColor',[0.8 0.85 0.9], ...
                'Color',[0.055 0.07 0.10],'Location','best');
        end
        styleAxes(axLat,'MERGING VEHICLE LATERAL MOTION');
        xlabel(axLat,'Time (s)');
        ylabel(axLat,'Offset (m)');
        grid(axLat,'on');
    end

% ========================== HELPERS ============================
    function p=makeKPI(pos,heading,value)
        p.Panel=uipanel(fig,'Units','normalized','Position',pos, ...
            'BackgroundColor',[0.09 0.12 0.17], ...
            'BorderType','line','HighlightColor',[0.18 0.25 0.34]);
        uicontrol(p.Panel,'Style','text','String',heading, ...
            'Units','normalized','Position',[0.03 0.57 0.94 0.25], ...
            'BackgroundColor',[0.09 0.12 0.17], ...
            'ForegroundColor',[0.55 0.66 0.78], ...
            'FontSize',8,'FontWeight','bold');
        p.Value=uicontrol(p.Panel,'Style','text','String',value, ...
            'Units','normalized','Position',[0.03 0.10 0.94 0.43], ...
            'BackgroundColor',[0.09 0.12 0.17], ...
            'ForegroundColor',[0.92 0.96 1], ...
            'FontSize',13,'FontWeight','bold');
    end

    function styleAxes(ax,titleText)
        set(ax,'Color',[0.055 0.07 0.10], ...
            'XColor',[0.72 0.80 0.90], ...
            'YColor',[0.72 0.80 0.90], ...
            'GridColor',[0.25 0.32 0.42], ...
            'FontSize',8);
        title(ax,titleText,'Color',[0.90 0.94 1], ...
            'FontWeight','bold','FontSize',10);
    end

    function x=computeTTC(dist,relV)
        if relV < -0.05
            x=max(dist/(-relV),0);
        else
            x=Inf;
        end
    end

    function s=fmtTTC(x)
        if ~isfinite(x)
            s='INF';
        else
            s=sprintf('%.2f s',x);
        end
    end

    function r=riskFromTTC(x)
        if x < 1.5
            r='HIGH';
        elseif x < 4
            r='MEDIUM';
        else
            r='LOW';
        end
    end

    function n=riskNumber(r)
        switch upper(r)
            case 'HIGH'
                n=3;
            case 'MEDIUM'
                n=2;
            otherwise
                n=1;
        end
    end

    function n=stateNumber(s)
        switch upper(s)
            case 'CRUISE'
                n=1;
            case 'FOLLOW'
                n=2;
            case 'YIELD'
                n=3;
            case 'MERGE'
                n=4;
            case 'AVOID'
                n=5;
            case 'RESUME'
                n=6;
            otherwise
                n=1;
        end
    end

    function s=predictedOccupancy()
        if mergeLat < 1
            s='MERGE CONFLICT';
        elseif mergeLat < 3
            s='PARTIAL OCCUPANCY';
        else
            s='FREE CORRIDOR';
        end
    end

    function s=ternary(c,a,b)
        if c
            s=a;
        else
            s=b;
        end
    end

    function score=currentSafetyIndex()
        r=riskNumber(risk);
        score=100-(r-1)*12;
        nearest=min(leadDist,mergeDist);
        if nearest<10
            score=score-12;
        elseif nearest<15
            score=score-5;
        end
        if egoAccel < -0.8
            score=score-3;
        end
        score=round(max(0,min(100,score)));
    end

    function closeFigure(~,~)
        stopSimulation();
        if ~isempty(timerObj) && isvalid(timerObj)
            delete(timerObj);
        end
        delete(fig);
    end
end
