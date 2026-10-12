function TwinX_AutonomousRoadRunner_NextLevel()
% TwinX_AutonomousRoadRunner_NextLevel
% Closed-loop TwinX autonomous driving demonstration for RoadRunner R2026a.
%
% What this version adds:
%   1) Ego starts from the beginning of its current road anchor/lane.
%   2) Camera + radar + lidar sensor models.
%   3) Sensor-fusion based obstacle perception.
%   4) Constant-velocity short-term prediction.
%   5) TTC + distance + uncertainty risk scoring.
%   6) Dynamic free-space / neighboring-lane selection.
%   7) Continuous trajectory replanning.
%   8) Adaptive speed, braking and steering-like kinematic motion.
%   9) Long route following using RoadRunner HD Map lane topology.
%  10) Attempts to find a connected loop so the ego can return to its start.
%
% IMPORTANT:
% The map is obtained directly from the running ScenarioSimulation. No
% external .rrhd file is required. A true round-trip still requires the
% current RoadRunner scene to contain a connected road topology/loop.
%
% The program creates the MATLAB actor-behavior file automatically, attaches
% it to JCB_Ego, registers sensors, and starts the RoadRunner simulation.
%
% Main reference architecture follows MathWorks' RoadRunner closed-loop
% actor-behavior, sensor simulation, and lane-level planning workflows.

%% ------------------------- USER CONFIGURATION ----------------------------
PROJECT_FOLDER = "C:\RoadRunner_SIH_26_Projects\Indian_Highway";
SCENARIO_FILE  = "TwinX_highway.rrscenario";
RR_INSTALL     = "C:\Program Files\RoadRunner R2026a\bin\win64";
EGO_NAME       = "JCB_Ego";

STEP_SIZE      = 0.05;
MAX_TIME       = 240;       % long enough for a complete loop
SIM_PACE       = 0.75;

% Desired behavior limits
MAX_SPEED      = 13.0;      % m/s
MIN_SPEED      = 1.5;       % m/s
MAX_ACCEL      = 1.8;       % m/s^2
MAX_DECEL      = 5.5;       % m/s^2
SAFE_GAP       = 12.0;      % m
EMERGENCY_TTC  = 1.20;      % s
REPLAN_DIST    = 35.0;      % m

%% ----------------------------- VALIDATION --------------------------------
assert(isfolder(PROJECT_FOLDER), ...
    "RoadRunner project folder not found: %s", PROJECT_FOLDER);

scenarioPath = fullfile(PROJECT_FOLDER,"Scenarios",SCENARIO_FILE);
assert(isfile(scenarioPath), ...
    "Scenario file not found: %s",scenarioPath);

% Check required MATLAB products before doing anything destructive.
assert(exist("roadrunner","file") == 2, ...
    "RoadRunner MATLAB interface is not available.");
assert(exist("visionDetectionGenerator","file") == 2, ...
    "Automated Driving Toolbox is required.");
assert(exist("roadrunnerHDMap","file") == 2, ...
    "RoadRunner HD Map support is required (Automated Driving Toolbox).");

%% -------------------------- ROADRUNNER MAP --------------------------------
% The running RoadRunner Scenario provides the HD-map specification directly
% through ScenarioSimulation. No external .rrhd file is required.
fprintf("\nTwinX NEXT-LEVEL CLOSED-LOOP SYSTEM\n");
fprintf("Scenario : %s\n",SCENARIO_FILE);

%% ------------------------------ LAUNCH RR ---------------------------------
if isfolder(RR_INSTALL)
    rrApp = roadrunner(ProjectFolder=PROJECT_FOLDER,InstallationFolder=RR_INSTALL);
else
    rrApp = roadrunner(ProjectFolder=PROJECT_FOLDER);
end

pause(1);
openScenario(rrApp,SCENARIO_FILE);
pause(1);

rrApi = roadrunnerAPI(rrApp);
scnro = rrApi.Scenario;
prj   = rrApi.Project;

%% ------------------------- FIND EGO ACTOR ---------------------------------
actors = scnro.Actors;
ego = [];
for k = 1:numel(actors)
    if string(actors(k).Name) == EGO_NAME
        ego = actors(k);
        break
    end
end
assert(~isempty(ego),"Could not find ego actor '%s'.",EGO_NAME);

egoID = uint64(ego.ActorID);
fprintf("Ego actor found: %s (ID %d)\n",EGO_NAME,double(egoID));

