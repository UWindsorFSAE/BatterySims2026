%% build_pack_model.m
clear; clc
load pack_profile.mat
mdl = 'pack_sim';
if bdIsLoaded(mdl), close_system(mdl,0); end
new_system(mdl); open_system(mdl);

% model settings
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','dt','StopTime','nLaps*T_lap');
set_param(mdl,'PreLoadFcn','load pack_profile.mat','InitFcn','load pack_profile.mat');

A = @(type,name,pos,varargin) add_block(type,[mdl '/' name],'Position',pos,varargin{:});

A('simulink/Sources/From Workspace','Power',[30 100 130 130],'VariableName','P_profile', ...
    'OutputAfterFinalValue','Holding final value');
A('simulink/Discontinuities/Saturation','PowerCap',[170 100 220 130], ...
    'UpperLimit','P_cap','LowerLimit','0');
A('simulink/Math Operations/MinMax','VSafe',[270 160 320 200],'Function','max','Inputs','2');
A('simulink/Sources/Constant','Vfloor',[200 200 240 220],'Value','50');
A('simulink/Math Operations/Product','Divide',[370 95 410 135],'Inputs','*/');
A('simulink/Math Operations/MinMax','CurrentLimit',[450 95 500 135],'Function','min','Inputs','2');
A('simulink/Sources/Constant','ImaxConst',[390 160 440 180],'Value','I_max');
A('simulink/Math Operations/Gain','PerCell',[540 100 590 130],'Gain','1/Np');

% ---- CELL: stand-in constant. DELETE this and drop in the Batemo block. ----
A('simulink/Sources/Constant','CellStandIn_V',[650 100 710 130],'Value','3.7');

A('simulink/Math Operations/Gain','ToPack',[760 100 810 130],'Gain','Ns');
A('simulink/Discrete/Unit Delay','VDelay',[760 180 810 210], ...
    'InitialCondition','V0_pack','SampleTime','dt');

% loggers
names = {'I_pack','V_pack','V_cell','I_cell'};
for k = 1:numel(names)
    A('simulink/Sinks/To Workspace',['log_' names{k}],[900 40+45*k 980 70+45*k], ...
        'VariableName',names{k},'SaveFormat','Timeseries');
end

% cutoff stop
A('simulink/Logic and Bit Operations/Compare To Constant','Cutoff',[760 260 840 290], ...
    'relop','<','const','Vc_min');
A('simulink/Sinks/Stop','StopSim',[880 260 920 290]);

% wiring
L = @(a,b) add_line(mdl,a,b,'autorouting','on');
L('Power/1','PowerCap/1');
L('PowerCap/1','Divide/1');
L('VDelay/1','VSafe/1');   L('Vfloor/1','VSafe/2');
L('VSafe/1','Divide/2');
L('Divide/1','CurrentLimit/1'); L('ImaxConst/1','CurrentLimit/2');
L('CurrentLimit/1','PerCell/1');
L('CurrentLimit/1','log_I_pack/1');
L('PerCell/1','log_I_cell/1');
L('CellStandIn_V/1','ToPack/1');
L('CellStandIn_V/1','log_V_cell/1');
L('CellStandIn_V/1','Cutoff/1');
L('ToPack/1','VDelay/1');
L('ToPack/1','log_V_pack/1');
L('Cutoff/1','StopSim/1');

save_system(mdl);
disp('Built pack_sim.slx. Next: replace CellStandIn_V with the Batemo block.');