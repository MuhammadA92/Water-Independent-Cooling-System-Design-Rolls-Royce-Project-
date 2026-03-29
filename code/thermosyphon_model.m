% steam_sponge_thermosyphon_PDC_Q_SWEEP_ALLINONE.m
% =========================================================================
% ONE-FILE: PDC-style step test (steady-state sweep) on Q_total.
% Sweeps down from 147.7 MW in -10 MW steps, then up in +10 MW steps,
% stopping when results become "unrealistic" by simple criteria.
% Outputs a summary table for each Q_total.
% =========================================================================
clear; clc; close all;

%% ---------------- USER SETTINGS ----------------
Q_base_MW   = 147.7;   % baseline [MW]
dQ_MW       = 10;      % step size [MW]
max_steps_each_side = 25; % hard cap so it can't run forever

% "Realism" stop criteria (edit if you want)
max_modules = 5000;        % stop if module count exceeds this
max_parasitic_frac = 0.20; % stop if fan power > 20% of Q_total
min_Q_MW = 10;             % stop if Q gets too small / meaningless

%% ---------------- BUILD Q VECTOR ----------------
Q_list_MW = Q_base_MW;  % start

% sweep down
Qk = Q_base_MW - dQ_MW;
for i=1:max_steps_each_side
    if Qk < min_Q_MW
        break;
    end
    Q_list_MW(end+1) = Qk; %#ok<SAGROW>
    Qk = Qk - dQ_MW;
end

% sweep up
Qk = Q_base_MW + dQ_MW;
for i=1:max_steps_each_side
    Q_list_MW(end+1) = Qk; %#ok<SAGROW>
    Qk = Qk + dQ_MW;
end

% Put baseline first, then decreasing, then increasing (as you described)
Q_down = sort(Q_list_MW(Q_list_MW<=Q_base_MW),'descend');  % 147.7,137.7,127.7,...
Q_up   = sort(Q_list_MW(Q_list_MW>=Q_base_MW),'ascend');   % 147.7,157.7,...
Q_vec_MW = [Q_down, Q_up(2:end)];

%% ---------------- RUN SWEEP ----------------
n = numel(Q_vec_MW);

% Preallocate containers (use NaN, then fill)
Q_MW        = nan(n,1);
N_modules   = nan(n,1);
Pfan_MW     = nan(n,1);
Vdot_m3s    = nan(n,1);
UA_margin   = nan(n,1);
Tair_out_C  = nan(n,1);
N_TPCT      = nan(n,1);

stop_idx = n;  % will shorten if stop criteria hit

for k=1:n
    Q_MW(k) = Q_vec_MW(k);
    out = steam_sponge_model_run(Q_MW(k)*1e6);

    % Pull outputs (guarded)
    if isfield(out,'N_modules'); N_modules(k) = out.N_modules; end
    if isfield(out,'P_fan_total_W'); Pfan_MW(k) = out.P_fan_total_W/1e6; end
    if isfield(out,'Vdot_air_total_m3s'); Vdot_m3s(k) = out.Vdot_air_total_m3s; end
    if isfield(out,'UA_margin'); UA_margin(k) = out.UA_margin; end
    if isfield(out,'T_air_out_C'); Tair_out_C(k) = out.T_air_out_C; end
    if isfield(out,'N_TPCT_total'); N_TPCT(k) = out.N_TPCT_total; end

    % ---- stop criteria ----
    parasitic_frac = Pfan_MW(k)*1e6 / (Q_MW(k)*1e6); % W/W
    if (~isnan(N_modules(k)) && N_modules(k) > max_modules) || ...
       (~isnan(parasitic_frac) && parasitic_frac > max_parasitic_frac)
        stop_idx = k;
        break;
    end
end

% Trim vectors if stopped early
Q_MW       = Q_MW(1:stop_idx);
N_modules  = N_modules(1:stop_idx);
Pfan_MW    = Pfan_MW(1:stop_idx);
Vdot_m3s   = Vdot_m3s(1:stop_idx);
UA_margin  = UA_margin(1:stop_idx);
Tair_out_C = Tair_out_C(1:stop_idx);
N_TPCT     = N_TPCT(1:stop_idx);

% Baseline index (should be first element)
idx0 = find(abs(Q_MW - Q_base_MW) < 1e-6, 1, 'first');

% Percent deltas vs baseline
dPfan_pct    = 100*(Pfan_MW - Pfan_MW(idx0)) / Pfan_MW(idx0);
dModules_pct = 100*(N_modules - N_modules(idx0)) / N_modules(idx0);

%% ---------------- SUMMARY TABLE ----------------
T = table(Q_MW, N_modules, N_TPCT, Pfan_MW, Vdot_m3s, Tair_out_C, UA_margin, dPfan_pct, dModules_pct, ...
    'VariableNames', {'Q_total_MW','N_modules','N_TPCT_total','P_fan_MW','Vdot_air_m3s','T_air_out_C','UA_margin','dPfan_pct','dModules_pct'});