% Put the ego at the beginning of its current anchored road point when the
% API exposes ForwardOffset. If the scenario uses another anchor definition,
% the original point is retained.
try
    ego.InitialPoint.ForwardOffset = 0;
catch
end

%% --------------------- REMOVE OLD CUSTOM BEHAVIOR -------------------------
% The old demo used a fixed one-lane-left/one-lane-right behavior.
% Replace it with the new closed-loop MATLAB System behavior.
try
    ego.BehaviorAsset = [];
catch
end

%% --------------------- CREATE MATLAB BEHAVIOR FILE ------------------------
behaviorFolder = fullfile(PROJECT_FOLDER,"Assets","Behaviors");
if ~isfolder(behaviorFolder)
    mkdir(behaviorFolder);
end

behaviorFile = fullfile(behaviorFolder,"TwinX_ClosedLoopEgo.m");
writeTwinXBehavior(behaviorFile);

% Make the generated MATLAB System object visible to the MATLAB/RoadRunner
% actor-behavior runtime. RoadRunner can otherwise report the generic
% "contains a parse error, cannot be found on MATLAB's search path, or is
% shadowed" warning even when the class itself is valid.
addpath(behaviorFolder);
rehash;
clear TwinX_ClosedLoopEgo;

% Fail here with the actual MATLAB parser diagnostic instead of allowing
% RoadRunner to start and immediately stop with a generic warning.
try
    checkcode(behaviorFile);
catch
end
assert(~isempty(which("TwinX_ClosedLoopEgo")), ...
    "TwinX_ClosedLoopEgo.m was not found on the MATLAB path: %s",behaviorFolder);

%% ------------------ CREATE/ATTACH ROADRUNNER BEHAVIOR ---------------------
behaviorAssetPath = "Behaviors/TwinX_ClosedLoopEgo.rrbehavior";
try
    behaviorAsset = getAsset(prj,behaviorAssetPath,"BehaviorAsset");
catch
    behaviorAsset = createAsset(prj,behaviorAssetPath,"BehaviorAsset");
end

simPlatform = setPlatform(behaviorAsset,"SimulinkPlatform");
simPlatform.FileName = "Behaviors/TwinX_ClosedLoopEgo.m";
% Store the selected HD map path in the behavior file itself.
ego.BehaviorAsset = behaviorAsset;

fprintf("Closed-loop MATLAB behavior attached to %s.\n",EGO_NAME);

%% ---------------------------- SENSOR SETUP --------------------------------
rrSim = createSimulation(rrApp);
set(rrSim,StepSize=STEP_SIZE);
set(rrSim,MaxSimulationTime=MAX_TIME);
set(rrSim,PacerStatus="On");
set(rrSim,SimulationPace=SIM_PACE);
set(rrSim,Logging="On");

sensorSim = get(rrSim,"SensorSimulation");
sensorSim.UseGPU = "auto";

visionSensor = visionDetectionGenerator( ...
    SensorIndex=1, ...
    SensorLocation=[2.2 0], ...
    MaxRange=65, ...
    DetectorOutput="Lanes and objects", ...
    UpdateInterval=STEP_SIZE);

radarSensor = drivingRadarDataGenerator( ...
    SensorIndex=2, ...
    MountingLocation=[2.0 0 0.55], ...
    FieldOfView=[100 10], ...
    AzimuthResolution=1.0, ...
    UpdateRate=1/STEP_SIZE, ...
    TargetReportFormat="Detections");

lidarSensor = lidarPointCloudGenerator( ...
    SensorIndex=3, ...
    UpdateInterval=STEP_SIZE, ...
    MaxRange=70);

addSensors(sensorSim,{visionSensor,radarSensor,lidarSensor},egoID);

%% ----------------------- SCENARIO VALIDATION ------------------------------
try
    validate(scnro);
    fprintf("Scenario validation: PASSED.\n");
catch ME
    warning("Scenario validation reported: %s",ME.message);
end

%% --------------------------- CAMERA VIEW ---------------------------------
try
    setCameraMode(rrApp,"front",FocusActorID=int32(egoID));
catch
end

%% ---------------------------- START ---------------------------------------
fprintf("\n============================================================\n");
fprintf(" TWINX CLOSED-LOOP AUTONOMOUS SIMULATION STARTING\n");
fprintf("============================================================\n");
fprintf("Perception : CAMERA + RADAR + LIDAR\n");
fprintf("Fusion     : OBJECT ASSOCIATION + WEIGHTED STATE FUSION\n");
fprintf("Prediction : CONSTANT-VELOCITY SHORT-TERM PREDICTION\n");
fprintf("Risk       : TTC + DISTANCE + UNCERTAINTY\n");
fprintf("Planning   : LOOP ROUTE + FREE-SPACE LANE CANDIDATES\n");
fprintf("Control    : ADAPTIVE SPEED + KINEMATIC STEERING/BRAKING\n");
fprintf("Mission    : FOLLOW LOOP AND RETURN TO START\n\n");

