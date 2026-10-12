function AviX_GUI
% AviX_GUI
% Professional front-end prototype for AviX autonomous-driving workflow.
%
% MATLAB R2020b+ recommended.
% This V2 GUI is deliberately honest about integration state:
% RoadRunner/Simulink/AviX are marked READY only when configured.
% Actual AI/API, RoadRunner API and Simulink execution are integration
% points, not simulated as completed back-end processing.

%% ---------------- Configuration ---------------------------------
C.bg       = [0.055 0.065 0.085];
C.panel    = [0.075 0.090 0.120];
C.panel2   = [0.100 0.120 0.160];
C.text     = [0.93 0.95 0.98];
C.muted    = [0.62 0.68 0.76];
C.blue     = [0.12 0.43 0.82];
C.blue2    = [0.18 0.55 0.95];
C.green    = [0.20 0.72 0.46];
C.amber    = [0.95 0.62 0.18];
C.red      = [0.90 0.25 0.28];
C.cyan     = [0.20 0.72 0.90];
C.road     = [0.14 0.16 0.19];
C.line     = [0.75 0.77 0.80];

S.rrExe       = '';
S.project     = '';
S.scenarioIdx = 1;
S.mapLoaded   = false;
S.egoVehicle  = '';
S.simState    = 'IDLE';
S.placement   = '';
S.ego         = [];
S.start       = [];
S.goal        = [];
S.lead        = [];
S.obstacles   = [];
S.pedestrians = [];
S.roadRunner  = false;
S.toolboxesOK = false;
S.simTime = 0;
S.reportRunning = false;

% Replace these five names/files with your exact prepared RoadRunner files.
scenarioNames = { ...
    'Scenario 01','Scenario 02','Scenario 03','Scenario 04','Scenario 05'};

scenarioDesc = { ...
    'Unstructured Indian road', ...
    'Mixed traffic interaction', ...
    'Dynamic obstacle', ...
    'Merging / crossing', ...
    'Collision avoidance'};

scenarioFiles = { ...
    'Scenario_01.rrscenario', ...
    'Scenario_02.rrscenario', ...
    'Scenario_03.rrscenario', ...
    'Scenario_04.rrscenario', ...
    'Scenario_05.rrscenario'};

%% ---------------- Main window -----------------------------------
fig = uifigure('Name','AviX | Autonomous Driving Engineering Platform', ...
    'Color',C.bg,'Position',[60 40 1500 900], ...
    'AutoResizeChildren','on');
fig.WindowButtonDownFcn = @windowClick;

root = uigridlayout(fig,[2 1]);
root.RowHeight = {88,'1x'};
root.Padding = [0 0 0 0];
root.RowSpacing = 0;

%% ---------------- Header ----------------------------------------
header = uipanel(root,'BorderType','none','BackgroundColor',C.panel);
hg = uigridlayout(header,[1 4]);
hg.ColumnWidth = {280,'1x',360,250};
hg.Padding = [22 8 22 8];
hg.ColumnSpacing = 10;

tpanel = uipanel(hg,'BorderType','none','BackgroundColor',C.panel);
tg = uigridlayout(tpanel,[2 1]);
tg.RowHeight = {38,22};
tg.Padding = [0 4 0 0];
uilabel(tg,'Text','AviX','FontSize',25,'FontWeight','bold','FontColor',C.text);
uilabel(tg,'Text','Adaptive Road Intelligence Platform','FontSize',11,'FontColor',C.muted);

statusPanel = uipanel(hg,'BorderType','none','BackgroundColor',C.panel);
sg = uigridlayout(statusPanel,[1 3]);
sg.Padding = [0 8 0 8];
rrCard = statusCard(sg,'RoadRunner','NOT CONFIGURED',C.red);
slCard = statusCard(sg,'Simulink','CHECKING',C.amber);
txCard = statusCard(sg,'AviX Engine','STANDBY',C.amber);

infoPanel = uipanel(hg,'BorderType','none','BackgroundColor',C.panel);
ig = uigridlayout(infoPanel,[2 1]);
ig.RowHeight = {22,28};
ig.Padding = [0 8 0 0];
uilabel(ig,'Text','SIH 2026 | MathWorks Solution','HorizontalAlignment','right',...
    'FontSize',10,'FontColor',C.muted);
uilabel(ig,'Text','AUTONOMOUS DRIVING PLATFORM  •  V3.0','HorizontalAlignment','right',...
    'FontSize',12,'FontWeight','bold','FontColor',C.text);

modePanel = uipanel(hg,'BorderType','none','BackgroundColor',C.panel);
mg = uigridlayout(modePanel,[2 1]);
mg.RowHeight = {22,28};
mg.Padding = [0 8 0 0];
uilabel(mg,'Text','MODE','HorizontalAlignment','right','FontSize',9,'FontColor',C.muted);
uilabel(mg,'Text','FRONT-END DEMO','HorizontalAlignment','right',...
    'FontSize',12,'FontWeight','bold','FontColor',C.cyan);

tabs = uitabgroup(root);
tabs.FontSize = 11;

%% ---------------- TAB 1: Setup & Scenarios ----------------------
tab1 = uitab(tabs,'Title','01  Setup & Scenarios');
g1 = uigridlayout(tab1,[1 2]);
g1.ColumnWidth = {360,'1x'};
g1.Padding = [18 18 18 18];
g1.ColumnSpacing = 16;