disp('==================== RESULTS SUMMARY (each step = new steady state) ====================');
disp(T);

%% ---------------- PLOTS ----------------
figure; plot(Q_MW, Pfan_MW, 'o-','LineWidth',1.5); grid on;
xlabel('Q_{total} [MW]'); ylabel('Fan parasitic power [MW]');
title('Steady-state sensitivity: P_{fan} vs Q_{total}');

figure; plot(Q_MW, dPfan_pct, 'o-','LineWidth',1.5); grid on;
xlabel('Q_{total} [MW]'); ylabel('\Delta P_{fan} vs baseline [%]');
title('Reactivity metric: % change in parasitic load');

%% =========================================================================
% MODEL WRAPPER (your vendorized sizing model, converted to a function)
% =========================================================================
function out = steam_sponge_model_run(Q_total_in)
% 0) SYSTEM-LEVEL INPUTS (TEAM VALUES)
% ========================================================================
% These are the top-level numbers your team already agreed on.
Q_total = Q_total_in;           % [W] swept input

% Ambient air side (TEAM SLIDES)
T_air_in_C  = 20;                 % [°C] ambient air inlet temperature (TEAM SLIDES)
P_amb       = 101325;             % [Pa] ambient pressure (TEAM SLIDES)
dT_air      = 15;                 % [K] allowed air temperature rise (TEAM SLIDES)
cp_air      = 1005;               % [J/kg-K] air specific heat (TEAM SLIDES)
rho_air     = 1.177;              % [kg/m^3] air density at design point (TEAM SLIDES)
dP_air      = 225;                % [Pa] allowed air pressure drop (TEAM SLIDES)
eta_fan     = 0.65;               % [-] fan+motor+drive efficiency (TEAM SLIDES)
crosswind_multiplier = 1.10;      % [-] airflow derate / multiplier (TEAM SLIDES)

% Coil "lumped" performance (TEAM SLIDES)
% This U_overall is a *design-level* overall coefficient (air-side dominated).
% In even more detailed coil design one would compute it from fin efficiency + j/f etc.
U_overall = 40;                   % [W/m^2-K] overall U (TEAM SLIDES)
F_LMTD    = 0.98;                 % [-] LMTD correction factor (TEAM SLIDES)

% Steam condition (TEAM SLIDES)
Tsat_C   = 65;                    % [°C] steam saturation temperature in receiver (TEAM SLIDES)
Psat_bar = 0.25;                  % [bar] saturation pressure (TEAM SLIDES)
x_in     = 0.88;                  % [-] steam quality at inlet (TEAM SLIDES)
x_out    = 0.0;                   % [-] quality after full condensation (design target)
h_fg     = 2.346e6;               % [J/kg] latent heat at ~65°C (TEAM SLIDES)

% Gravity (physical constant)
g = 9.81;                         % [m/s^2] gravity

% Condenser surface temperature target
% Must exceed air outlet temperature for heat to flow to air.
T_cond_surface_C = 62;            % [°C] (TEAM / DESIGN TARGET)

%% ========================================================================
% 1) FLUID PROPERTIES (WATER/STEAM + AIR)
% ========================================================================
% In a perfect model one would use IAPWS-IF97 or CoolProp.
% Here, we use a simple saturation-table helper for the 50–100°C range.
% This is adequate for preliminary sizing near 65°C.

st = satWater_simple(Tsat_C);     % [sat properties] (internal function below)

% Enthalpy of wet steam mixture in and saturated liquid out:
%   h_in = hf + x*hfg,  h_out = hf (since x_out=0).
% We use h_fg from your slides for consistency with your work, but the sat
% table provides a similar value.
h_in  = st.hf + x_in*h_fg;        % [J/kg] (TEAM h_fg + sat hf)
h_out = st.hf + x_out*h_fg;       % [J/kg]
dh    = h_in - h_out;             % [J/kg] heat removed per kg mixture

% Mass flow required to reject Q_total:
m_dot_mix   = Q_total/dh;         % [kg/s] total mixture mass flow (CALC)
m_dot_vapor = x_in*m_dot_mix;     % [kg/s] incoming vapor that condenses (CALC)

% Air dynamic viscosity and thermal conductivity:
% Your slides don’t specify mu_air and k_air. For preliminary work, we set
% typical values near ~25–30°C.
% If you want higher fidelity, replace these with CoolProp calls.
mu_air  = 1.90e-5;                % [Pa·s] typical air viscosity near room temp (ASSUMPTION)
k_air   = 0.027;                  % [W/m-K] typical air conductivity near room temp (ASSUMPTION)
Pr_air  = cp_air*mu_air/k_air;    % [-] Prandtl number (CALC)

