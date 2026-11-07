function report(out, T_lap, nLaps, Np)
    t = out.I_pack.Time;  I = out.I_pack.Data(:);  V = out.V_pack.Data(:);
    Vc = out.V_cell.Data(:);  soc = out.SOC.Data(:);  Tc = out.T_cell.Data(:);
    if max(soc) <= 1.5, soc = soc*100; end
    if max(Tc) > 200, Tc = Tc - 273.15; end

    [Ipk,k] = max(I);
    fprintf('\n===== RESULTS =====\n');
    fprintf('Finished %.1f of %d laps\n', t(end)/T_lap, nLaps);
    fprintf('Peak pack current: %.1f A at t = %.0f s (lap %d)\n', Ipk, t(k), floor(t(k)/T_lap)+1);
    fprintf('Peak per cell:     %.1f A\n', Ipk/Np);
    fprintf('Mean / RMS:        %.1f / %.1f A\n', mean(I), sqrt(mean(I.^2)));
    fprintf('Ah drawn: %.2f | Wh drawn: %.0f\n', trapz(t,I)/3600, trapz(t,I.*V)/3600);
    fprintf('Final SOC: %.1f %% | Min cell V: %.3f | Max cell T: %.1f C\n', soc(end), min(Vc), max(Tc));

    lapIdx = floor(t/T_lap)+1;
    peakPerLap = accumarray(lapIdx, I, [], @max);
    meanPerLap = accumarray(lapIdx, I, [], @mean);
    socEndLap  = accumarray(lapIdx, soc, [], @(x) x(end));
    disp(table((1:numel(peakPerLap))', peakPerLap, meanPerLap, socEndLap, ...
        'VariableNames', {'Lap','PeakA','MeanA','SOC_end'}))

    figure
    subplot(4,1,1), plot(t/60,I),   ylabel('Pack current [A]'), grid on
    subplot(4,1,2), plot(t/60,soc), ylabel('SOC [%]'), grid on
    subplot(4,1,3), plot(t/60,V),   ylabel('Pack voltage [V]'), grid on
    subplot(4,1,4), plot(peakPerLap,'-o'), xlabel('Lap'), ylabel('Peak current [A]'), grid on
end

%{
%% ===== SETUP (always run first after opening MATLAB) =====
cd 'C:\path\to\your\folder'          % <-- CHANGE: folder with pack_profile.mat, pack_sim.slx, report.m
load pack_profile.mat                % loads P_profile, T_lap, nLaps, dt, Ns, Np, ...
Vc_min = 2.5*Ns;                     % cutoff is pack voltage now: 2.5 V x 112 = 280 V
set_param('pack_sim','SolverType','Fixed-step','Solver','FixedStepDiscrete','FixedStep','dt');  % Batemo needs fixed-step discrete
set_param('pack_sim/PerCell','Gain','-1');   % block is the whole 112s5p pack, so pass pack current, sign flipped so SOC falls
set_param('pack_sim/ToPack','Gain','1');     % block already outputs pack voltage, so no x112

%% ===== STEP 1: TIMING TEST (2 laps) =====
I_max = 1000;                                % effectively no current limit, so peak shows true demand
set_param('pack_sim','StopTime','2*T_lap');  % simulate only 2 laps (~123 s)
tic; out = sim('pack_sim'); toc              % toc prints the wall-clock seconds this took
% Estimate full race time = toc x 11. If under ~15 min, continue.

%% ===== STEP 2: FULL RACE, NO CURRENT LIMIT =====
I_max = 1000;                                % no limit: this run shows your true worst-case demand
set_param('pack_sim','StopTime','nLaps*T_lap');  % all 22 laps (~1357 s)
out1 = sim('pack_sim');                      % run the simulation (may take several minutes)
report(out1, T_lap, nLaps, Np)               % print peak/mean/RMS current, SOC, per-lap table, plots

%% ===== STEP 3: FULL RACE, REAL CURRENT LIMIT =====
I_max = 104;                                 % <-- CHANGE to 129.5 if that is your real BMS/fuse limit
out2 = sim('pack_sim');                      % same race, but current is clipped at I_max
report(out2, T_lap, nLaps, Np)               % compare with Step 2: same numbers = limit never engages

%% ===== STEP 4: SAVE RESULTS =====
save('batemo_results.mat','out1','out2');    % stores both runs so you can reload them later

%}