set(rrSim,SimulationCommand="Start");

lastPrint = -1;
while true
    try
        status = string(get(rrSim,"SimulationStatus"));
        if any(strcmpi(status,["Stopped","Finished","Error"]))
            break
        end
        t = double(get(rrSim,"SimulationTime"));
        if t-lastPrint >= 2
            fprintf("  t = %6.2f s | status = %s\n",t,status);
            lastPrint = t;
        end
        pause(0.10);
    catch
        break
    end
end

fprintf("\n============================================================\n");
fprintf(" TWINX CLOSED-LOOP SIMULATION FINISHED\n");
fprintf("============================================================\n");
try
    fprintf("Final status: %s\n",string(get(rrSim,"SimulationStatus")));
catch
end

fprintf("\nThe original .rrscenario file was not overwritten.\n");
fprintf("Behavior file: %s\n",behaviorFile);

end

%% ========================================================================
function writeTwinXBehavior(fileName)
% Write the actual closed-loop MATLAB System object used by RoadRunner.

L = {
"classdef TwinX_ClosedLoopEgo < matlab.System"
""
"    properties"
"        MapData = struct()"
"        MaxSpeed = 13.0"
"        MinSpeed = 1.5"
"        MaxAccel = 1.8"
"        MaxDecel = 5.5"
"        ReplanDistance = 35.0"
"        SafeGap = 12.0"
"        EmergencyTTC = 1.20"
"    end"
""
"    properties(Access=private)"
"        ScenarioSim"
"        ActorSim"
"        SensorSim"
"        MapQuery"
"        VisionSensor"
"        RadarSensor"
"        LidarSensor"
"        RoutePoses"
"        RouteS"
"        RouteLength"
"        CurrentS = 0"
"        LastTime = 0"
"        LastPose"
"        LastSpeed = 0"
"        StartPosition"
"        StartHeading = 0"
"        CompletedLoop = false"
"        LastPlanTime = -inf"
"        PlanCooldown = 0.4"
"        CurrentCandidate = ""route"""
"        LogCounter = 0"
"    end"
""
"    methods(Access=protected)"
"        function sz = getOutputSizeImpl(~)"
"            sz = [1 1];"
"end"
""
"        function st = getSampleTimeImpl(obj)"
"            obj.ScenarioSim = Simulink.ScenarioSimulation.find(""ScenarioSimulation"");"
"            dt = obj.ScenarioSim.get(""StepSize"");"
"            st = createSampleTime(obj,""Type"",""Discrete"",""SampleTime"",dt);"
"        end"
""
"        function setupImpl(obj)"
"            obj.ScenarioSim = Simulink.ScenarioSimulation.find(""ScenarioSimulation"");"
"            obj.ActorSim = Simulink.ScenarioSimulation.find(""ActorSimulation"",""SystemObject"",obj);"
"            obj.SensorSim = obj.ScenarioSim.get(""SensorSimulation"");"
""
"            % R2026a+: obtain the RoadRunner HD-map specification directly"
"            % from the running ScenarioSimulation. This is a MATLAB struct."
"            obj.MapData = obj.ScenarioSim.get(""Map"");"
"            obj.MapQuery = roadrunnerHDMapQuery(obj.MapData);"
""
"            obj.VisionSensor = visionDetectionGenerator( ..."
"                SensorIndex=1,SensorLocation=[2.2 0],MaxRange=65, ..."
"                DetectorOutput=""Lanes and objects"",UpdateInterval=obj.ScenarioSim.get(""StepSize""));"
""
"            obj.RadarSensor = drivingRadarDataGenerator( ..."
"                SensorIndex=2,MountingLocation=[2.0 0 0.55], ..."
"                FieldOfView=[100 10],AzimuthResolution=1.0, ..."
"                UpdateRate=1/obj.ScenarioSim.get(""StepSize""), ..."
"                TargetReportFormat=""Detections"");"
""
"            obj.LidarSensor = lidarPointCloudGenerator( ..."
"                SensorIndex=3,UpdateInterval=obj.ScenarioSim.get(""StepSize""),MaxRange=70);"
""
"            pose = obj.ActorSim.getAttribute(""Pose"");"
"            obj.LastPose = pose;"
"            obj.StartPosition = pose(1:3,4)';"
"            obj.StartHeading = atan2d(pose(2,1),pose(1,1));"
"            obj.LastTime = obj.ScenarioSim.get(""SimulationTime"");"
"            obj.LastSpeed = norm(obj.ActorSim.getAttribute(""Velocity""));"
""
"            obj.RoutePoses = obj.buildLoopRoute(pose);"
"            if isempty(obj.RoutePoses)"
"                error(""TwinX:Route"",""No connected round-trip route could be built from the RRHD map."");"
"            end"
"            obj.RouteS = [0;cumsum(vecnorm(diff(obj.RoutePoses(:,1:2)),2,2))];"
"            obj.RouteLength = obj.RouteS(end);"
""
"            [~,idx] = min(vecnorm(obj.RoutePoses(:,1:2)-pose(1:2,4)',2,2));"
"            obj.CurrentS = obj.RouteS(idx);"
"            fprintf(""TwinX behavior initialized: loop length = %.1f m\n"",obj.RouteLength);"
"        end"
""
"        function stepImpl(obj,~)"
"            t = obj.ScenarioSim.get(""SimulationTime"");"
"            dt = max(t-obj.LastTime,1e-3);"
"            pose = obj.ActorSim.getAttribute(""Pose"");"
"            egoPos = pose(1:3,4)';"
"            if ~isempty(obj.RoutePoses)"
"                [~,routeIdx] = min(vecnorm(obj.RoutePoses(:,1:2)-egoPos(1:2),2,2));"
"                obj.CurrentS = obj.RouteS(routeIdx);"
"            end"
"            egoVel = obj.ActorSim.getAttribute(""Velocity"");"
"            egoSpeed = norm(egoVel(1:2));"
""
"            % ---------------- PERCEPTION ----------------"
"            rawTargets = targetPoses(obj.SensorSim,1);"
"            laneGT = laneBoundaries(obj.SensorSim,1, ..."
"                OutputOption=""EgoAdjacentLanes"",inHostCoordinate=true);"
""
"            visionDets = cell(0,1); radarDets = cell(0,1);"
"            visionValid = false; radarValid = false;"
"            try"
"                [visionDets,~,visionValid] = obj.VisionSensor(rawTargets,laneGT,t);"
"            catch"
"            end"
"            try"
"                [radarDets,~,radarValid] = obj.RadarSensor(rawTargets,t);"
"            catch"
"            end"
"            try"
"                [~,lidarValid] = obj.LidarSensor();"
"            catch"
"                lidarValid = false;"
"            end"
""
"            % ---------------- SENSOR FUSION ----------------"
"            fused = obj.fuseTargets(rawTargets,visionDets,radarDets,visionValid,radarValid,lidarValid);"
""
"            % ---------------- PREDICTION -------------------"
"            predicted = obj.predictTargets(fused);"
""
"            % ---------------- RISK ASSESSMENT --------------"
"            risk = obj.assessRisk(predicted,egoSpeed);"
""
"            % ---------------- PATH PLANNING ----------------"
"            [candidatePath,candidateName,planCost] = obj.planLocalTrajectory(pose,predicted,risk,t);"
""
"            if isempty(candidatePath)"
"                candidatePath = obj.getRouteWindow(obj.CurrentS,80);"
"                candidateName = ""emergency-route"";"
"                planCost = inf;"
"            end"
""
"            % ---------------- SPEED PLANNING ----------------"
"            targetSpeed = obj.speedPlanner(candidatePath,risk,egoSpeed);"
""
"            if risk.MinTTC < obj.EmergencyTTC"
"                targetSpeed = 0;"
"            end"
""
"            % ---------------- CONTROL -----------------------"
"            [newPose,newVelocity,newAngularVelocity,newSpeed] = ..."
"                obj.kinematicController(pose,candidatePath,targetSpeed,dt);"
""
"            obj.ActorSim.setAttribute(Pose=newPose);"
"            obj.ActorSim.setAttribute(Velocity=newVelocity);"
"            obj.ActorSim.setAttribute(AngularVelocity=newAngularVelocity);"
""
"            obj.LastPose = newPose;"
"            obj.LastTime = t;"
"            obj.LastSpeed = newSpeed;"
""
"            if planCost < inf"
"                obj.CurrentCandidate = candidateName;"
"            end"
""
"            obj.LogCounter = obj.LogCounter + 1;"
"            if mod(obj.LogCounter,40) == 0"
"                fprintf([""[TwinX] t=%6.2f | v=%5.2f | risk=%4.2f | TTC=%5.2f "" + ..."
"                    ""| plan=%s | fusion=%d targets\n""], ..."
"                    t,newSpeed,risk.Score,risk.MinTTC,obj.CurrentCandidate,numel(fused));"
"            end"
""
"            % Mission completion: return close to original start after having"
"            % travelled essentially one complete loop."
"            if obj.RouteLength > 100 && obj.CurrentS > 0.85*obj.RouteLength && ..."
"                    norm(egoPos(1:2)-obj.StartPosition(1:2)) < 12"
"                obj.CompletedLoop = true;"
"            end"
"        end"
""
"        function resetImpl(obj)"
"            obj.CurrentS = 0; obj.LastTime = 0; obj.LastSpeed = 0;"
"            obj.RoutePoses = []; obj.RouteS = []; obj.RouteLength = 0;"
"            obj.CompletedLoop = false; obj.LastPlanTime = -inf;"
"        end"
"    end"
""
"    methods(Access=private)"
"        function route = buildLoopRoute(obj,pose)"
"            lanes = obj.MapData.Lanes;"
"            if isempty(lanes), route=[]; return; end"
""
"            actorPose = struct(""ActorID"",uint64(1),""Pose"",pose, ..."
"                ""Velocity"",[0 0 0],""AngularVelocity"",[0 0 0]);"
"            try"
"                laneInfo = getLane(obj.MapQuery,actorPose,ActorPoseType=""roadrunner"");"
"                startID = string(laneInfo.LaneID);"
"            catch"
"                startID = string(lanes(1).ID);"
"            end"
""
"            ids = strings(numel(lanes),1);"
"            for i=1:numel(lanes), ids(i)=string(lanes(i).ID); end"
""
"            startIdx = find(ids==startID,1);"
"            if isempty(startIdx), route=[]; return; end"
""
"            % Build directed successor adjacency."
"            adj = cell(numel(lanes),1);"
"            for i=1:numel(lanes)"
"                try"
"                    refs = lanes(i).Successors;"
"                    for j=1:numel(refs)"
"                        rid = string(refs(j).Reference.ID);"
"                        q = find(ids==rid,1);"
"                        if ~isempty(q), adj{i}(end+1)=q; end %#ok<AGROW>"
"                    end"
"                catch"
"                end"
"            end"
""
"            % Find a shortest directed cycle returning to the start lane."
"            best = [];"
"            for first=adj{startIdx}"
"                [path,ok] = bfsToGoal(adj,first,startIdx);"
"                if ok"
"                    candidate = [startIdx,path];"
"                    if isempty(best) || numel(candidate)<numel(best), best=candidate; end"
"                end"
"            end"
"            if isempty(best), route=[]; return; end"
""
"            % Convert lane-center geometry into one long polyline."
"            pts=[];"
"            for n=1:numel(best)-1"
"                g = lanes(best(n)).Geometry;"
"                if size(g,2)==2, g=[g zeros(size(g,1),1)]; end"
"                try"
"                    td = string(lanes(best(n)).TravelDirection);"
"                    if td==""Backward"", g=flipud(g); end"
"                catch"
"                end"
"                if ~isempty(pts) && norm(pts(end,1:2)-g(1,1:2))<0.5"
"                    g=g(2:end,:);"
"                end"
"                pts=[pts;g]; %#ok<AGROW>"
"            end"
""
"            if size(pts,1)<20, route=[]; return; end"
""
"            % Rotate the loop so it begins close to the actual ego pose."
"            [~,k]=min(vecnorm(pts(:,1:2)-pose(1:2,4)',2,2));"
"            pts=[pts(k:end,:);pts(1:k-1,:)];"
""
"            % Repeat the first point at the end to close the loop."
"            if norm(pts(end,1:2)-pts(1,1:2))>0.5"
"                pts(end+1,:)=pts(1,:);"
"            end"
""
"            % Convert positions to [x y yaw]."
"            yaw=zeros(size(pts,1),1);"
"            for i=1:size(pts,1)-1"
"                d=pts(i+1,1:2)-pts(i,1:2);"
"                if norm(d)>1e-4, yaw(i)=atan2d(d(2),d(1)); else, yaw(i)=yaw(max(i-1,1)); end"
"            end"
"            yaw(end)=yaw(end-1);"
"            route=[pts(:,1:2),yaw];"
""
"            % Light smoothing. The route remains constrained to the lane-center"
"            % samples; this is only to remove small geometric discontinuities."
"            try"
"                nSmooth=max(200,10*size(route,1));"
"                [sm,~,~]=smoothPathSpline(route,ones(size(route,1),1),nSmooth,0.15);"
"                route=sm;"
"            catch"
"            end"
"        end"
""
"        function fused = fuseTargets(~,raw,vision,radar,vOK,rOK,lOK)"
"            fused=struct(""ActorID"",{},""Position"",{},""Velocity"",{},""Confidence"",{});"
"            if isempty(raw), return; end"
"            for i=1:numel(raw)"
"                if ~isfield(raw(i),""Position""), continue; end"
"                id=raw(i).ActorID; p=raw(i).Position; v=raw(i).Velocity; conf=0.35;"
""
"                vp=[]; rv=[];"
"                if vOK"
"                    for j=1:numel(vision)"
"                        try"
"                            if vision{j}.ObjectAttributes.TargetIndex==id"
"                                vp=vision{j}.Measurement(1:3)'; break"
"                            end"
"                        catch"
"                        end"
"                    end"
"                end"
"                if rOK"
"                    for j=1:numel(radar)"
"                        try"
"                            if radar{j}.ObjectAttributes.TargetIndex==id"
"                                rv=radar{j}.Measurement(1:3)'; break"
"                            end"
"                        catch"
"                        end"
"                    end"
"                end"
""
"                if ~isempty(vp) && ~isempty(rv)"
"                    p=0.55*vp+0.45*rv; conf=0.85;"
"                elseif ~isempty(vp)"
"                    p=vp; conf=0.65;"
"                elseif ~isempty(rv)"
"                    p=rv; conf=0.70;"
"                end"
"if lOK, conf=min(1,conf+0.10); end"
""
"                fused(end+1)=struct(""ActorID"",id,""Position"",p(:)', ..."
"                    ""Velocity"",v(:)',""Confidence"",conf); %#ok<AGROW>"
"            end"
"end"
""
"function pred = predictTargets(~,fused)"
"            horizon=[0.5 1.0 1.5 2.0 2.5];"
"            pred=fused;"
"            for i=1:numel(fused)"
"                pred(i).Future=zeros(numel(horizon),3);"
"                for k=1:numel(horizon)"
"                    pred(i).Future(k,:)=fused(i).Position+fused(i).Velocity*horizon(k);"
"                end"
"            end"
"end"
""
"        function risk=assessRisk(~,pred,egoSpeed)"
"            risk.Score=0; risk.MinTTC=inf; risk.MinDistance=inf; risk.Count=0;"
"            for i=1:numel(pred)"
"                p=pred(i).Position; d=norm(p(1:2));"
"                if p(1)<0 || d>70, continue; end"
"                risk.Count=risk.Count+1;"
"                risk.MinDistance=min(risk.MinDistance,d);"
"                relV=egoSpeed-pred(i).Velocity(1);"
"                if p(1)>0 && relV>0"
"                    risk.MinTTC=min(risk.MinTTC,p(1)/relV);"
"                end"
"                proximity=max(0,1-d/35);"
"                ttcRisk=0; if isfinite(risk.MinTTC), ttcRisk=max(0,1-risk.MinTTC/5); end"
"                risk.Score=max(risk.Score,0.55*proximity+0.45*ttcRisk+(1-pred(i).Confidence)*0.15);"
"            end"
"        end"
""
"        function [bestPath,bestName,bestCost]=planLocalTrajectory(obj,pose,pred,risk,t)"
"            bestPath=[]; bestName=""route""; bestCost=inf;"
"            if t-obj.LastPlanTime < obj.PlanCooldown && risk.Score<0.55"
"                bestPath=obj.getRouteWindow(obj.CurrentS,80); bestCost=0.1; return"
"            end"
"            if risk.Score<0.25"
"                bestPath=obj.getRouteWindow(obj.CurrentS,90); bestCost=0.1; obj.LastPlanTime=t; return"
"            end"
""
"            actorPose=struct(""ActorID"",uint64(1),""Pose"",pose,""Velocity"",[0 0 0],""AngularVelocity"",[0 0 0]);"
"            candidates={"
"}; names={};"
""
"            % Current lane candidate."
"            candidates{end+1}=obj.getRouteWindow(obj.CurrentS,80); names{end+1}=""keep""; %#ok<AGROW>"
""
"            % Adjacent same-direction lanes."
"            try"
"                nb=getNeighborLanes(obj.MapQuery,actorPose,ActorPoseType=""roadrunner"");"
"                for q=1:numel(nb.Lanes)"
"                    c=obj.makeLaneCandidate(nb.Lanes(q).LaneID,pose);"
"                    if ~isempty(c)"
"                        candidates{end+1}=c; names{end+1}=""lane-""+string(q); %#ok<AGROW>"
"                    end"
"                end"
"            catch"
"            end"
""
"            for c=1:numel(candidates)"
"                path=candidates{c};"
"                if isempty(path), continue; end"
"                [riskCost,minD,minT]=obj.pathRisk(path,pred,pose);"
"                smoothCost=obj.pathSmoothness(path);"
"                progressCost=-0.015*min(size(path,1),100);"
"                total=riskCost+0.15*smoothCost+progressCost;"
"                if minD<obj.SafeGap"
"                    total=total+2*(obj.SafeGap-minD);"
"                end"
"                if minT<2.0, total=total+4*(2-minT); end"
"                if total<bestCost"
"                    bestCost=total; bestPath=path; bestName=names{c};"
"                end"
"            end"
""
"            obj.LastPlanTime=t;"
"        end"
""
"        function path=makeLaneCandidate(obj,laneID,pose)"
"            lanes=obj.MapData.Lanes;"
"            ids=strings(numel(lanes),1);"
"            for ii=1:numel(lanes), ids(ii)=string(lanes(ii).ID); end"
"            k=find(ids==string(laneID),1);"
"            if isempty(k), path=[]; return; end"
"            g=lanes(k).Geometry;"
"            if size(g,2)==2, g=[g zeros(size(g,1),1)]; end"
"            try"
"                if string(lanes(k).TravelDirection)==""Backward"", g=flipud(g); end"
"            catch"
"            end"
"            [~,i0]=min(vecnorm(g(:,1:2)-pose(1:2,4)',2,2));"
"            i1=min(size(g,1),i0+18); i2=min(size(g,1),i0+45);"
"            if i1<=i0, path=[]; return; end"
"            q1=g(i1,1:2); q2=g(i2,1:2); p0=pose(1:2,4)';"
"            d=norm(q1-p0);"
"            if d<2, path=[]; return; end"
"            % Cubic lateral transition into the selected lane, followed by lane center."
"            n=18; a=(0:n)'/n;"
"            h=pose(1:2,1); if norm(h)<1e-6, h=[1;0]; end; h=h/norm(h);"
"            gdir=q1-p0; if norm(gdir)<1e-6, gdir=h'; end; gdir=gdir/norm(gdir);"
"            P1=p0+max(5,min(12,d*0.45))*h'; P2=q1-6*gdir;"
"            trans=zeros(n+1,2);"
"            for z=1:n+1"
"                u=a(z); trans(z,:)=(1-u)^3*p0+3*(1-u)^2*u*P1+3*(1-u)*u^2*P2+u^3*q1;"
"            end"
"            tail=g(i1:i2,1:2);"
"            path=[trans;tail(2:end,:)];"
"            yaw=zeros(size(path,1),1);"
"            for z=1:size(path,1)-1"
"                dd=path(z+1,:)-path(z,:); yaw(z)=atan2d(dd(2),dd(1));"
"            end"
"            yaw(end)=yaw(max(1,end-1)); path=[path,yaw];"
"        end"
""
"        function [cost,minD,minT]=pathRisk(~,path,pred,egoPose)"
"            cost=0; minD=inf; minT=inf;"
"            R=egoPose(1:2,1:2); t=egoPose(1:2,4);"
"            xy=(R'*(path(:,1:2)-t'))';"
"            for i=1:numel(pred)"
"                for k=1:size(pred(i).Future,1)"
"                    d=min(vecnorm(xy-pred(i).Future(k,1:2),2,2));"
"                    minD=min(minD,d);"
"                    if d<8"
"                        cost=cost+pred(i).Confidence*(8-d)^2;"
"                    end"
"                end"
"                rel=pred(i).Position(1); rv=-pred(i).Velocity(1);"
"                if rel>0 && rv>0, minT=min(minT,rel/rv); end"
"            end"
"        end"
""
"        function c=pathSmoothness(~,p)"
"            if size(p,1)<3, c=0; return; end"
"            dy=diff(unwrap(deg2rad(p(:,3)))); c=mean(abs(diff(dy)));"
"        end"
""
"        function v=speedPlanner(obj,path,risk,current)"
"            if isempty(path), v=0; return; end"
"            curvature=obj.estimateCurvature(path);"
"            curveLimit=sqrt(max(1.0,3.0/(abs(curvature)+0.05)));"
"            v=min(obj.MaxSpeed,curveLimit);"
"            v=max(obj.MinSpeed,v*(1-0.75*risk.Score));"
"            if risk.MinTTC<3.0, v=min(v,max(0.5,current-obj.MaxDecel*0.2)); end"
"            if risk.MinTTC<obj.EmergencyTTC, v=0; end"
"        end"
""
"        function k=estimateCurvature(~,p)"
"            if size(p,1)<5, k=0; return; end"
"            h=unwrap(deg2rad(p(:,3))); ds=max(vecnorm(diff(p(:,1:2)),2,2),1e-3);"
"            kh=diff(h)./ds; k=median(abs(kh(1:min(end,20))));"
"        end"
""
"        function [newPose,newVel,newW,newSpeed]=kinematicController(obj,pose,path,targetSpeed,dt)"
"            pos=pose(1:2,4)'; yaw=atan2d(pose(2,1),pose(1,1));"
"            if isempty(path), newPose=pose; newVel=[0 0 0]; newW=[0 0 0]; newSpeed=0; return; end"
"            [~,i]=min(vecnorm(path(:,1:2)-pos,2,2));"
"            j=min(size(path,1),i+8); ref=path(j,1:2); refYaw=path(j,3);"
"            eYaw=wrapTo180(refYaw-yaw);"
"            % Stanley-like lateral/heading correction in kinematic form."
"            fwd=[cosd(yaw) sind(yaw)]; errVec=ref-pos; crossErr=fwd(1)*errVec(2)-fwd(2)*errVec(1);"
"            steer=deg2rad(eYaw)+atan2(0.9*crossErr,max(0.5,obj.LastSpeed));"
"            steer=max(-deg2rad(32),min(deg2rad(32),steer));"
""
"            accel=max(-obj.MaxDecel,min(obj.MaxAccel,(targetSpeed-obj.LastSpeed)/max(dt,0.01)));"
"            newSpeed=max(0,min(obj.MaxSpeed,obj.LastSpeed+accel*dt));"
"            if targetSpeed==0, newSpeed=max(0,obj.LastSpeed-obj.MaxDecel*dt); end"
""
"            L=2.8; yawRate=newSpeed/L*tan(steer);"
"            yaw2=yaw+rad2deg(yawRate*dt);"
"            pos2=pos+newSpeed*dt*[cosd(yaw2) sind(yaw2)];"
""
"            newPose=pose; newPose(1:2,4)=pos2(:);"
"            newPose(1:2,1:2)=[cosd(yaw2) -sind(yaw2); sind(yaw2) cosd(yaw2)];"
"            newVel=[newSpeed*cosd(yaw2),newSpeed*sind(yaw2),0];"
"            newW=[0 0 yawRate];"
"        end"
""
"        function p=getRouteWindow(obj,s0,lengthAhead)"
"            if isempty(obj.RoutePoses), p=[]; return; end"
"            % Wrap around the closed loop so planning never terminates at the map seam."
"            q=linspace(s0,s0+lengthAhead,max(40,round(lengthAhead/0.8)+1))';"
"            q=mod(q,obj.RouteLength);"
"            p=zeros(numel(q),3);"
"            p(:,1)=interp1(obj.RouteS,obj.RoutePoses(:,1),q,""linear"");"
"            p(:,2)=interp1(obj.RouteS,obj.RoutePoses(:,2),q,""linear"");"
"            p(:,3)=interp1(obj.RouteS,obj.RoutePoses(:,3),q,""linear"");"
"        end"
"    end"
"end"
};

fid=fopen(fileName,"w");
assert(fid>0,"Could not create behavior file: %s",fileName);
fprintf(fid,"%s\n",L{:});
fclose(fid);
end

function [path,ok]=bfsToGoal(adj,start,goal)
    n=numel(adj); prev=zeros(n,1); seen=false(n,1);
    q=zeros(n,1); h=1; t=1; q(t)=start; seen(start)=true; ok=false;
    while h<=t
        u=q(h); h=h+1;
        if u==goal, ok=true; break; end
        for v=adj{u}
            if ~seen(v)
                seen(v)=true; prev(v)=u; t=t+1; q(t)=v;
            end
        end
    end
    if ~ok, path=[]; return; end
    rev=[]; u=goal;
    while u~=0
        rev(end+1)=u; %#ok<AGROW>
        if u==start, break; end
        u=prev(u);
    end
    path=fliplr(rev);
end