%% ========================================================================
% 2) THERMOSYPHON (TPCT) GEOMETRY + MATERIAL (VENDOR-ORIENTED)
% ========================================================================
% Here we choose a geometry that matches *published* vendor language:
% ACT brochure for split-loop thermosyphon coil: "Half-inch diameter tubes"
% (interpreted as ~12.7 mm OD). (ACT HVAC brochure PDF, see link above.)

% --- Tube outside diameter (OD) ---
tp.OD = 0.0127;                   % [m] 1/2 inch = 12.7 mm (ACT brochure gives 1/2-inch tubes)

% --- Tube wall thickness and inside diameter (ID) ---
% ACT brochure does not provide wall thickness; for a defendable starting
% point we use a standard copper tube "Type L" wall thickness of ~0.040"
% for nominal 1/2" size (example supplier listing).
% Source (example): https://www.coppertubingsales.com/collections/copper-tubing-type-l
tp.t_wall = 0.001016;             % [m] 0.040 inch = 1.016 mm (ASTM B88 Type L typical)
tp.ID = tp.OD - 2*tp.t_wall;      % [m] derived internal diameter (CALC)

% --- Lengths ---
% These MUST come from the mechanical layout (CAD) and system constraints.
% Earlier code used Lev=1.5 m and Lco=3.0 m. We keep those as the
% current "team layout assumption" until a vendor drawing / final CAD exists.
tp.Lev = 1.50;                    % [m] evaporator length inside sponge (TEAM CAD ASSUMPTION)
tp.Lco = 3.00;                    % [m] condenser length in air coil region (TEAM CAD ASSUMPTION)

% --- Tube wall thermal conductivity ---
% If these TPCTs are copper tubes, copper k ~ 401 W/m-K at ~0°C (order is
% similar at room temp). We use 390 W/m-K as a conservative near-room value.
% Source: EngineeringToolbox copper k table.
% https://www.engineeringtoolbox.com/thermal-conductivity-metals-d_858.html
tp.k_wall = 390;                  % [W/m-K] copper tube wall conductivity (REFERENCE TABLE)

% --- Areas for heat transfer and wall conduction resistances ---
Aev_od = pi*tp.OD*tp.Lev;         % [m^2] external evaporator area (tube outside) (CALC)
Aev_id = pi*tp.ID*tp.Lev;         % [m^2] internal boiling area (CALC)
Aco_id = pi*tp.ID*tp.Lco;         % [m^2] internal condensation area (CALC)

% Conduction resistance of tube wall (cylindrical log conduction):
R_wall_ev = log(tp.OD/tp.ID)/(2*pi*tp.k_wall*tp.Lev);   % [K/W] (CALC)
R_wall_co = log(tp.OD/tp.ID)/(2*pi*tp.k_wall*tp.Lco);   % [K/W] (CALC)

%% ========================================================================
% 3) POROUS RECEIVER ("SPONGE/FOAM") (RECEMAT-BASED PLACEHOLDERS)
% ========================================================================
% For the foam, we select a Recemat grade whose datasheet explicitly gives
% porosity and specific surface area density.
%
% Example chosen grade: Recemat copper foam "Cu-1116"
% Datasheet gives:
%   Porosity = 95%   (eps = 0.95)
%   Specific surface ≈ 1000 m^2/m^3 (a_s = 1000)
% Source:
%   https://www.recemat.nl/wp-content/uploads/2020/08/Datasheet_Cu.pdf

foam.eps = 0.95;                  % [-] porosity (Recemat datasheet)
foam.a_s = 1000;                  % [m^2/m^3] specific surface area density (Recemat datasheet)

% The following are NOT typically given as a single number on Recemat’s short
% datasheet and should be requested from the vendor (or measured):
%   - effective thermal conductivity k_eff at your temperature and boundary
%   - permeability K_perm for liquid drainage (or pressure-drop curve)
%   - ligament thickness t_lig (or micrograph / strut thickness)
%
% Until you have those, we keep the same values you had in your updated code,
% but mark them clearly as "NEEDS VENDOR DATA".
foam.k_eff  = 5.8;                % [W/m-K] NEED VENDOR DATA (temporary team estimate)
foam.K_perm = 2e-8;               % [m^2]   NEED VENDOR DATA (temporary assumption)
foam.t_lig  = 0.0008;             % [m]     NEED VENDOR DATA (temporary assumption)

% Foam thickness between steam surface and TPCT tube (geometric design)
% This should come from your CAD.
foam.t_receiver = 0.020;          % [m] (TEAM CAD ASSUMPTION)

% Optional enhancement factor for condensation on porous surfaces.
% Use 1.0 unless you have test/literature support for your exact foam.
foam.F_cond_enh = 1.0;            % [-] NEED TEST/LITERATURE (default 1.0)

% Geometry: treat foam as annulus around tube evaporator section
r0 = tp.OD/2;                     % [m] tube outer radius (CALC)
r1 = r0 + foam.t_receiver;        % [m] outer foam radius (CALC)