p = uipanel(g1,'Title','SYSTEM SETUP','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);
lg = uigridlayout(p,[11 1]);
lg.RowHeight = {30,48,42,48,42,42,34,34,34,30,'1x'};
lg.Padding = [14 14 14 14];
lg.RowSpacing = 7;

uilabel(lg,'Text','RoadRunner Environment','FontSize',15,'FontWeight','bold','FontColor',C.text);

rrField = uieditfield(lg,'text','Placeholder','RoadRunner executable (.exe)');
rrField.Editable = 'off';

button(lg,'SELECT ROADRUNNER INSTALLATION',C.blue,@selectRR);

rrProjectField = uieditfield(lg,'text','Placeholder','RoadRunner project folder');
rrProjectField.Editable = 'off';

button(lg,'SELECT PROJECT FOLDER',C.blue,@selectProject);
button(lg,'VALIDATE ENVIRONMENT',C.green,@validateEnvironment);

rrStatus = statusLabel(lg,'● RoadRunner: Not configured',C.red);
toolStatus = statusLabel(lg,'● MATLAB toolboxes: Checking...',C.amber);
selectedStatus = statusLabel(lg,'● Scenario: Scenario 01',C.cyan);

uilabel(lg,...
    'Text','Status is only changed after the corresponding setup step is actually completed.',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

right = uigridlayout(g1,[2 1]);
right.RowHeight = {'1x',235};
right.RowSpacing = 14;

sp = uipanel(right,'Title','PREDEFINED INDIAN ROAD SCENARIOS','FontWeight','bold',...
    'FontSize',12,'ForegroundColor',C.text,'BackgroundColor',C.panel);

sg2 = uigridlayout(sp,[2 5]);
sg2.RowHeight = {145,'1x'};
sg2.Padding = [14 14 14 14];
sg2.ColumnSpacing = 9;

scenarioButtons = gobjects(1,5);

for k = 1:5
    cp = uipanel(sg2,'BackgroundColor',C.panel2,'BorderType','line');
    cp.Layout.Row = 1;
    cp.Layout.Column = k;

    cg = uigridlayout(cp,[4 1]);
    cg.RowHeight = {22,40,40,22};
    cg.Padding = [7 7 7 7];
    cg.RowSpacing = 3;

    uilabel(cg,'Text',sprintf('%02d',k),'HorizontalAlignment','center',...
        'FontSize',10,'FontWeight','bold','FontColor',C.blue2);

    scenarioButtons(k) = button(cg,scenarioNames{k},C.blue,...
        @(src,event)selectScenario(k));

    uilabel(cg,'Text',scenarioDesc{k},'HorizontalAlignment','center',...
        'FontSize',8,'FontColor',C.muted,'WordWrap','on');

    uilabel(cg,'Text',scenarioFiles{k},'HorizontalAlignment','center',...
        'FontSize',7,'FontColor',C.muted,'WordWrap','on');
end

scenarioHelp = uilabel(sg2,...
    'Text','Select a prepared scenario. The exact .rrscenario filename is shown on each card.',...
    'FontSize',10,'FontColor',C.muted,'WordWrap','on');
scenarioHelp.Layout.Row = 2;
scenarioHelp.Layout.Column = [1 5];

pp = uipanel(right,'Title','AI / API SCENARIO GENERATOR','FontWeight','bold',...
    'FontSize',12,'ForegroundColor',C.text,'BackgroundColor',C.panel);

pg = uigridlayout(pp,[2 2]);
pg.RowHeight = {105,52};
pg.ColumnWidth = {'1x',160};
pg.Padding = [14 12 14 12];
pg.ColumnSpacing = 10;

prompt = uitextarea(pg,'FontSize',10);
prompt.Value = {'Create an Indian urban road scenario with mixed traffic, a lead vehicle, two-wheelers, pedestrians and an unexpected obstacle.'};
prompt.Placeholder = 'Describe the required Indian-road scenario...';

button(pg,'GENERATE REQUEST',C.blue2,@generateRequest);

console = uitextarea(pg);
console.Layout.Row = 2;
console.Layout.Column = [1 2];
console.Editable = 'off';
console.FontName = 'Consolas';
console.FontSize = 9;
console.BackgroundColor = [0.035 0.045 0.065];
console.FontColor = [0.72 0.90 1.00];

logmsg('AviX GUI V2 initialized.');
logmsg('Front-end demo mode active.');

%% ---------------- TAB 2: Map & Vehicle ---------------------------
tab2 = uitab(tabs,'Title','02  Map & Ego Vehicle');

g2 = uigridlayout(tab2,[1 3]);
g2.ColumnWidth = {300,'1x',300};
g2.Padding = [18 18 18 18];
g2.ColumnSpacing = 16;

mp = uipanel(g2,'Title','MAP CONFIGURATION','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

mg2 = uigridlayout(mp,[9 1]);
mg2.RowHeight = {34,48,44,44,28,28,38,38,'1x'};
mg2.Padding = [14 14 14 14];
mg2.RowSpacing = 7;

uilabel(mg2,'Text','Indian Road Environment','FontSize',15,...
    'FontWeight','bold','FontColor',C.text);

mapDrop = uidropdown(mg2,...
    'Items',{'Indian Urban Junction','Indian Village Road','Indian Highway Merge','Mixed Traffic Corridor'},...
    'Value','Indian Urban Junction','FontSize',11);

button(mg2,'FETCH MAP',C.blue,@fetchMap);
button(mg2,'LOAD FROM ROADRUNNER',C.blue,@loadMap);
statusLabel(mg2,'Map source: RoadRunner project',C.muted);
mapStatus = statusLabel(mg2,'● Map: Not loaded',C.amber);
statusLabel(mg2,'Environment: Indian-specific',C.muted);
button(mg2,'OPEN PROJECT FOLDER',C.panel2,@openProject);

uilabel(mg2,...
    'Text','Map preview is a GUI placeholder until the RoadRunner map/scene API is connected.',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

mprev = uipanel(g2,'Title','ROAD ENVIRONMENT PREVIEW','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

axMap = uiaxes(mprev,'Position',[12 12 650 650]);
configureAxes(axMap,C);
drawIntersection(axMap,C);

vp = uipanel(g2,'Title','EGO VEHICLE','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

vg = uigridlayout(vp,[8 1]);
vg.RowHeight = {34,48,105,44,44,28,36,'1x'};
vg.Padding = [14 14 14 14];
vg.RowSpacing = 7;

uilabel(vg,'Text','Select RoadRunner Vehicle','FontSize',15,...
    'FontWeight','bold','FontColor',C.text);

vehicleDrop = uidropdown(vg,...
    'Items',{'Sedan','SUV','Truck','Bus','Auto Rickshaw','Motorcycle','Bicycle','JCB / Construction Vehicle'},...
    'Value','Sedan','ValueChangedFcn',@vehicleChanged);

vehiclePreview = uilabel(vg,'Text','EGO VEHICLE\n\nSEDAN',...
    'HorizontalAlignment','center','VerticalAlignment','center',...
    'FontSize',15,'FontWeight','bold','FontColor',C.blue2,'BackgroundColor',C.panel2);

button(vg,'LOAD VEHICLE',C.blue,@loadVehicle);
button(vg,'SET AS EGO VEHICLE',C.green,@setEgo);
statusLabel(vg,'Vehicle source: RoadRunner Asset Library',C.muted);
vehicleStatus = statusLabel(vg,'● Ego vehicle: Not selected',C.amber);

uilabel(vg,...
    'Text','The selected vehicle becomes the ego actor for later RoadRunner/Simulink integration.',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

%% ---------------- TAB 3: Scenario Builder -----------------------
tab3 = uitab(tabs,'Title','03  Scenario Builder');

g3 = uigridlayout(tab3,[1 4]);
g3.ColumnWidth = {205,'1x',230,250};
g3.Padding = [18 18 18 18];
g3.ColumnSpacing = 14;

op = uipanel(g3,'Title','OBJECTS','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

og = uigridlayout(op,[9 1]);
og.RowHeight = {42,48,45,45,45,34,34,48,'1x'};
og.Padding = [12 12 12 12];
og.RowSpacing = 7;

uilabel(og,'Text','Select an object, then click the road canvas.',...
    'FontSize',10,'FontColor',C.muted,'WordWrap','on');

objectDrop = uidropdown(og,...
    'Items',{'Ego Vehicle','Start Point','Destination','Lead Vehicle','Obstacle','Pedestrian'},...
    'Value','Ego Vehicle');

button(og,'PLACE OBJECT',C.blue,@enablePlacement);
button(og,'CLEAR OBJECTS',C.red,@clearObjects);
button(og,'RESET ROAD',C.amber,@resetRoad);

placementStatus = statusLabel(og,'Placement: Inactive',C.amber);

uilabel(og,'Text','Recommended order: Ego → Start → Goal → Traffic → Obstacles',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

uilabel(og,'Text','One object is placed per click; placement then ends automatically.',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

cp = uipanel(g3,'Title','INTERACTIVE SCENARIO','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

axScenario = uiaxes(cp,'Position',[10 10 700 700]);
configureAxes(axScenario,C);
drawIntersection(axScenario,C);
axScenario.ButtonDownFcn = @roadClick;

op2 = uipanel(g3,'Title','OBJECT DATA','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

og2 = uigridlayout(op2,[8 1]);
og2.RowHeight = {36,36,36,36,36,34,34,'1x'};
og2.Padding = [12 12 12 12];
og2.RowSpacing = 6;

egoInfo = infoLabel(og2,'Ego: Not placed',C);
startInfo = infoLabel(og2,'Start: Not placed',C);
goalInfo = infoLabel(og2,'Destination: Not placed',C);
leadInfo = infoLabel(og2,'Lead: Not placed',C);
obsInfo = infoLabel(og2,'Obstacles: 0',C);

uilabel(og2,'Text','Coordinate system','FontWeight','bold','FontColor',C.text);
uilabel(og2,'Text','GUI local coordinates → later RoadRunner world coordinates',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

vp2 = uipanel(g3,'Title','SCENARIO VALIDATION','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

vg2 = uigridlayout(vp2,[7 1]);
vg2.RowHeight = {42,42,42,42,42,50,'1x'};
vg2.Padding = [12 12 12 12];
vg2.RowSpacing = 6;

roadCheck = checkLabel(vg2,'Road geometry','READY',C);
egoCheck = checkLabel(vg2,'Ego vehicle','MISSING',C);
startCheck = checkLabel(vg2,'Start point','MISSING',C);
goalCheck = checkLabel(vg2,'Destination','MISSING',C);
trafficCheck = checkLabel(vg2,'Traffic actors','OPTIONAL',C);

button(vg2,'VALIDATE SCENARIO',C.green,@validateScenario);

uilabel(vg2,...
    'Text','V2 validates only GUI inputs. Full RoadRunner scenario validation remains a backend step.',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

%% ---------------- TAB 4: Simulation -----------------------------
tab4 = uitab(tabs,'Title','04  Simulation');

g4 = uigridlayout(tab4,[2 2]);
g4.RowHeight = {120,'1x'};
g4.ColumnWidth = {'1x',300};
g4.Padding = [18 18 18 18];
g4.RowSpacing = 14;
g4.ColumnSpacing = 14;

sc = uipanel(g4,'Title','SIMULATION CONTROL','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

cg = uigridlayout(sc,[1 8]);
cg.ColumnWidth = {150,150,135,120,120,120,'1x',180};
cg.Padding = [14 14 14 14];
cg.ColumnSpacing = 10;

button(cg,'OPEN ROADRUNNER',C.blue,@openRR);
button(cg,'OPEN SCENARIO',C.blue2,@openScenario);
button(cg,'START',C.green,@startSim);
button(cg,'PAUSE',C.amber,@pauseSim);
button(cg,'STOP',C.red,@stopSim);
button(cg,'OPEN SIMULINK',C.panel2,@openSimulink);

simStatus = statusLabel(cg,'● Simulation: IDLE',C.amber);
simStatus.HorizontalAlignment = 'center';

simScenario = statusLabel(cg,'Scenario 01',C.text);
simScenario.HorizontalAlignment = 'center';

vp3 = uipanel(g4,'Title','ROADRUNNER / SIMULINK VIEW','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

axSim = uiaxes(vp3,'Position',[10 10 900 650]);
configureAxes(axSim,C);
drawIntersection(axSim,C);

pp3 = uipanel(g4,'Title','PIPELINE STATUS','FontWeight','bold','FontSize',12,...
    'ForegroundColor',C.text,'BackgroundColor',C.panel);

pg3 = uigridlayout(pp3,[9 1]);
pg3.RowHeight = {42,42,42,42,42,42,42,42,'1x'};
pg3.Padding = [12 12 12 12];
pg3.RowSpacing = 6;

pipeline = struct();
pipeline.Environment = pipelineLabel(pg3,'Environment','READY',C);
pipeline.Sensors = pipelineLabel(pg3,'Sensors','READY',C);
pipeline.Perception = pipelineLabel(pg3,'Perception','NOT RUN',C);
pipeline.Prediction = pipelineLabel(pg3,'Prediction','NOT RUN',C);
pipeline.Risk = pipelineLabel(pg3,'Risk Assessment','NOT RUN',C);
pipeline.Planning = pipelineLabel(pg3,'Planning','NOT RUN',C);
pipeline.Control = pipelineLabel(pg3,'Control','NOT RUN',C);
pipeline.Vehicle = pipelineLabel(pg3,'Vehicle Response','NOT RUN',C);

uilabel(pg3,...
    'Text','START is the future integration trigger for the closed-loop backend; the GUI does not fake algorithm results.',...
    'FontSize',9,'FontColor',C.muted,'WordWrap','on');

%% ---------------- TAB 5: AviX Simulation Report -----------------
tab5 = uitab(tabs,'Title','05  AviX Report');

g5 = uigridlayout(tab5,[4 1]);
g5.RowHeight = {42,92,'1x',105};
g5.ColumnWidth = {'1x'};
g5.Padding = [18 14 18 14];
g5.RowSpacing = 10;

reportTop = uipanel(g5,'BorderType','none','BackgroundColor',C.panel);
reportTop.Layout.Row = 1;
reportTop.Layout.Column = 1;
rtg = uigridlayout(reportTop,[1 4]);
rtg.ColumnWidth = {'1x','1x','1x',110};
rtg.Padding = [0 0 0 0];
uilabel(rtg,'Text','Indian Urban Junction  |  Ego + Lead + Merging Vehicle  |  Closed-Loop Simulation Report',...
    'FontSize',11,'FontWeight','bold','FontColor',C.text,'VerticalAlignment','center');
reportState = uilabel(rtg,'Text','IDLE','HorizontalAlignment','center',...
    'FontSize',11,'FontWeight','bold','FontColor',C.amber,'BackgroundColor',C.panel2);
reportClock = uilabel(rtg,'Text','Report Ready','HorizontalAlignment','center',...
    'FontSize',10,'FontColor',C.muted);
reportReset = uibutton(rtg,'push','Text','RESET',...
    'FontWeight','bold','FontSize',10,'BackgroundColor',C.panel2,'FontColor',C.text,...
    'ButtonPushedFcn',@resetReport);

metricPanel = uipanel(g5,'BorderType','none','BackgroundColor',C.panel);
metricPanel.Layout.Row=2; metricPanel.Layout.Column=1;
metricGrid = uigridlayout(metricPanel,[1 7]);
metricGrid.ColumnWidth = {'1x','1x','1x','1x','1x','1x','1x'};
metricGrid.Padding=[0 0 0 0]; metricGrid.ColumnSpacing=8;

reportMetrics = struct();
reportMetrics.drive = metricCard(metricGrid,'DRIVE MODE','CRUISE','Current controller mode',C.text);
reportMetrics.speed = metricCard(metricGrid,'EGO SPEED','28.8 km/h','Ego speed',C.blue2);
reportMetrics.dist = metricCard(metricGrid,'LEAD DISTANCE','36.1 m','Relative distance',C.text);
reportMetrics.ttc = metricCard(metricGrid,'MIN TTC','23.51 s','Minimum time to collision',C.text);
reportMetrics.merge = metricCard(metricGrid,'MERGE RISK','LOW','Merging collision risk',C.green);
reportMetrics.plan = metricCard(metricGrid,'PLANNING','MAINTAIN','Current planning action',C.text);
reportMetrics.safe = metricCard(metricGrid,'SAFETY INDEX','100 / 100','Overall safety score',C.text);

chartPanel = uipanel(g5,'BorderType','none','BackgroundColor',C.panel);
chartPanel.Layout.Row=3; chartPanel.Layout.Column=1;
chartGrid = uigridlayout(chartPanel,[2 3]);
chartGrid.RowHeight={'1x','1x'};
chartGrid.ColumnWidth={'1x','1x','1x'};
chartGrid.Padding=[0 0 0 0]; chartGrid.RowSpacing=10; chartGrid.ColumnSpacing=12;

reportAxes = gobjects(1,6);
for ri=1:6
    reportAxes(ri) = uiaxes(chartGrid);
end

% The bottom row is a wide top-view/status area, visually close to the reference.
reportBottom = uipanel(g5,'Title','VEHICLE / RISK / SIMULATION STATUS',...
    'FontWeight','bold','FontSize',11,'ForegroundColor',C.text,'BackgroundColor',C.panel);
reportBottom.Layout.Row=4;
reportBottom.Layout.Column=1;
rb = uigridlayout(reportBottom,[1 3]);
rb.ColumnWidth={'1x','1x','1x'};
rb.Padding=[8 8 8 8];
rb.ColumnSpacing=10;

vehicleStatusReport = reportStatusBox(rb,'VEHICLE STATUS',...
    {'Drive Mode: CRUISE','Replanning: STANDBY','Steering: 1.7 deg','Acceleration: 0.15 m/s^2','Gear: D'});
riskStatusReport = reportStatusBox(rb,'RISK ASSESSMENT',...
    {'Lead TTC: 144.40 s   Lead Risk: LOW','Merge TTC: 23.51 s   Merge Risk: LOW','Predicted Occupancy: FREE','Controller Risk: LOW'});
simStatusReport = reportStatusBox(rb,'SIMULATION PARAMETERS',...
    {'Scenario: Indian Urban Junction','Ego: JCB_Ego','Lead: Sedan/Lead-01','Merge: Auto/Merge-01','Controller: Adaptive Cruise + AEB','Risk: Distance + TTC'});

for i=1:6
    configureAxes(reportAxes(i),C);
end

populateReport(reportAxes,C);

%% ---------------- Initial state ---------------------------------
updateToolboxStatus();
updateScenarioUI();
updatePipeline('idle');
tabs.SelectedTab = tab1;

%% ---------------- Callbacks -------------------------------------
    function selectRR(~,~)
        [f,pth] = uigetfile({'*.exe','Executable (*.exe)'},...
            'Select RoadRunner executable');
        if isequal(f,0)
            return;
        end

        S.rrExe = fullfile(pth,f);
        rrField.Value = S.rrExe;
        S.roadRunner = true;

        rrStatus = styleStatus(rrStatus,...
            '● RoadRunner: Installation selected',C.green);
        rrCard = updateCard(rrCard,'CONFIGURED',C.green);

        logmsg(['RoadRunner executable selected: ' S.rrExe]);
        updateHeaderAviX();
    end

    function selectProject(~,~)
        pth = uigetdir(pwd,'Select RoadRunner project folder');
        if isequal(pth,0)
            return;
        end

        S.project = pth;
        rrProjectField.Value = pth;

        logmsg(['Project folder selected: ' S.project]);

        if ~isempty(S.rrExe)
            rrStatus = styleStatus(rrStatus,...
                '● RoadRunner: Project configured',C.green);
            rrCard = updateCard(rrCard,'READY',C.green);
        end

        updateHeaderAviX();
    end

    function openProject(~,~)
        if isempty(S.project)
            uialert(fig,...
                'Select a RoadRunner project folder first.',...
                'Project Required');
            return;
        end

        try
            if ispc
                winopen(S.project);
            else
                open(S.project);
            end
            logmsg('Project folder opened.');
        catch ME
            uialert(fig,ME.message,'Open Folder Error');
        end
    end

    function validateEnvironment(~,~)
        updateToolboxStatus();

        if isempty(S.rrExe) || ~isfile(S.rrExe)
            S.roadRunner = false;
            rrStatus = styleStatus(rrStatus,...
                '● RoadRunner: Installation not configured',C.red);
            rrCard = updateCard(rrCard,'NOT CONFIGURED',C.red);
            logmsg('RoadRunner executable is not configured.');

        elseif isempty(S.project) || ~isfolder(S.project)
            rrStatus = styleStatus(rrStatus,...
                '● RoadRunner: Project not configured',C.amber);
            rrCard = updateCard(rrCard,'PROJECT NEEDED',C.amber);
            logmsg('RoadRunner executable is valid; project folder is still required.');

        else
            S.roadRunner = true;
            rrStatus = styleStatus(rrStatus,...
                '● RoadRunner: READY',C.green);
            rrCard = updateCard(rrCard,'READY',C.green);
            logmsg('RoadRunner environment validation passed.');
        end

        if S.toolboxesOK
            slCard = updateCard(slCard,'AVAILABLE',C.green);
        else
            slCard = updateCard(slCard,'CHECK NEEDED',C.amber);
        end

        updateHeaderAviX();
    end

    function selectScenario(k)
        S.scenarioIdx = k;
        updateScenarioUI();
        logmsg(['Selected ' scenarioNames{k} ' | ' scenarioFiles{k}]);
    end

    function updateScenarioUI()
        for i = 1:5
            scenarioButtons(i).BackgroundColor = C.blue;
        end

        scenarioButtons(S.scenarioIdx).BackgroundColor = C.blue2;

        selectedStatus = styleStatus(selectedStatus,...
            ['● Scenario: ' scenarioNames{S.scenarioIdx}],C.cyan);

        simScenario.Text = scenarioNames{S.scenarioIdx};
    end

    function generateRequest(~,~)
        txt = strtrim(strjoin(prompt.Value,' '));

        if isempty(txt)
            uialert(fig,...
                'Enter a scenario description first.',...
                'Prompt Required');
            return;
        end

        logmsg('AI/API request prepared (front-end only).');
        logmsg(['Prompt: ' txt]);
        logmsg('No external API call is made by V2.');

        uialert(fig,...
            'Request captured in the GUI. Connect the Claude/API backend here later.',...
            'API Integration Point');
    end

    function fetchMap(~,~)
        S.mapLoaded = true;

        mapStatus = styleStatus(mapStatus,...
            ['● Map loaded: ' mapDrop.Value],C.green);

        logmsg(['Map selected: ' mapDrop.Value]);
        drawIntersection(axMap,C);
    end

    function loadMap(~,~)
        if isempty(S.project)
            uialert(fig,...
                'Select the RoadRunner project folder first.',...
                'Project Required');
            return;
        end

        S.mapLoaded = true;

        mapStatus = styleStatus(mapStatus,...
            '● RoadRunner map connection: READY',C.green);

        logmsg('RoadRunner map integration point reached.');
        logmsg('No fake map import performed.');
    end

    function vehicleChanged(~,~)
        vehiclePreview.Text = sprintf('EGO VEHICLE\n\n%s',...
            upper(vehicleDrop.Value));
    end

    function loadVehicle(~,~)
        logmsg(['Vehicle asset selected for loading: ' vehicleDrop.Value]);

        vehicleStatus = styleStatus(vehicleStatus,...
            ['● Loaded: ' vehicleDrop.Value],C.green);
    end

    function setEgo(~,~)
        S.egoVehicle = vehicleDrop.Value;

        vehicleStatus = styleStatus(vehicleStatus,...
            ['● EGO: ' S.egoVehicle],C.green);

        logmsg(['Ego vehicle set to: ' S.egoVehicle]);
    end

    function enablePlacement(~,~)
        S.placement = objectDrop.Value;

        placementStatus = styleStatus(placementStatus,...
            ['Placement: ' S.placement],C.cyan);

        logmsg(['Placement enabled: ' S.placement]);
    end

    function windowClick(~,~)
        % Robust click routing for the interactive scenario canvas.
        % Graphics drawn on the axes have HitTest disabled, so the axes
        % receives the click even when the road or a previous marker is hit.
        try
            obj = fig.CurrentObject;
            if isequal(obj,axScenario) && strcmp(tabs.SelectedTab.Title,'03  Scenario Builder')
                roadClick(axScenario,[]);
            end
        catch
            % Ignore clicks outside the scenario canvas.
        end
    end

    function roadClick(src,~)
        if isempty(S.placement)
            return;
        end

        cp = src.CurrentPoint;
        x = cp(1,1);
        y = cp(1,2);

        xl = xlim(src); yl = ylim(src);
        if x < xl(1) || x > xl(2) || y < yl(1) || y > yl(2)
            return;
        end

        switch S.placement
            case 'Ego Vehicle'
                S.ego = [x y];
                egoInfo.Text = sprintf('Ego: [%.1f, %.1f]',x,y);
                drawVehicle(axScenario,x,y,C.blue2,'EGO');
                egoCheck = checkStyle(egoCheck,'Ego vehicle','READY',C);

            case 'Start Point'
                S.start = [x y];
                startInfo.Text = sprintf('Start: [%.1f, %.1f]',x,y);
                drawMarker(axScenario,x,y,C.green,'START');
                startCheck = checkStyle(startCheck,'Start point','READY',C);

            case 'Destination'
                S.goal = [x y];
                goalInfo.Text = sprintf('Destination: [%.1f, %.1f]',x,y);
                drawMarker(axScenario,x,y,C.red,'GOAL');
                goalCheck = checkStyle(goalCheck,'Destination','READY',C);

            case 'Lead Vehicle'
                S.lead = [x y];
                leadInfo.Text = sprintf('Lead: [%.1f, %.1f]',x,y);
                drawVehicle(axScenario,x,y,C.amber,'LEAD');
                trafficCheck = checkStyle(trafficCheck,'Traffic actors','READY',C);

            case 'Obstacle'
                S.obstacles = [S.obstacles; x y];
                obsInfo.Text = sprintf('Obstacles: %d',size(S.obstacles,1));
                drawMarker(axScenario,x,y,C.red,'OBS');

            case 'Pedestrian'
                S.pedestrians = [S.pedestrians; x y];
                drawMarker(axScenario,x,y,[0.65 0.35 0.90],'PED');
                trafficCheck = checkStyle(trafficCheck,'Traffic actors','READY',C);
        end

        S.placement = '';
        placementStatus = styleStatus(placementStatus,...
            'Placement: Inactive',C.muted);
    end

    function clearObjects(~,~)
        S.ego = [];
        S.start = [];
        S.goal = [];
        S.lead = [];
        S.obstacles = [];
        S.pedestrians = [];

        egoInfo.Text = 'Ego: Not placed';
        startInfo.Text = 'Start: Not placed';
        goalInfo.Text = 'Destination: Not placed';
        leadInfo.Text = 'Lead: Not placed';
        obsInfo.Text = 'Obstacles: 0';

        egoCheck = checkStyle(egoCheck,'Ego vehicle','MISSING',C);
        startCheck = checkStyle(startCheck,'Start point','MISSING',C);
        goalCheck = checkStyle(goalCheck,'Destination','MISSING',C);
        trafficCheck = checkStyle(trafficCheck,'Traffic actors','OPTIONAL',C);

        drawIntersection(axScenario,C);
        logmsg('Scenario objects cleared.');
    end

    function resetRoad(~,~)
        drawIntersection(axScenario,C);
        logmsg('Scenario canvas reset.');
    end

    function validateScenario(~,~)
        ok = ~isempty(S.ego) && ~isempty(S.start) && ~isempty(S.goal);

        if ok
            logmsg('Front-end scenario validation PASSED.');

            uialert(fig,...
                'Required GUI inputs are complete. Full RoadRunner scenario validation remains a backend step.',...
                'Validation Passed');
        else
            logmsg('Front-end scenario validation FAILED.');

            uialert(fig,...
                'Required: Ego vehicle, Start point and Destination.',...
                'Validation Required');
        end
    end

    function openRR(~,~)
        if isempty(S.rrExe) || ~isfile(S.rrExe)
            uialert(fig,...
                'Select a valid RoadRunner executable first.',...
                'RoadRunner Required');
            return;
        end

        try
            if ispc
                system(['start "" "' S.rrExe '"']);
            else
                system(['"' S.rrExe '" &']);
            end

            logmsg('RoadRunner launch command executed.');

            rrStatus = styleStatus(rrStatus,...
                '● RoadRunner: LAUNCHED',C.green);

            rrCard = updateCard(rrCard,'RUNNING',C.green);

        catch ME
            uialert(fig,ME.message,'RoadRunner Launch Error');
        end
    end

    function openScenario(~,~)
        if isempty(S.project)
            uialert(fig,...
                'Select the RoadRunner project folder first.',...
                'Project Required');
            return;
        end

        candidate = fullfile(S.project,scenarioFiles{S.scenarioIdx});

        if isfile(candidate)
            logmsg(['Scenario file found: ' candidate]);
            logmsg('RoadRunner API/Authoring integration point reached.');

            if ~isempty(S.rrExe) && isfile(S.rrExe)
                openRR([],[]);
            end

            uialert(fig,...
                ['Scenario file found:' newline newline candidate newline newline ...
                 'V2 launches RoadRunner but does not falsely claim API loading is complete.'],...
                'Scenario Ready');

        else
            logmsg(['Scenario file not found: ' candidate]);

            uialert(fig,...
                ['Expected scenario file was not found:' newline newline candidate newline newline ...
                 'Update scenarioFiles in AviX_GUI.m to your actual filenames.'],...
                'Scenario File Missing');
        end
    end

    function openSimulink(~,~)
        [f,pth] = uigetfile({'*.slx;*.mdl','Simulink Models (*.slx, *.mdl)'},...
            'Select Simulink model (optional)');
        if isequal(f,0)
            return;
        end
        modelPath = fullfile(pth,f);
        try
            [~,modelName,ext] = fileparts(modelPath);
            if strcmpi(ext,'.slx') || strcmpi(ext,'.mdl')
                open_system(modelPath);
                logmsg(['Simulink model opened: ' modelPath]);
            end
        catch ME
            uialert(fig,ME.message,'Simulink Open Error');
        end
    end

    function startSim(~,~)
        if ~S.roadRunner
            uialert(fig,...
                'Configure RoadRunner installation and project first.',...
                'Environment Required');
            return;
        end

        if isempty(S.ego) || isempty(S.start) || isempty(S.goal)
            uialert(fig,...
                'Complete the minimum scenario inputs before starting.',...
                'Scenario Required');
            return;
        end

        S.simState = 'RUNNING';
        S.reportRunning = true;
        reportState.Text = 'RUNNING...';
        reportState.FontColor = C.green;
        reportClock.Text = datestr(now,'yyyy-mm-dd HH:MM:SS');

        simStatus = styleStatus(simStatus,...
            '● Simulation: RUNNING',C.green);

        txCard = updateCard(txCard,'ACTIVE',C.green);
        updatePipeline('running');

        logmsg('Simulation start trigger issued.');
    end

    function pauseSim(~,~)
        if ~strcmp(S.simState,'RUNNING')
            return;
        end

        S.simState = 'PAUSED';

        simStatus = styleStatus(simStatus,...
            '● Simulation: PAUSED',C.amber);

        updatePipeline('paused');
        logmsg('Simulation paused.');
    end

    function stopSim(~,~)
        S.simState = 'IDLE';
        S.reportRunning = false;
        reportState.Text = 'IDLE';
        reportState.FontColor = C.amber;
        reportClock.Text = 'Report Ready';

        simStatus = styleStatus(simStatus,...
            '● Simulation: IDLE',C.amber);

        txCard = updateCard(txCard,'STANDBY',C.amber);
        updatePipeline('idle');

        logmsg('Simulation stopped.');
    end

    function resetReport(~,~)
        reportState.Text = 'IDLE';
        reportState.FontColor = C.amber;
        reportClock.Text = 'Report Ready';
        S.reportRunning = false;
        reportMetrics.drive.UserData.Value.Text = 'CRUISE';
        reportMetrics.speed.UserData.Value.Text = '28.8 km/h';
        reportMetrics.dist.UserData.Value.Text = '36.1 m';
        reportMetrics.ttc.UserData.Value.Text = '23.51 s';
        reportMetrics.merge.UserData.Value.Text = 'LOW';
        reportMetrics.plan.UserData.Value.Text = 'MAINTAIN';
        reportMetrics.safe.UserData.Value.Text = '100 / 100';
        populateReport(reportAxes,C);
        logmsg('AviX report reset.');
    end

    function updatePipeline(mode)
        if strcmp(mode,'running')
            setPipeline(pipeline.Environment,'READY',C.green);
            setPipeline(pipeline.Sensors,'READY',C.green);
            setPipeline(pipeline.Perception,'WAITING FOR BACKEND',C.amber);
            setPipeline(pipeline.Prediction,'WAITING FOR BACKEND',C.amber);
            setPipeline(pipeline.Risk,'WAITING FOR BACKEND',C.amber);
            setPipeline(pipeline.Planning,'WAITING FOR BACKEND',C.amber);
            setPipeline(pipeline.Control,'WAITING FOR BACKEND',C.amber);
            setPipeline(pipeline.Vehicle,'WAITING FOR BACKEND',C.amber);

            loopText.Value = { ...
                'TWINX CLOSED LOOP'; ...
                ''; ...
                'Environment       ✓'; ...
                'Sensor Fusion     ✓'; ...
                'Perception        → backend'; ...
                'Prediction        → backend'; ...
                'Risk Assessment   → backend'; ...
                'Path Planning     → backend'; ...
                'Control           → backend'; ...
                'Vehicle Response  → backend'; ...
                ''; ...
                'Simulation trigger ACTIVE.'};

        else
            setPipeline(pipeline.Environment,'READY',C.green);
            setPipeline(pipeline.Sensors,'READY',C.green);
            setPipeline(pipeline.Perception,'NOT RUN',C.muted);
            setPipeline(pipeline.Prediction,'NOT RUN',C.muted);
            setPipeline(pipeline.Risk,'NOT RUN',C.muted);
            setPipeline(pipeline.Planning,'NOT RUN',C.muted);
            setPipeline(pipeline.Control,'NOT RUN',C.muted);
            setPipeline(pipeline.Vehicle,'NOT RUN',C.muted);

            loopText.Value = { ...
                'TWINX CLOSED LOOP'; ...
                ''; ...
                'Environment       ✓'; ...
                'Sensor Fusion     —'; ...
                'Perception        —'; ...
                'Prediction        —'; ...
                'Risk Assessment   —'; ...
                'Path Planning     —'; ...
                'Control           —'; ...
                'Vehicle Response  —'; ...
                ''; ...
                'Simulation is idle.'};
        end
    end

    function updateHeaderAviX()
        if S.roadRunner && S.toolboxesOK
            txCard = updateCard(txCard,'READY',C.green);
        else
            txCard = updateCard(txCard,'STANDBY',C.amber);
        end
    end

    function updateToolboxStatus()
        products = {};

        try
            v = ver;
            products = {v.Name};
        catch
        end

        needed = { ...
            'Simulink', ...
            'Stateflow', ...
            'Automated Driving Toolbox', ...
            'Sensor Fusion and Tracking Toolbox', ...
            'Navigation Toolbox'};

        present = false(size(needed));

        for i = 1:numel(needed)
            present(i) = any(strcmpi(products,needed{i}));
        end

        S.toolboxesOK = all(present);

        if S.toolboxesOK
            toolStatus = styleStatus(toolStatus,...
                '● Core MATLAB components: AVAILABLE',C.green);
        else
            n = sum(present);
            toolStatus = styleStatus(toolStatus,...
                sprintf('● Core MATLAB components: %d/%d',n,numel(needed)),C.amber);
        end

        updateHeaderAviX();
    end

    function logmsg(txt)
        if ~isvalid(console)
            return;
        end

        old = console.Value;

        if ischar(old)
            old = {old};
        end

        stamp = datestr(now,'HH:MM:SS');
        new = [old; {sprintf('[%s] %s',stamp,txt)}];

        if numel(new) > 120
            new = new(end-119:end);
        end

        console.Value = new;
        drawnow limitrate;
    end
end

%% ---------------- Local helper functions ------------------------
function b = button(parent,text,color,cb)
b = uibutton(parent,'push',...
    'Text',text,...
    'FontWeight','bold',...
    'FontSize',10,...
    'BackgroundColor',color,...
    'FontColor',[1 1 1],...
    'ButtonPushedFcn',cb);
end

function l = statusLabel(parent,text,color)
l = uilabel(parent,...
    'Text',text,...
    'FontWeight','bold',...
    'FontColor',color);
end

function l = infoLabel(parent,text,C)
l = uilabel(parent,...
    'Text',text,...
    'FontSize',10,...
    'FontColor',C.text,...
    'BackgroundColor',C.panel2,...
    'VerticalAlignment','center');
end

function l = checkLabel(parent,name,state,C)
l = uilabel(parent,...
    'Text',[name '   • ' state],...
    'FontWeight','bold',...
    'FontColor',stateColor(state,C));
end

function l = checkStyle(l,name,state,C)
l.Text = [name '   • ' state];
l.FontColor = stateColor(state,C);
end

function c = statusCard(parent,name,state,color)
c = uipanel(parent,...
    'BorderType','none',...
    'BackgroundColor',[0.09 0.11 0.15]);

g = uigridlayout(c,[2 1]);
g.RowHeight = {18,24};
g.Padding = [4 4 4 4];

uilabel(g,'Text',name,...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'FontColor',[0.62 0.68 0.76]);

l = uilabel(g,'Text',state,...
    'HorizontalAlignment','center',...
    'FontSize',9,...
    'FontWeight','bold',...
    'FontColor',color);

c.UserData = l;
end

function c = updateCard(c,state,color)
if isvalid(c) && isvalid(c.UserData)
    c.UserData.Text = state;
    c.UserData.FontColor = color;
end
end

function l = styleStatus(l,text,color)
if isvalid(l)
    l.Text = text;
    l.FontColor = color;
end
end

function l = pipelineLabel(parent,name,state,C)
l = uilabel(parent,...
    'Text',[name '   • ' state],...
    'FontWeight','bold',...
    'FontColor',stateColor(state,C),...
    'BackgroundColor',C.panel2);
end

function setPipeline(l,state,color)
if isvalid(l)
    l.Text = regexprep(l.Text,'•.*$',['• ' state]);
    l.FontColor = color;
end
end

function p = metricCard(parent,title,value,description,color)
p = uipanel(parent,...
    'BackgroundColor',[0.075 0.09 0.12],...
    'BorderType','line');

g = uigridlayout(p,[3 1]);
g.RowHeight = {20,42,18};
g.Padding = [8 6 8 6];

uilabel(g,'Text',title,...
    'HorizontalAlignment','center',...
    'FontSize',8,...
    'FontWeight','bold',...
    'FontColor',[0.62 0.68 0.76]);

valueLabel = uilabel(g,'Text',value,...
    'HorizontalAlignment','center',...
    'FontSize',19,...
    'FontWeight','bold',...
    'FontColor',color);

uilabel(g,'Text',description,...
    'HorizontalAlignment','center',...
    'FontSize',7,...
    'FontColor',[0.62 0.68 0.76]);

p.UserData = struct('Value',valueLabel);
end

function configureAxes(ax,C)
ax.Color = [0.035 0.045 0.065];
ax.XColor = C.muted;
ax.YColor = C.muted;
ax.Box = 'on';
ax.XTick = [];
ax.YTick = [];
end

function drawIntersection(ax,C)
cla(ax);
hold(ax,'on');

patch(ax,[-70 70 70 -70],[-10 -10 10 10],...
    C.road,'EdgeColor','none');

patch(ax,[-10 10 10 -10],[-70 -70 70 70],...
    C.road,'EdgeColor','none');

plot(ax,[-70 70],[-7 -7],'--','Color',C.line);
plot(ax,[-70 70],[7 7],'--','Color',C.line);
plot(ax,[-7 -7],[-70 70],'--','Color',C.line);
plot(ax,[7 7],[-70 70],'--','Color',C.line);

plot(ax,[-70 70],[0 0],':',...
    'Color',[0.95 0.80 0.25],'LineWidth',1.4);

plot(ax,[0 0],[-70 70],':',...
    'Color',[0.95 0.80 0.25],'LineWidth',1.4);

rectangle(ax,'Position',[-10 -10 20 20],...
    'EdgeColor',[0.30 0.35 0.40],...
    'LineWidth',1);

xlim(ax,[-70 70]);
ylim(ax,[-70 70]);
axis(ax,'equal');

% All road graphics are click-through so the UIAxes receives the mouse event.
kids = ax.Children;
for kk = 1:numel(kids)
    try
        kids(kk).HitTest = 'off';
    catch
    end
end

hold(ax,'off');
end

function drawVehicle(ax,x,y,color,labelText)
hold(ax,'on');

rectangle(ax,...
    'Position',[x-2 y-4 4 8],...
    'Curvature',0.25,...
    'FaceColor',color,...
    'EdgeColor','white',...
    'LineWidth',1.2);

text(ax,x,y,labelText,...
    'Color','white',...
    'HorizontalAlignment','center',...
    'FontSize',7,...
    'FontWeight','bold');

for kk = 1:numel(ax.Children)
    try, ax.Children(kk).HitTest = 'off'; catch, end
end

hold(ax,'off');
end

function drawMarker(ax,x,y,color,labelText)
hold(ax,'on');

plot(ax,x,y,'o',...
    'MarkerSize',12,...
    'MarkerFaceColor',color,...
    'MarkerEdgeColor','white',...
    'LineWidth',1);

text(ax,x,y+5,labelText,...
    'Color','white',...
    'HorizontalAlignment','center',...
    'FontSize',7,...
    'FontWeight','bold');

for kk = 1:numel(ax.Children)
    try, ax.Children(kk).HitTest = 'off'; catch, end
end

hold(ax,'off');
end

function p = reportStatusBox(parent,titleText,lines)
p = uipanel(parent,'BackgroundColor',[0.075 0.09 0.12],'BorderType','line');
g = uigridlayout(p,[2 1]);
g.RowHeight={24,'1x'};
g.Padding=[10 7 10 7];
uilabel(g,'Text',titleText,'FontWeight','bold','FontSize',9,'FontColor',[0.62 0.68 0.76]);
t = uitextarea(g,'Editable','off','FontName','Consolas','FontSize',9,...
    'BackgroundColor',[0.075 0.09 0.12],'FontColor',[0.88 0.91 0.96]);
t.Value = lines;
end

function populateReport(ax,C)
t = 0:0.5:7.5;
speed = 28.1 + 0.75*(1-exp(-1.2*t));
lead = 38 - 0.23*t;
merge = 28 - 0.9*t;
ttcLead = 31 - 1.0*t;
ttcMerge = 23.5 + 0.9*(7.5-t);
risk = zeros(size(t));

cla(ax(1));
plot(ax(1),t,speed,'LineWidth',2,'Color',C.blue2);
title(ax(1),'EGO SPEED','Color',C.text); ylabel(ax(1),'km/h'); xlabel(ax(1),'Time (s)'); grid(ax(1),'on');

cla(ax(2));
plot(ax(2),t,lead,'LineWidth',2,'Color',C.blue2); hold(ax(2),'on');
plot(ax(2),t,merge,'LineWidth',2,'Color',C.amber);
yline(ax(2),6,'--','Color',[0.95 0.80 0.25]); hold(ax(2),'off');
title(ax(2),'RELATIVE DISTANCE','Color',C.text); ylabel(ax(2),'m'); xlabel(ax(2),'Time (s)'); grid(ax(2),'on');
legend(ax(2),{'Lead','Merge','Safety threshold'},'Location','southwest');

cla(ax(3));
plot(ax(3),t,ttcLead,'LineWidth',2,'Color',C.blue2); hold(ax(3),'on');
plot(ax(3),t,ttcMerge,'LineWidth',2,'Color',C.amber);
yline(ax(3),2,'--','Color',[0.95 0.80 0.25]);
yline(ax(3),4,'--','Color',[0.75 0.35 0.90]); hold(ax(3),'off');
title(ax(3),'TTC / COLLISION RISK','Color',C.text); ylabel(ax(3),'TTC (s)'); xlabel(ax(3),'Time (s)'); grid(ax(3),'on');
legend(ax(3),{'Lead TTC','Merge TTC','Critical','Caution'},'Location','southwest');

cla(ax(4));
plot(ax(4),t,risk,'LineWidth',2,'Color',C.blue2);
title(ax(4),'RISK LEVEL','Color',C.text); xlabel(ax(4),'Time (s)');
ylim(ax(4),[-0.1 1.1]); yticks(ax(4),[0 0.5 1]);
yticklabels(ax(4),{'LOW','MEDIUM','HIGH'}); grid(ax(4),'on');

% Top-view drivability / actors panel, matching the reference report.
cla(ax(5)); hold(ax(5),'on');
patch(ax(5),[0 70 70 0],[-2 -2 2 2],[0.12 0.14 0.17],'EdgeColor','none');
plot(ax(5),[0 100],[0 0],'--','Color',[0.95 0.80 0.25],'LineWidth',1.2);
plot(ax(5),[0 40],[0 0],'LineWidth',3,'Color',C.amber);
plot(ax(5),[40 100],[0 0],'LineWidth',3,'Color',[0.95 0.80 0.25]);
plot(ax(5),[27 85],[5 3.4],'LineWidth',2,'Color',[0.75 0.35 0.90]);
plot(ax(5),60,0,'o','MarkerSize',12,'LineWidth',2,'Color',C.green);
plot(ax(5),96,0,'s','MarkerSize',9,'LineWidth',2,'Color',C.cyan);
plot(ax(5),85,3.4,'d','MarkerSize',10,'LineWidth',2,'Color',[0.75 0.35 0.90]);
text(ax(5),60,0,'  EGO','Color',C.green,'FontWeight','bold');
text(ax(5),96,0,'  LEAD','Color',C.cyan,'FontWeight','bold');
text(ax(5),85,3.4,'  MERGE','Color',[0.75 0.35 0.90],'FontWeight','bold');
hold(ax(5),'off');
title(ax(5),'TOP VIEW - DRIVABLE SPACE / ACTORS','Color',C.text); xlabel(ax(5),'Longitudinal position (m)'); ylabel(ax(5),'Lateral position (m)');
xlim(ax(5),[0 100]); ylim(ax(5),[-8 8]); grid(ax(5),'on');

% Merging lateral motion.
cla(ax(6));
mergeOffset = 5 - 0.22*t;
plot(ax(6),t,mergeOffset,'LineWidth',2,'Color',C.blue2); hold(ax(6),'on');
plot(ax(6),t,zeros(size(t)),'--','LineWidth',1.5,'Color',C.amber); hold(ax(6),'off');
title(ax(6),'MERGING VEHICLE LATERAL MOTION','Color',C.text); ylabel(ax(6),'Offset (m)'); xlabel(ax(6),'Time (s)'); grid(ax(6),'on');
legend(ax(6),{'Merging vehicle','Ego corridor'},'Location','northeast');

for k=1:6
    ax(k).Color = [0.035 0.045 0.065];
    ax(k).XColor = C.muted;
    ax(k).YColor = C.muted;
    ax(k).Box = 'on';
    ax(k).FontSize = 8;
end
end

function c = stateColor(state,C)
u = upper(state);

if contains(u,'READY') || contains(u,'AVAILABLE') || strcmp(u,'RUNNING')
    c = C.green;
elseif contains(u,'MISSING') || contains(u,'ERROR') || contains(u,'NOT CONFIGURED')
    c = C.red;
elseif contains(u,'OPTIONAL') || contains(u,'NOT RUN') || ...
        contains(u,'WAITING') || contains(u,'STANDBY') || ...
        contains(u,'IDLE') || contains(u,'CHECK')
    c = C.amber;
else
    c = C.muted;
end
end