A_cs_foam   = pi*(r1^2 - r0^2);   % [m^2] foam flow cross-section per TPCT (CALC)
V_foam      = A_cs_foam * tp.Lev; % [m^3] foam volume per TPCT evaporator (CALC)
A_foam_geom = foam.a_s * V_foam;  % [m^2] geometric internal foam area (CALC)

%% ========================================================================
% 4) STEAM-SIDE CONDENSATION HTC (NUSSELT FILM CONDENSATION)
% ========================================================================
% Physical meaning:
%   - Steam at Tsat condenses on cooler surfaces.
%   - A liquid film forms; heat flows through the film by conduction.
% Nusselt’s laminar-film condensation theory gives a baseline average h.
%
% We use a standard vertical-surface average form:
%   h = 0.943 * [ rhoL*(rhoL-rhoV)*g*hfg*kL^3 / (muL*L*ΔT) ]^(1/4)
%
% This gives order-of-magnitude realistic condensation HTCs without guessing.
% (You can later upgrade this to forced convection / shear-driven models if
% steam velocities are high.)

w = satWater_simple(Tsat_C);      % sat densities and hfg from table (internal function)

mu_l = muWater_simple(Tsat_C);    % [Pa·s] liquid viscosity (simple correlation)
k_l  = kWater_simple(Tsat_C);     % [W/m-K] liquid conductivity (simple correlation)

% Key sizing assumption: the temperature drop driving condensation.
% This depends on how cool the receiver surface is relative to Tsat.
dT_steam_receiver = 8;            % [K] TEAM DESIGN ASSUMPTION (explicit)

h_nusselt = hFilmCond_NusseltVertical( ...
    w.rho_l, w.rho_v, mu_l, k_l, h_fg, g, tp.Lev, dT_steam_receiver);  % (CORRELATION)

h_steam = foam.F_cond_enh * h_nusselt; % apply optional enhancement (default 1.0)

% Foam extended-surface efficiency:
% We treat ligaments as thin fins of characteristic thickness t_lig and
% length ~ foam thickness. This is conservative but physically motivated.
L_fin = foam.t_receiver;          % [m] fin length scale (geometry)
m = sqrt(2*h_steam/(foam.k_eff*foam.t_lig));  % [1/m] fin parameter (CALC)
eta_foam = tanh(m*L_fin)/(m*L_fin);           % [-] fin efficiency (CALC)
eta_foam = max(min(eta_foam,1),0.05);         % clamp to sane range (CODE SAFETY)

% Effective steam-side area per TPCT:
%   A_eff = tube OD area + (foam internal area * fin efficiency)
A_eff_steam = Aev_od + eta_foam*A_foam_geom;  % [m^2] (CALC)

% Steam-side thermal resistance (condensation film):
R_steam = 1/(h_steam*A_eff_steam);            % [K/W] (CALC)

%% ========================================================================
% 5) INTERNAL EVAPORATOR BOILING HTC (INSIDE TPCT EVAPORATOR)
% ========================================================================
% In a wickless thermosyphon evaporator, heat transfer can resemble pool
% boiling / thin-film evaporation on the inner wall.
%
% In preliminary design one typically does *not* compute this from first
% principles; instead you:
%   - ask the TPCT vendor for a performance curve, OR
%   - use a conservative internal boiling HTC range.
%
% Here we keep a conservative value and clearly mark it as "TPCT vendor input".
h_boil = 12000;                   % [W/m^2-K] NEED TPCT VENDOR DATA (placeholder)
R_boil = 1/(h_boil*Aev_id);       % [K/W] (CALC)

% Total evaporator-side resistance from steam to TPCT working fluid:
R_evap_total = R_steam + R_wall_ev + R_boil;  % [K/W] (CALC)

% Allowable evaporator temperature drop (design criterion)
dT_allow_evap = 12;               % [K] TEAM DESIGN CRITERION

%% ========================================================================
% 6) AIR-COOLED CONDENSER (PREFERRED: VENDOR MODULE UA)
% ========================================================================
% Because coil internal geometry is often proprietary, the most defensible
% approach is to use *vendor module surface area and overall U* we have. 
% This keeps the theory correct (Q = UA * F * LMTD) while avoiding
% reverse-engineering fin pitch/tube pitch.
%
% Vendor module used here: Kelvion RF-NC101E4H drycooler (example)
% - Surface area: 197.1 m^2  (spec)
% - Airflow: 19,400 m^3/h    (spec)
% - Dimensions: 2220x1610x1350 mm (L x W x H) (listing)
% Sources:
%   https://www.hosbv.com/data/specifications/15917_15917_Kelvion_RF-NC101E4H_Drycooler.pdf
%   https://hosbv.com/en/product/17499/condensers/Kelvion-RF-NC101E4H-.html

coil.vendor = 'Kelvion RF-NC101E4H (example drycooler module)';
coil.Ao_total_per_module = 197.1;            % [m^2] external surface area (Kelvion spec)
coil.airflow_m3ph = 19400;                   % [m^3/h] airflow (Kelvion spec)

% Convert airflow to SI volumetric flow:
coil.Vdot_air_mod = coil.airflow_m3ph/3600;  % [m^3/s] (CALC)

% Module footprint / frontal dimensions:
% From listing: sizes 2220 x 1610 x 1350 mm (L x W x H). We treat:
%   W = 1.610 m, H = 1.350 m as the frontal area (air passes through W×H).
coil.mod_W = 1.610;                          % [m] module width (Kelvion listing)
coil.mod_H = 1.350;                          % [m] module height (Kelvion listing)
coil.A_frontal = coil.mod_W*coil.mod_H;      % [m^2] (CALC)

% Face velocity implied by vendor airflow (useful sanity check):
V_face_vendor = coil.Vdot_air_mod/coil.A_frontal; % [m/s] (CALC)

% Air energy capacity per module (simple energy balance):
% Q = m_dot_air * cp * dT_air
mdot_air_mod = rho_air*coil.Vdot_air_mod;          % [kg/s] (CALC)
Qcap_mod = mdot_air_mod*cp_air*dT_air;             % [W] (CALC)

% Apply crosswind multiplier (if crosswind increases required flow / modules)
Qcap_mod_effective = Qcap_mod/crosswind_multiplier; % [W] (TEAM SLIDES multiplier)

% Modules needed by *air energy balance*:
N_modules = max(1, ceil(Q_total/Qcap_mod_effective)); % [-] integer count (CALC)

% Total airflow and estimated fan power (using your slide dP and eta_fan):
Vdot_air_total = coil.Vdot_air_mod*N_modules;          % [m^3/s] (CALC)
P_fan_total = dP_air*Vdot_air_total/eta_fan;           % [W] (CALC)

% Now check UA requirement using LMTD:
T_air_out_C = T_air_in_C + dT_air;                     % [°C] (CALC)
DT1 = T_cond_surface_C - T_air_in_C;                   % [K] (CALC)
DT2 = T_cond_surface_C - T_air_out_C;                  % [K] (CALC)

% LMTD for a constant-temperature condensing surface vs air warming:
DTlm = (DT1 - DT2)/log(DT1/DT2);                       % [K] (CALC)

UA_req = Q_total/(F_LMTD*DTlm);                        % [W/K] required UA (TEAM F_LMTD)

% Available UA from modules:
UA_avail = U_overall * coil.Ao_total_per_module * N_modules; % [W/K] (TEAM U_overall + vendor Ao)

UA_margin = UA_avail/UA_req;                           % [-] >1 means enough UA

%% ========================================================================
% 7) TPCT HEAT-TRANSPORT LIMITS (FLOODING + BOILING + SONIC CHECK)
% ========================================================================
% Even if the air cooler has enough UA, each TPCT can only carry so much
% heat before hitting internal limits. For wickless thermosyphons, flooding
% / entrainment is often dominant at high powers.
%
% We keep the same functional forms as your code (engineering correlation).
%
% Representative TPCT operating temperature:
T_tp_C = (Tsat_C + T_cond_surface_C)/2;                 % [°C] (TEAM ASSUMPTION)
wt = satWater_simple(T_tp_C);                            % sat properties (internal)

% Surface tension of water from IAPWS 2014 (official)
sigma_w = surfaceTension_IAPWS2014(T_tp_C);              % [N/m] (IAPWS 2014)

A_v = pi*(tp.ID^2)/4;                                    % [m^2] vapor core area (CALC)

% Flooding limit correlation (engineering form)
Qmax_flood = QmaxFlood_FaghriStyle(tp.ID, A_v, wt.rho_l, wt.rho_v, h_fg, sigma_w, g); % (CORRELATION)
Qmax_design = 0.60*Qmax_flood;                            % [W] design margin factor (TEAM CHOICE)

% Boiling/CHF margin using Zuber pool boiling CHF (very conservative bound)
qCHF_frac = 0.30;                                         % [-] design criterion (TEAM)
qCHF_Zuber = CHF_ZuberPoolBoiling(wt.rho_l, wt.rho_v, h_fg, sigma_w, g); % [W/m^2] (CORRELATION)
Qmax_boil = qCHF_frac*qCHF_Zuber * (pi*tp.ID*tp.Lev);     % [W] (CALC)

% Sonic limit check (rough):
% Speed of sound for steam ~400 m/s order at these conditions. This should
% be replaced by a property call if you need tight accuracy.
a_v = 430;                                                % [m/s] TEAM ASSUMPTION
G_sonic_allow = 0.25*wt.rho_v*a_v;                         % [kg/m^2/s] conservative fraction (TEAM)
Qmax_sonic = G_sonic_allow*A_v*h_fg;                       % [W] (CALC)

% TPCT maximum per-pipe heat transport:
Qmax_tpct = min([Qmax_design, Qmax_boil, Qmax_sonic]);     % [W] (CALC)

%% ========================================================================
% 8) NUMBER OF THERMOSYPHONS REQUIRED (BASED ON LIMITS + TEMPERATURE DROP)
% ========================================================================
% We size N_pipes so that:
%   (1) each pipe carries less than Qmax_tpct, AND
%   (2) evaporator-side temperature drop is within dT_allow_evap.
%
% Condenser-side resistances:
% Internal condensation HTC in TPCT condenser is also a vendor input.
h_cond_int = 12000;                                       % [W/m^2-K] NEED TPCT VENDOR DATA
R_cond_int = 1/(h_cond_int*Aco_id);                        % [K/W] (CALC)

% Air-side resistance per pipe is taken from the *module UA* approach:
% We assign each pipe an equal share of total UA. This is a simplification,
% but good for preliminary sizing when pipes are evenly distributed.
%
% Total air-side resistance = 1 / UA_avail_total
R_air_total = 1/(UA_avail);                                % [K/W] (CALC)

% Now find N_pipes with an adaptive loop:
N_pipes = 5000;                                            % [-] initial guess (TEAM GUESS)
while true
    Q_pipe = Q_total/N_pipes;                              % [W] per-pipe duty (CALC)

    % Evaporator temperature drop:
    dT_evap = Q_pipe*R_evap_total;                         % [K] (CALC)

    % Condenser temperature drop per pipe:
    % Each pipe shares air-side UA equally, so air-side R per pipe scales with N_pipes.
    R_air_per_pipe = R_air_total * N_pipes;                % [K/W] (CALC)
    R_cond_total = R_cond_int + R_wall_co + R_air_per_pipe;% [K/W] (CALC)
    dT_cond = Q_pipe*R_cond_total;                         % [K] (CALC)

    limits_ok = (Q_pipe <= Qmax_tpct);
    dT_ok     = (dT_evap <= dT_allow_evap);

    if limits_ok && dT_ok
        break;
    end

    % Increase pipe count; larger steps if limit violation is big
    if ~limits_ok
        N_pipes = N_pipes + 2000;
    else
        N_pipes = N_pipes + 500;
    end
end

Q_pipe = Q_total/N_pipes;                                  % [W] (CALC)
dT_evap = Q_pipe*R_evap_total;                             % [K] (CALC)
dT_cond = Q_pipe*R_cond_total;                             % [K] (CALC)
dT_total_pipe = dT_evap + dT_cond;                          % [K] (CALC)

%% ========================================================================
% 9) CONDENSATE DRAINAGE CHECK IN POROUS RECEIVER (DARCY)
% ========================================================================
% Steam condensate produced is approximately the incoming vapor mass flow.
m_dot_cond_total = m_dot_vapor;                             % [kg/s] (CALC)

% Condensate per pipe:
m_dot_cond_per_pipe = m_dot_cond_total/N_pipes;             % [kg/s] (CALC)
Vdot_cond_per_pipe = m_dot_cond_per_pipe / w.rho_l;         % [m^3/s] (CALC)

% Darcy superficial velocity through foam annulus:
v_Darcy = Vdot_cond_per_pipe / A_cs_foam;                   % [m/s] (CALC)

% Darcy pressure drop required: dP/dz = mu * v / K
dP_dz = mu_l * v_Darcy / foam.K_perm;                       % [Pa/m] (CALC)
dP_total = dP_dz * tp.Lev;                                  % [Pa] (CALC)

% Available hydrostatic head (liquid column height ~ Lev):
dP_head = w.rho_l*g*tp.Lev;                                 % [Pa] (CALC)

drain_ok = (dP_total <= 0.5*dP_head);                       % [-] 50% margin (TEAM CRITERION)

%% ========================================================================
% 10) REPORT (HUMAN-READABLE OUTPUT)
% ========================================================================
fprintf('\n==================== DESIGN REPORT (VENDOR-AWARE) ====================\n');
fprintf('TOTAL DUTY: Q_total = %.2f MW\n', Q_total/1e6);

fprintf('\n--- Steam side ---\n');
fprintf('Steam Tsat=%.1f C (Psat~%.2f bar), x_in=%.2f\n', Tsat_C, Psat_bar, x_in);
fprintf('Mixture flow m_dot_mix = %.2f kg/s; vapor to condense m_dot_vapor = %.2f kg/s\n', m_dot_mix, m_dot_vapor);

fprintf('\n--- Condensation on receiver ---\n');
fprintf('Assumed ΔT(sat-to-surface)=%.1f K\n', dT_steam_receiver);
fprintf('Nusselt film h_nusselt=%.0f W/m^2K; foam enhancement F=%.2f => h_steam=%.0f W/m^2K\n', h_nusselt, foam.F_cond_enh, h_steam);
fprintf('Foam fin efficiency eta_foam=%.3f; A_eff_steam per TPCT=%.3f m^2\n', eta_foam, A_eff_steam);

fprintf('\n--- Air cooler modules (Kelvion example) ---\n');
fprintf('Vendor module: %s\n', coil.vendor);
fprintf('Ao per module=%.1f m^2; airflow per module=%.1f m^3/s; implied face V=%.2f m/s\n', ...
    coil.Ao_total_per_module, coil.Vdot_air_mod, V_face_vendor);
fprintf('Air energy per module Qcap_mod=%.1f kW (before crosswind factor)\n', Qcap_mod/1e3);
fprintf('Crosswind multiplier=%.2f => effective Qcap_mod=%.1f kW\n', crosswind_multiplier, Qcap_mod_effective/1e3);
fprintf('Modules by air energy balance: N_modules=%d\n', N_modules);
fprintf('Total airflow=%.1f m^3/s; fan power≈%.2f MW (ΔP=%.0f Pa, η=%.2f)\n', Vdot_air_total, P_fan_total/1e6, dP_air, eta_fan);

fprintf('\n--- UA check (vendor surface + slide U_overall) ---\n');
fprintf('T_cond_surface=%.1f C, air in=%.1f C, air out=%.1f C => LMTD=%.2f K\n', ...
    T_cond_surface_C, T_air_in_C, T_air_out_C, DTlm);
fprintf('UA required = %.3e W/K (includes F_LMTD=%.2f)\n', UA_req, F_LMTD);
fprintf('UA available = %.3e W/K (U_overall=%.1f, Ao_total=%g m^2, modules=%d)\n', ...
    UA_avail, U_overall, coil.Ao_total_per_module, N_modules);
fprintf('UA margin (avail/req) = %.2f\n', UA_margin);

fprintf('\n--- TPCT per-pipe limits ---\n');
fprintf('Qmax_flood*0.60=%.2f kW, Qmax_boil=%.2f kW, Qmax_sonic=%.2f kW => Qmax_tpct=%.2f kW\n', ...
    Qmax_design/1e3, Qmax_boil/1e3, Qmax_sonic/1e3, Qmax_tpct/1e3);

fprintf('\n--- Selected TPCT count (preliminary) ---\n');
fprintf('N_pipes=%d => Q_pipe=%.2f kW\n', N_pipes, Q_pipe/1e3);
fprintf('Per-pipe ΔT_evap=%.2f K (allow %.1f K), ΔT_cond=%.2f K, total ΔT≈%.2f K\n', ...
    dT_evap, dT_allow_evap, dT_cond, dT_total_pipe);

fprintf('\n--- Condensate drainage (Darcy) ---\n');
fprintf('Per-pipe condensate Vdot=%.3e m^3/s; Darcy v=%.3e m/s\n', Vdot_cond_per_pipe, v_Darcy);
fprintf('Required ΔP across Lev: %.0f Pa; available hydrostatic head: %.0f Pa => drain_ok=%d\n', ...
    dP_total, dP_head, drain_ok);

fprintf('=======================================================================\n');

%% ========================================================================

% -------- PACK OUTPUTS --------
out = struct();
out.Q_total_W = Q_total;
if exist('N_modules','var'); out.N_modules = N_modules; end
if exist('P_fan_total','var'); out.P_fan_total_W = P_fan_total; end
if exist('Vdot_air_total','var'); out.Vdot_air_total_m3s = Vdot_air_total; end
if exist('mdot_air_total','var'); out.mdot_air_total_kgs = mdot_air_total; end
if exist('T_air_out_C','var'); out.T_air_out_C = T_air_out_C; end
if exist('UA_req','var'); out.UA_req_WK = UA_req; end
if exist('UA_avail','var'); out.UA_avail_WK = UA_avail; end
if exist('UA_margin','var'); out.UA_margin = UA_margin; end
if exist('Qcap_mod_effective','var'); out.Qcap_mod_effective_W = Qcap_mod_effective; end
if exist('coil','var')
    if isfield(coil,'Ao_total_per_module'); out.Ao_total_per_module_m2 = coil.Ao_total_per_module; end
    if isfield(coil,'Vdot_air_mod'); out.Vdot_air_mod_m3s = coil.Vdot_air_mod; end
    if isfield(coil,'A_frontal'); out.A_frontal_m2 = coil.A_frontal; end
    if isfield(coil,'mod_W'); out.mod_W_m = coil.mod_W; end
    if isfield(coil,'mod_H'); out.mod_H_m = coil.mod_H; end
end
if exist('N_TPCT_total','var'); out.N_TPCT_total = N_TPCT_total; end
if exist('Qmax_TPCT_flood_W','var'); out.Qmax_TPCT_flood_W = Qmax_TPCT_flood_W; end
if exist('qpp_evap','var'); out.qpp_evap_Wm2 = qpp_evap; end
if exist('qpp_CHF','var'); out.qpp_CHF_Wm2 = qpp_CHF; end

end

% =========================================================================
% ORIGINAL SUBFUNCTIONS FROM MODEL_2 (unchanged)
% =========================================================================
function st = satWater_simple(T_C)
% satWater_simple
%   Quick saturated-water lookup for 50–100°C, linear interpolation.
%   Returns:
%     psat [Pa], rho_l [kg/m3], rho_v [kg/m3], hf [J/kg], hfg [J/kg]
%
%   Source of numbers: typical steam tables (embedded dataset).
%   Upgrade path: replace with IF97 (IAPWS) or CoolProp for production work.

T = [50 55 60 65 70 75 80 85 90 95 100];
ps_MPa = [0.012352 0.015761 0.019946 0.025042 0.031201 0.038563 0.047373 0.057834 0.070140 0.084552 0.101325];
rho_l  = [988.05 985.65 983.16 980.52 977.76 974.89 971.91 968.82 965.62 962.33 958.37];
rho_v  = [0.08302 0.10266 0.13043 0.16146 0.19833 0.24418 0.29216 0.34569 0.41451 0.49220 0.59752];
hf_kJ  = [209.33 230.23 251.18 272.12 292.98 313.93 334.91 355.90 376.92 397.96 419.04];
hfg_kJ = [2382.7 2370.7 2357.7 2345.4 2333.8 2321.4 2308.8 2296.0 2283.2 2270.2 2257.0];

T_C = max(min(T_C, max(T)), min(T));

st.psat = interp1(T, ps_MPa, T_C, 'linear')*1e6;
st.rho_l = interp1(T, rho_l,  T_C, 'linear');
st.rho_v = interp1(T, rho_v,  T_C, 'linear');
st.hf  = interp1(T, hf_kJ,  T_C, 'linear')*1e3;
st.hfg = interp1(T, hfg_kJ, T_C, 'linear')*1e3;
end

function mu = muWater_simple(T_C)
% muWater_simple
%   Rough liquid water viscosity correlation (Andrade-type).
%   Valid-ish for ~0–100°C. Replace with IAPWS viscosity for higher fidelity.
T = T_C + 273.15;
mu = 2.414e-5*10^(247.8/(T-140));
end

function k = kWater_simple(T_C)
% kWater_simple
%   Rough liquid water thermal conductivity fit, 0–100°C.
k = 0.561 + 0.0019*T_C - 1.0e-5*T_C.^2;
end

function h = hFilmCond_NusseltVertical(rhoL, rhoV, muL, kL, hfg, g, L, dT)
% hFilmCond_NusseltVertical
%   Nusselt laminar film condensation on a vertical surface (average h).
%   h = 0.943 * [ rhoL*(rhoL-rhoV)*g*hfg*kL^3 / (muL*L*dT) ]^(1/4)
h = 0.943 * (rhoL*(rhoL-rhoV)*g*hfg*kL^3/(muL*L*max(dT,1e-6)))^(1/4);
end

function sigma = surfaceTension_IAPWS2014(T_C)
% surfaceTension_IAPWS2014
%   Official IAPWS (2014) surface tension correlation:
%     sigma = B * tau^mu * (1 + b*tau),  tau = 1 - T/Tc
%   Parameters from IAPWS PDF:
%     Tc=647.096 K, B=235.8 mN/m, mu=1.256, b=-0.625
%   Source: https://iapws.org/public/documents/CH-L9/Surf-H2O-2014.pdf
T = T_C + 273.15;
Tc = 647.096;
tau = 1 - T/Tc;
B = 235.8e-3;  mu = 1.256;  b = -0.625;
sigma = B*(tau^mu)*(1 + b*tau);
end

function Qmax = QmaxFlood_FaghriStyle(D, Av, rhoL, rhoV, hfg, sigma, g)
% QmaxFlood_FaghriStyle
%   Engineering flooding/entrainment limit form for wickless thermosyphons.
%   Used as a practical bound; vendor data should replace if available.
Bo = sqrt((rhoL - rhoV)*g*D^2/sigma);
K  = (rhoL/rhoV)^0.14 * (tanh(sqrt(Bo)))^2;
term1 = (g*sigma*(rhoL - rhoV))^(0.25);
term2 = (rhoV^(-0.5) + rhoL^(-0.5))^(-2);
Qmax = K*hfg*Av*term1*term2;
end

function qCHF = CHF_ZuberPoolBoiling(rhoL, rhoV, hfg, sigma, g)
% CHF_ZuberPoolBoiling
%   Zuber CHF correlation for pool boiling (large horizontal surface):
%   q''_CHF = 0.131 * hfg * rhoV^(1/2) * [ sigma*g*(rhoL-rhoV) ]^(1/4)
qCHF = 0.131 * hfg * sqrt(rhoV) * (sigma*g*(rhoL-rhoV))^(1/4);
end
